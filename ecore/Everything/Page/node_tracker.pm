package Everything::Page::node_tracker;

use Moose;
extends 'Everything::Page';

with 'Everything::Security::NoGuest';

=head1 NAME

Everything::Page::node_tracker - Node Tracker statistics page

=head1 DESCRIPTION

Tracks user writing statistics over time, including XP, reputation, cools,
and individual node changes. Originally ported from cow of doom's node tracker.

=cut

sub buildReactData {
    my ( $self, $REQUEST ) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $USER = $REQUEST->user;
    my $query = $REQUEST->cgi;
    my $USER_HASHREF = $USER->NODEDATA;
    my $userid = $USER_HASHREF->{user_id};

    # Intro text
    my $intro_text = '<p><em>Finally, its time had come.</em></p>

<p>This is essentially a port of [cow of doom]\'s node tracker.
Obviously there\'s been some interface modification since we\'ve got a
direct line to the e2 database, but he did most of the heavy lifting,
and should be lauded for his hard work, [pbuh].</p>

<p>This is in beta, and things may change at any moment. To that end,
I haven\'t really messed with any of the data being collected (or much of anything else),
so if there\'s a feature you would like here or something seems off (especially if things are broken!),
please let [kthejoker|me] know.  Thanks.</p>

<p>P.S.: Do <strong>not</strong> sit here and refresh this page constantly.
It\'s not the heaviest page on the site, but it\'s not exactly the lightest either, okay?
I will hunt you down. So just visit it every once in a while, marvel at your greatness,
hit "update" to save the new data, and then head back out into the nodegel. Cool? - k</p>';

    # Get old tracker data
    my %oldinfo;
    my %oldnode;
    my $hasOld = $self->_getOldInfo($userid, \%oldinfo, \%oldnode);

    if (!$hasOld) {
        $DB->sqlInsert("nodetracker", {tracker_user => $userid, tracker_data => 'data'});
    }

    # Get current stats
    my %info;
    my %node;
    my %types;
    my @reps;
    $self->_getCurrentInfo($userid, \%info, \%node, \%types, \@reps);

    # Calculate merit and other derived stats
    my ($minmerit, $maxmerit) = $self->_meritCalc(\%info, \@reps);

    # Handle update request
    if ($query->param("update")) {
        $self->_updateTracker($userid, \%info, \%node);
        # Reload old info after update
        $self->_getOldInfo($userid, \%oldinfo, \%oldnode);
    }

    # Get last update time
    my $lasttime = $DB->sqlSelect("lasttime", "nodetracker", "tracker_user=$userid limit 1") || 'never';

    # Build structured data for React
    my $data = $self->_buildTrackerData(
        $userid, \%info, \%oldinfo, \%node, \%oldnode, \%types, $minmerit, $maxmerit, $lasttime
    );

    return {
        type => 'node_tracker',
        intro_text => $intro_text,
        %$data
    };
}

sub _getOldInfo {
    my ($self, $userid, $oldinfo, $oldnode) = @_;
    my $DB = $self->DB;

    my $tData = $DB->sqlSelect("tracker_data", "nodetracker", "tracker_user=$userid limit 1");
    return 0 unless $tData;
    return 1 if ($tData eq 'data');

    my @tD = split(/\n/, $tData);
    my $iData = shift(@tD);

    ($oldinfo->{xp}, $oldinfo->{nodes}, $oldinfo->{cools}, $oldinfo->{totalrep}, $oldinfo->{merit},
     $oldinfo->{devotion}, $oldinfo->{average}, $oldinfo->{median}, $oldinfo->{upvotes}, $oldinfo->{downvotes},
     $oldinfo->{maxcools}, $oldinfo->{maxvotes}) = split(/:/, $iData);

    # Initialize defaults
    for my $key (qw(xp cools totalrep nodes merit devotion average median upvotes downvotes maxcools maxvotes)) {
        $oldinfo->{$key} ||= 0;
        chomp($oldinfo->{$key});
    }

    if ($oldinfo->{nodes}) {
        $oldinfo->{wnf} = (($oldinfo->{totalrep} + (10 * $oldinfo->{cools})) / $oldinfo->{nodes});
        $oldinfo->{nodefu} = $oldinfo->{xp} / $oldinfo->{nodes};
        $oldinfo->{coolratio} = ($oldinfo->{cools} * 100) / $oldinfo->{nodes};
    }

    foreach (@tD) {
        chomp;
        if (/^(\d+):(-?\d+):(\d+):(.+):(\d+):(\d+)$/) {
            $oldnode->{$1} = [$2, $3, $4, $5, $6];
        } elsif (/^(\d+):(-?\d+):(\d+):(.*)$/) {
            $oldnode->{$1} = [$2, $3, $4, 0, 0];
        }

        if ($oldinfo->{maxrep} <= 0) {
            $oldinfo->{maxrep} = $oldinfo->{minrep} = $2;
        }
        if (defined $2) {
            $oldinfo->{maxrep} = $2 if ($2 > $oldinfo->{maxrep});
            $oldinfo->{minrep} = $2 if ($2 < $oldinfo->{minrep});
        }
    }

    $oldinfo->{votes} = $oldinfo->{upvotes} + $oldinfo->{downvotes};
    return 1;
}

sub _getCurrentInfo {
    my ($self, $userid, $info, $node, $types, $reps) = @_;
    my $DB = $self->DB;
    my $USER_HASHREF = $DB->getNodeById($userid);

    $info->{xp} = $USER_HASHREF->{experience};

    my $csr = $DB->sqlSelectMany(
        "node.node_id, node.reputation, writeup.cooled, parent_node.title, type_node.title AS type",
        'node
          JOIN writeup ON node.node_id = writeup.writeup_id
          JOIN node AS parent_node ON parent_node.node_id = writeup.parent_e2node
          JOIN node AS type_node ON type_node.node_id = writeup.wrtype_writeuptype',
        "node.author_user = $userid AND node.type_nodetype=117",
        'ORDER BY writeup.publishtime DESC'
    );

    while (my $N = $csr->fetchrow_hashref) {
        my $name = $N->{title};
        my $type = $N->{type};

        # Skip admin writeups
        next if ($name eq "E2 Nuke Request" || $name eq "Edit these E2 titles" ||
                 $name eq "Nodeshells marked for destruction" || $name eq "Broken Nodes");

        my $node_id = $N->{node_id};
        my $reputation = $N->{reputation};
        my $cooled = $N->{cooled};

        my $votescast = $DB->sqlSelect('count(*)', 'vote', "vote_id=$node_id");
        my $upvotes = ($votescast + $reputation) / 2;
        my $downvotes = ($votescast - $reputation) / 2;

        if (int($upvotes) != $upvotes) {
            $downvotes = $DB->sqlSelect('count(*)', 'vote', "vote_id=$node_id and weight=-1");
            $upvotes = $votescast - $downvotes;
            $reputation = $upvotes - $downvotes;
        }

        my $votes = $downvotes + $upvotes;

        $types->{$type} = 0 unless defined($types->{$type});
        $types->{$type}++;
        $info->{nodes}++;

        push(@$reps, $reputation);
        $info->{totalrep} += $reputation;
        $info->{cools} += $cooled;
        $info->{downvotes} += $downvotes;
        $info->{upvotes} += $upvotes;

        if ($info->{nodes} == 1) {
            $info->{maxrep} = $info->{minrep} = $reputation;
            $info->{maxvotes} = $votes;
            $info->{maxcools} = $cooled;
        }

        $info->{maxrep} = $reputation if ($reputation > $info->{maxrep});
        $info->{minrep} = $reputation if ($reputation < $info->{minrep});
        $info->{maxvotes} = $votes if ($votes > $info->{maxvotes});
        $info->{maxcools} = $cooled if ($cooled > $info->{maxcools});

        $node->{$node_id} = [$reputation, $cooled, $name, $upvotes, $downvotes];
    }

    $info->{votes} = $info->{upvotes} + $info->{downvotes};
    return;
}

