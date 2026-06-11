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

done_testing();

=head1 NAME

t/141_pagestate.t - SPIKE tests for Everything::PageState (chrome/content partition)

=cut
