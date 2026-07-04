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

SKIP: {
    my $root = $DB->getNode('root', 'user');
    skip 'root not present', 8 unless $root;
    my $uid = $root->{node_id};

    # Clean slate for our documentation IPs.
    ok(!$APP->is_ip_blacklisted('203.0.113.77'), 'single IP not blacklisted before add');
    ok(!$APP->is_ip_blacklisted('198.51.100.50'), 'range IP not blacklisted before add');

    # --- single IP ---------------------------------------------------------
    $DB->sqlInsert('ipblacklistref', {});
    my $ref1 = $DB->sqlSelect('LAST_INSERT_ID()');
    $DB->sqlInsert('ipblacklist', {
        ipblacklistref_id      => $ref1,
        ipblacklist_user       => $uid,
        ipblacklist_ipaddress  => '203.0.113.77',
        ipblacklist_comment    => 't190 single',
        -ipblacklist_timestamp => 'NOW()',
    });
    ok($APP->is_ip_blacklisted('203.0.113.77'), 'single IP is blacklisted after add');

    # --- CIDR range (the restored #4465 behaviour) -------------------------
    $DB->sqlInsert('ipblacklistref', {});
    my $ref2 = $DB->sqlSelect('LAST_INSERT_ID()');
    $DB->{dbh}->do(
        "INSERT INTO ipblacklistrange (banner_user_id, min_ip, max_ip, comment, ipblacklistref_id)"
        . " VALUES ($uid, INET_ATON('198.51.100.0'), INET_ATON('198.51.100.255'), 't190 range', $ref2)");

    ok($APP->is_ip_blacklisted('198.51.100.50'), 'IP INSIDE a CIDR range is blacklisted (#4465 fix)');
    like($APP->is_ip_blacklisted('198.51.100.50'), qr/198\.51\.100\.0 - 198\.51\.100\.255/,
        'range match returns a readable dotted range, not raw integers');
    ok(!$APP->is_ip_blacklisted('198.51.101.50'), 'IP OUTSIDE the range is not blacklisted');

    # --- NULL-safety for non-IPv4 input ------------------------------------
    ok(!$APP->is_ip_blacklisted('not-an-ip-address'), 'malformed input matches nothing (INET_ATON NULL-safe)');

    # --- cleanup -----------------------------------------------------------
    $DB->sqlDelete('ipblacklist',      "ipblacklistref_id=$ref1");
    $DB->sqlDelete('ipblacklistref',   "ipblacklistref_id=$ref1");
    $DB->sqlDelete('ipblacklistrange', "ipblacklistref_id=$ref2");
    $DB->sqlDelete('ipblacklistref',   "ipblacklistref_id=$ref2");
}

done_testing;
