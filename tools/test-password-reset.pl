#!/usr/bin/perl
# Show the password reset email, and the link in it, for a development account.
#
# Development sends no mail: node2mail keeps a copy of each message in the dev mail spool
# instead (Everything::Application::dev_mail_spool). This tool reads it back.
#
#   test-password-reset.pl --sent <username>
#       The newest email already sent to that user, e.g. after using the Reset password form.
#
#   test-password-reset.pl <username> [new_password]
#       Make a reset request first, through the same API code the Reset password form uses
#       (Everything::API::password), then show the email it sent. new_password defaults to
#       newpassword123.
#
# Either way it prints the email and then, under COPY-PASTE URL, the link from it pointed at
# the local dev server (http://localhost:9080). Exits non-zero if no email is found.
#
#   docker exec e2devapp perl /var/everything/tools/test-password-reset.pl normaluser1 mynewpass
#
# Used by tests/e2e/password-reset.spec.js. Development only.

use strict;
use warnings;
use lib '/var/libraries/lib/perl5';
use lib '/var/everything/ecore';

use Everything;
use Everything::API::password;
use JSON;

initEverything();

my $APP = $Everything::APP;
my $DB  = $APP->{db};
die "ERROR: development only\n" unless $APP->inDevEnvironment;

my $sent_only = @ARGV && $ARGV[0] eq '--sent' ? shift(@ARGV) : 0;
my ( $username, $new_password ) = @ARGV;
$new_password //= 'newpassword123';
die "Usage: $0 [--sent] <username> [new_password]\n" unless $username;

my $user = $DB->getNode( $username, 'user' ) or die "ERROR: User '$username' not found\n";
my $email = $user->{email} or die "ERROR: '$username' has no email address\n";

my $since = time();
unless ($sent_only) {
    # reset_request reads only the JSON body from its request.
    my $request = bless { who => $username, password => $new_password, passwordConfirm => $new_password }, 'ResetToolRequest';
    my $r = Everything::API::password->new->reset_request($request);
    die 'ERROR: reset request refused: ' . ( $r->[1]{error} // 'unknown' ) . "\n" unless $r->[1]{success};
    print "Reset requested for $username: $r->[1]{message}\n\n";
}

# The newest spooled message to this user (made by this run's request, unless --sent).
my $spool = $Everything::Application::DEV_MAIL_SPOOL;
my ($mail) =
    grep { $sent_only || $_->{sent} >= $since }
    grep { grep { lc($_) eq lc($email) } @{ $_->{to} || [] } }
    map  { my $f = $_; my $m = eval { open( my $fh, '<:raw', $f ) or die; local $/; decode_json(<$fh>) }; $m ? ($m) : () }
    reverse sort glob("$spool/*.json");
die "ERROR: no email to $email in $spool\n" unless $mail;

print '-' x 60, "\nEMAIL\n", '-' x 60, "\n";
print "To: @{ $mail->{to} }\nSubject: $mail->{subject}\n\n$mail->{body}\n\n";

# The link a mail client would follow: the href, entities decoded, pointed at local dev.
my ($href) = $mail->{body} =~ m{href="([^"]*Confirm\+password[^"]*)"}
    or die "ERROR: no Confirm password link in the email\n";
( my $link = $href ) =~ s/&amp;/&/g;
my $host = $Everything::CONF->canonical_web_server;
$link =~ s{^https?://\Q$host\E}{http://localhost:9080};

print '-' x 60, "\nCOPY-PASTE URL\n", '-' x 60, "\n\n$link\n\n";
print "Open it, enter the new password, then log in as $username with it.\n" unless $sent_only;

package ResetToolRequest;
sub JSON_POSTDATA { return { %{ $_[0] } } }
