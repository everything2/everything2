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

#############################################################################
# coolcount -- count of a user's cooled writeups (the C! count)
#############################################################################

subtest 'coolcount' => sub {
    my $user = $DB->getNode( 'root', 'user' );
    ok( $user, 'got a test user' );

    my $count = $APP->coolcount( $user->{node_id} );
    ok( defined $count,                'coolcount returns a value' );
    like( $count, qr/^\d+$/,           'coolcount is a non-negative integer' );

    # Matches an independent count of the same join (the method is a thin wrapper).
    my $expected = $DB->sqlSelect( 'count(*)',
        'coolwriteups JOIN node ON coolwriteups_id = node_id',
        "author_user=$user->{node_id} and type_nodetype=117" );
    is( $count, $expected, 'coolcount matches the direct query' );
};

#############################################################################
# usergroupToUserIds / explode_ug -- recursive usergroup -> user_id flatten
#############################################################################

subtest 'usergroupToUserIds + explode_ug' => sub {
    # Helper: is this node_id a user?
    my $is_user = sub {
        my $n = $DB->getNodeById( $_[0] );
        return $n && ( $n->{type}{title} || '' ) eq 'user';
    };

    # Flat group: every member is a user.
    my $gods = $DB->getNode( 'gods', 'usergroup' );
    SKIP: {
        skip 'no gods usergroup in dev DB', 3 unless $gods;
        my $ids = $APP->usergroupToUserIds( $gods->{node_id} );
        like( $ids, qr/\A\d+(,\d+)*\z/, 'returns a comma-separated id list' );
        my @ids = split /,/, $ids;
        ok( scalar(@ids) >= 1, 'gods has members' );
        is( scalar( grep { !$is_user->($_) } @ids ), 0,
            'every returned id is a user (no group ids leak)' );
    }

    # Nested group: "Content Editors" contains the "e2gods" usergroup, which must be
    # FLATTENED to its users -- explode_ug recurses, the sub-usergroup id never appears.
    my $ce     = $DB->getNode( 'Content Editors', 'usergroup' );
    my $e2gods = $DB->getNode( 'e2gods',          'usergroup' );
    SKIP: {
        skip 'no nested usergroup fixture in dev DB', 2 unless $ce && $e2gods;
        my %out = map { $_ => 1 } split /,/, $APP->usergroupToUserIds( $ce->{node_id} );
        ok( !$out{ $e2gods->{node_id} },
            'nested usergroup id is NOT in the output (recursion flattened it)' );
        is( scalar( grep { !$is_user->($_) } keys %out ), 0,
            'every flattened id is a user' );
    }
};

done_testing();
