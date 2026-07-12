#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use MockUser;

# #4508 + #4509: the admin_bestow_tool-family Pages are pure gates -- each ships ONLY its own
# { type } and reads ZERO params. React (AdminBestowTool) owns all flavor text + the permission
# tier, keyed on the type. This test proves both:
#   (1) buildReactData returns exactly { type => <tool_key> } (no config, no permission flag), and
#   (2) it does so while the request's param() DIES if ever called.
# If any Page still reaches for a param -- or leaks config back into the payload -- this fails.

initEverything('development-docker');
ok($DB,  "Database connection established");
ok($APP, "Application object created");

# A request whose param() is a landmine: calling it fails the test's intent immediately.
{
    package NoParamRequest;
    sub new  { my ($c, %a) = @_; return bless { user => $a{user} }, $c; }
    sub user { return shift->{user}; }
    sub param { die "buildReactData read a URL param -- the bestow Pages must be param-free (#4508)\n"; }
}

my $root = $DB->getNode('root', 'user');
ok($root, "Got root user node");

# Even an admin request must get back a bare { type } -- permission now lives in React.
my $req = NoParamRequest->new(
    user => MockUser->new(node_id => $root->{node_id}, title => 'root', is_admin_flag => 1, nodedata => $root)
);

# Every family Page -> the exact type key it must now ship (and nothing else).
my %expected_type = (
    'Everything::Page::bestow_cools'          => 'bestow_cools',
    'Everything::Page::bestow_easter_eggs'    => 'bestow_easter_eggs',
    'Everything::Page::enrichify'             => 'enrichify',
    'Everything::Page::fiery_teddy_bear_suit' => 'fiery_teddy_bear_suit',
    'Everything::Page::giant_teddy_bear_suit' => 'giant_teddy_bear_suit',
    'Everything::Page::superbless'            => 'superbless',
    'Everything::Page::xp_superbless'         => 'xp_superbless',
    'Everything::Page::the_well_of_cool'      => 'the_well_of_cool',
);

for my $mod (sort keys %expected_type) {
    my $want = $expected_type{$mod};
    require_ok($mod) or next;
    my $page = $mod->new;
    isa_ok($page, $mod);

    my $data = eval { $page->buildReactData($req) };
    ok($data, "$want: buildReactData returned without reading a param");
    is($data->{type}, $want, "$want: ships its own type key");

    # Pure gate: the ONLY key is 'type'. No title/api_endpoint/has_permission/prefill leaking through.
    is_deeply([sort keys %$data], ['type'], "$want: ships nothing but { type } (config lives in React)");
}

done_testing();
