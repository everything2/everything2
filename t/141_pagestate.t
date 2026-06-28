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

is(scalar(@chrome),    34, 'chrome manifest has 34 keys');
is(scalar(@content),   10, 'content manifest has 10 keys');
is(scalar(@ambiguous),  2, 'ambiguous set has 2 keys (bounties, otherUsersData)');

my %seen;
$seen{$_}++ for (@chrome, @content, @ambiguous);
my @dupes = grep { $seen{$_} > 1 } keys %seen;
is_deeply(\@dupes, [], 'no key is classified into more than one bucket');
is(scalar(keys %seen), 46, 'manifest covers exactly 46 distinct blob keys');

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
    usergroupData user coolnodes staffpicks
);
is(scalar(@blob_keys), 46, 'reference blob inventory is 46 keys');

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
    # _build_news/_build_stash read via cached_stash now (#3981); the mock returns the
    # same fixture, since the TTL cache is irrelevant to the builders' transform logic.
    sub cached_stash { return $_[0]->{stash} }
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

#############################################################################
# Phase 2b builder: _build_epicenter (#4367). PER-USER, with SIDE EFFECTS on
# $VARS->{oldexp}/{oldGP}. Mock $app (conf->user_settings + DateTimeLocal).
#############################################################################
{
    package T141::EpiConf; sub new { bless {}, $_[0] } sub user_settings { return 12345 }
    package T141::EpiApp;
    sub new { bless { conf => T141::EpiConf->new }, $_[0] }
    sub DateTimeLocal { my ( $self, $now, $flag, $vars ) = @_; return $flag ? 'server-time' : 'local-time'; }
}
{
    # XP + GP gained; has nodelet; level 3; localTimeUse on
    my $USER = { experience => 150, GP => 30 };
    my $VARS = { oldexp => 100, oldGP => 20, localTimeUse => 1 };
    my $epi = Everything::PageState->_build_epicenter( T141::EpiApp->new, $USER, $VARS, 1, 3 );
    is(${ $epi->{showEpicenterZen} }, 0,  '_build_epicenter showEpicenterZen=0 when user has the nodelet');
    is(${ $epi->{localTimeUse} },     1,  'epicenter localTimeUse flag');
    is($epi->{userSettingsId},        12345, 'epicenter userSettingsId from conf');
    is($epi->{helpPage}, 'Everything2 Help', 'epicenter helpPage for level >= 2');
    is($epi->{experienceGain}, 50, 'epicenter experienceGain = exp - oldexp (positive)');
    is($epi->{gpGain},         10, 'epicenter gpGain = GP - oldGP (positive)');
    is($epi->{serverTime}, 'server-time', 'epicenter serverTime via DateTimeLocal');
    is($epi->{localTime},  'local-time',  'epicenter localTime present when localTimeUse');
    is($VARS->{oldexp}, 150, 'SIDE EFFECT: oldexp advanced to current experience');
    is($VARS->{oldGP},  30,  'SIDE EFFECT: oldGP advanced to current GP');

    # No XP delta; GPoptout; no nodelet; level 1; no localTimeUse; non-numeric oldexp resets
    my $USER2 = { experience => 80, GP => 99 };
    my $VARS2 = { oldexp => 'garbage', GPoptout => 1 };
    my $epi2  = Everything::PageState->_build_epicenter( T141::EpiApp->new, $USER2, $VARS2, 0, 1 );
    is(${ $epi2->{showEpicenterZen} }, 1, 'epicenter showEpicenterZen=1 when user lacks the nodelet');
    is($epi2->{helpPage}, 'E2 Quick Start', 'epicenter helpPage for level < 2');
    ok(!exists $epi2->{experienceGain}, 'epicenter: non-numeric oldexp resets -> no phantom gain');
    ok(!exists $epi2->{gpGain},   'epicenter: no gpGain when GPoptout');
    ok(!exists $epi2->{localTime}, 'epicenter: no localTime when localTimeUse off');
    is($VARS2->{oldexp}, 80, 'epicenter: oldexp reset to current experience');
    ok(!exists $VARS2->{oldGP}, 'epicenter: oldGP untouched when GPoptout');
}

#############################################################################
# Phase 2b builder: _build_masterControl (#4367). Editor/admin tooling. Mock $app
# (role checks + getNodeNotes/getParameter/db) + $query; stub CONF + canDeleteNode.
#############################################################################
{
    package T141::MCDb;  sub new { bless {}, $_[0] } sub sqlSelectHashref { return undef }
    package T141::MCApp;
    sub new { bless { db => T141::MCDb->new, _ed => $_[1], _ad => $_[2] }, $_[0] }
    sub isEditor     { return $_[0]->{_ed} }
    sub isAdmin      { return $_[0]->{_ad} }
    sub getNodeNotes { return [ { t => 1 }, { t => 2 } ] }
    sub getParameter { return 0 }
    package T141::MCQuery; sub new { bless {}, $_[0] } sub script_name { return '/node' } sub param { return undef }
    package T141::MCConf;  sub server_hostname { return 'test.example.com' }
}
{
    no warnings 'redefine', 'once';
    local *Everything::canDeleteNode = sub { return 1 };
    local $Everything::CONF = bless {}, 'T141::MCConf';

    my $NODE  = { node_id => 555, title => 'SomeNode', type => { title => 'writeup' } };
    my $query = T141::MCQuery->new;
    my $USER  = { node_id => 42 };

    # Editor (not admin)
    my $mc = Everything::PageState->_build_masterControl( T141::MCApp->new( 1, 0 ), $NODE, {}, $query, $USER );
    is($mc->{adminSearchForm}{nodeId},     555,                'masterControl editor: adminSearchForm nodeId');
    is($mc->{adminSearchForm}{serverName}, 'test.example.com', 'masterControl editor: serverName from CONF');
    is($mc->{adminSearchForm}{scriptName}, '/node',            'masterControl editor: scriptName from query');
    ok(exists $mc->{ceSection},           'masterControl editor: ceSection present');
    is($mc->{nodeNotesData}{count}, 2,    'masterControl editor: nodeNotesData count');
    ok(!exists $mc->{nodeToolsetData},    'masterControl editor(non-admin): no nodeToolsetData');
    ok(!exists $mc->{adminSection},       'masterControl editor(non-admin): no adminSection');

    # Admin (also editor)
    my $mca = Everything::PageState->_build_masterControl( T141::MCApp->new( 1, 1 ), $NODE, {}, $query, $USER );
    ok(exists $mca->{nodeToolsetData},        'masterControl admin: nodeToolsetData present');
    is(${ $mca->{nodeToolsetData}{isWriteup} }, 1, 'masterControl admin: isWriteup for writeup node');
    is(${ $mca->{nodeToolsetData}{canDelete} }, 1, 'masterControl admin: canDelete (writeup + canDeleteNode)');
    ok(exists $mca->{adminSection},           'masterControl admin: adminSection present');

    # Non-editor -> empty (degenerate; the gate normally prevents the call)
    is_deeply(Everything::PageState->_build_masterControl( T141::MCApp->new( 0, 0 ), $NODE, {}, $query, $USER ),
        {}, 'masterControl non-editor: empty hash');
}

#############################################################################
# Phase 2b builder: _build_user (#4367). The global identity object: role flags
# always; gp/xp/level/votes/cools only for logged-in users.
#############################################################################
{
    package T141::UserApp;
    sub new { bless { ad=>$_[1], ed=>$_[2], ch=>$_[3], dv=>$_[4], gu=>$_[5], lv=>$_[6], un=>$_[7] }, $_[0] }
    sub isAdmin{$_[0]{ad}} sub isEditor{$_[0]{ed}} sub isChanop{$_[0]{ch}}
    sub isDeveloper{$_[0]{dv}} sub isGuest{$_[0]{gu}}
    sub getLevel{$_[0]{lv}} sub get_unread_message_count{$_[0]{un}}
}
{
    my $app  = T141::UserApp->new( 0, 1, 0, 0, 0, 5, 3 );   # editor, non-dev, level 5, 3 unread
    my $USER = { node_id=>42, title=>'alice', in_room=>0, GP=>100, experience=>2000, votesleft=>20 };
    my $u = Everything::PageState->_build_user( $app, $USER, { GPoptout=>0, cools=>4, coolsafety=>1, votesafety=>0 } );
    is($u->{node_id}, 42, '_build_user node_id');
    is(${ $u->{editor} },    1, 'user editor flag');
    is(${ $u->{admin} },     0, 'user admin flag');
    is(${ $u->{developer} }, 0, 'user developer flag = false for a non-developer (#4390: was always \1)');
    # #4390: the true branch -- an actual developer (isDeveloper=1) now gets \1, not the old always-\1
    my $du = Everything::PageState->_build_user( T141::UserApp->new(0,0,0,1,0,1,0), { node_id=>43, title=>'dev' }, {} );
    is(${ $du->{developer} }, 1, 'user developer flag = true for an actual developer (#4390)');
    is($u->{gp},        100, 'user gp (logged-in)');
    is($u->{level},     5,   'user level = getLevel');
    is($u->{coolsleft}, 4,   'user coolsleft = int(VARS cools)');
    is($u->{unreadMessages}, 3, 'user unreadMessages');

    my $gu = Everything::PageState->_build_user( T141::UserApp->new(0,0,0,0,1,0,0),
        { node_id=>1, title=>'Guest User', in_room=>0 }, {} );
    is(${ $gu->{guest} }, 1, '_build_user guest flag');
    ok(!exists $gu->{gp},    'guest: no gp (logged-in-only block skipped)');
    ok(!exists $gu->{level}, 'guest: no level');
}

