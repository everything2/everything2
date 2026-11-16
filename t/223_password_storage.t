#!/usr/bin/perl -w
#
# Password storage forms (Application "Password storage"): the rules, login through the app
# (form and cookie) for every form, password reset, and the one-time migration of pre-salt
# accounts (Everything::PasswordMigration).
#
use strict;
use warnings;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5);
use Test::More;
use JSON;
use URI::Escape qw(uri_escape_utf8);
use Everything;
use Everything::PasswordMigration;

initEverything 'everything';

my $app = eval { do '/var/everything/app.psgi' };
plan skip_all => "app.psgi unavailable: $@" unless ref $app eq 'CODE';
require Plack::Test;
require HTTP::Request::Common;
my $test = Plack::Test->create($app);

my $LEGACY = $APP->LEGACY_PASSWD_PREFIX;
my $NONE   = $APP->NO_PASSWORD;
my $stamp  = time() . $$;
my @created;

# A throwaway user stored in a given form.
sub make_user {
    my ( $tag, $passwd, $salt ) = @_;
    my $title = "pwtest_${tag}_$stamp";
    my $id = $DB->insertNode( $title, 'user', -1, {} ) or die "could not create $title";
    push @created, $id;
    $DB->{dbh}->do( 'UPDATE user SET passwd = ?, salt = ?, acctlock = 0 WHERE user_id = ?', undef, $passwd, $salt, $id );
    $DB->{dbh}->do( 'UPDATE node SET author_user = ? WHERE node_id = ?', undef, $id, $id );    # users author themselves (create_user)
    $APP->node_by_id($id)->cache_refresh;
    return { id => $id, title => $title };
}

sub stored { my ($u) = @_; return $DB->{dbh}->selectrow_hashref( 'SELECT passwd, salt FROM user WHERE user_id = ?', undef, $u->{id} ) }

