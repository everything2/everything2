#!/usr/bin/perl -w
# Account emails: mail templates are filled per message (never in the shared cached template),
# every placeholder form is filled, and development keeps each email in the dev mail spool
# where tools/test-password-reset.pl and the e2e specs read it back.

use strict;
use warnings;
use utf8;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use File::Temp ();
use JSON;
use Everything;
use Everything::API::signup;
use Everything::API::password;
use MockRequest;

initEverything('development-docker');
my $APP = $Everything::APP;

# Each test writes to its own spool directory.
my $spool_dir = File::Temp->newdir;
local $Everything::Application::DEV_MAIL_SPOOL = "$spool_dir";

sub spooled_to {
    my ($addr) = @_;
    my @mail;
    for my $file ( sort glob("$spool_dir/*.json") ) {
        open( my $fh, '<:raw', $file ) or die "$file: $!";
        my $m = decode_json( do { local $/; <$fh> } );
        push @mail, $m if grep { lc($_) eq lc($addr) } @{ $m->{to} };
    }
    return @mail;
}

my @made;    # accounts to remove at the end
END {
    my $root = $DB->getNode( 'root', 'user' );
    for my $user ( grep { $_ } map { $DB->getNodeById($_) } @made ) {
        eval { $DB->nukeNode( $user, $root, 1 ); 1 } or diag("cleanup of $user->{title} failed: $@");
    }
}

my $tag = substr( sprintf( '%x', time() ), -6 ) . ( $$ % 100 );    # usernames max out at 20 characters

subtest 'mail_from_template fills every placeholder form, in a copy' => sub {
    my $template = $DB->getNode( 'Welcome to Everything2', 'mail' );
    ok( $template, 'the activation template exists' );
    my $before = $template->{doctext};

    my $mail = $APP->mail_from_template( 'Welcome to Everything2',
        { name => 'Alice', link => '/node/superdoc/Confirm+password?user=Alice', servername => 'example.test' } );
    like( $mail->{doctext}, qr{https://example\.test/node/superdoc/Confirm\+password\?user=Alice}, 'link filled' );
    unlike( $mail->{doctext}, qr/<(?:name|link|servername)>|&lt;(?:name|link|servername)&gt;/, 'no placeholders left' );
    is( $DB->getNode( 'Welcome to Everything2', 'mail' )->{doctext}, $before, 'the cached template is unchanged' );

    # Every form a template may use.
    local $template->{doctext} = "\x{AB}name\x{BB} &#171;name&#187; <name> &lt;name&gt;";
    is( $APP->mail_from_template( 'Welcome to Everything2', { name => 'Bob' } )->{doctext},
        'Bob Bob Bob Bob', 'guillemets, entity guillemets, angle brackets, encoded angle brackets' );
};

subtest 'two signups in a row each get their own activation email' => sub {
    for my $n ( 1, 2 ) {
        my $username = "mt${n}_$tag";
        my $email    = "$username\@test.example.com";
        my $r = Everything::API::signup->new->create_account( MockRequest->new(
            node_id => 0, title => 'Guest User', is_guest_flag => 1, request_method => 'POST',
            postdata => encode_json( { username => $username, password => 'mailpass123', email => $email } ),
        ) );
        is( $r->[1]{success}, 1, "signup $n accepted" ) or diag explain $r->[1];
        my $user = $DB->getNode( $username, 'user' );
        push @made, $user->{node_id} if $user;

        my @mail = spooled_to($email);
        is( scalar(@mail), 1, "signup $n: one email to its own address" );
        my $body = $mail[0]{body} // '';
        is( $mail[0]{subject}, 'Welcome to Everything2', "signup $n: the activation email" );
        like( $body, qr/\Q$username\E/, "signup $n: addressed to its own user" );
        like( $body, qr{href="https://[^"]*Confirm\+password[^"]*user=\Q$username\E}, "signup $n: its own activation link" );
        unlike( $body, qr/<(?:name|link|servername)>/, "signup $n: no placeholders left" );
    }
};

subtest 'a reset request for an account never activated sends a working activation email' => sub {
    my $username = "mt3_$tag";
    my $email    = "$username\@test.example.com";
    my $user = $APP->create_user( $username, 'firstpass123', $email );
    ok( $user, 'unactivated account created' );
    push @made, $user->{node_id} if $user;

    my $r = Everything::API::password->new->reset_request( MockRequest->new(
        postdata => { who => $username, password => 'secondpass123', passwordConfirm => 'secondpass123' } ) );
    is( $r->[1]{success}, 1, 'request accepted' );
    my ($mail) = spooled_to($email);
    ok( $mail, 'an email went to the account' );
    is( $mail->{subject}, 'Welcome to Everything2', 'it is the activation email' );
    my $host = $Everything::CONF->canonical_web_server;
    like( $mail->{body}, qr{href="https://\Q$host\E/[^"]*Confirm\+password[^"]*action=activate}, 'with a working activation link' );
    like( $mail->{body}, qr{href="[^"]*Confirm\+password[^"]*user=\Q$username\E}, '... for this account' );
    unlike( $mail->{body}, qr/<(?:name|link|servername)>/, 'no placeholders left' );
};

done_testing();