#############################################################################
# Phase 2b builder: _build_quickRefSearchTerm (#4367). node title / parent e2node
# title for writeups / searched term on Findings.
#############################################################################
{
    package T141::QRDb;  sub new{bless{},shift} sub getNodeById{ return { title => 'ParentNode' } }
    package T141::QRApp; sub new{ bless { db => T141::QRDb->new }, $_[0] }
    package T141::QRQ;   sub new{bless{},shift} sub param{ return 'searchedterm' }
}
{
    my $app = T141::QRApp->new;
    is(Everything::PageState->_build_quickRefSearchTerm( $app, { title=>'Tomato', type=>{title=>'e2node'} }, undef ),
        'Tomato', '_build_quickRefSearchTerm: e2node uses node title');
    is(Everything::PageState->_build_quickRefSearchTerm( $app, { title=>'T (thing)', type=>{title=>'writeup'}, parent_e2node=>99 }, undef ),
        'ParentNode', '_build_quickRefSearchTerm: writeup uses parent e2node title');
    is(Everything::PageState->_build_quickRefSearchTerm( $app, { title=>'Findings:', type=>{title=>'superdoc'} }, T141::QRQ->new ),
        'searchedterm', '_build_quickRefSearchTerm: Findings uses query node param');
}

#############################################################################
# Phase 2b builder: _build_bounties (#4367). Top open bounties, descending, capped at 5.
# (Provide exactly 5 ranks so the pre-existing descending loop terminates.)
#############################################################################
{
    package T141::BountyDb; sub new{bless{},shift} sub getNode{ return { node_id => 1000 } }
}
{
    no warnings 'redefine';
    local *Everything::getNode = sub { return $_[0] };
    local *Everything::getVars = sub {
        my $name = shift;
        return { map { ( $_ => "user$_" ) } 1 .. 5 }            if $name eq 'bounty order';
        return { map { ( "user$_" => "outlaw$_" ) } 1 .. 5 }   if $name eq 'outlaws';
        return { map { ( "user$_" => "reward$_" ) } 1 .. 5 }   if $name eq 'bounties';
        return { 1 => 5 }                                       if $name eq 'bounty number';
        return {};
    };
    my $b = Everything::PageState->_build_bounties( bless { db => T141::BountyDb->new }, 'T141::BApp' );
    is(scalar(@$b), 5, '_build_bounties returns up to MAX=5');
    is($b->[0]{requester_name},  'user5',   '_build_bounties: highest rank first (descending)');
    is($b->[0]{reward},          'reward5', '_build_bounties: reward carried');
    is($b->[0]{outlaw_nodeshell},'outlaw5', '_build_bounties: outlaw carried');
}
{
    # Regression (#4367): fewer-than-MAX bounties must TERMINATE. Before the $i>0 bound this
    # spun forever (it would hang the test suite), since exists $REQ{negative} is never true.
    no warnings 'redefine';
    local *Everything::getNode = sub { return $_[0] };
    local *Everything::getVars = sub {
        my $name = shift;
        return { map { ( $_ => "user$_" ) } 1 .. 3 } if $name eq 'bounty order';
        return { 1 => 3 }                            if $name eq 'bounty number';
        return {};
    };
    my $b3 = Everything::PageState->_build_bounties( bless { db => T141::BountyDb->new }, 'T141::BApp' );
    is(scalar(@$b3), 3, '_build_bounties terminates + returns all when fewer than MAX exist (#4367 fix)');
    is($b3->[0]{requester_name}, 'user3', '_build_bounties: highest available rank first');

    # Absent 'bounty number' setting -> bountyTot defaults to 0 -> empty list, no spin/warning
    local *Everything::getVars = sub { return {} };
    is_deeply(Everything::PageState->_build_bounties( bless { db => T141::BountyDb->new }, 'T141::BApp' ), [],
        '_build_bounties: no/undef bounty count -> empty list (terminates)');
}

#############################################################################
# Phase 2b builder: _build_recaptcha (#4367). Enabled in prod or on the dev host.
#############################################################################
{
    package T141::RCConf;
    sub new{ bless { prod=>$_[1] }, $_[0] } sub is_production{$_[0]{prod}} sub recaptcha_v3_public_key{'PUBKEY'}
}
{
    local $ENV{HTTP_HOST} = '';
    my $rc = Everything::PageState->_build_recaptcha( bless { conf => T141::RCConf->new(1) }, 'T141::RCApp' );
    is(${ $rc->{enabled} }, 1, '_build_recaptcha enabled in production');
    is($rc->{publicKey}, 'PUBKEY', '_build_recaptcha publicKey from conf');

    local $ENV{HTTP_HOST} = 'localhost';
    is(${ Everything::PageState->_build_recaptcha( bless { conf => T141::RCConf->new(0) }, 'T141::RCApp' )->{enabled} },
        0, '_build_recaptcha disabled in non-prod / non-dev host');

    local $ENV{HTTP_HOST} = 'development.everything2.com';
    is(${ Everything::PageState->_build_recaptcha( bless { conf => T141::RCConf->new(0) }, 'T141::RCApp' )->{enabled} },
        1, '_build_recaptcha enabled on development.everything2.com host');
}

done_testing();

=head1 NAME

t/141_pagestate.t - SPIKE tests for Everything::PageState (chrome/content partition)

=cut
