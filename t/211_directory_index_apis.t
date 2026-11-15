#!/usr/bin/perl -w
# Directory / index report pages tranche (#4557): everything_data_pages, edev_documentation_index,
# everything_document_directory, everything_publication_directory. Each moved its listing out of a
# Page (now a pure gate) into an API, and each API re-asserts the gate -- a pure gate serves the page
# to anyone and /api/pagestate bypasses node permissions.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use JSON;
use Everything;
use Everything::API::everything_data_pages;
use Everything::API::edev_documentation_index;
use Everything::API::everything_document_directory;
use Everything::API::everything_publication_directory;
use MockRequest;

initEverything('development-docker');
ok($DB, 'DB connection established');

my $root = $DB->getNode('root', 'user');

my $guest = sub { MockRequest->new(is_guest_flag => 1, query_params => { %{$_[0] || {}} }) };
# A plain logged-in member: no roles, no NODEDATA-derived privileges.
my $member = sub { MockRequest->new(is_guest_flag => 0, node_id => 1, title => 'mockmember',
                                    query_params => { %{$_[0] || {}} }) };
my $admin = sub { MockRequest->new(is_guest_flag => 0, node_id => $root->{node_id}, nodedata => $root,
                                   is_admin_flag => 1, is_editor_flag => 1,
                                   query_params => { %{$_[0] || {}} }) };

my $J = JSON->new;

