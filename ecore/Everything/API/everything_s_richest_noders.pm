package Everything::API::everything_s_richest_noders;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::everything_s_richest_noders - GP wealth leaderboard

=head1 DESCRIPTION

Admin-only GP distribution: the richest 1500, the 10 poorest (nonzero), the top 10, and what share
of all GP the top 10 hold. The source node is a restricted superdoc; that gate lives here now (a pure
gate serves the page to anyone and /api/pagestate bypasses node permissions, so the API is the real
boundary). Moved out of C<Everything::Page::everything_s_richest_noders>'s buildReactData (#4546).

  GET /api/everything_s_richest_noders

=cut

sub routes { return { "/" => "list" }; }

sub _rows {
    my ($self, $where, $limit) = @_;
    my $DB = $self->DB;
    my $csr = $DB->sqlSelectMany('user_id, gp', 'user', $where, 'ORDER BY gp ' . $limit);
    my @out;
    while (my ($user_id, $gp) = $csr->fetchrow_array) {
        my $user_node = $DB->getNodeById($user_id);
        next unless $user_node;
        # 0 + $gp: fetchrow_array values are string-flagged, so re-numify or gp ships as a string (#4152).
        push @out, { user_id => int($user_id), title => $user_node->{title}, gp => 0 + $gp };
    }
    $csr->finish();
    return \@out;
}

sub list {
    my ($self, $REQUEST) = @_;
    my $DB   = $self->DB;
    my $APP  = $self->APP;
    my $user = $REQUEST->user;

    return [$self->HTTP_OK, { success => 0, state => 'guest' }] if $user->is_guest;
    return [$self->HTTP_OK, { success => 0, state => 'permission' }]
        unless $APP->isAdmin($user->NODEDATA);

    my $limit_all = 1500;
    my $limit_top = 10;

    my ($total_gp) = $DB->sqlSelect('SUM(GP)', 'user');
    $total_gp = 0 + ($total_gp || 0);

    my $richest_all = $self->_rows('',        "DESC LIMIT $limit_all");
    my $poorest     = $self->_rows('gp <> 0', "ASC LIMIT $limit_top");
    my $richest_top = $self->_rows('',        "DESC LIMIT $limit_top");

    my $richest_top_gp = 0;
    $richest_top_gp += $_->{gp} for @$richest_top;

    my $top_percentage = $total_gp > 0 ? ($richest_top_gp / $total_gp * 100) : 0;

    return [$self->HTTP_OK, {
        success        => 1,
        total_gp       => $total_gp,
        richest_all    => $richest_all,
        poorest        => $poorest,
        richest_top    => $richest_top,
        richest_top_gp => 0 + $richest_top_gp,
        top_percentage => 0 + $top_percentage,
        limit_all      => $limit_all,
        limit_top      => $limit_top,
    }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut
