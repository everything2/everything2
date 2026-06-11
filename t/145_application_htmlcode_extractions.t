#!/usr/bin/perl -w
#
# Unit tests for the Everything::Application methods extracted from the
# Everything::Delegation::htmlcode holdout (getGravatarMD5, DateTimeLocal,
# isSpecialDate). These pin the behavior the old htmlcode snippets had, so the
# extraction is provably faithful.
#
use strict;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5);
use Test::More;
use Digest::MD5 qw(md5_hex);
use DateTime;
use Everything;
use Everything::Application;

initEverything 'everything';

ok( $DB,  'DB connected' );
ok( $APP, 'Application object' );

#############################################################################
# getGravatarMD5 -- md5 of lc/trimmed gravatar_email (or the chat.e2 default)
#############################################################################

subtest 'getGravatarMD5' => sub {
    my $root = $DB->getNode( 'root', 'user' );
    ok( $root, 'got a test user' );

    # Independently compute the email the method should hash (same spec).
    my $email = $DB->sqlSelect( 'setting_value', 'uservars',
        "user_id = $root->{node_id} AND setting_name = 'gravatar_email'" );
    $email = "$root->{title}\@chat.everything2.com" unless defined $email;
    $email = lc $email;
    $email =~ s/^\s+|\s+$//g;
    my $expected = md5_hex($email);

    is( $APP->getGravatarMD5($root), $expected, 'hashref arg -> expected md5' );
    is( $APP->getGravatarMD5( $root->{node_id} ), $expected, 'node_id arg -> same md5 (getRef)' );
    like( $APP->getGravatarMD5($root), qr/^[0-9a-f]{32}$/, 'is a 32-char lowercase hex digest' );
};

#############################################################################
# DateTimeLocal -- epoch -> "Weekday, Month D, YYYY at HH:MM:SS"
#############################################################################

subtest 'DateTimeLocal' => sub {
    my $epoch = 1700000000;    # fixed reference

    like( $APP->DateTimeLocal( $epoch, 1, {} ),
        qr/^\w+day, \w+ \d+, \d{4} at \d+:\d\d:\d\d$/, 'server-time format' );

    # show_server forces server time -- localTime VARS are ignored.
    is( $APP->DateTimeLocal( $epoch, 1, { localTimeUse => 1, localTimeOffset => 3600 } ),
        $APP->DateTimeLocal( $epoch, 1, {} ),
        'show_server ignores localTime VARS' );

    # localTimeOffset shifts the clock: offset+localTimeUse on $epoch ==
    # server time on $epoch+offset. TZ-agnostic invariant.
    is( $APP->DateTimeLocal( $epoch, 0, { localTimeUse => 1, localTimeOffset => 3600 } ),
        $APP->DateTimeLocal( $epoch + 3600, 1, {} ),
        'localTimeOffset applied == server time at epoch+offset' );

    # localTimeDST adds an hour.
    is( $APP->DateTimeLocal( $epoch, 0, { localTimeUse => 1, localTimeDST => 1 } ),
        $APP->DateTimeLocal( $epoch + 3600, 1, {} ),
        'localTimeDST adds an hour' );

    like( $APP->DateTimeLocal( $epoch, 1, { localTime12hr => 1 } ),
        qr/ (AM|PM)$/, '12-hour mode appends AM/PM' );

    ok( length( $APP->DateTimeLocal( undef, 1, {} ) ) > 0, 'undef use_time falls back to now()' );
};

#############################################################################
# isSpecialDate -- named UTC holidays, optional year pin, injectable "now"
#############################################################################

subtest 'isSpecialDate' => sub {
    my $d = sub { DateTime->new( year => $_[0], month => $_[1], day => $_[2], time_zone => 'UTC' ) };

    is( $APP->isSpecialDate( 'halloween', $d->( 2025, 10, 31 ) ), 1, 'halloween on Oct 31' );
    is( $APP->isSpecialDate( 'HALLOWEEN', $d->( 2025, 10, 31 ) ), 1, 'case-insensitive' );
    is( $APP->isSpecialDate( 'halloween', $d->( 2025, 11, 1 ) ),  0, 'not halloween on Nov 1' );
    is( $APP->isSpecialDate( 'xmas',      $d->( 2025, 12, 25 ) ), 1, 'xmas on Dec 25' );
    is( $APP->isSpecialDate( 'afd',       $d->( 2025, 4, 1 ) ),   1, 'afd on Apr 1' );
    is( $APP->isSpecialDate( 'nyd',       $d->( 2025, 1, 1 ) ),   1, 'nyd on Jan 1' );
    is( $APP->isSpecialDate( 'nye',       $d->( 2025, 12, 31 ) ), 1, 'nye on Dec 31' );

    # Year pin
    is( $APP->isSpecialDate( 'xmas2025', $d->( 2025, 12, 25 ) ), 1, 'year-pinned match' );
    is( $APP->isSpecialDate( 'xmas2024', $d->( 2025, 12, 25 ) ), 0, 'year-pin mismatch' );

    # Non-matches
    is( $APP->isSpecialDate( undef ),                          0, 'undef -> 0' );
    is( $APP->isSpecialDate( 'notaholiday', $d->( 2025, 10, 31 ) ), 0, 'unknown name -> 0' );
};

done_testing();