sub _meritCalc {
    my ($self, $info, $reps) = @_;

    my @rep2 = sort { $a <=> $b } @$reps;
    my $sz = scalar(@rep2);
    return (0, 0) unless $sz;

    my $stt = int($sz / 4);
    my $stp = int(($sz * 3) / 4 + 0.5);
    my $tot = 0;
    my $tot2 = 0;

    for (my $i = $stt; $i < $stp; ++$i) {
        $tot += $rep2[$i];
    }

    for (my $i = 0; $i < $sz; ++$i) {
        $tot2 += $rep2[$i];
    }

    $info->{average} = $tot2 / $sz;
    $info->{median} = $rep2[$sz / 2];
    $info->{merit} = $tot / ($stp - $stt);
    $info->{devotion} = int($info->{merit} * scalar(@rep2) + 0.5);

    my $minmerit = $rep2[$stt];
    my $maxmerit = $rep2[$stp - 1];

    if ($info->{nodes}) {
        $info->{wnf} = (($info->{totalrep} + (10 * $info->{cools})) / $info->{nodes});
        $info->{nodefu} = $info->{xp} / $info->{nodes};
        $info->{coolratio} = ($info->{cools} * 100) / $info->{nodes};
    }

    return ($minmerit, $maxmerit);
}

sub _updateTracker {
    my ($self, $userid, $info, $node) = @_;
    my $DB = $self->DB;

    my $tStr = "$info->{xp}:$info->{nodes}:$info->{cools}:$info->{totalrep}:" .
               "$info->{merit}:$info->{devotion}:$info->{average}:$info->{median}:$info->{upvotes}:$info->{downvotes}:" .
               "$info->{maxcools}:$info->{maxvotes}\n";

    foreach (sort { $b <=> $a } keys %$node) {
        $tStr .= "$_:" . join(":", @{$node->{$_}}) . "\n";
    }

    $DB->sqlUpdate("nodetracker",
        {tracker_data => $tStr, -lasttime => 'now()', -hits => 'hits + 1'},
        "tracker_user=$userid limit 1"
    );
    return;
}

