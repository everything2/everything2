#!/usr/bin/perl -w
# Everything::API::ip_blacklist -- POST /api/ip_blacklist/list|add|remove (#4464,
# Refs #4298). One unified admin interface backing BOTH the ip_blacklist and
# mass_ip_blacklister pages: `add` takes a newline block (each line a single IP or CIDR),
# so single-IP is just a one-line list; `source` selects the audit event. Shared logic is
# in Everything::Roles::IPBlacklist. Uses RFC-5737 documentation IPs and cleans them up.
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::API::ip_blacklist;
use MockRequest;

initEverything('development-docker');
ok($DB, 'Database connection established');

my $api = Everything::API::ip_blacklist->new();
ok($api, 'Created ip_blacklist API instance');
is_deeply($api->routes, {list => 'list_entries', add => 'add_entries', remove => 'remove_entry'},
    'routes: list/add/remove');

#############################################################################
# Admin gate on all three routes
#############################################################################
for my $pair (['list', 'list_entries'], ['add', 'add_entries'], ['remove', 'remove_entry']) {
    my ($label, $method) = @$pair;
    my $r = $api->$method(MockRequest->new(is_admin_flag => 0, is_guest_flag => 0, postdata => {}));
    is($r->[1]{success}, 0, "$label refused for non-admin");
    like($r->[1]{error}, qr/administrator/i, "$label admin-required error");
}

SKIP: {
    my $root = $DB->getNode('root', 'user');
    skip 'root not present', 20 unless $root;

    my $admin = sub {
        MockRequest->new(is_admin_flag => 1, is_guest_flag => 0,
            node_id => $root->{node_id}, nodedata => $root, title => 'root', postdata => $_[0]);
    };
    my $find_id = sub {
        my ($entries, $ip) = @_;
        for my $e (@$entries) { return $e->{id} if ($e->{ip_address} // '') eq $ip }
        return undef;
    };

    # list works for admin
    my $r = $api->list_entries($admin->({offset => 0}));
    is($r->[1]{success}, 1, 'list succeeds for admin');
    ok(ref $r->[1]{entries} eq 'ARRAY', 'list returns entries array');
    is($r->[1]{page_size}, 200, 'page_size in payload');

    # Orphaned ipblacklistref (no address partner) must NOT render as a blank row (#4464).
    $DB->sqlInsert('ipblacklistref', {});
    my $orphan = $DB->sqlSelect('LAST_INSERT_ID()');
    my $lr = $api->list_entries($admin->({offset => 0}));
    my $orphan_shown = grep { ($_->{id} // 0) == $orphan } @{$lr->[1]{entries}};
    is($orphan_shown, 0, 'orphaned ref excluded from list entries');
    $DB->sqlDelete('ipblacklistref', "ipblacklistref_id=$orphan");

    # add a single IP
    $r = $api->add_entries($admin->({ips => '203.0.113.7', reason => 't189 single', source => 'ip_blacklist'}));
    is($r->[1]{success}, 1, 'add single: API call succeeds');
    is($r->[1]{results}[0]{success}, 1, 'add single: entry succeeded');
    like($r->[1]{results}[0]{message}, qr/successfully added/i, 'add single: success message');
    my $id1 = $find_id->($r->[1]{entries}, '203.0.113.7');
    ok($id1, 'single IP present in refreshed entries');

    # add multiple, one invalid -> mixed per-line results
    $r = $api->add_entries($admin->({ips => "203.0.113.8\n999.1.1.1\n203.0.113.9",
        reason => 't189 multi', source => 'mass_ip_blacklister'}));
    is(scalar @{$r->[1]{results}}, 3, 'add multi: three per-line results');
    is($r->[1]{results}[0]{success}, 1, 'add multi: line 1 ok');
    is($r->[1]{results}[1]{success}, 0, 'add multi: line 2 (invalid) failed');
    like($r->[1]{results}[1]{message}, qr/not a valid/i, 'add multi: invalid message');
    is($r->[1]{results}[2]{success}, 1, 'add multi: line 3 ok');
    my $id8 = $find_id->($r->[1]{entries}, '203.0.113.8');
    my $id9 = $find_id->($r->[1]{entries}, '203.0.113.9');

    # add a CIDR range
    $r = $api->add_entries($admin->({ips => '198.51.100.0/24', reason => 't189 cidr', source => 'ip_blacklist'}));
    is($r->[1]{results}[0]{success}, 1, 'add CIDR: succeeded');
    my $idc = $find_id->($r->[1]{entries}, '198.51.100.0/24');
    ok($idc, 'CIDR range rendered as min/bits in entries');

    # validation: missing reason / empty ips
    $r = $api->add_entries($admin->({ips => '203.0.113.1', reason => '', source => 'ip_blacklist'}));
    is($r->[1]{success}, 0, 'add without reason rejected');
    like($r->[1]{error}, qr/reason/i, 'reason-required error');

    $r = $api->add_entries($admin->({ips => "  \n ", reason => 'x', source => 'ip_blacklist'}));
    is($r->[1]{success}, 0, 'add with no real IPs rejected');

    # remove the single-IP entries (tests remove + cleans up)
    for my $id ($id1, $id8, $id9) {
        next unless $id;
        my $rr = $api->remove_entry($admin->({id => $id, source => 'ip_blacklist'}));
        is($rr->[1]{success}, 1, "remove entry $id succeeds");
    }

    # remove the CIDR range -- the message must read as dotted CIDR, NOT the raw integers
    # stored in ipblacklistrange (#4464 follow-up).
    if ($idc) {
        my $rr = $api->remove_entry($admin->({id => $idc, source => 'ip_blacklist'}));
        is($rr->[1]{success}, 1, 'remove CIDR entry succeeds');
        like($rr->[1]{message}, qr{198\.51\.100\.0/24}, 'CIDR remove message shows CIDR notation');
        unlike($rr->[1]{message}, qr/\b\d{7,}\b/, 'CIDR remove message has no raw integer range');
    }

    # remove validation
    $r = $api->remove_entry($admin->({id => 'not-a-number'}));
    is($r->[1]{success}, 0, 'remove with bad id rejected');

    # belt-and-suspenders: nuke any lingering test rows
    for my $ip ('203.0.113.7', '203.0.113.8', '203.0.113.9', '203.0.113.1') {
        my $ref = $DB->sqlSelect('ipblacklistref_id', 'ipblacklist',
            'ipblacklist_ipaddress = ' . $DB->quote($ip));
        if ($ref) {
            $DB->sqlDelete('ipblacklist',    "ipblacklistref_id=$ref");
            $DB->sqlDelete('ipblacklistref', "ipblacklistref_id=$ref");
        }
    }
    my $cref = $DB->sqlSelect('ipblacklistref_id', 'ipblacklistrange',
        'comment = ' . $DB->quote('t189 cidr'));
    if ($cref) {
        $DB->sqlDelete('ipblacklistrange', "ipblacklistref_id=$cref");
        $DB->sqlDelete('ipblacklistref',   "ipblacklistref_id=$cref");
    }
}

done_testing;
