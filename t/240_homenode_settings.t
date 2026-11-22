#!/usr/bin/perl -w

# Homenode settings (#4659): "Don't list my usergroups / categories on my homenode" hide them from
# other members (admins and the member still see them), guests see only staff groups, and "your daily
# votes and C!s" show only on your own homenode unless hidden. The rules live on the user node, so the
# generic node API gives the same answer as the homenode.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "$FindBin::Bin/lib";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;
use Everything::API::nodes;

initEverything('development-docker');
my $DB  = $Everything::DB;
my $APP = $Everything::APP;

my $owner_ref = $DB->getNode('normaluser22', 'user');
my $other_ref = $DB->getNode('normaluser23', 'user');
my $root_ref  = $DB->getNode('root', 'user');
my $edev      = $DB->getNode('edev', 'usergroup');
ok($owner_ref && $other_ref && $root_ref && $edev, 'test users and edev exist');

my $owner_id = $owner_ref->{node_id};
my %saved_vars = %{ Everything::getVars($owner_ref) || {} };
my ($group_id, $category_id, $added_to_edev);

END {
    return unless $DB;
    if (my $u = $DB->getNodeById($owner_id, 'force')) {
        Everything::setVars($u, { %saved_vars });
        $DB->updateNode($u, -1);
    }
    $DB->removeFromNodegroup($DB->getNodeById($edev->{node_id}, 'force'), $DB->getNodeById($owner_id, 'force'), -1)
        if $added_to_edev;
    for my $id (grep { $_ } $group_id, $category_id) {
        if (my $n = $DB->getNodeById($id, 'force')) { $DB->nukeNode($n, -1, 1) }
        $DB->sqlDelete('tomb', 'node_id=' . int($id));
    }
}

# The owner: in an ordinary usergroup and in edev (a staff group), maintaining one category.
$group_id = $DB->insertNode("Homenode settings group $$", 'usergroup', $root_ref, {}, 'skip maintenance');
$DB->insertIntoNodegroup($DB->getNodeById($group_id, 'force'), -1, $owner_id);
unless (grep { $_ == $owner_id } @{ $DB->getNodeById($edev->{node_id}, 'force')->{group} || [] }) {
    $DB->insertIntoNodegroup($DB->getNodeById($edev->{node_id}, 'force'), -1, $owner_id);
    $added_to_edev = 1;
}
$category_id = $DB->insertNode("Homenode settings category $$", 'category', $owner_ref,
    { author_user => $owner_id }, 'skip maintenance');
ok($group_id && $category_id, 'planted a usergroup and a category');

sub set_owner_vars {
    my (%vars) = @_;
    my $u = $DB->getNodeById($owner_id, 'force');
    my $v = Everything::getVars($u);
    $v->{$_} = $vars{$_} for keys %vars;
    Everything::setVars($u, $v);
    $DB->updateNode($u, -1);
}

sub owner  { return $APP->node_by_id($owner_id) }
sub viewer { return $APP->node_by_id($_[0]) }

my %viewer = (
    guest => viewer($Everything::CONF->guest_user),
    other => viewer($other_ref->{node_id}),
    admin => viewer($root_ref->{node_id}),
    owner => viewer($owner_id),
);
ok($viewer{guest}->is_guest && !$viewer{other}->is_admin && $viewer{admin}->is_admin, 'viewer roles are as expected');

sub group_titles {
    my ($who) = @_;
    my %t = map { $_->title => 1 } @{ owner()->usergroups_visible_to($viewer{$who}) };
    return join(',', sort grep { $_ eq 'edev' || /^Homenode settings group/ } keys %t);
}
sub sees_category {
    my ($who) = @_;
    return scalar grep { $_->node_id == $category_id } @{ owner()->categories_visible_to($viewer{$who}, owner()->maintained_categories) };
}
# GET /api/nodes/:id as this viewer, through the API's own read check.
{
    package ViewerRequest;
    sub new      { my ($class, $user) = @_; return bless { user => $user }, $class }
    sub user     { return $_[0]{user} }
    sub is_guest { return $_[0]{user}->is_guest }
}
sub api_json {
    my ($who) = @_;
    my $r = Everything::API::nodes->new->get_id(ViewerRequest->new($viewer{$who}), $owner_id);
    is($r->[0], 200, "GET /api/nodes/:id as the $who");
    return $r->[1] || {};
}

my $all   = "Homenode settings group $$,edev";
my $staff = 'edev';

subtest 'nothing hidden' => sub {
    set_owner_vars(hidehomenodeUG => 0, hidehomenodeUC => 0);
    is(group_titles('other'), $all, 'another member sees every usergroup');
    is(group_titles('guest'), $staff, 'a guest sees only staff groups');
    is(group_titles('owner'), $all, 'the member sees their own');
    ok(sees_category($_), "the $_ sees the category") for qw(other guest owner admin);
};

subtest "Don't list my usergroups on my homenode" => sub {
    set_owner_vars(hidehomenodeUG => 1, hidehomenodeUC => 0);
    is(group_titles('other'), $staff, 'another member sees only staff groups');
    is(group_titles('guest'), $staff, 'so does a guest');
    is(group_titles('admin'), $all, 'an admin still sees every usergroup');
    is(group_titles('owner'), $all, 'the member still sees their own');
    ok(sees_category('other'), 'categories are unaffected');

    my $json = api_json('other');
    my %api = map { $_->{title} => 1 } @{ $json->{groups} || [] };
    ok(!$api{"Homenode settings group $$"}, 'the node API hides it from another member too');
    ok($api{edev}, 'and still lists the staff group');
};

subtest "Don't list my categories on my homenode" => sub {
    set_owner_vars(hidehomenodeUG => 0, hidehomenodeUC => 1);
    ok(!sees_category('other'), 'another member does not see the category');
    ok(!sees_category('guest'), 'nor does a guest');
    ok(sees_category('admin'), 'an admin still does');
    ok(sees_category('owner'), 'the member still does');
    is(group_titles('other'), $all, 'usergroups are unaffected');

    my $json = api_json('other');
    is_deeply($json->{categories} || [], [], 'the node API hides categories from another member too');
    ok(scalar(grep { $_->{node_id} == $category_id } @{ api_json('owner')->{categories} || [] }),
        'and shows them to the member');
};

subtest 'your daily votes and C!s' => sub {
    set_owner_vars(hidevotedata => 0, cools => 2);
    my $daily = owner()->daily_votes_and_cools;
    ok($daily, 'shown by default');
    is($daily->{cools_left}, 2, 'with the C!s left');
    ok(defined $daily->{votes} && defined $daily->{cools}, 'and the daily allowance at their level');

    set_owner_vars(hidevotedata => 1);
    is(owner()->daily_votes_and_cools, undef, 'hidden when hidevotedata is set');
};

done_testing();
