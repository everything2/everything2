#!/usr/bin/perl -w
# Everything::Roles::Bestow (#4497) -- the shared server-side logic the websterbless Page and
# API twin both need, extracted so the Page stops calling $DB directly.
#
# The point of the role is *testability without a live DB*: the role only `requires DB()/APP()`,
# so we compose it into a throwaway consumer backed by a mock DB and assert its reads/payload in
# isolation -- no initEverything, no real database, no request/render machinery. That's the tier-2
# controller-data test net the extraction buys. (The real Page/API consumers are exercised by the
# full suite + t/184_websterbless_api.t.)
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;

# --- a mock DB: getNode('Webster 1913') -> the seeded node (or undef), sqlSelect -> a count ----
{
    package MockBestowDB;
    sub new { my ($class, %args) = @_; return bless {%args}, $class }
    sub getNode {
        my ($self, $name, $type) = @_;
        return undef unless $name eq 'Webster 1913' && $type eq 'user';
        return $self->{webster};
    }
    sub sqlSelect {
        my ($self, $what, $table, $where) = @_;
        # mirror the real call shape so a wrong query would show up here
        return undef unless $what eq 'COUNT(*)' && $table eq 'message' && $where =~ /^for_user=\d+$/;
        return $self->{count};
    }
    sub updateNode { my ($self, $node, $user) = @_; push @{$self->{updates}}, $node; return 1; }
}

# --- a mock APP: records the karma achievement checks award_karma triggers -------------------
{
    package MockBestowAPP;
    sub new { my ($class, %args) = @_; return bless {%args, checks => []}, $class }
    sub checkAchievementsByType { my ($self, $type, $uid) = @_; push @{$self->{checks}}, [$type, $uid]; return 1; }
}

# --- a throwaway consumer of the role, backed by the mock (no Everything, no DB) --------------
{
    package BestowConsumer;
    use Moose;
    # DB()/APP() must exist before `with` so the role's `requires` is satisfied at composition.
    has DB  => (is => 'ro');
    has APP => (is => 'ro');
    with 'Everything::Roles::Bestow';
    __PACKAGE__->meta->make_immutable;
}

ok(BestowConsumer->does('Everything::Roles::Bestow'), 'consumer composes Everything::Roles::Bestow');

#############################################################################
# Webster present: reads + payload
#############################################################################
{
    my $db = MockBestowDB->new(webster => { node_id => 176726 }, count => 42);
    my $c  = BestowConsumer->new(DB => $db);

    is($c->webster_user->{node_id}, 176726, 'webster_user returns the Webster 1913 node');
    is($c->webster_message_count, 42, 'webster_message_count returns the COUNT');

    my $p = $c->webster_payload;
    is($p->{webster_id}, 176726, 'payload: webster_id');
    is($p->{msg_count}, 42, 'payload: msg_count');
    ok(!exists $p->{error}, 'payload: no error when Webster present');
}

#############################################################################
# COUNT(*) returns nothing -> msg_count defaults to 0 (|| 0 guard)
#############################################################################
{
    my $db = MockBestowDB->new(webster => { node_id => 176726 }, count => undef);
    my $c  = BestowConsumer->new(DB => $db);
    is($c->webster_message_count, 0, 'msg_count falls back to 0 when the COUNT is empty');
    is($c->webster_payload->{msg_count}, 0, 'payload msg_count is 0, not undef');
}

#############################################################################
# Webster missing -> payload is an { error }, and no COUNT is attempted
#############################################################################
{
    my $db = MockBestowDB->new(webster => undef, count => 99);
    my $c  = BestowConsumer->new(DB => $db);

    is($c->webster_user, undef, 'webster_user is undef when the account is absent');
    is($c->webster_message_count, 0, 'message count short-circuits to 0 without a Webster node');

    my $p = $c->webster_payload;
    like($p->{error}, qr/Webster 1913/, 'payload carries the missing-Webster error');
    ok(!exists $p->{webster_id}, 'no webster_id in the error payload');
}

#############################################################################
# award_karma: the shared bless-write (karma bump + persist + achievement check) behind
# superbless grant_gp/grant_xp and the websterbless thank-you (#4500).
#############################################################################
{
    my $db  = MockBestowDB->new(updates => []);
    my $app = MockBestowAPP->new;
    my $c   = BestowConsumer->new(DB => $db, APP => $app);

    my $target = { node_id => 500, user_id => 500, karma => 10 };

    is($c->award_karma($target, 1), 11, 'award_karma(+1) returns the new karma total');
    is($target->{karma}, 11, 'target karma bumped in place');
    is(scalar @{$db->{updates}}, 1, 'updateNode called once (persisted)');
    is_deeply($app->{checks}, [['karma', 500]], 'checkAchievementsByType(karma, user_id) run');

    is($c->award_karma($target, -1), 10, 'award_karma(-1) decrements');
    is($target->{karma}, 10, 'karma back to 10');

    # delta 0 -> no-op: no persist, no achievement check, karma untouched (matches the old guard)
    my ($u0, $c0) = (scalar @{$db->{updates}}, scalar @{$app->{checks}});
    $c->award_karma($target, 0);
    is($target->{karma}, 10, 'award_karma(0) leaves karma unchanged');
    is(scalar @{$db->{updates}}, $u0, 'award_karma(0) does not persist');
    is(scalar @{$app->{checks}}, $c0, 'award_karma(0) skips the achievement check');

    # undef karma treated as 0 (|| 0 guard) -- no undef-warning, result identical to the old code
    my $fresh = { node_id => 501, user_id => 501 };
    is($c->award_karma($fresh, 1), 1, 'award_karma on an undef karma yields 1');
}

done_testing;
