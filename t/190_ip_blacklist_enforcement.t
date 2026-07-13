#!/usr/bin/perl -w
# Everything::Application::is_ip_blacklisted -- the actual signup-gate enforcement
# (#4465). Historically the old [Sign up] node called the `check_blacklist` htmlcode, which
# checked BOTH single IPs and CIDR ranges (int BETWEEN min_ip AND max_ip). When signup
# moved to Everything::API::signup + is_ip_blacklisted, only the single-IP half survived,
# so range blocks added via the IP Blacklist tool never blocked anyone. This pins the
# restored behaviour: single-IP hit/miss AND CIDR-range hit/miss, plus NULL-safety for
# malformed input. Inserts + cleans up its own rows (RFC-5737 documentation IPs).
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;

initEverything('development-docker');
ok($DB,  'Database connection established');
ok($APP, 'Application available');

# is_ip_blacklisted() reads the GLOBAL ipblacklist* tables, so this file must own
# IPs no other test touches -- otherwise a concurrent test's rows flip our
# hit/miss assertions under `prove -j`. t/189 owns 203.0.113.x + 198.51.100.0/24
# and t/157 owns 203.0.113.77, so this file lives entirely in 192.0.2.0/24
# (RFC-5737 TEST-NET-1), which nothing else uses. The single IP, the in-range IP,
# and the out-of-range IP are all disjoint from every other file's fixtures.
my $SINGLE_IP  = '192.0.2.77';
my $INRANGE_IP = '192.0.2.50';
my $OUTOF_IP   = '192.0.3.50';   # deliberately outside 192.0.2.0/24
my $RANGE_MIN  = '192.0.2.0';
my $RANGE_MAX  = '192.0.2.255';

# Delete only this file's own rows, by value. Used both up front (in case a prior
# run died before cleanup and left residue) and in END (so a mid-test die still
# cleans up). Keyed on our IPs, never on ids, so leftover rows are always swept.
sub _sweep_t190_rows {
    return unless $DB && $DB->{dbh};
    for my $ip ($SINGLE_IP) {
        my $ref = $DB->sqlSelect('ipblacklistref_id', 'ipblacklist',
            'ipblacklist_ipaddress=' . $DB->quote($ip));
        if ($ref) {
            $DB->sqlDelete('ipblacklist',    "ipblacklistref_id=$ref");
            $DB->sqlDelete('ipblacklistref', "ipblacklistref_id=$ref");
        }
    }
    my $cref = $DB->sqlSelect('ipblacklistref_id', 'ipblacklistrange',
        "min_ip=INET_ATON('$RANGE_MIN') AND max_ip=INET_ATON('$RANGE_MAX')");
    if ($cref) {
        $DB->sqlDelete('ipblacklistrange', "ipblacklistref_id=$cref");
        $DB->sqlDelete('ipblacklistref',   "ipblacklistref_id=$cref");
    }
}
END { _sweep_t190_rows(); }

SKIP: {
    my $root = $DB->getNode('root', 'user');
    skip 'root not present', 8 unless $root;
    my $uid = $root->{node_id};

    # Clean slate for our documentation IPs (guards against crash residue).
    _sweep_t190_rows();
    ok(!$APP->is_ip_blacklisted($SINGLE_IP),  'single IP not blacklisted before add');
    ok(!$APP->is_ip_blacklisted($INRANGE_IP), 'range IP not blacklisted before add');

    # --- single IP ---------------------------------------------------------
    $DB->sqlInsert('ipblacklistref', {});
    my $ref1 = $DB->sqlSelect('LAST_INSERT_ID()');
    $DB->sqlInsert('ipblacklist', {
        ipblacklistref_id      => $ref1,
        ipblacklist_user       => $uid,
        ipblacklist_ipaddress  => $SINGLE_IP,
        ipblacklist_comment    => 't190 single',
        -ipblacklist_timestamp => 'NOW()',
    });
    ok($APP->is_ip_blacklisted($SINGLE_IP), 'single IP is blacklisted after add');

    # --- CIDR range (the restored #4465 behaviour) -------------------------
    $DB->sqlInsert('ipblacklistref', {});
    my $ref2 = $DB->sqlSelect('LAST_INSERT_ID()');
    $DB->{dbh}->do(
        "INSERT INTO ipblacklistrange (banner_user_id, min_ip, max_ip, comment, ipblacklistref_id)"
        . " VALUES ($uid, INET_ATON('$RANGE_MIN'), INET_ATON('$RANGE_MAX'), 't190 range', $ref2)");

    ok($APP->is_ip_blacklisted($INRANGE_IP), 'IP INSIDE a CIDR range is blacklisted (#4465 fix)');
    like($APP->is_ip_blacklisted($INRANGE_IP), qr/\Q$RANGE_MIN\E - \Q$RANGE_MAX\E/,
        'range match returns a readable dotted range, not raw integers');
    ok(!$APP->is_ip_blacklisted($OUTOF_IP), 'IP OUTSIDE the range is not blacklisted');

    # --- NULL-safety for non-IPv4 input ------------------------------------
    ok(!$APP->is_ip_blacklisted('not-an-ip-address'), 'malformed input matches nothing (INET_ATON NULL-safe)');

    # --- cleanup -----------------------------------------------------------
    $DB->sqlDelete('ipblacklist',      "ipblacklistref_id=$ref1");
    $DB->sqlDelete('ipblacklistref',   "ipblacklistref_id=$ref1");
    $DB->sqlDelete('ipblacklistrange', "ipblacklistref_id=$ref2");
    $DB->sqlDelete('ipblacklistref',   "ipblacklistref_id=$ref2");
}

done_testing;
