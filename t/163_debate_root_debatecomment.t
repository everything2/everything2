#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions ProhibitMagicNumbers ProhibitInterpolationOfLiterals ValuesAndExpressions)

#############################################################################
# 163_debate_root_debatecomment.t
#
# Regression guard for usergroup-discussion visibility.
#
# A top-level discussion must root itself (root_debatecomment = its own node_id),
# and replies must point at the THREAD root. The htmlpage->API conversion
# (252576b08) regressed this by passing root_debatecomment=0 in the insert
# nodedata, which silently defeated the debate_create maintenance hook -- so
# discussions landed with root_debatecomment=0 and vanished from
# usergroup_discussions (it GROUP BYs root_debatecomment then getNodeById()s it).
#############################################################################

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;
use Everything::API::debatecomments;

initEverything('development-docker');
ok($DB,  'DB connection');
ok($APP, 'APP object');

my $GODS = 114;   # the 'gods' usergroup; root is a member/admin

# Minimal request stub: create_debate/reply read is_guest, user, JSON_POSTDATA.
{
    package DebateReq;
    sub new          { bless { u => $_[1], d => $_[2] }, $_[0] }
    sub is_guest     { 0 }
    sub user         { $_[0]->{u} }
    sub JSON_POSTDATA { $_[0]->{d} }
}

my $api  = Everything::API::debatecomments->new;
my $root = $APP->node_by_id(113);
my $ts   = time();
my @cleanup;

sub rc_of { $DB->sqlSelect('root_debatecomment', 'debatecomment', "debatecomment_id=$_[0]") }

# --- top-level discussion roots itself ---------------------------------------
my $disc = $api->create_debate(
    DebateReq->new($root, { title => "RootTest discussion $ts", restricted => $GODS }))->[1]{node_id};
ok($disc, 'create_debate returned a node_id');
push @cleanup, $disc;
isnt(rc_of($disc), 0,     'discussion root_debatecomment is NOT 0 (the regression value)');
is(rc_of($disc),  $disc,  'discussion roots itself (root_debatecomment = own node_id)');

# it is now visible to the listing query (GROUP BY root_debatecomment, restricted=ug)
my $listable = $DB->sqlSelect('COUNT(*)', 'debatecomment',
    "restricted=$GODS AND root_debatecomment=$disc");
is($listable, 1, 'discussion is listable on usergroup_discussions');

# --- a reply points at the thread root ---------------------------------------
my $reply = $api->reply(
    DebateReq->new($root, { title => 're: RootTest', doctext => 'first reply' }), $disc)->[1]{node_id};
ok($reply, 'reply returned a node_id');
unshift @cleanup, $reply;
is(rc_of($reply), $disc, 'reply root_debatecomment = the discussion (thread root)');

# --- a nested reply still points at the thread root, not its immediate parent -
my $nested = $api->reply(
    DebateReq->new($root, { title => 're: re:', doctext => 'nested reply' }), $reply)->[1]{node_id};
ok($nested, 'nested reply returned a node_id');
unshift @cleanup, $nested;
is(rc_of($nested), $disc, 'nested reply root_debatecomment = the thread root, not the immediate parent');

# cleanup (children first)
$DB->nukeNode($DB->getNodeById($_, 'force'), -1, 1) for grep { $DB->getNodeById($_, 'force') } @cleanup;

done_testing();
