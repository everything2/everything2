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

#############################################################################
# Phase 2b builders (docs/pagestate-design.md). Each migrates ONE e2-blob key's
# assembly out of Everything::Application::buildNodeInfoStructure into a focused,
# independently-testable builder. The orchestrator still decides WHETHER a key is
# present (nodelet gating, guest checks); the builder only does the assembly.
# Same value, new home -- the move is verified byte-identical by t/141.
#############################################################################

# news: the ReadThis nodelet's front-page "News" list. Reads the cron-cached
# `frontpagenews` datastash (weblog entries from the "News" usergroup), resolves
# each entry to its node, and drops removed/draft entries (parity with the old
# show_content_frontpage). Returns an arrayref of { node_id, title }.
#
# Gated by the caller on the ReadThis nodelet (1157024) -- this builder is only
# invoked when that nodelet is installed, so $e2->{news} is absent otherwise.
sub _build_news {
    my ( $class, $db ) = @_;

    my $fpnews = $db->stashData("frontpagenews");
    $fpnews = [] unless defined($fpnews) && UNIVERSAL::isa( $fpnews, "ARRAY" );

    my $news = [];
    for my $entry (@$fpnews) {
        my $n = $db->getNodeById( $entry->{to_node} );
        next unless $n && $n->{type}{title} ne 'draft';
        push @$news, { node_id => $n->{node_id}, title => $n->{title} };
    }
    return $news;
}

# statistics: the Statistics nodelet -- the viewing user's own progression numbers
# (XP/writeups/level/GP, the "fun" trinkets, and the legacy merit/devotion block).
# PER-USER, not shareable: every value is $USER/$VARS data. The only site-wide inputs
# are the level-threshold settings ('level experience'/'level writeups') and the
# 'hrstats' mean/stddev -- and those just feed per-user math, so the output is per-user.
# The caller gates on the Statistics nodelet (838296) AND non-guest, so this is absent
# for guests entirely and for users without the nodelet. Takes the Application ($app)
# for getLevel/getHRLF; the site-setting lookups go through Everything:: directly.
sub _build_statistics {
    my ( $class, $app, $USER, $VARS ) = @_;

    my $stats = {};

    # Personal section
    my $numwriteups = $VARS->{numwriteups} || 0;
    my $xp          = $USER->{experience} || 0;
    my $lvl         = $app->getLevel($USER) + 1;
    my $LVLS = Everything::getVars( Everything::getNode( 'level experience', 'setting' ) );
    my $WRPS = Everything::getVars( Everything::getNode( 'level writeups',  'setting' ) );

    my $expleft = 0;
    $expleft = $$LVLS{$lvl} - $xp if exists $$LVLS{$lvl};
    my $wrpleft = 0;
    $wrpleft = $$WRPS{$lvl} - $numwriteups if exists $$WRPS{$lvl};

    $stats->{personal} = {
        xp        => $xp,
        writeups  => $numwriteups,
        level     => $app->getLevel($USER),
        xpNeeded  => $expleft > 0 ? $expleft : undef,
        wusNeeded => ( $expleft <= 0 && $wrpleft ) ? $wrpleft : undef,
        gp        => $USER->{GP} || 0,
        gpOptout  => $VARS->{GPoptout} ? 1 : 0
    };

    # Fun Stats section
    my $nodeFu = ( $numwriteups > 0 ) ? sprintf( '%.1f', $xp / $numwriteups ) : '0.0';
    $stats->{fun} = {
        nodeFu         => $nodeFu,
        goldenTrinkets => $USER->{karma}    || 0,
        silverTrinkets => $USER->{sanctity} || 0,
        stars          => $USER->{stars}    || 0,
        easterEggs     => $VARS->{easter_eggs} || 0,
        tokens         => $VARS->{tokens}      || 0
    };

    # Old Merit System (advancement) section
    my $hv = Everything::getVars( Everything::getNode( "hrstats", "setting" ) );
    my $merit    = ( $USER->{merit} ) ? $USER->{merit} : 0;
    my $lf       = $app->getHRLF($USER) || 0;
    my $devotion = int( ( $numwriteups * $merit ) + .5 );

    $stats->{advancement} = {
        merit       => sprintf( '%.2f', $merit ),
        lf          => sprintf( '%.4f', $lf ),
        devotion    => $devotion,
        meritMean   => $$hv{mean}   || 0,
        meritStddev => $$hv{stddev} || 0
    };

    return $stats;
}

