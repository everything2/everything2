#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching)
## no critic (ValuesAndExpressions ProhibitMagicNumbers ProhibitInterpolationOfLiterals)

#############################################################################
# 111_notified_notified_time.t
#
# Guards the MySQL 8.4 zero-date fix on notified.notified_time (#4082):
#   notified_time datetime NOT NULL DEFAULT CURRENT_TIMESTAMP
#
# Two-part bug:
#  (a) Schema: the old '0000-00-00' default. notified_time feeds UNIX_TIMESTAMP()
#      math, so it's an always-set event timestamp → CURRENT_TIMESTAMP (not NULL).
#  (b) Code: the notification-dismiss path (API/notifications.pm) wrote
#      `notified_time => \"NOW()"` — a scalar-ref literal that E2's sqlInsert does
#      NOT honor (only the `-key => 'now()'` form works). That silently produced a
#      zero-date on every dismiss, which would be *rejected* under 8.4 strict mode.
#
# This test pins the convention (the root cause) so a revert can't sneak back,
# and verifies the schema default produces a real timestamp.
#############################################################################

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;
use Everything::API::notifications;
use JSON;

# Minimal mocks to drive the real dismiss() action end-to-end (#4193 guard).
package T111User {
  sub new      { my ($c, $node) = @_; return bless $node, $c }  # bless a real user node hashref
  sub is_guest { return 0 }
  sub node_id  { return $_[0]->{node_id} }
  sub NODEDATA { return $_[0] }
  sub VARS     { return Everything::getVars($_[0]) }
}
package T111Request {
  sub new           { my ($c, %a) = @_; return bless { %a }, $c }
  sub user          { return $_[0]->{user} }
  sub is_guest      { return $_[0]->{user}->is_guest }
  sub JSON_POSTDATA { return $_[0]->{postdata} }
}
package main;

$SIG{__WARN__} = sub {
    my $w = shift;
    warn $w unless $w =~ /Could not open log/ || $w =~ /Use of uninitialized value/
                || $w =~ /overwriting a locally defined function/;
};

initEverything('development-docker');
ok($DB, 'Database connection established');

my $uid = 999990;
$DB->sqlDelete('notified', "user_id=$uid");   # clean any prior run

#############################################################################
# 1. Schema default: a bare insert (no notified_time) → real CURRENT_TIMESTAMP.
#############################################################################
{
    $DB->sqlInsert('notified',
        { user_id => $uid, notification_id => 1, args => '{}' });
    my $t = $DB->sqlSelect('notified_time', 'notified',
        "user_id=$uid order by notified_id desc limit 1");
    ok(defined $t && $t !~ /^0000-00-00/,
        'bare insert: notified_time defaults to a real CURRENT_TIMESTAMP (#4082)');
    like($t, qr/^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$/, 'well-formed datetime');
    $DB->sqlDelete('notified', "user_id=$uid");
}

#############################################################################
# 2. The convention the dismiss path now uses: `-notified_time => 'now()'`
#    produces a real time. This is the corrected form (the root-cause fix).
#############################################################################
{
    $DB->sqlInsert('notified',
        { user_id => $uid, notification_id => 1, args => '{}', -notified_time => 'now()' });
    my $t = $DB->sqlSelect('notified_time', 'notified',
        "user_id=$uid order by notified_id desc limit 1");
    ok(defined $t && $t !~ /^0000-00-00/,
        'the `-key => now()` literal form (used by the dismiss path) yields a real time');
    $DB->sqlDelete('notified', "user_id=$uid");
}

#############################################################################
# 3. End-to-end #4193 guard: the REAL dismiss() action must write a real
#    notified_time on the reference record it creates (the subscribed branch).
#    This is the coverage that was missing — t/049 hand-inlined the insert with
#    the *correct* form and never called dismiss(), so the production zero-date
#    bug went unseen. Calling the real action would have caught it.
#############################################################################
{
    my $root_node = $DB->getNode('root', 'user');
    my $nodenote  = $DB->getNode('nodenote', 'notification');
    SKIP: {
        skip 'need root + nodenote notification', 3 unless $root_node && $nodenote;
        my $root = $DB->getNodeById($root_node->{node_id}, 'force');

        # Broadcast notification (user_id = the notification node_id) — i.e. NOT root's
        # own, so dismiss() takes the subscribed branch (the one that does the insert).
        $DB->sqlInsert('notified', {
            notification_id => $nodenote->{node_id},
            user_id         => $nodenote->{node_id},
            args            => '{}',
            is_seen         => 0,
            -notified_time  => 'now()',
        });
        my $broadcast_id = $DB->sqlSelect('LAST_INSERT_ID()');

        # Subscribe root to that notification type so the dismiss is permitted.
        my $vars = Everything::getVars($root);
        my $orig_settings = $vars->{settings};
        my $settings = $orig_settings ? decode_json($orig_settings) : {};
        $settings->{notifications}{ $nodenote->{node_id} } = 1;
        $vars->{settings} = encode_json($settings);
        Everything::setVars($root, $vars);

        # Drive the REAL dismiss action through the API.
        my $api = Everything::API::notifications->new();
        my $req = T111Request->new(
            user     => T111User->new($DB->getNodeById($root->{node_id}, 'force')),
            postdata => { notified_id => $broadcast_id },
        );
        my $res = $api->dismiss($req);
        is($res->[0], $api->HTTP_OK, 'dismiss() returns HTTP_OK for a subscribed broadcast');

        my $ref = $DB->sqlSelectHashref('*', 'notified',
            "reference_notified_id = $broadcast_id ORDER BY notified_id DESC");
        ok($ref, 'dismiss() created a reference record');
        ok($ref && $ref->{notified_time} && $ref->{notified_time} !~ /^0000-00-00/,
            'reference record notified_time is real, not a zero-date (#4193 end-to-end)');

        # Cleanup
        $DB->sqlDelete('notified', "reference_notified_id = $broadcast_id");
        $DB->sqlDelete('notified', "notified_id = $broadcast_id");
        if (defined $orig_settings) { $vars->{settings} = $orig_settings }
        else { delete $vars->{settings} }
        Everything::setVars($root, $vars);
    }
}

done_testing();
