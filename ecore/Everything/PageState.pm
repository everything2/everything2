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
    coolnodes staffpicks
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

# epicenter: the Epicenter nodelet -- per-user identity/progression header. PER-USER, and
# carries SIDE EFFECTS: it advances $VARS->{oldexp} / $VARS->{oldGP} (the XP/GP "since last
# page" deltas), mutating the passed $VARS in place exactly as the inline code did. Cross-deps
# passed in by the caller: $has_epicenter_nodelet (whether the user actually has nodelet 262,
# computed in the orchestrator from the effective nodelet list) and $user_level (== the
# already-built $e2->{user}{level}, used to pick the help page). Takes $app for conf +
# DateTimeLocal. Gated by the caller on non-guest.
sub _build_epicenter {
    my ( $class, $app, $USER, $VARS, $has_epicenter_nodelet, $user_level ) = @_;

    my $epicenter = {};

    # Show EpicenterZen header bar if the user doesn't have the Epicenter nodelet
    $epicenter->{showEpicenterZen} = $has_epicenter_nodelet ? \0 : \1;

    # Core settings
    $epicenter->{localTimeUse}   = $VARS->{localTimeUse} ? \1 : \0;
    $epicenter->{userSettingsId} = $app->{conf}->user_settings;
    $epicenter->{helpPage}       = ( $user_level < 2 ) ? 'E2 Quick Start' : 'Everything2 Help';

    # Experience change (SIDE EFFECT: advances $VARS->{oldexp}). Initialize/reset oldexp on
    # first visit or if non-numeric (legacy garbage), then report a positive delta.
    $VARS->{oldexp} = $USER->{experience}
        unless ( defined $VARS->{oldexp} && $VARS->{oldexp} =~ /^\d+$/ );
    my $expChange = $USER->{experience} - $VARS->{oldexp};
    $epicenter->{experienceGain} = $expChange if $expChange > 0;
    $VARS->{oldexp} = $USER->{experience};   # keep in sync even on reset/decrease

    # GP change (SIDE EFFECT: advances $VARS->{oldGP}), unless the user opted out
    unless ( $VARS->{GPoptout} ) {
        $VARS->{oldGP} = $USER->{GP}
            unless ( defined $VARS->{oldGP} && $VARS->{oldGP} =~ /^\d+$/ );
        my $gpChange = $USER->{GP} - $VARS->{oldGP};
        $epicenter->{gpGain} = $gpChange if $gpChange > 0;
        $VARS->{oldGP} = $USER->{GP};
    }

    # Server time (formatted strings for the React component)
    my $NOW = time;
    $epicenter->{serverTime} = $app->DateTimeLocal( $NOW, 1, $VARS );
    $epicenter->{localTime}  = $app->DateTimeLocal( $NOW, 0, $VARS ) if $VARS->{localTimeUse};

    return $epicenter;
}

