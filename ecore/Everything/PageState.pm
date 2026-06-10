package Everything::PageState;

use Moose;
use namespace::autoclean;

# Everything::PageState -- SPIKE skeleton (docs/pagestate-design.md, branch pagestate-spike).
#
# Step 2 of the API-driven architecture: split the 44-key `e2` blob that
# Everything::Application::buildNodeInfoStructure assembles into a per-user CHROME
# partition (cacheable, page-independent: nodelets, identity, messages) and a
# per-node CONTENT partition (the node, its body, its categories).
#
# Phase 2a (this skeleton) is a non-invasive FACADE: it does NOT move any assembly
# logic. buildNodeInfoStructure still builds the whole blob; PageState->from_blob
# just PARTITIONS the result by the manifest below. That alone yields two API
# resources (/api/pagestate = chrome, /api/nodes/:id = content) and a caching seam,
# at zero behavioural risk. Phase 2b migrates each key's assembly into focused
# builders here until buildNodeInfoStructure is empty.
#
# The manifest is the contract. `unclassified_keys` is the migration safety net:
# a newly-added blob key that nobody classified shows up there (and fails the test),
# rather than silently landing in the wrong resource.

# Per-user / session chrome -- identical regardless of which node is viewed.
our @CHROME_KEYS = qw(
    guest user currentUserId
    display_prefs use_local_assets assets_location architecture
    noquickvote nonodeletcollapser hasMessagesNodelet
    recaptcha lastCommit reactPageMode pageheader quickRefSearchTerm
    epicenter messagesData notificationsData personalLinks favoriteWriteups
    chatterbox developerNodelet
    masterControl neglectedDrafts forReviewData
    newWriteups news randomNodes recentNodes statistics daylogLinks currentPoll
);

# Per-node content -- varies with the viewed node.
our @CONTENT_KEYS = qw(
    node_id title currentNodeId currentNodeTitle node nodetype
    contentData nodeCategories usergroupData noteletData
);

# Not yet settled (see docs/pagestate-design.md "open questions"). Held apart so the
# classification is HONEST -- these are knowingly-undecided, not silently defaulted.
our @AMBIGUOUS_KEYS = qw(
    bounties otherUsersData
);

sub chrome_keys    { return @CHROME_KEYS }
sub content_keys   { return @CONTENT_KEYS }
sub ambiguous_keys { return @AMBIGUOUS_KEYS }

# Partition an existing e2 blob into { chrome => {...}, content => {...} }.
# Ambiguous keys are (for now) carried in BOTH so nothing is lost while their home
# is decided -- deliberately conservative; tighten once classified.
sub from_blob {
    my ( $self, $e2 ) = @_;
    $e2 ||= {};

    my %chrome    = map { exists $e2->{$_} ? ( $_ => $e2->{$_} ) : () } @CHROME_KEYS;
    my %content   = map { exists $e2->{$_} ? ( $_ => $e2->{$_} ) : () } @CONTENT_KEYS;
    my %ambiguous = map { exists $e2->{$_} ? ( $_ => $e2->{$_} ) : () } @AMBIGUOUS_KEYS;

    # Until the ambiguous three are placed, expose them in both partitions so no
    # consumer breaks during the migration.
    %chrome  = ( %chrome,  %ambiguous );
    %content = ( %content, %ambiguous );

    return { chrome => \%chrome, content => \%content };
}

# The migration safety net: blob keys present in $e2 that no manifest classifies.
# Should always be empty; the test asserts it against a live blob so a new key in
# buildNodeInfoStructure forces a conscious classification decision.
sub unclassified_keys {
    my ( $self, $e2 ) = @_;
    $e2 ||= {};
    my %known = map { $_ => 1 } @CHROME_KEYS, @CONTENT_KEYS, @AMBIGUOUS_KEYS;
    return [ sort grep { !$known{$_} } keys %$e2 ];
}

__PACKAGE__->meta->make_immutable;

1;