# _build_stash: shared builder for the cron-cached datastash passthroughs -- the chrome
# keys that are nothing but `stashData($key)` behind a nodelet gate. SITE-WIDE, shareable
# chrome (not per-user). Returns the stash value verbatim (an arrayref, or undef on a
# cache miss), preserving the original inline behaviour exactly. Used for:
#   daylogLinks -> "dayloglinks"   (New Logs nodelet 1923735)
#   randomNodes -> "randomnodes"   (Random Nodes nodelet 457857)
#   neglectedDrafts -> "neglecteddrafts" (Neglected Drafts nodelet 2051342)
sub _build_stash {
    my ( $class, $db, $key ) = @_;
    return $db->stashData($key);
}

# recentNodes: the Recent Nodes nodelet -- the user's breadcrumb trail. PER-USER, and the
# one builder in this batch with a SIDE EFFECT: it rewrites $VARS->{nodetrail} in place
# (current node to the front, then the de-duped recent visits, capped). Mutates the passed
# $VARS hashref exactly as the inline code did -- this is the "nodetrail bump" page side
# effect #4257 flags as the route-through-render cost to retire later. Returns the recent
# list as an arrayref of { node_id, title }.
sub _build_recentNodes {
    my ( $class, $db, $NODE, $VARS ) = @_;

    $VARS->{nodetrail} ||= "";
    my @trail_ids = split( ",", $VARS->{nodetrail} );

    # Current node goes to the front of the trail for the next page load.
    $VARS->{nodetrail} = $NODE->{node_id} . ',';

    my @recent_nodes = ();
    my $count = 0;

    foreach my $nid (@trail_ids) {
        next unless $nid;
        # Skip if already in our updated trail (avoids dupes)
        next if $VARS->{nodetrail} =~ /\b$nid\b/;

        my $node = $db->getNodeById($nid);
        if ( $node && $node->{node_id} ) {
            push @recent_nodes, {
                node_id => $node->{node_id},
                title   => $node->{title}
            };

            $VARS->{nodetrail} .= $nid . ',';
            $count++;
            last if $count > 8;
        }
    }

    return \@recent_nodes;
}

# favoriteWriteups: the Favorite Noders nodelet -- the latest writeups by the authors this
# user has favorited. PER-USER (keyed on $USER->{user_id}). Resolves each writeup to its
# author/parent/writeuptype, capped at 5 (#3765). Takes the db handle ($app->{db}) for the
# raw query + node hydration; linktype/type lookups go through Everything:: directly.
sub _build_favoriteWriteups {
    my ( $class, $db, $USER ) = @_;

    # Hard cap at 5 to match the React nodelet's display limit (#3765).
    my $wuLimit = 5;

    # No 'favorite' linktype (degenerate) -> undef so the caller leaves the key absent,
    # matching the original (which only set it inside the `if($linktypeFavorite)` block).
    # An EXISTING linktype with no favorites still returns [] (key present), as before.
    my $linktypeFavorite = Everything::getNode( 'favorite', 'linktype' );
    return unless $linktypeFavorite;   # scalar caller -> undef -> key left absent

    my $linktypeIdFavorite = $linktypeFavorite->{node_id};
    my $typeIdWriteup      = Everything::getType('writeup')->{node_id};

    my $sql = "SELECT node.node_id, node.author_user
        FROM links
        JOIN node ON links.to_node = node.author_user
        WHERE links.linktype = $linktypeIdFavorite
          AND links.from_node = $USER->{user_id}
          AND node.type_nodetype = $typeIdWriteup
        ORDER BY node.node_id DESC
        LIMIT $wuLimit";

    my $writeuplist = $db->{dbh}->selectall_arrayref($sql);
    my @fav_writeups = ();

    foreach my $row (@$writeuplist) {
        my $node = $db->getNodeById( $row->[0] );
        next unless $node && $node->{node_id};

        my $author = $db->getNodeById( $node->{author_user} );
        my $parent = $db->getNodeById( $node->{parent_e2node} );

        # Get writeup type from the writeuptype table
        my $writeuptype_name = '';
        if ( $node->{wrtype_writeuptype} ) {
            my $wutype = $db->getNodeById( $node->{wrtype_writeuptype} );
            $writeuptype_name = $wutype->{title} if $wutype;
        }

        push @fav_writeups, {
            node_id => $node->{node_id},
            title   => $node->{title},
            parent  => $parent ? { node_id => $parent->{node_id}, title => $parent->{title} } : undef,
            author  => { node_id => int( $node->{author_user} ), title => ( $author ? $author->{title} : 'Unknown' ) },
            writeuptype => $writeuptype_name
        };
    }

    return \@fav_writeups;
}

