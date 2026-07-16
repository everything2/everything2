package Everything::API::noding_speedometer;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::noding_speedometer - a user's noding speed + level-up projection

=head1 DESCRIPTION

Computes days-per-node over a user's last N writeups and projects time-to-next-level. Moved out of
C<Everything::Page::noding_speedometer>'s buildReactData (#4539): the Page is a pure gate, React
reads speedyuser/clocknodes off the URL and calls this.

  GET /api/noding_speedometer?speedyuser=<name>&clocknodes=<n>

Logged-in only (NoGuest). The speedometer's colour/width/comment tiers live in React, keyed on the
raw C<speed> this ships. Error C<state>s: 'guest' / 'user_not_found' / 'no_writeups' /
'insufficient_days'.

=cut

sub routes { return { "/" => "list" }; }

sub list {
    my ($self, $REQUEST) = @_;
    my $DB   = $self->DB;
    my $APP  = $self->APP;
    my $USER = $REQUEST->user;

    return [$self->HTTP_OK, { success => 0, state => 'guest' }] if $USER->is_guest;

    my $speedyuser  = $REQUEST->param('speedyuser');
    $speedyuser = defined($speedyuser) ? $speedyuser : '';
    my $clock_nodes = int($REQUEST->param('clocknodes') || 50);
    $clock_nodes = 50 if $clock_nodes < 1;

    # No user yet: form-only shell (default to the viewer's own name).
    return [$self->HTTP_OK, { success => 1, username => $USER->title, clock_nodes => $clock_nodes }]
        if $speedyuser eq '';

    my $target_user = $DB->getNode($speedyuser, 'user');
    return [$self->HTTP_OK, { success => 0, state => 'user_not_found', username => $speedyuser, clock_nodes => $clock_nodes }]
        unless $target_user;

    my $uid = int($target_user->{node_id});
    my $writeup_type_id = int(($DB->getType('writeup') || {})->{node_id} || 0);

    my $total_writeups = $DB->sqlSelect('COUNT(*)', 'node',
        "author_user=$uid AND type_nodetype=$writeup_type_id") || 0;

    return [$self->HTTP_OK, { success => 0, state => 'no_writeups', username => $target_user->{title}, clock_nodes => $clock_nodes }]
        if $total_writeups == 0;

    my $actual_count = $clock_nodes;
    $actual_count = $total_writeups if $total_writeups < $clock_nodes;

    # Age (in days) of the Nth-most-recent writeup.
    my $offset = $actual_count - 1;
    my $days_elapsed = $DB->sqlSelect(
        'TO_DAYS(NOW()) - TO_DAYS(publishtime)',
        'node JOIN writeup ON writeup_id=node_id',
        "author_user=$uid ORDER BY publishtime DESC LIMIT $offset,1"
    );

    return [$self->HTTP_OK, { success => 0, state => 'insufficient_days', username => $target_user->{title}, clock_nodes => $clock_nodes }]
        if !defined($days_elapsed) || $days_elapsed < 1;

    my $speed = $days_elapsed / $actual_count;   # days per node

    # XP-per-writeup average over the clocked window.
    my $csr = $DB->sqlSelectMany(
        'title, node_id, reputation, cooled',
        'node INNER JOIN writeup ON node_id=writeup_id',
        "author_user=$uid AND type_nodetype=$writeup_type_id",
        "ORDER BY publishtime DESC LIMIT 0, $actual_count"
    );

    my $total_upvotes = 0;
    my $total_cools   = 0;
    while (my $row = $csr->fetchrow_hashref) {
        next if $row->{title} =~ /^(E2 Nuke Request|Edit these E2 titles|Nodeshells marked for destruction|Broken Nodes) \(/;
        my $votes_cast = $DB->sqlSelect('COUNT(*)', 'vote', 'vote_id=' . int($row->{node_id}));
        my $upvotes = ($votes_cast + $row->{reputation}) / 2;
        if (int($upvotes) != $upvotes) {
            $upvotes = $DB->sqlSelect('COUNT(*)', 'vote', 'vote_id=' . int($row->{node_id}) . ' AND weight=1');
        }
        $total_upvotes += $upvotes;
        $total_cools   += ($row->{cooled} || 0);
    }

    my $avg_xp = (($actual_count * 5) + ($total_cools * 20) + $total_upvotes) / $actual_count;

    my $level_wu_vars = $APP->getVars($DB->getNode('level writeups', 'setting'));
    my $level_xp_vars = $APP->getVars($DB->getNode('level experience', 'setting'));
    my $current_level = $APP->getLevel($target_user);
    my $current_xp    = $target_user->{experience};

    my $req_wu = ($level_wu_vars->{$current_level + 1} || 0) - $total_writeups;
    my $req_xp = ($level_xp_vars->{$current_level + 1} || 0) - $current_xp;

    my $days_wu = $req_wu > 0 ? $req_wu * $speed : 0;
    my $days_xp = $req_xp > 0 ? $req_xp / ((1 / $speed) * $avg_xp) : 0;
    my $days_to_level = $days_wu > $days_xp ? $days_wu : $days_xp;

    my $nodes_needed = $req_wu > 0 ? $req_wu : 0;
    if ($req_xp > 0) {
        my $temp = $req_xp / $avg_xp;
        $nodes_needed = $temp if $temp > $nodes_needed;
    }

    return [$self->HTTP_OK, {
        success        => 1,
        username       => $target_user->{title},
        clock_nodes    => $clock_nodes,
        total_writeups => int($total_writeups),
        actual_count   => int($actual_count),
        days_elapsed   => $days_elapsed + 0,
        speed          => $speed + 0,
        level_data     => {
            current_level => int($current_level),
            next_level    => int($current_level) + 1,
            req_wu        => $req_wu > 0 ? int($req_wu) : 0,
            req_xp        => $req_xp > 0 ? int($req_xp) : 0,
            avg_xp        => $avg_xp + 0,
            nodes_needed  => $nodes_needed + 0,
            days_to_level => $days_to_level + 0,
        },
    }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut
