#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::API::bounties;
use MockRequest;
use TestSeed;

# Coverage for Everything::API::bounties (everything_s_most_wanted migration,
# #4198). Dedicated users + unique outlaw e2node so it's -j4 safe -- bounty
# entries are keyed by the dedicated sheriff's (unique) title. #4267

initEverything('development-docker');
my $APP = $Everything::APP;
my $DB  = $Everything::DB;
my $api = Everything::API::bounties->new();

my $root = $DB->getNode('root', 'user');

# A poster with enough level (experience) + GP, and a winner.
# Ample GP so the test reward amounts stay under the 10%-of-GP bounty cap.
my $sheriff = TestSeed::make_user($DB, $APP, label => 'sheriff', experience => 50000, numwriteups => 100, GP => 10000);
my $winner  = TestSeed::make_user($DB, $APP, label => 'winner',  GP => 0);
my $sheriff_title = $sheriff->{title};

# A valid outlaw e2node (create validates it exists).
my $outlaw_title = "e2e_bounty_outlaw_$$";
my $outlaw_id = $DB->insertNode($outlaw_title, 'e2node', $root, { title => $outlaw_title });

# Each bounty action is its own request in prod (fresh setting-node reads). In
# this single process the node cache otherwise serves a stale bounties blob
# across sequential actions, so flush before every action ($req) and verification
# read ($sv) to mirror per-request freshness.
my $sv = sub {
    $DB->{cache}->flushCache() if $DB->{cache};
    my $n = $APP->node_by_name($_[0], 'setting');
    return $n ? $APP->getVars($n->NODEDATA) : {};
};
my $req = sub {
    $DB->{cache}->flushCache() if $DB->{cache};
    my (%o) = @_;
    return MockRequest->new(
        node_id => $o{user}->{node_id}, title => $o{user}->{title},
        nodedata => $o{user}, is_guest_flag => ($o{guest} ? 1 : 0),
        request_method => 'POST', postdata => $o{post} || {},
    );
};
my $gp = sub { $DB->sqlSelect('GP', 'user', "user_id=$_[0]") };

# ---- gate: guest cannot post ----
{
    my $r = $api->list_or_create($req->(user => $DB->getNode('Guest User', 'user'), guest => 1,
        post => { outlaw => $outlaw_title, reward => 0 }));
    is($r->[1]{success}, 0, 'guest cannot post a bounty');
}

# ---- create: post a 10 GP bounty ----
{
    my $before = $gp->($sheriff->{node_id});
    my $r = $api->list_or_create($req->(user => $sheriff, post => { outlaw => $outlaw_title, reward => 10, comment => 'fill me' }));
    is($r->[1]{success}, 1, 'bounty posted') or diag($r->[1]{error});
    is($gp->($sheriff->{node_id}), $before - 10, 'sheriff GP reduced by the staked reward');
    is($sv->('outlaws')->{$sheriff_title}, "[$outlaw_title]", 'outlaw recorded for sheriff');
    is($sv->('bounties')->{$sheriff_title}, 10, 'reward recorded for sheriff');
    ok($APP->getVars($DB->getNode($sheriff->{node_id}))->{Bounty}, 'sheriff Bounty var set');
}

# ---- reward: pay the GP bounty to the winner, record justice ----
{
    my $wbefore = $gp->($winner->{node_id});
    my $jbefore = ($sv->('bounty number')->{justice} || 0);
    my $r = $api->reward_bounty($req->(user => $sheriff, post => { winner => $winner->{title} }));
    is($r->[1]{success}, 1, 'reward paid') or diag($r->[1]{error});
    is($gp->($winner->{node_id}), $wbefore + 10, 'winner GP increased by the reward');
    ok(!$APP->getVars($DB->getNode($sheriff->{node_id}))->{Bounty}, 'sheriff Bounty cleared after reward');
    cmp_ok(($sv->('bounty number')->{justice} || 0), '>', $jbefore, 'a justice citation was recorded');
}

# ---- remove: refund the sheriff's own bounty ----
{
    $api->list_or_create($req->(user => $sheriff, post => { outlaw => $outlaw_title, reward => 15 }));  # re-post
    my $before = $gp->($sheriff->{node_id});
    my $r = $api->remove_bounty($req->(user => $sheriff));
    is($r->[1]{success}, 1, 'own bounty removed');
    is($gp->($sheriff->{node_id}), $before + 15, 'staked GP refunded on remove');
    ok(!$APP->getVars($DB->getNode($sheriff->{node_id}))->{Bounty}, 'Bounty cleared after remove');
}

# ---- award: custom prize + GP portion ----
{
    $api->list_or_create($req->(user => $sheriff, post => { outlaw => $outlaw_title, reward => 5 }));  # re-post
    my $wbefore = $gp->($winner->{node_id});
    my $r = $api->award_bounty($req->(user => $sheriff, post => { winner => $winner->{title}, prize => 'a C!' }));
    is($r->[1]{success}, 1, 'custom award paid');
    like($r->[1]{message}, qr/a C!/, 'award message names the prize');
    is($gp->($winner->{node_id}), $wbefore + 5, 'winner got the GP portion of the award');
}

# ---- yank: admin removes the sheriff's bounty, refunds them ----
{
    $api->list_or_create($req->(user => $sheriff, post => { outlaw => $outlaw_title, reward => 20 }));  # re-post
    my $before = $gp->($sheriff->{node_id});
    # non-privileged user cannot yank
    my $bad = $api->yank_bounty($req->(user => $winner, post => { removee => $sheriff_title }));
    is($bad->[1]{success}, 0, 'non-sheriff/admin cannot yank');
    # admin (root) can
    my $r = $api->yank_bounty($req->(user => $root, post => { removee => $sheriff_title }));
    is($r->[1]{success}, 1, 'admin yanked the bounty');
    is($gp->($sheriff->{node_id}), $before + 20, 'yanked sheriff refunded');
}

# ---- validation: malformed create requests are rejected, and reject BEFORE any
#      GP is staked (every guard returns ahead of the adjustGP deduction) ----
{
    my $before = $gp->($sheriff->{node_id});

    my $miss = $api->list_or_create($req->(user => $sheriff, post => { reward => 5 }));
    is($miss->[1]{success}, 0, 'create without an outlaw is rejected');
    like($miss->[1]{error}, qr/specify a node/i, 'error names the missing outlaw');

    my $nonode = $api->list_or_create($req->(user => $sheriff,
        post => { outlaw => "no_such_outlaw_zzz_$$", reward => 5 }));
    is($nonode->[1]{success}, 0, 'create against a nonexistent outlaw node is rejected');
    like($nonode->[1]{error}, qr/no such node/i, 'error flags the invalid outlaw node');

    # sheriff GP ~10000 -> bounty cap is ~1000; 2000 must be refused.
    my $toohigh = $api->list_or_create($req->(user => $sheriff,
        post => { outlaw => $outlaw_title, reward => 2000 }));
    is($toohigh->[1]{success}, 0, 'reward over the 10%-of-GP cap is rejected');
    like($toohigh->[1]{error}, qr/too high/i, 'error explains the 10% cap');

    my $neg = $api->list_or_create($req->(user => $sheriff,
        post => { outlaw => $outlaw_title, reward => -5 }));
    is($neg->[1]{success}, 0, 'a negative reward is rejected');
    like($neg->[1]{error}, qr/0 or greater/i, 'error requires a non-negative bounty');

    is($gp->($sheriff->{node_id}), $before, 'no GP was staked by any rejected create');
}

# cleanup: drop the dedicated sheriff's entries from the shared bounty blobs,
# then nuke the throwaway users + outlaw node.
for my $setting ('outlaws', 'bounties', 'bounty comments') {
    my $n = $APP->node_by_name($setting, 'setting');
    next unless $n;
    my $v = $APP->getVars($n->NODEDATA);
    if (exists $v->{$sheriff_title}) { delete $v->{$sheriff_title}; Everything::setVars($n->NODEDATA, $v); }
}
$DB->nukeNode($DB->getNodeById($outlaw_id), -1) if $outlaw_id;
TestSeed::cleanup($DB);

done_testing();