# personalLinks: the Personal Links nodelet -- the user's own list of node titles parsed
# from $VARS->{personal_nodelet}, capped at 20 items / 1000 chars. PER-USER, pure ($VARS
# only). NOTE: the caller still sets currentNodeTitle/currentNodeId alongside this (those
# are separate keys with their own logic); this builder returns just the links arrayref.
sub _build_personalLinks {
    my ( $class, $VARS ) = @_;

    my $item_limit = 20;
    my $char_limit = 1000;

    my $personal_nodelet_str = $VARS->{personal_nodelet} || '';
    my @nodes = split( '<br>', $personal_nodelet_str );
    my @links = ();
    my $total_chars = 0;

    foreach my $title (@nodes) {
        next unless $title && $title !~ /^\s*$/;
        my $title_length = length($title);

        # Stop if we would exceed either limit
        last if scalar(@links) >= $item_limit;
        last if ( $total_chars + $title_length ) > $char_limit;

        push @links, $title;
        $total_chars += $title_length;
    }

    return \@links;
}

# currentPoll: the Current User Poll nodelet. The poll itself is site-wide, but userVote is
# PER-USER (this user's choice on the active poll). Returns the poll hashref, or undef when
# there is no active poll -- the caller then leaves the key ABSENT, matching the original.
sub _build_currentPoll {
    my ( $class, $db, $USER ) = @_;

    my @POLL = $db->getNodeWhere( { poll_status => 'current' }, 'e2poll' );
    return unless @POLL;   # scalar caller -> undef -> key left absent

    my $POLL = $POLL[0];
    my $vote = (
        $db->sqlSelect(
            'choice', 'pollvote',
            "voter_user=" . $USER->{node_id} . " AND pollvote_id=" . $POLL->{node_id}
        )
    )[0];
    $vote = -1 unless defined $vote;

    # Parse options + results from the poll node
    my @options = split /\s*\n\s*/, $POLL->{doctext};
    my @results = split ',', $POLL->{e2poll_results} || '';

    my $author = $db->getNodeById( $POLL->{poll_author} );
    my $author_name = $author ? $author->{title} : 'Unknown';

    return {
        node_id        => $POLL->{node_id},
        title          => $POLL->{title},
        poll_author    => $POLL->{poll_author},
        author_name    => $author_name,
        question       => $POLL->{question},
        options        => \@options,
        poll_status    => $POLL->{poll_status},
        e2poll_results => \@results,
        totalvotes     => $POLL->{totalvotes} || 0,
        userVote       => $vote
    };
}

# Keys whose values are conceptually integers but sometimes serialize as strings
# (the #4152 class -- e.g. newWriteups[].node_id comes back as "1234567"). React uses
# these as list keys (key={node_id}) and in truthy guards ({x && <JSX/>}), where a
# string "0" is truthy and a string id breaks key identity. normalize_types coerces
# them to real integers recursively so the /api/pagestate contract is correctly typed.
# Conservative set -- IDs/counts/flags only; the deeper source-level coercion (in the
# stash generators) is the 2b fix. Extend as that catches up.
my %INT_KEYS = map { $_ => 1 } qw(
    node_id user_id parent_e2node author_user type_nodetype lastnode_id
    to_node from_node reputation numwriteups use_local_assets
);

sub normalize_types {
    my ( $self, $data ) = @_;
    _coerce_ints($data);
    return $data;
}

# Recursively coerce integer-valued strings under INT_KEYS to real integers (mutates
# in place). int() forces an IV so JSON encodes a number, not a quoted string.
sub _coerce_ints {
    my ($v) = @_;
    if ( ref $v eq 'HASH' ) {
        for my $k ( keys %$v ) {
            if ( $INT_KEYS{$k} && defined $v->{$k} && !ref $v->{$k} && $v->{$k} =~ /\A-?\d+\z/ ) {
                $v->{$k} = int( $v->{$k} );
            }
            else {
                _coerce_ints( $v->{$k} );
            }
        }
    }
    elsif ( ref $v eq 'ARRAY' ) {
        _coerce_ints($_) for @$v;
    }
    return;
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
