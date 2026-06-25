#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything::PageState;

# Everything::PageState -- SPIKE (docs/pagestate-design.md). Pins the chrome/content
# partition contract and the migration safety net (unclassified_keys). Pure: PageState
# carries no DB/CONF dependency, so no framework init is needed.

#############################################################################
# The manifest classifies the full e2 blob (44 keys, no overlaps, no gaps)
#############################################################################

my @chrome    = Everything::PageState->chrome_keys;
my @content   = Everything::PageState->content_keys;
my @ambiguous = Everything::PageState->ambiguous_keys;

is(scalar(@chrome),    32, 'chrome manifest has 32 keys');
is(scalar(@content),   10, 'content manifest has 10 keys');
is(scalar(@ambiguous),  2, 'ambiguous set has 2 keys (bounties, otherUsersData)');

my %seen;
$seen{$_}++ for (@chrome, @content, @ambiguous);
my @dupes = grep { $seen{$_} > 1 } keys %seen;
is_deeply(\@dupes, [], 'no key is classified into more than one bucket');
is(scalar(keys %seen), 44, 'manifest covers exactly 44 distinct blob keys');

# The exact key inventory of buildNodeInfoStructure (Application.pm:6787), captured
# 2026-06-10. If buildNodeInfoStructure gains/loses a key, this list and the manifest
# must move together -- that is the whole point of the safety net.
my @blob_keys = qw(
    architecture assets_location bounties chatterbox contentData currentNodeId
    currentNodeTitle currentPoll currentUserId daylogLinks developerNodelet
    display_prefs epicenter favoriteWriteups forReviewData guest hasMessagesNodelet
    lastCommit masterControl messagesData neglectedDrafts newWriteups news
    nodeCategories node_id nodetype node nonodeletcollapser noquickvote noteletData
    notificationsData otherUsersData pageheader personalLinks quickRefSearchTerm
    randomNodes reactPageMode recaptcha recentNodes statistics title use_local_assets
    usergroupData user
);
is(scalar(@blob_keys), 44, 'reference blob inventory is 44 keys');

#############################################################################
# unclassified_keys: the migration safety net
#############################################################################

# A blob whose keys are exactly the manifest's -> nothing unclassified.
my %full_blob = map { $_ => 1 } @blob_keys;
is_deeply(Everything::PageState->unclassified_keys(\%full_blob), [],
    'the live blob inventory is fully classified (no orphan keys)');

# Inject a hypothetical new blob key -> it surfaces, forcing a classification decision.
my %with_new = (%full_blob, someNewNodelet => 1, anotherNewThing => 1);
is_deeply(Everything::PageState->unclassified_keys(\%with_new),
    ['anotherNewThing', 'someNewNodelet'],
    'an unclassified key is flagged (sorted)');

#############################################################################
# from_blob: partition behaviour
#############################################################################

my $part = Everything::PageState->from_blob(\%full_blob);
ok($part->{chrome},  'from_blob returns a chrome partition');
ok($part->{content}, 'from_blob returns a content partition');

# Representative chrome keys land in chrome.
ok($part->{chrome}{epicenter},  'epicenter is chrome');
ok($part->{chrome}{messagesData}, 'messagesData is chrome');
ok($part->{chrome}{user},       'user identity is chrome');
ok(!exists $part->{chrome}{contentData}, 'contentData is NOT chrome');

# Representative content keys land in content.
ok($part->{content}{contentData}, 'contentData is content');
ok($part->{content}{node},        'node is content');
ok($part->{content}{nodeCategories}, 'nodeCategories is content');
ok(!exists $part->{content}{epicenter}, 'epicenter is NOT content');

# Ambiguous keys appear in BOTH partitions until placed (conservative, lossless).
ok($part->{chrome}{bounties},  'bounties (ambiguous) is in chrome for now');
ok($part->{content}{bounties}, 'bounties (ambiguous) is in content for now');

# Only-present keys are carried; absent keys are not invented.
my $sparse = Everything::PageState->from_blob({ user => {id=>1}, contentData => {x=>1} });
is_deeply([sort keys %{$sparse->{chrome}}],  ['user'],        'sparse chrome carries only present keys');
is_deeply([sort keys %{$sparse->{content}}], ['contentData'], 'sparse content carries only present keys');

# Empty / undef input is safe.
my $empty = Everything::PageState->from_blob();
is_deeply($empty, { chrome => {}, content => {} }, 'undef blob -> empty partitions');

#############################################################################
# Phase 2b builder: _build_news (#4257). Resolves the cron-cached frontpagenews
# stash to [{node_id,title}], dropping removed nodes + drafts. A mock DB keeps
# this pure (the builder only touches stashData + getNodeById).
#############################################################################
{
    package T141::MockDB;
    sub new         { bless { stash => $_[1], nodes => $_[2] }, $_[0] }
    sub stashData   { return $_[0]->{stash} }
    sub getNodeById { return $_[0]->{nodes}{ $_[1] } }
}

