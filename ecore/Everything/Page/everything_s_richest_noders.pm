package Everything::Page::everything_s_richest_noders;

use Moose;
extends 'Everything::Page';

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $limit_all = 1500;
    my $limit_top = 10;

    # Get total GP in circulation
    my ($total_gp) = $DB->sqlSelect('SUM(GP)', 'user');
    $total_gp ||= 0;

    # Get top 1500 richest users
    my $csr = $DB->sqlSelectMany('user_id, gp', 'user', '', 'ORDER BY gp DESC LIMIT ' . $limit_all);
    my @richest_all = ();
    while (my ($user_id, $gp) = $csr->fetchrow_array) {
        my $user_node = $DB->getNodeById($user_id);
        next unless $user_node;
        push @richest_all, {
            user_id => $user_id,
            title => $user_node->{title},
            gp => $gp
        };
    }
    $csr->finish();

    # Get 10 poorest users (excluding 0 GP)
    $csr = $DB->sqlSelectMany('user_id, gp', 'user', 'gp <> 0', 'ORDER BY gp ASC LIMIT ' . $limit_top);
    my @poorest = ();
    while (my ($user_id, $gp) = $csr->fetchrow_array) {
        my $user_node = $DB->getNodeById($user_id);
        next unless $user_node;
        push @poorest, {
            user_id => $user_id,
            title => $user_node->{title},
            gp => $gp
        };
    }
    $csr->finish();

    # Get top 10 richest users
    $csr = $DB->sqlSelectMany('user_id, gp', 'user', '', 'ORDER BY gp DESC LIMIT ' . $limit_top);
    my @richest_top = ();
    my $richest_top_gp = 0;
    while (my ($user_id, $gp) = $csr->fetchrow_array) {
        my $user_node = $DB->getNodeById($user_id);
        next unless $user_node;
        push @richest_top, {
            user_id => $user_id,
            title => $user_node->{title},
            gp => $gp
        };
        $richest_top_gp += $gp;
    }
    $csr->finish();

    # Calculate percentage of GP held by top 10
    my $top_percentage = $total_gp > 0 ? ($richest_top_gp / $total_gp * 100) : 0;

    return {
        type => 'everything_s_richest_noders',
        total_gp => $total_gp,
        richest_all => \@richest_all,
        poorest => \@poorest,
        richest_top => \@richest_top,
        richest_top_gp => $richest_top_gp,
        top_percentage => $top_percentage,
        limit_all => $limit_all,
        limit_top => $limit_top
    };
}

__PACKAGE__->meta->make_immutable;
1;
