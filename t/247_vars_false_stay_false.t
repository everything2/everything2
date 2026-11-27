#!/usr/bin/perl -w
#
# Saving a node's settings (setVars) must leave the caller's hash as it was. The settings string
# stores a false value as " ", and " " is true in Perl: if saving rewrote the caller's hash, every
# setting that's off would read as on for the rest of the request (#4751). The homenode shows it:
# the request that refreshes a member's writeup count (hourly) saves their settings, then reads
# "don't list my usergroups / categories" and "hide last seen" from the same hash.
#
use strict;
use warnings;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5 /var/everything/t/lib);
use Test::More;
use Everything;
use Everything::Controller::user;
use TestSeed;

initEverything 'everything';
my $DB  = $Everything::DB;
my $APP = $Everything::APP;

my @planted;
END {
    for my $id (@planted) {
        if (my $n = $DB->getNodeById($id, 'force')) { $DB->nukeNode($n, -1, 1) }
        $DB->sqlDelete('tomb', "node_id=$id");
    }
    TestSeed::cleanup($DB);
}

subtest 'turning settings into the stored string' => sub {
    my %vars = (off => 0, blank => '', on => 1, gone => undef);
    my $string = $APP->getVarStringFromHash(\%vars);
    is($string, 'blank=%20&gone=%20&off=%20&on=1', 'false and undefined values are stored as a space');
    is_deeply(\%vars, { off => 0, blank => '', on => 1, gone => undef }, "and the caller's hash is left as it was");
};

subtest 'saving settings' => sub {
    my $member = TestSeed::make_user($DB, $APP, label => 'varsfalse');
    my $node = $DB->getNodeById($member->{node_id}, 'force');
    my $vars = $APP->getVars($node);
    @$vars{qw(hidelastseen hidehomenodeUG keepme dropme)} = (0, '', 'yes', 'x');
    Everything::setVars($node, $vars);

    $vars = $APP->getVars($DB->getNodeById($member->{node_id}, 'force'));
    is($vars->{keepme}, 'yes', 'saved');
    is($vars->{hidelastseen}, '', 'an off setting reads back as false');

    $vars->{hidelastseen} = 0;
    $vars->{dropme} = undef;
    $vars->{keepme} = 'still';
    my %before = %$vars;
    Everything::setVars($DB->getNodeById($member->{node_id}, 'force'), $vars);
    is_deeply($vars, \%before, "the caller's hash is left as it was");
    ok(!$vars->{hidelastseen} && !$vars->{hidehomenodeUG}, 'so its off settings still read as off');

    my $stored = $DB->sqlSelect('vars', 'setting', "setting_id=$member->{node_id}");
    like($stored, qr/(?:^|&)keepme=still(?:&|$)/, 'the change is stored');
    like($stored, qr/(?:^|&)hidelastseen=%20(?:&|$)/, 'an off setting is stored as a space, as before');
    like($stored, qr/(?:^|&)dropme=%20(?:&|$)/, 'and so is an undefined one, as before');
};

subtest "the homenode request that refreshes a member's writeup count" => sub {
    my $owner  = TestSeed::make_user($DB, $APP, label => 'varsowner');
    my $viewer = TestSeed::make_user($DB, $APP, label => 'varsviewer');
    my $root   = $DB->getNode('root', 'user');
    my $group  = $DB->insertNode("Vars false group $$", 'usergroup', $root, {}, 'skip maintenance');
    push @planted, $group;
    $DB->insertIntoNodegroup($DB->getNodeById($group, 'force'), -1, $owner->{node_id});
    my $category = $DB->insertNode("Vars false category $$", 'category', $owner, { author_user => $owner->{node_id} }, 'skip maintenance');
    push @planted, $category;

    # Everything off, and the writeup count due for its hourly refresh.
    my $u = $DB->getNodeById($owner->{node_id}, 'force');
    my $v = $APP->getVars($u);
    @$v{qw(hidehomenodeUG hidehomenodeUC hidelastseen nwriteupsupdate)} = (0, 0, 0, 1);
    Everything::setVars($u, $v);

    $DB->{cache}->resetCache;
    my $node = $APP->node_by_id($owner->{node_id});
    my $as   = $APP->node_by_id($viewer->{node_id});
    Everything::Controller::user->new->_setup_user_vars($node, $as, 0);
    cmp_ok($APP->getVars($DB->getNodeById($owner->{node_id}, 'force'))->{nwriteupsupdate}, '>', 1, 'the writeup count was refreshed');

    # What the homenode then shows this viewer, read as Controller::user::display does.
    my @groups = map { $_->node_id } @{ $node->usergroups_visible_to($as) };
    ok((grep { $_ == $group } @groups), 'the usergroup is listed');
    my @cats = map { $_->node_id } @{ $node->categories_visible_to($as, $node->maintained_categories) };
    ok((grep { $_ == $category } @cats), 'the category is listed');
    ok(!$node->VARS->{hidelastseen}, '"last seen" is not hidden');
};

done_testing();