my $news_nodes = {
    10 => { node_id => 10, title => 'Real News', type => { title => 'weblog' } },
    20 => { node_id => 20, title => 'A Draft',   type => { title => 'draft' } },  # dropped
    # node 30 absent -> getNodeById returns undef -> dropped (removed node)
};
my $news_stash = [ { to_node => 10 }, { to_node => 20 }, { to_node => 30 } ];

is_deeply(
    Everything::PageState->_build_news( T141::MockDB->new( $news_stash, $news_nodes ) ),
    [ { node_id => 10, title => 'Real News' } ],
    '_build_news keeps non-draft existing nodes, drops drafts + removed, carries node_id+title'
);
is_deeply(Everything::PageState->_build_news( T141::MockDB->new( undef, {} ) ), [],
    '_build_news: undef stash -> empty list');
is_deeply(Everything::PageState->_build_news( T141::MockDB->new( 'not-an-array', {} ) ), [],
    '_build_news: non-array stash -> empty list');

#############################################################################
# Phase 2b builder: _build_stash (#4257). Shared passthrough for the cron-cached
# datastash chrome keys (daylogLinks/randomNodes/neglectedDrafts). Returns the stash
# value verbatim -- including undef on a cache miss (no normalization, parity with the
# original inline behaviour).
#############################################################################
my $stash_list = [ { node_id => 1, title => 'June 25, 2026' } ];
is_deeply(Everything::PageState->_build_stash( T141::MockDB->new( $stash_list, {} ), 'dayloglinks' ),
    $stash_list, '_build_stash returns the datastash value verbatim');
is(Everything::PageState->_build_stash( T141::MockDB->new( undef, {} ), 'randomnodes' ), undef,
    '_build_stash returns undef on a cache miss (no normalization)');

#############################################################################
# Phase 2b builder: _build_recentNodes (#4257). PER-USER, and the one builder in this
# batch with a SIDE EFFECT -- it rewrites $VARS->{nodetrail}. Mock DB drives getNodeById.
#############################################################################
{
    my $nodes = {
        1 => { node_id => 1, title => 'One' },
        2 => { node_id => 2, title => 'Two' },
        3 => { node_id => 3, title => 'Three' },
        # node 999 absent -> getNodeById undef -> skipped (removed node)
    };
    my $VARS = { nodetrail => '1,2,2,3,999,' };  # dupe (2 twice), missing (999)
    my $recent = Everything::PageState->_build_recentNodes(
        T141::MockDB->new( undef, $nodes ), { node_id => 100 }, $VARS );

    is_deeply($recent,
        [ { node_id => 1, title => 'One' }, { node_id => 2, title => 'Two' }, { node_id => 3, title => 'Three' } ],
        '_build_recentNodes resolves the trail, dropping dupes + removed nodes');
    is($VARS->{nodetrail}, '100,1,2,3,',
        '_build_recentNodes SIDE EFFECT: nodetrail rewritten (current node first, then de-duped visits)');

    # Cap: at most 9 entries (the original "last if $count > 8").
    my %many  = map { $_ => { node_id => $_, title => "N$_" } } ( 1 .. 12 );
    my $VARS2 = { nodetrail => join( ',', 1 .. 12 ) . ',' };
    my $capped = Everything::PageState->_build_recentNodes(
        T141::MockDB->new( undef, \%many ), { node_id => 500 }, $VARS2 );
    is(scalar(@$capped), 9, '_build_recentNodes caps the list at 9 (last if count > 8)');
}

#############################################################################
# Phase 2b builder: _build_personalLinks (#4257). PER-USER, pure ($VARS only). Parses
# the <br>-separated personal_nodelet string with item (20) + char (1000) caps.
#############################################################################
is_deeply(
    Everything::PageState->_build_personalLinks({ personal_nodelet => 'Alpha<br>Beta<br> <br>Gamma' }),
    [ 'Alpha', 'Beta', 'Gamma' ],
    '_build_personalLinks splits on <br> and skips blank/whitespace entries');
is_deeply(Everything::PageState->_build_personalLinks({}), [],
    '_build_personalLinks: no personal_nodelet -> empty list');
{
    # item cap: 25 entries -> only 20 kept
    my $many = join('<br>', map { "L$_" } ( 1 .. 25 ) );
    is(scalar(@{ Everything::PageState->_build_personalLinks({ personal_nodelet => $many }) }), 20,
        '_build_personalLinks caps at 20 items');
    # char cap: one 1500-char title exceeds 1000 -> dropped (nothing fits)
    is(scalar(@{ Everything::PageState->_build_personalLinks({ personal_nodelet => ('x' x 1500) }) }), 0,
        '_build_personalLinks caps at 1000 chars');
}

#############################################################################
# Phase 2b builder: _build_currentPoll (#4257). Returns undef when no active poll, so
# the caller leaves the key absent. (The populated path is covered by real-framework
# byte-identical checks -- it needs getNodeWhere/sqlSelect against poll rows.)
#############################################################################
{
    package T141::NoPollDB;
    sub new         { bless {}, $_[0] }
    sub getNodeWhere { return () }   # no current poll
}
is(Everything::PageState->_build_currentPoll( T141::NoPollDB->new, { node_id => 1 } ), undef,
    '_build_currentPoll returns undef when there is no active poll');