sub _buildTrackerData {
    my ($self, $userid, $info, $oldinfo, $node, $oldnode, $types, $minmerit, $maxmerit, $lasttime) = @_;
    my $APP = $self->APP;

    # Build stats with diffs
    my %stats = (
        nodes => {current => $info->{nodes} || 0, diff => ($info->{nodes} || 0) - ($oldinfo->{nodes} || 0)},
        xp => {current => $info->{xp} || 0, diff => ($info->{xp} || 0) - ($oldinfo->{xp} || 0)},
        cools => {current => $info->{cools} || 0, diff => ($info->{cools} || 0) - ($oldinfo->{cools} || 0)},
        maxrep => {current => $info->{maxrep} || 0, diff => ($info->{maxrep} || 0) - ($oldinfo->{maxrep} || 0)},
        minrep => {current => $info->{minrep} || 0, diff => ($info->{minrep} || 0) - ($oldinfo->{minrep} || 0)},
        totalrep => {current => $info->{totalrep} || 0, diff => ($info->{totalrep} || 0) - ($oldinfo->{totalrep} || 0)},
        nodefu => {current => $info->{nodefu} || 0, diff => ($info->{nodefu} || 0) - ($oldinfo->{nodefu} || 0)},
        wnf => {current => $info->{wnf} || 0, diff => ($info->{wnf} || 0) - ($oldinfo->{wnf} || 0)},
        coolratio => {current => $info->{coolratio} || 0, diff => ($info->{coolratio} || 0) - ($oldinfo->{coolratio} || 0)},
        merit => {current => $info->{merit} || 0, diff => ($info->{merit} || 0) - ($oldinfo->{merit} || 0)},
        average => {current => $info->{average} || 0, diff => ($info->{average} || 0) - ($oldinfo->{average} || 0)},
        median => {current => $info->{median} || 0, diff => ($info->{median} || 0) - ($oldinfo->{median} || 0)},
        upvotes => {current => $info->{upvotes} || 0, diff => ($info->{upvotes} || 0) - ($oldinfo->{upvotes} || 0)},
        devotion => {current => $info->{devotion} || 0, diff => ($info->{devotion} || 0) - ($oldinfo->{devotion} || 0)},
        downvotes => {current => $info->{downvotes} || 0, diff => ($info->{downvotes} || 0) - ($oldinfo->{downvotes} || 0)},
        votes => {current => $info->{votes} || 0, diff => ($info->{votes} || 0) - ($oldinfo->{votes} || 0)},
        maxcools => {current => $info->{maxcools} || 0, diff => ($info->{maxcools} || 0) - ($oldinfo->{maxcools} || 0)},
        maxvotes => {current => $info->{maxvotes} || 0, diff => ($info->{maxvotes} || 0) - ($oldinfo->{maxvotes} || 0)},
    );

    # Type breakdown
    my @type_breakdown = ();
    if ($info->{nodes}) {
        foreach (sort keys %$types) {
            push @type_breakdown, {
                type => $_,
                count => $types->{$_},
                percentage => sprintf("%.1f", (100 * $types->{$_}) / $info->{nodes})
            };
        }
    }

    # Published/Removed/Renamed nodes
    my @published = ();
    my @removed = ();
    my @renamed = ();
    my @changed_nodes = ();

    my %all_nodes = map { $_ => 1 } (keys %$node, keys %$oldnode);
    foreach (sort { $b <=> $a } keys %all_nodes) {
        if (!exists($oldnode->{$_})) {
            push @published, {node_id => $_, title => $node->{$_}->[2]};
            $oldnode->{$_} = [0, 0, $node->{$_}->[2]];
            push @changed_nodes, $_;
        } elsif (!exists($node->{$_})) {
            push @removed, {node_id => $_, title => $oldnode->{$_}->[2]};
        } else {
            push(@changed_nodes, $_) if ($node->{$_}->[0] != $oldnode->{$_}->[0]);
            push(@changed_nodes, $_) if ($node->{$_}->[1] != $oldnode->{$_}->[1]);
            push(@changed_nodes, $_) if (defined $node->{$_}->[3] && defined $oldnode->{$_}->[3] && $node->{$_}->[3] != $oldnode->{$_}->[3]);
            push(@changed_nodes, $_) if (defined $node->{$_}->[4] && defined $oldnode->{$_}->[4] && $node->{$_}->[4] != $oldnode->{$_}->[4]);

            if ($node->{$_}->[2] ne $oldnode->{$_}->[2]) {
                push @renamed, {
                    node_id => $_,
                    old_title => $oldnode->{$_}->[2],
                    new_title => $node->{$_}->[2]
                };
            }
        }
    }

    # Reputation changes
    my @changes = ();
    my %seen;
    foreach (grep { !$seen{$_}++ } @changed_nodes) {
        next unless exists($node->{$_});

        $oldnode->{$_}->[3] = 0 unless defined($oldnode->{$_}->[3]);
        $oldnode->{$_}->[4] = 0 unless defined($oldnode->{$_}->[4]);

        my $d = $node->{$_}->[0] - $oldnode->{$_}->[0];
        my $d1 = $node->{$_}->[3] - $oldnode->{$_}->[3];
        my $d2 = $node->{$_}->[4] - $oldnode->{$_}->[4];
        my $dcool = $node->{$_}->[1] - $oldnode->{$_}->[1];

        push @changes, {
            node_id => $_,
            title => $node->{$_}->[2],
            reputation => $node->{$_}->[0],
            rep_change => $d,
            upvotes => $node->{$_}->[3],
            downvotes => $node->{$_}->[4],
            upvotes_change => $d1,
            downvotes_change => $d2,
            cools => $node->{$_}->[1],
            cool_change => $dcool
        };
    }

    return {
        last_update => $lasttime,
        stats => \%stats,
        type_breakdown => \@type_breakdown,
        merit_range => {min => $minmerit || 0, max => $maxmerit || 0},
        published_nodes => \@published,
        removed_nodes => \@removed,
        renamed_nodes => \@renamed,
        changed_nodes => \@changes,
        has_changes => (scalar(@published) > 0 || scalar(@removed) > 0 || scalar(@renamed) > 0 || scalar(@changes) > 0)
    };
}

__PACKAGE__->meta->make_immutable;
1;
