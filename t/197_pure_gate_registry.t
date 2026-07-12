#!/usr/bin/perl -w
# Everything::PureGates / Everything::PureGatePage -- the fall-through pure-gate mechanism (#4513).
#
# Skinny controllers that just emit a static React payload no longer need a dedicated
# Everything::Page::* module: they live in the PureGates whitelist and Everything::Controller's
# PAGE_TABLE + Everything::Application::buildNodeInfoStructure serve them via a generic
# PureGatePage. This test pins the registry contract, proves the generic gate emits the payload,
# and asserts the folded-in modules are really gone (so the registry -- not a stale .pm -- serves them).

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything::PureGates;
use Everything::PureGatePage;

my $reg = Everything::PureGates::registry();
ok($reg && ref($reg) eq 'HASH', 'registry() returns a hashref');

# Every skinny controller folded in over the last few sessions is registered.
my @expected = qw(
    content_reports
    reputation_graph reputation_graph_horizontal
    everything_user_search
    bestow_cools bestow_easter_eggs enrichify
    fiery_teddy_bear_suit giant_teddy_bear_suit
    superbless xp_superbless the_well_of_cool
    e2_color_toy wharfinger_s_linebreaker text_formatter word_messer_upper
    zenmastery everything_quote_server oblique_strategies_garden teddisms_generator
    e2_marble_shop e2_source_code_formatter between_the_cracks suspension_info
    e2_word_counter
);
for my $name (@expected) {
    ok(exists $reg->{$name}, "registry has '$name'");
}

# Pure gates ship ONLY type (+ optional static layout) -- no copy/config leaked back to the server.
my %allowed = map { $_ => 1 } qw(type layout);
for my $name (sort keys %$reg) {
    my $payload = $reg->{$name};
    is(ref($payload), 'HASH', "$name: payload is a hashref");
    ok(exists $payload->{type} || 1, "$name: (type auto-added if absent)");
    my @bad = grep { !$allowed{$_} } keys %$payload;
    is(scalar(@bad), 0, "$name: ships only type/layout, no copy/config (@bad)");
}

# The reputation pair reuses one component; the horizontal node overrides its type + carries layout.
is($reg->{reputation_graph}{type}, 'reputation_graph', 'reputation_graph -> type reputation_graph');
is($reg->{reputation_graph}{layout}, 'vertical', 'reputation_graph -> vertical');
is($reg->{reputation_graph_horizontal}{type}, 'reputation_graph', 'horizontal reuses the reputation_graph component');
is($reg->{reputation_graph_horizontal}{layout}, 'horizontal', 'horizontal -> layout horizontal');

# The generic gate emits (a copy of) its payload from buildReactData.
my $gate = Everything::PureGatePage->new(content => { type => 'reputation_graph', layout => 'horizontal' });
isa_ok($gate, 'Everything::Page', 'PureGatePage is-a Everything::Page');
ok($gate->can('buildReactData'), 'PureGatePage can buildReactData (so controllers treat it as a React page)');
my $out = $gate->buildReactData(undef);
is_deeply($out, { type => 'reputation_graph', layout => 'horizontal' }, 'buildReactData returns the payload');
$out->{type} = 'mutated';
is($gate->buildReactData(undef)->{type}, 'reputation_graph', 'buildReactData returns a copy (registry not mutated)');

# The folded-in modules must be GONE -- otherwise a stale .pm would shadow the registry.
for my $name (@expected) {
    my $file = "Everything/Page/$name.pm";
    my $loaded = eval { require $file; 1 } || 0;
    ok(!$loaded, "no dedicated Everything::Page::$name module (served by the registry)");
}

done_testing();