sub form_login {
    my ( $u, $password ) = @_;
    my $res = $test->request( HTTP::Request::Common::POST( '/api/sessions/create',
        'Content-Type' => 'application/json', Content => encode_json( { username => $u->{title}, passwd => $password } ) ) );
    my $json = eval { decode_json( $res->content ) } || {};
    my ($cookie) = map { /^([^;]+)/ } grep { /^\Q$Everything::CONF->{cookiepass}\E=/ } $res->header('Set-Cookie');
    return ( ( $json->{user} && $json->{user}{title} // '' ) eq $u->{title} ? 1 : 0, $cookie );
}

sub cookie_login {
    my ( $u, $cookie_pass, $raw ) = @_;
    my $cookie = $raw // ( $Everything::CONF->cookiepass . '=' . uri_escape_utf8("$u->{title}|$cookie_pass") );
    my $res = $test->request( HTTP::Request::Common::GET( '/api/sessions', Cookie => $cookie ) );
    my $json = eval { decode_json( $res->content ) } || {};
    return ( ( $json->{user} && $json->{user}{title} // '' ) eq $u->{title} ) ? 1 : 0;
}

# ---- the rules ---------------------------------------------------------------------------------
{
    my ( $hash, $salt ) = $APP->saltNewPassword('correct horse');
    my %u = (
        hashed      => { passwd => $hash, salt => $salt },
        plain_short => { passwd => 'abc123', salt => undef },
        plain_10    => { passwd => 'abcdefghij', salt => '' },
        plain_long  => { passwd => 'abcdefghijklm', salt => undef },    # stored >10 (21 such rows in prod)
        empty       => { passwd => '', salt => undef },
        null        => { passwd => undef, salt => undef },
        marker      => { passwd => $NONE, salt => $APP->new_password_salt },
        pending     => { passwd => 'sometoken|1999999999', salt => $APP->new_password_salt },
    );
    is( $APP->password_kind( $u{hashed} ),      'hashed',    'kind: hashed' );
    is( $APP->password_kind( $u{plain_short} ), 'plaintext', 'kind: pre-salt' );
    is( $APP->password_kind( $u{empty} ),       'none',      'kind: empty is no password' );
    is( $APP->password_kind( $u{null} ),        'none',      'kind: NULL is no password' );
    is( $APP->password_kind( $u{marker} ),      'none',      'kind: the no-password marker' );
    is( $APP->password_kind( $u{pending} ),     'hashed',    'kind: awaiting activation reads as hashed' );

    ok( $APP->check_password( $u{hashed}, 'correct horse' ),         'hashed: right password' );
    ok( !$APP->check_password( $u{hashed}, 'correct horsf' ),        'hashed: wrong password' );
    ok( $APP->check_password( $u{plain_short}, 'abc123' ),          'pre-salt: right password' );
    ok( $APP->check_password( $u{plain_10}, 'abcdefghijXYZ' ),       'pre-salt: first 10 characters are what counted' );
    ok( !$APP->check_password( $u{plain_10}, 'abcdefghi' ),          'pre-salt: but all 10 are needed' );
    ok( $APP->check_password( $u{plain_long}, 'abcdefghijklm' ),     'pre-salt stored over 10: the full value works' );
    ok( !$APP->check_password( $u{pending}, 'sometoken|1999999999' ), 'awaiting activation: nothing matches' );
    for my $k (qw(empty null marker)) {
        ok( !$APP->check_password( $u{$k}, $_ ), "$k: '$_' does not match" ) for ( '', 'x', $NONE, '!no-passw' );
        ok( !$APP->check_password_cookie( { %{ $u{$k} }, title => 'x' }, $_, "x|$_" ), "$k: cookie '$_' does not match" ) for ( '', 'x', $NONE );
    }

    # migrated values accept exactly what the old one did
    for my $k (qw(plain_short plain_10 plain_long)) {
        my ( $p, $s ) = $APP->migrated_legacy_password( $u{$k} );
        my $m = { passwd => $p, salt => $s };
        is( $APP->password_kind($m), 'legacy', "$k migrates to the legacy form" );
        unlike( $p, qr/\Q$u{$k}{passwd}\E/, "$k: the stored value no longer contains the password" );
        ok( $APP->check_password( $m, $u{$k}{passwd} ), "$k: the old password still works" );
        ok( !$APP->check_password( $m, 'wrong' ), "$k: a wrong one doesn't" );
    }
    isnt( ( $APP->migrated_legacy_password( $u{plain_10} ) )[1], ( $APP->migrated_legacy_password( $u{plain_10} ) )[1], 'each migration gets its own salt' );
    for my $k (qw(empty null)) {
        my ( $p, $s ) = $APP->migrated_legacy_password( $u{$k} );
        is( $p, $NONE, "$k migrates to the no-password marker" );
        ok( length($s), "$k gets a salt too" );
    }
    is( scalar( () = $APP->migrated_legacy_password( $u{hashed} ) ),  0, 'hashed accounts are not migrated' );
    is( scalar( () = $APP->migrated_legacy_password( $u{pending} ) ), 0, 'accounts awaiting activation are not migrated' );
    is( scalar( () = $APP->migrated_legacy_password( $u{marker} ) ),  0, 'already-migrated accounts are not migrated again' );
}

# ---- login through the app ----------------------------------------------------------------------
{
    my $u = make_user( 'hashed', $APP->saltNewPassword('normal-pass-1') );
    my $before = stored($u);
    my ( $ok, $cookie ) = form_login( $u, 'normal-pass-1' );
    ok( $ok, 'a normal account logs in' );
    ok( $cookie && cookie_login( $u, undef, $cookie ), 'and its cookie works' );
    ok( !( form_login( $u, 'normal-pass-2' ) )[0], 'a wrong password does not' );
    is_deeply( stored($u), $before, 'and nothing is rewritten' );
}

for my $case (
    [ 'short',  'pa55wd',     'pa55wd' ],
    [ 'ten',    'abcdefghij', 'abcdefghijKLMNOP' ],    # typed longer than the 10 stored characters
) {
    my ( $tag, $stored_plain, $typed ) = @$case;

    my $pre = make_user( "pre_$tag", $stored_plain, undef );
    ok( cookie_login( $pre, $stored_plain ), "pre-salt ($tag): an existing cookie still works before migration" );
    my ($ok) = form_login( $pre, $typed );
    ok( $ok, "pre-salt ($tag): logs in" );
    my $after = stored($pre);
    is( $APP->password_kind($after), 'hashed', "pre-salt ($tag): upgraded to a normal hash on login" );
    ok( ( form_login( $pre, $typed ) )[0], "pre-salt ($tag): the full password works afterwards" );
    ok( !cookie_login( $pre, $stored_plain ), "pre-salt ($tag): the old cookie no longer works" );

    my $mig = make_user( "mig_$tag", $APP->migrated_legacy_password( { passwd => $stored_plain, salt => undef } ) );
    ($ok) = form_login( $mig, $typed );
    ok( $ok, "migrated ($tag): logs in with what worked before" );
    is( $APP->password_kind( stored($mig) ), 'hashed', "migrated ($tag): upgraded to a normal hash on login" );
    ok( ( form_login( $mig, $typed ) )[0], "migrated ($tag): the full password works afterwards" );
    if ( length($typed) > 10 ) {
        ok( !( form_login( $mig, substr( $typed, 0, 10 ) ) )[0], "migrated ($tag): and only the full password, once upgraded" );
    }
}

{
    # Many old pre-salt accounts carry a zero lasttime. Logging in (which upgrades the password)
    # and resetting must work for them under dev's strict sql_mode too.
    my $u = make_user( 'zero_lasttime', 'olduser1', undef );
    my ($mode) = $DB->{dbh}->selectrow_array('SELECT @@SESSION.sql_mode');
    $DB->{dbh}->do(q{SET SESSION sql_mode = ''});
    $DB->{dbh}->do( q{UPDATE user SET lasttime = '0000-00-00 00:00:00' WHERE user_id = ?}, undef, $u->{id} );
    $DB->{dbh}->do( 'SET SESSION sql_mode = ?', undef, $mode );
    $APP->node_by_id( $u->{id} )->cache_refresh;
    ok( ( form_login( $u, 'olduser1' ) )[0], 'an old account with a zero lasttime logs in' );
    is( $APP->password_kind( stored($u) ), 'hashed', 'and its password is upgraded' );

    my $node = $DB->getNodeById( $u->{id}, 'force' );
    my $expiry = time() + 600;
    my $token = $APP->getToken( $node, 'reset-pass-2', 'reset', $expiry );
    ok( $APP->checkToken( $node, 'reset', $expiry, 'reset-pass-2', $token ), 'and it can reset its password' );
    $APP->node_by_id( $u->{id} )->cache_refresh;
    ok( ( form_login( $u, 'reset-pass-2' ) )[0], 'and log in with the new one' );
}

{
    # Changing a password writes only the password: a stale cached copy of the user must not
    # overwrite fresher columns in the database.
    my $u = make_user( 'stale', $APP->saltNewPassword('first-pass-1') );
    my $cached = $DB->getNodeById( $u->{id} );
    $DB->{dbh}->do( 'UPDATE user SET realname = ? WHERE user_id = ?', undef, 'Changed Elsewhere', $u->{id} );
    ok( $APP->updatePassword( $cached, 'second-pass-2' ), 'updatePassword succeeds' );
    is( $DB->sqlSelect( 'realname', 'user', "user_id = $u->{id}" ), 'Changed Elsewhere', 'and leaves the other columns alone' );
    ok( ( form_login( $u, 'second-pass-2' ) )[0], 'and the new password works' );
}

for my $case ( [ 'empty', '' ], [ 'null', undef ], [ 'marker', $NONE ] ) {
    my ( $tag, $passwd ) = @$case;
    my $u = make_user( "nopw_$tag", $passwd, $tag eq 'marker' ? $APP->new_password_salt : undef );
    ok( !cookie_login( $u, $_ ), "no password ($tag): cookie '$_' does not log in" ) for ( 'anything', 'x', $NONE );
    ok( !( form_login( $u, $_ ) )[0], "no password ($tag): password '$_' does not log in" ) for ( 'anything', $NONE );
    is( stored($u)->{passwd}, $passwd, "no password ($tag): and nothing is rewritten" );
}

{
    my $u = make_user( 'pending', 'sometoken|1999999999', $APP->new_password_salt );
    ok( !( form_login( $u, 'sometoken|1999999999' ) )[0], 'awaiting activation: no login' );
    ok( !cookie_login( $u, 'sometoken|1999999999' ), 'awaiting activation: no cookie login' );
}

# ---- password reset ---------------------------------------------------------------------------------
{
    # A no-password account (any form) can still be recovered by a reset.
    my $u = make_user( 'reset_none', '', undef );
    my $res = $test->request( HTTP::Request::Common::POST( '/api/password/reset-request',
        'Content-Type' => 'application/json',
        Content => encode_json( { who => $u->{title}, password => 'brand-new-pass', passwordConfirm => 'brand-new-pass' } ) ) );
    my $row = stored($u);
    is( $row->{passwd}, $NONE, 'reset request on a no-password account stores the marker, not a hash of it' );
    ok( length( $row->{salt} // '' ), 'and gives it a salt' );
    ok( !( form_login( $u, $NONE ) )[0], 'the marker does not work as a password' );

    my $node = $DB->getNodeById( $u->{id}, 'force' );
    my $expiry = time() + 600;
    my $token = $APP->getToken( $node, 'brand-new-pass', 'reset', $expiry );
    ok( $APP->checkToken( $node, 'reset', $expiry, 'brand-new-pass', $token ), 'the reset link works' );
    $APP->node_by_id( $u->{id} )->cache_refresh;
    ok( ( form_login( $u, 'brand-new-pass' ) )[0], 'and the account can log in with its new password' );
}

{
    my $guest = $DB->getNodeById( $Everything::CONF->guest_user );
    my %before = %{ stored( { id => $guest->{node_id} } ) };
    my $res = $test->request( HTTP::Request::Common::POST( '/api/password/reset-request',
        'Content-Type' => 'application/json',
        Content => encode_json( { who => $guest->{title}, password => 'take-over-1', passwordConfirm => 'take-over-1' } ) ) );
    my $json = eval { decode_json( $res->content ) } || {};
    ok( !$json->{success}, 'a password reset for Guest User is refused' );
    is_deeply( stored( { id => $guest->{node_id} } ), \%before, 'and Guest User is unchanged' );
}

# ---- the migration --------------------------------------------------------------------------------
{
    my $hashed  = make_user( 'm_hashed', $APP->saltNewPassword('keep-me-1') );
    my $pending = make_user( 'm_pending', 'tok|1999999999', $APP->new_password_salt );
    my @plain   = map { make_user( "m_plain$_", "pw$_$_$_$_", undef ) } 1 .. 5;
    my $empty   = make_user( 'm_empty', '', undef );
    my $null    = make_user( 'm_null', undef, undef );
    my @all     = ( $hashed, $pending, @plain, $empty, $null );
    my @ids     = map { $_->{id} } @all;
    my %before  = map { $_->{id} => stored($_) } @all;
    my %version = map { $_ => ( $DB->sqlSelect( 'version', 'version', "version_id = $_" ) // 0 ) } @ids;

    my $run = sub {
        my (%opt) = @_;
        my $out = '';
        open( my $fh, '>', \$out ) or die;
        my $r = Everything::PasswordMigration->new( ids => \@ids, pause => 0, out => $fh, %opt )->run;
        close $fh;
        return ( $r, [ map { decode_json($_) } $out =~ /^MIGRATION (\{.*\})$/mg ] );
    };

    my ( $r, $lines ) = $run->();
    ok( $r->{ok}, 'dry run completes' );
    is( $r->{plaintext}, 5, 'dry run: counts the pre-salt passwords' );
    is( $r->{none}, 2, 'dry run: and the empty ones' );
    is_deeply( { map { $_->{id} => stored($_) } @all }, \%before, 'dry run: changes nothing' );
    is( $lines->[0]{status}, 'start', 'prints a start line' );
    is( $lines->[-1]{status}, 'done', 'and a done line' );
    is( $lines->[-1]{remaining}, 7, 'dry run: everything still to do' );
    unlike( join( "\n", map { encode_json($_) } @$lines ), qr/pw1111|pw2222/, 'never prints passwords' );

    ( $r, $lines ) = $run->( apply => 1, limit => 3, batch_size => 2 );
    ok( $r->{ok}, 'a limited run completes' );
    is( $r->{scanned}, 3, 'and stops at the limit' );
    is( scalar( grep { $_->{status} eq 'progress' } @$lines ), 2, 'in batches' );
    is( $lines->[-1]{remaining}, 4, 'leaving the rest' );

    ( $r, $lines ) = $run->( apply => 1, batch_size => 2 );
    ok( $r->{ok}, 'resuming completes' );
    is( $lines->[-1]{remaining}, 0, 'with nothing left' );

    is_deeply( stored($hashed),  $before{ $hashed->{id} },  'a normal account is untouched' );
    is_deeply( stored($pending), $before{ $pending->{id} }, 'an account awaiting activation is untouched' );
    for my $u (@plain) {
        my $row = stored($u);
        is( $APP->password_kind($row), 'legacy', "$u->{title}: migrated" );
        ok( $DB->sqlSelect( 'version', 'version', "version_id = $u->{id}" ) > $version{ $u->{id} }, "$u->{title}: cache version bumped" );
    }
    for my $u ( $empty, $null ) {
        is( stored($u)->{passwd}, $NONE, "$u->{title}: has the no-password marker" );
        ok( length( stored($u)->{salt} ), "$u->{title}: and a salt" );
    }

    # every migrated account still logs in with its old password (and is then upgraded)
    my $n = 0;
    for my $u (@plain) {
        $n++;
        $APP->node_by_id( $u->{id} )->cache_refresh;
        ok( ( form_login( $u, "pw$n$n$n$n" ) )[0], "$u->{title}: logs in after migration" );
        is( $APP->password_kind( stored($u) ), 'hashed', "$u->{title}: and is upgraded" );
    }
    ok( !cookie_login( $empty, 'anything' ), 'a migrated no-password account cannot log in' );

    ( $r, $lines ) = $run->( apply => 1 );
    is( $r->{scanned}, 0, 'a second run finds nothing to do' );

    # Guest User never authenticates by password: it gets the no-password marker, by name in the log
    my $guestish = make_user( 'm_guest', 'guestpw', undef );
    {
        my $out = '';
        open( my $fh, '>', \$out ) or die;
        my $res = Everything::PasswordMigration->new( ids => [ $guestish->{id} ], guest_user_id => $guestish->{id},
            apply => 1, pause => 0, out => $fh )->run;
        is( $res->{guest}, 1, 'the guest account is counted on its own' );
        is( stored($guestish)->{passwd}, $NONE, 'and gets the no-password marker, not a legacy hash' );
        ok( ( grep { /"account":"Guest User"/ && /"status":"special"/ } split /\n/, $out ), 'and is named in the output' );
        ok( !( form_login( $guestish, 'guestpw' ) )[0], 'and its old password no longer logs in' );
    }

    # a row that changes between read and write is left alone
    my $racer = make_user( 'm_race', 'raceme12', undef );
    my $m = Everything::PasswordMigration->new( apply => 1, pause => 0 );
    my $stale = { user_id => $racer->{id}, passwd => 'raceme12', salt => undef };
    $DB->{dbh}->do( 'UPDATE user SET passwd = ? WHERE user_id = ?', undef, 'changed-meanwhile', $racer->{id} );
    is( $m->migrate_row($stale), 'changed', 'a row that changed after it was read is skipped' );
    is( stored($racer)->{passwd}, 'changed-meanwhile', 'and not overwritten' );

    # a value that doesn't verify stops the batch and rolls it back (the first row was already written)
    my $bad1 = make_user( 'm_bad1', 'okfine12', undef );
    my $bad2 = make_user( 'm_bad2', 'okfine34', undef );
    {
        no warnings 'redefine';
        my $real  = \&Everything::Application::check_password;
        my $calls = 0;
        local *Everything::Application::check_password = sub { return ++$calls == 1 ? $real->(@_) : 0 };
        my $out = '';
        open( my $fh, '>', \$out ) or die;
        my $res = Everything::PasswordMigration->new( ids => [ $bad1->{id}, $bad2->{id} ], apply => 1, pause => 0, out => $fh )->run;
        ok( !$res->{ok}, 'a value that fails verification stops the run' );
        like( $out, qr/"status":"error"/, 'and says so' );
    }
    is( stored($bad1)->{passwd}, 'okfine12', 'and the batch is rolled back' );
    is( stored($bad2)->{passwd}, 'okfine34', 'all of it' );
}

my $root = $DB->getNode( 'root', 'user' );
$DB->nukeNode( $DB->getNodeById($_), $root ) for grep { $DB->getNodeById($_) } reverse @created;
$DB->{dbh}->do( 'DELETE FROM version WHERE version_id = ?', undef, $_ ) for @created;

done_testing();
