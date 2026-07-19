#!/usr/bin/perl -w
# Registries reports tranche (#4548): the_registries, registry_information, recent_registry_entries.
# Each moved its NoGuest read out of a Page (now a pure gate) into an API. Guests get state:'guest';
# node_ids are JSON numbers (#4152); boolean flags (include_empty, has_entries) are JSON booleans (#4108).

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use JSON;
use Everything;
use Everything::API::the_registries;
use Everything::API::registry_information;
use Everything::API::recent_registry_entries;
use MockRequest;

initEverything('development-docker');
ok($DB, 'DB connection established');

my $root = $DB->getNode('root', 'user');

my $guest  = sub { MockRequest->new(is_guest_flag => 1, query_params => { %{$_[0] || {}} }) };
my $member = sub { MockRequest->new(is_guest_flag => 0, node_id => $root->{node_id},
                                    nodedata => $root, query_params => { %{$_[0] || {}} }) };

my $J = JSON->new;

#############################################################################
# the_registries -- NoGuest; include_empty toggle
#############################################################################
{
    my $api = Everything::API::the_registries->new;
    is_deeply($api->routes, { '/' => 'list' }, 'the_registries: routes');
    is($api->list($guest->())->[1]{state}, 'guest', 'the_registries: guest -> guest state');

    my $r = $api->list($member->());
    is($r->[1]{success}, 1, 'the_registries: member ok');
    ok(ref($r->[1]{registries}) eq 'ARRAY', 'the_registries: registries array');
    is(ref($r->[1]{include_empty}), 'SCALAR', 'the_registries: include_empty is a JSON boolean (#4108)');
    is(${ $r->[1]{include_empty} }, 0, 'the_registries: include_empty defaults false');

    my $r2 = $api->list($member->({ include_empty => 1 }));
    is(${ $r2->[1]{include_empty} }, 1, 'the_registries: include_empty=1 echoed true');

    if (@{ $r->[1]{registries} }) {
        unlike($J->encode($r->[1]{registries}[0]), qr/"(?:node_id|entry_count)"\s*:\s*"/,
            'the_registries: node_id/entry_count are JSON numbers');
    }
}

#############################################################################
# registry_information -- NoGuest; user-scoped
#############################################################################
{
    my $api = Everything::API::registry_information->new;
    is($api->list($guest->())->[1]{state}, 'guest', 'registry_information: guest -> guest state');

    my $r = $api->list($member->());
    is($r->[1]{success}, 1, 'registry_information: member ok');
    ok(ref($r->[1]{entries}) eq 'ARRAY', 'registry_information: entries array');
    is(ref($r->[1]{has_entries}), 'SCALAR', 'registry_information: has_entries is a JSON boolean (#4108)');
}

#############################################################################
# recent_registry_entries -- NoGuest
#############################################################################
{
    my $api = Everything::API::recent_registry_entries->new;
    is($api->list($guest->())->[1]{state}, 'guest', 'recent_registry_entries: guest -> guest state');

    my $r = $api->list($member->());
    is($r->[1]{success}, 1, 'recent_registry_entries: member ok');
    ok(ref($r->[1]{entries}) eq 'ARRAY', 'recent_registry_entries: entries array');
}

done_testing();
