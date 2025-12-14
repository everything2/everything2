package Everything::Page::voting_data;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::voting_data - Voting statistics analysis tool

=head1 DESCRIPTION

Admin tool for analyzing voting patterns by date or month.
Shows vote counts for specific dates or monthly breakdowns.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB    = $self->DB;
    my $APP   = $self->APP;
    my $USER  = $REQUEST->user;
    my $query = $REQUEST->cgi;

    # Admin only
    unless ($APP->isAdmin($USER->NODEDATA)) {
        return {
            type  => 'voting_data',
            error => 'Access denied. This tool is restricted to administrators.'
        };
    }

    my @results = ();
    my $search_type = '';

    # Date range search
    my $voteday = $query->param('voteday') || '';
    my $voteday2 = $query->param('voteday2') || '';

    if ($voteday) {
        $voteday =~ s/[^\d-]//g;  # Sanitize
        $voteday2 =~ s/[^\d-]//g if $voteday2;
        $voteday2 ||= $voteday;

        my $count = $DB->sqlSelect(
            "count(*)", "vote",
            "votetime >= " . $DB->quote("$voteday 00:00:00") .
            " AND votetime <= " . $DB->quote("$voteday2 23:59:59")
        );

        $search_type = 'date_range';
        push @results, {
            start_date => $voteday,
            end_date   => $voteday2,
            count      => int($count || 0)
        };
    }

    # Monthly breakdown search
    my $votemonth = $query->param('votemonth') || '';
    my $voteyear = $query->param('voteyear') || '';

    if ($votemonth && $voteyear) {
        $votemonth =~ s/\D//g;
        $voteyear =~ s/\D//g;

        $search_type = 'monthly';
        @results = ();

        for my $day (1..31) {
            my $checkdate = sprintf("%04d-%02d-%02d", $voteyear, $votemonth, $day);
            my $count = $DB->sqlSelect(
                "count(*)", "vote",
                "votetime >= " . $DB->quote("$checkdate 00:00:00") .
                " AND votetime <= " . $DB->quote("$checkdate 23:59:59")
            );
            push @results, {
                date  => $checkdate,
                count => int($count || 0)
            };
        }
    }

    return {
        type        => 'voting_data',
        search_type => $search_type,
        results     => \@results,
        voteday     => $voteday,
        voteday2    => $voteday2,
        votemonth   => $votemonth,
        voteyear    => $voteyear
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
