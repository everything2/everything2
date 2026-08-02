#!/usr/bin/perl -w
# Registry family completion (#4550): popular_registries (public report) + create_a_registry (the
# level-8 create gate). Also exercises the QA registration seeds (tools/seeds.pl) -- popular_registries
# should now return ranked rows instead of an empty page.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use JSON;
use Everything;
use Everything::API::popular_registries;
use Everything::API::create_a_registry;
use MockRequest;

initEverything('development-docker');
ok($DB, 'DB connection established');

my $root = $DB->getNode('root', 'user');

my $guest  = sub { MockRequest->new(is_guest_flag => 1) };
my $member = sub { MockRequest->new(is_guest_flag => 0, node_id => $root->{node_id}, nodedata => $root) };

my $J = JSON->new;

#############################################################################
# popular_registries -- public; the QA seeds give it a real ranking
#############################################################################
{
    my $api = Everything::API::popular_registries->new;
    is_deeply($api->routes, { '/' => 'list' }, 'popular_registries: routes');

    my $r = $api->list($guest->());
    is($r->[1]{success}, 1, 'popular_registries: ok (public)');
    ok(ref($r->[1]{registries}) eq 'ARRAY', 'popular_registries: registries array');
    ok(@{ $r->[1]{registries} } > 0, 'popular_registries: QA seeds produced rows');

    my @counts = map { $_->{submission_count} } @{ $r->[1]{registries} };
    is_deeply(\@counts, [ sort { $b <=> $a } @counts ], 'popular_registries: ordered by submission_count desc');
    unlike($J->encode($r->[1]{registries}[0]), qr/"(?:node_id|submission_count)"\s*:\s*"/,
        'popular_registries: node_id/submission_count are JSON numbers');
}

#############################################################################
# create_a_registry -- guest gate + level-8 check
#############################################################################
{
    my $api = Everything::API::create_a_registry->new;
    is($api->list($guest->())->[1]{state}, 'guest', 'create_a_registry: guest -> guest state');

    my $r = $api->list($member->());
    is($r->[1]{success}, 1, 'create_a_registry: member ok');
    is(ref($r->[1]{can_create}), 'SCALAR', 'create_a_registry: can_create is a JSON boolean (#4108)');
    is(${ $r->[1]{can_create} }, 1, 'create_a_registry: root (high level) can create');
    like("$r->[1]{current_level}", qr/^\d+$/, 'create_a_registry: current_level is numeric');
    is($r->[1]{level_required}, 8, 'create_a_registry: level_required 8');
}

#############################################################################
# create_a_registry/create -- the answer style + description must actually stick (#4554).
# The generic POST /api/node/create takes only type+title, so it dropped both and every registry
# came back free-text. Creation lives on this API now, and it is the real level-8 boundary.
#############################################################################
{
    my $api = Everything::API::create_a_registry->new;
    is($api->routes->{'/create'}, 'create_registry', 'create_a_registry: /create route');

    my $post = sub {
        MockRequest->new(is_guest_flag => 0, node_id => $root->{node_id}, nodedata => $root,
                         postdata => $_[0]);
    };

    is($api->create_registry(MockRequest->new(is_guest_flag => 1))->[1]{state}, 'guest',
        'create: guest -> guest state');

    # A yes/no registry must come back yes/no -- the actual reported bug.
    my $title = "QA yes-no registry $$";
    my $c = $api->create_registry($post->({ title => $title, description => 'Pick one', input_style => 'yes/no' }));
    is($c->[1]{success}, 1, 'create: yes/no registry created');
    is($c->[1]{input_style}, 'yes/no', 'create: echoes the requested input_style');

    my $made = $DB->getNodeById($c->[1]{node_id}, 'force');
    is($made->{input_style}, 'yes/no', 'create: input_style PERSISTED as yes/no (#4554 regression guard)');
    is($made->{doctext}, 'Pick one', 'create: description persisted to doctext');

    # Unknown styles are rejected rather than written through to the registry row.
    my $bad = $api->create_registry($post->({ title => "QA bogus $$", input_style => 'sql; drop' }));
    is($bad->[1]{success}, 0, 'create: unknown answer style rejected');
    ok(!$DB->getNode("QA bogus $$", 'registry'), 'create: rejected style created no node');

    # A title is required.
    is($api->create_registry($post->({ title => '   ', input_style => 'text' }))->[1]{success}, 0,
        'create: blank title rejected');

    # Duplicate titles are refused.
    is($api->create_registry($post->({ title => $title, input_style => 'text' }))->[1]{success}, 0,
        'create: duplicate title rejected');

    # Cleanup so reruns stay idempotent.
    $DB->nukeNode($made, -1) if $made;
}

done_testing();