# Populated path (no active poll exists in dev, so drive it with a mock).
{
    package T141::PollDB;
    sub new          { bless {}, $_[0] }
    sub getNodeWhere {
        return ( {
            node_id => 700, title => 'Best Color?', poll_author => 42,
            question => 'Pick one', doctext => "Red\nGreen\nBlue",
            e2poll_results => '3,5,2', poll_status => 'current', totalvotes => 10
        } );
    }
    sub sqlSelect   { return (1) }                              # this user voted choice 1
    sub getNodeById { return { node_id => 42, title => 'PollMaker' } }  # author
}
{
    package T141::PollNoVoteDB;
    our @ISA = ('T141::PollDB');
    sub sqlSelect { return () }                                # user has not voted
}
my $poll = Everything::PageState->_build_currentPoll( T141::PollDB->new, { node_id => 99 } );
is($poll->{node_id},     700,          '_build_currentPoll: poll node_id');
is($poll->{author_name}, 'PollMaker',  '_build_currentPoll: author resolved via getNodeById');
is_deeply($poll->{options}, [ 'Red', 'Green', 'Blue' ], '_build_currentPoll: options split from doctext');
is_deeply($poll->{e2poll_results}, [ '3', '5', '2' ],   '_build_currentPoll: results split from e2poll_results');
is($poll->{userVote},    1,            '_build_currentPoll: userVote from sqlSelect');
is($poll->{totalvotes},  10,           '_build_currentPoll: totalvotes carried');
is(Everything::PageState->_build_currentPoll( T141::PollNoVoteDB->new, { node_id => 99 } )->{userVote},
    -1, '_build_currentPoll: userVote defaults to -1 when the user has not voted');

#############################################################################
# Phase 2b builder: _build_statistics (#4257). PER-USER -- the viewing user's own
# progression numbers. Mock $app (getLevel/getHRLF) + stub the site-wide setting
# lookups so the math (xpNeeded/wusNeeded/nodeFu/devotion) is pinned, no DB needed.
#############################################################################
{
    package T141::StatApp;
    sub new      { bless {}, $_[0] }
    sub getLevel { return 2 }
    sub getHRLF  { return 1.5 }
}

{
    no warnings 'redefine';
    # getNode passes the setting name through; getVars returns the setting hash.
    local *Everything::getNode = sub { return $_[0] };
    local *Everything::getVars = sub {
        my $name = shift;
        return { 3 => 100 }               if $name eq 'level experience';  # lvl 3 needs 100xp
        return { 3 => 25  }               if $name eq 'level writeups';     # lvl 3 needs 25wus
        return { mean => 5, stddev => 2 } if $name eq 'hrstats';
        return {};
    };

    my $USER = { experience => 60, GP => 10, karma => 3, sanctity => 1, stars => 0, merit => 4 };
    my $VARS = { numwriteups => 20, GPoptout => 0, easter_eggs => 2, tokens => 5 };
    my $st = Everything::PageState->_build_statistics( T141::StatApp->new, $USER, $VARS );

    # personal: lvl = getLevel(2)+1 = 3; LVLS{3}=100, xp=60 -> xpNeeded=40 (still climbing)
    is($st->{personal}{xp},        60,    '_build_statistics personal.xp');
    is($st->{personal}{level},     2,     'personal.level = getLevel');
    is($st->{personal}{xpNeeded},  40,    'personal.xpNeeded = LVLS{lvl} - xp');
    is($st->{personal}{wusNeeded}, undef, 'wusNeeded undef while xp still owed');
    is($st->{personal}{gp},        10,    'personal.gp');
    is($st->{personal}{gpOptout},  0,     'personal.gpOptout flag');

    # fun: nodeFu = 60/20 = 3.0
    is($st->{fun}{nodeFu},         '3.0', 'fun.nodeFu = xp/writeups');
    is($st->{fun}{goldenTrinkets}, 3,     'fun.goldenTrinkets = karma');
    is($st->{fun}{tokens},         5,     'fun.tokens from VARS');

    # advancement: devotion = int(20*4 + .5) = 80; merit '4.00'; lf '1.5000'
    is($st->{advancement}{devotion},    80,       'advancement.devotion = int(writeups*merit+.5)');
    is($st->{advancement}{merit},       '4.00',   'advancement.merit formatted');
    is($st->{advancement}{lf},          '1.5000', 'advancement.lf = getHRLF formatted');
    is($st->{advancement}{meritMean},   5,        'advancement.meritMean from hrstats');
    is($st->{advancement}{meritStddev}, 2,        'advancement.meritStddev from hrstats');
}

done_testing();

=head1 NAME

t/141_pagestate.t - SPIKE tests for Everything::PageState (chrome/content partition)

=cut