#############################################################################
# everything_data_pages -- public feed directory
#############################################################################
{
    my $api = Everything::API::everything_data_pages->new;
    is_deeply($api->routes, { '/' => 'list' }, 'data_pages: routes');

    my $r = $api->list($guest->());
    is($r->[1]{success}, 1, 'data_pages: public');
    ok(ref($r->[1]{fullpages}) eq 'ARRAY', 'data_pages: fullpages array');
    ok(ref($r->[1]{tickers}) eq 'ARRAY',   'data_pages: tickers array');
    ok(@{ $r->[1]{tickers} } > 0, 'data_pages: dev DB has ticker nodes to list');

    # The excluded internal pages must never be advertised.
    my %titles = map { $_->{title} => 1 } @{ $r->[1]{fullpages} };
    ok(!$titles{'inboxlight'}, 'data_pages: deprecated inboxlight excluded');
    ok(!$titles{'Guest Front Page'}, 'data_pages: Guest Front Page excluded');

    unlike($J->encode($r->[1]{tickers}[0]), qr/"node_id"\s*:\s*"/, 'data_pages: node_id is a JSON number');
}

#############################################################################
# edev_documentation_index -- public listing, is_developer is an affordance flag
#############################################################################
{
    my $api = Everything::API::edev_documentation_index->new;
    my $r = $api->list($guest->());
    is($r->[1]{success}, 1, 'edev_index: public listing');
    ok(ref($r->[1]{docs}) eq 'ARRAY', 'edev_index: docs array');
    is(ref($r->[1]{is_developer}), 'SCALAR', 'edev_index: is_developer is a JSON boolean (#4108)');
    is(${ $r->[1]{is_developer} }, 0, 'edev_index: guest is never a developer');

    # Deliberately the gods-counting form the Page used ($APP->isDeveloper, no "nogods"), not
    # $user->is_developer -- an admin can create edevdocs, so the create box stays visible.
    is(${ $api->list($admin->())->[1]{is_developer} }, 1,
       'edev_index: an admin counts as a developer (matches the Page it replaced)');
}

#############################################################################
# everything_document_directory -- NoGuest; permissions scope the visible types
#############################################################################
{
    my $api = Everything::API::everything_document_directory->new;
    is($api->list($guest->())->[1]{state}, 'guest', 'doc_directory: guest -> guest state');

    my $m = $api->list($member->());
    is($m->[1]{success}, 1, 'doc_directory: member ok');
    ok(ref($m->[1]{documents}) eq 'ARRAY', 'doc_directory: documents array');

    my %m_types = map { $_ => 1 } @{ $m->[1]{available_nodetypes} };
    ok($m_types{superdoc} && $m_types{document}, 'doc_directory: member sees the base types');
    ok(!$m_types{restricted_superdoc}, 'doc_directory: member does NOT see restricted_superdoc');
    ok(!$m_types{oppressor_superdoc},  'doc_directory: member does NOT see oppressor_superdoc');

    my $a = $api->list($admin->());
    my %a_types = map { $_ => 1 } @{ $a->[1]{available_nodetypes} };
    ok($a_types{restricted_superdoc}, 'doc_directory: admin sees restricted_superdoc');
    ok($a_types{oppressor_superdoc},  'doc_directory: admin/editor sees oppressor_superdoc');

    # The gate is enforced, not merely reflected: asking for a type you may not see must not widen
    # the result -- it yields nothing rather than restricted documents.
    my $sneak = $api->list($member->({ filter_nodetype => 'restricted_superdoc' }));
    is($sneak->[1]{success}, 1, 'doc_directory: unpermitted filter still returns a payload');
    is(scalar(@{ $sneak->[1]{documents} }), 0, 'doc_directory: unpermitted filter returns NO documents');
    is($sneak->[1]{filter_nodetype}, '', 'doc_directory: unpermitted filter is not echoed back');

    # A permitted filter narrows normally.
    my $ok = $api->list($member->({ filter_nodetype => 'superdoc' }));
    is($ok->[1]{filter_nodetype}, 'superdoc', 'doc_directory: permitted filter honoured');

    # edd_limit is digits-only; garbage falls back to the role default rather than reaching SQL.
    my $bad = $api->list($member->({ edd_limit => '10; DROP TABLE node' }));
    is($bad->[1]{limit}, 60, 'doc_directory: non-numeric edd_limit falls back to the default');
    my $lim = $api->list($member->({ edd_limit => '5' }));
    is($lim->[1]{limit}, 5, 'doc_directory: numeric edd_limit honoured');
    ok(scalar(@{ $lim->[1]{documents} }) <= 5, 'doc_directory: limit actually caps the list');

    is(ref($m->[1]{is_developer}), 'SCALAR', 'doc_directory: is_developer is a JSON boolean (#4108)');

    # edd_limit is capped: "show all" on a large result set is an author lookup per row.
    my $huge = $api->list($member->({ edd_limit => '999999' }));
    is($huge->[1]{limit}, 1000, 'doc_directory: edd_limit capped at $MAX_LIMIT');

    # Sort comes from the viewer's stored pref and is READ here only (#4416) -- the value reaches
    # ORDER BY, so it goes through a whitelist and an unmapped value must degrade, not interpolate.
    my $sorted = MockRequest->new(is_guest_flag => 0, node_id => 1, vars => { EDD_Sort => 'nameA' });
    is($api->list($sorted)->[1]{current_sort}, 'nameA', 'doc_directory: current_sort read from VARS');
    my $bogus = MockRequest->new(is_guest_flag => 0, node_id => 1,
                                 vars => { EDD_Sort => "idA; DROP TABLE node" });
    is($api->list($bogus)->[1]{success}, 1, 'doc_directory: unmapped EDD_Sort falls back, no SQL');

    # The developer tier adds Edevdoc to the browsable types.
    my $dev = MockRequest->new(is_guest_flag => 0, node_id => 1, is_developer_flag => 1);
    my $d = $api->list($dev);
    my %d_types = map { $_ => 1 } @{ $d->[1]{available_nodetypes} };
    ok($d_types{Edevdoc}, 'doc_directory: developer sees Edevdoc');
    is(${ $d->[1]{is_developer} }, 1, 'doc_directory: developer flag set');
}

#############################################################################
# everything_publication_directory -- thepub usergroup OR admin (in-code gate,
# narrower than the oppressor_superdoc type default)
#############################################################################
{
    my $api = Everything::API::everything_publication_directory->new;
    is($api->list($guest->())->[1]{state}, 'guest', 'pub_directory: guest -> guest state');
    is($api->list($member->())->[1]{state}, 'permission', 'pub_directory: non-thepub member -> permission');

    my $a = $api->list($admin->());
    is($a->[1]{success}, 1, 'pub_directory: admin ok');
    ok(ref($a->[1]{debates}) eq 'ARRAY', 'pub_directory: debates array');

    # The admin must actually see debates -- an empty list means the per-debate group filter
    # rejected everything. tools/seeds.pl guarantees a restricted=114 root ("Seed Debate for
    # PageState"), so this is a hard assertion: a conditional skip here once let a malformed seed
    # (root_debatecomment=0) make it pass vacuously.
    my $roots = $DB->sqlSelect('COUNT(DISTINCT root_debatecomment)', 'debatecomment',
                               'restricted=114 AND root_debatecomment > 0');
    ok($roots, 'pub_directory: seed provides a restricted=114 debate root (see tools/seeds.pl)');
    ok(scalar(@{ $a->[1]{debates} }) > 0, 'pub_directory: admin actually sees the debates');
    ok((grep { $_->{title} eq 'Seed Debate for PageState' } @{ $a->[1]{debates} }),
       'pub_directory: the seeded debate is in the list');

    ok(!exists $a->[1]{can_create}, 'pub_directory: can_create no longer shipped (React config)');
}

done_testing();