# masterControl: the Master Control nodelet -- editor/admin tooling. Built only for editors
# (and the admin sub-section only for admins). Per-user. The caller gates on isEditor||isAdmin
# and separately sets $e2->{currentUserId} (a distinct key, kept in the orchestrator). Takes
# $app for the role checks + getNodeNotes/getParameter/db, plus $NODE/$VARS/$query.
sub _build_masterControl {
    my ( $class, $app, $NODE, $VARS, $query, $USER ) = @_;

    my $mc = {};

    if ( $app->isEditor($USER) ) {
        # Admin search form data
        $mc->{adminSearchForm} = {
            nodeId     => $$NODE{node_id} || '',
            nodeType   => $$NODE{type}{title},
            nodeTitle  => $$NODE{title},
            serverName => $Everything::CONF->server_hostname,
            scriptName => $query->script_name
        };

        # CE Section data
        my ( undef, undef, undef, $mday, $mon, $year ) = localtime(time);
        $year += 1900;
        $mc->{ceSection} = {
            currentMonth => $mon,
            currentYear  => $year,
            isUserNode   => ( $$NODE{type}{title} eq 'user' ),
            nodeId       => $$NODE{node_id},
            nodeTitle    => $$NODE{title},
            showSection  => ( ( $VARS->{epi_hideces} // 0 ) != 1 )
        };

        # NodeNote data, unless the hidenodenotes preference is set
        unless ( $VARS->{hidenodenotes} ) {
            my $notes = $app->getNodeNotes($NODE);
            $mc->{nodeNotesData} = {
                node_id    => $NODE->{node_id},
                node_title => $NODE->{title},
                node_type  => $NODE->{type}{title},
                notes      => $notes,
                count      => scalar(@$notes),
            };
        }

        if ( $app->isAdmin($USER) ) {
            # Node Toolset data (React nuke-confirmation modal)
            my $currentDisplay = $query->param("displaytype") || "display";
            my $nodeType       = $NODE->{type}{title};
            my $canDelete = Everything::canDeleteNode( $USER, $NODE )
                && $nodeType ne 'draft' && $nodeType ne 'user';
            my $hasHelp = $app->{db}->sqlSelectHashref( "*", "nodehelp", "nodehelp_id=$$NODE{node_id}" ) ? \1 : \0;
            my $preventNuke = $app->getParameter( $NODE->{node_id}, "prevent_nuke" ) ? \1 : \0;

            $mc->{nodeToolsetData} = {
                nodeId         => $NODE->{node_id},
                nodeTitle      => $NODE->{title},
                nodeType       => $nodeType,
                canDelete      => $canDelete ? \1 : \0,
                currentDisplay => $currentDisplay,
                hasHelp        => $hasHelp,
                isWriteup      => ( $nodeType eq 'writeup' ) ? \1 : \0,
                preventNuke    => $preventNuke,
            };

            # Admin Section data
            $mc->{adminSection} = {
                isBorged    => $$VARS{borged} ? \1 : \0,
                showSection => ( ( $VARS->{epi_hideadmins} // 0 ) != 1 )
            };
        }
    }

    return $mc;
}

# user: the global user-identity object -- node_id/title, role flags, and (for logged-in
# users) gp/xp/level/votes/cools/safety prefs/unread-message count. CHROME, always present.
# Takes $app for the role checks + getLevel + get_unread_message_count. The `developer`
# flag's ?(\1):(\1) is a pre-existing quirk (both branches true) -- preserved byte-identical.
sub _build_user {
    my ( $class, $app, $USER, $VARS ) = @_;

    my $user = {};
    $user->{node_id}   = $USER->{node_id};
    $user->{title}     = $USER->{title};
    $user->{admin}     = $app->isAdmin($USER)     ? \1 : \0;
    $user->{editor}    = $app->isEditor($USER)    ? \1 : \0;
    $user->{chanop}    = $app->isChanop($USER)    ? \1 : \0;
    $user->{developer} = $app->isDeveloper($USER) ? \1 : \1;   # pre-existing quirk: both \1
    $user->{guest}     = $app->isGuest($USER)     ? \1 : \0;
    $user->{in_room}   = $USER->{in_room};

    # Core user properties (logged-in only)
    unless ( $app->isGuest($USER) ) {
        $user->{gp}            = $USER->{GP} || 0;
        $user->{gpOptOut}      = $VARS->{GPoptout} ? \1 : \0;
        $user->{experience}    = $USER->{experience} || 0;
        $user->{level}         = $app->getLevel($USER);
        $user->{votesleft}     = $USER->{votesleft} || 0;
        $user->{coolsleft}     = int( $VARS->{cools} || 0 );
        # Confirm-before-acting prefs (#4052 cool / #3613 vote) read off the global user object
        $user->{coolsafety}    = int( $VARS->{coolsafety} || 0 );
        $user->{votesafety}    = int( $VARS->{votesafety} || 0 );
        $user->{unreadMessages} = $app->get_unread_message_count($USER);
    }

    return $user;
}

# quickRefSearchTerm: the Quick Reference nodelet's lookup term -- the node title, or the
# parent e2node title for a writeup, or (on Findings:/Nothing Found) the searched-for term
# from the query. Node-derived but classified chrome. Caller gates on nodelet 2146276.
sub _build_quickRefSearchTerm {
    my ( $class, $app, $NODE, $query ) = @_;

    my $lookfor = $NODE->{title};
    if ( $$NODE{type}{title} eq 'writeup' ) {
        # Use the e2node title rather than the writeup title w/ type annotation
        $lookfor = $app->{db}->getNodeById( $NODE->{parent_e2node} )->{title};
    }
    else {
        if ( ( $NODE->{title} eq 'Findings:' ) || ( $NODE->{title} eq 'Nothing Found' ) ) {
            # Special-case findings: look up what was searched
            $lookfor = $query->param('node');
        }
    }
    return $lookfor;
}

# bounties: the Most Wanted nodelet -- the top open bounties from the bounty-order/outlaws/
# bounties/bounty-number settings, highest rank first, capped at $MAX. Caller gates on 1986723.
# The descending loop is bounded by `$i > 0` (#4367): the original lacked that bound and would
# spin forever whenever fewer than $MAX bounties existed (or $bountyTot was undef). $bountyTot
# defaults to 0 so an absent 'bounty number' setting yields an empty list rather than a warning.
sub _build_bounties {
    my ( $class, $app ) = @_;

    my $REQ  = Everything::getVars( Everything::getNode( 'bounty order',  'setting' ) );
    my $OUT  = Everything::getVars( Everything::getNode( 'outlaws',       'setting' ) );
    my $REW  = Everything::getVars( Everything::getNode( 'bounties',      'setting' ) );
    my $HIGH = Everything::getVars( Everything::getNode( 'bounty number', 'setting' ) );
    my $MAX  = 5;

    my $bountyTot   = $$HIGH{1} // 0;
    my $numberShown = 0;
    my @bounties    = ();

    for ( my $i = $bountyTot; $numberShown < $MAX && $i > 0; $i-- ) {
        if ( exists $$REQ{$i} ) {
            $numberShown++;
            my $requesterName = $$REQ{$i};
            my $requesterNode = $app->{db}->getNode( $requesterName, 'user' );
            my $outlawStr     = $$OUT{$requesterName} || '';
            my $reward        = $$REW{$requesterName} || '';

            push @bounties, {
                requester_id     => $requesterNode->{node_id},
                requester_name   => $requesterName,
                outlaw_nodeshell => $outlawStr,
                reward           => $reward
            };
        }
    }

    return \@bounties;
}

# recaptcha: the global reCAPTCHA config for the guest signup modal. Caller gates on guest.
# Enabled in production (or on development.everything2.com via the request host).
sub _build_recaptcha {
    my ( $class, $app ) = @_;

    my $conf          = $app->{conf};
    my $use_recaptcha = 0;
    if ( $conf->is_production || ( $ENV{HTTP_HOST} // '' ) =~ /^development\.everything2\.com/ ) {
        $use_recaptcha = 1;
    }
    return {
        enabled   => $use_recaptcha ? \1 : \0,
        publicKey => $conf->recaptcha_v3_public_key // ''
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
