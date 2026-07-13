package Everything::API::voting_data;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::voting_data - admin vote-count statistics by date or month

=head1 DESCRIPTION

Admin tool: count votes over a date range, or produce a per-day breakdown for a given month. Moved
out of C<Everything::Page::voting_data>'s buildReactData (#4530): the Page is a pure gate, React
reads voteday/voteday2/votemonth/voteyear off the URL and calls this.

  GET /api/voting_data?voteday=YYYY-MM-DD[&voteday2=YYYY-MM-DD]
  GET /api/voting_data?votemonth=MM&voteyear=YYYY

Admin-only. All date inputs are stripped to digits/dashes before interpolation (injection-safe).

=cut

sub routes { return { "/" => "list" }; }

sub list {
    my ($self, $REQUEST) = @_;
    my $DB   = $self->DB;
    my $USER = $REQUEST->user;

    return [$self->HTTP_OK, { success => 0, state => 'admin' }] unless $USER->is_admin;

    my $voteday   = $REQUEST->param('voteday');
    my $voteday2  = $REQUEST->param('voteday2');
    my $votemonth = $REQUEST->param('votemonth');
    my $voteyear  = $REQUEST->param('voteyear');
    $_ = defined($_) ? $_ : '' for ($voteday, $voteday2, $votemonth, $voteyear);

    my @results;
    my $search_type = '';

    # Monthly breakdown takes precedence when a month+year is supplied (matches the
    # legacy order: the monthly branch overwrote the date-range results).
    if ($votemonth ne '' && $voteyear ne '') {
        $votemonth =~ s/\D//g;
        $voteyear  =~ s/\D//g;
        $search_type = 'monthly';
        for my $day (1 .. 31) {
            my $checkdate = sprintf('%04d-%02d-%02d', $voteyear, $votemonth, $day);
            my $count = $DB->sqlSelect('count(*)', 'vote',
                'votetime >= ' . $DB->quote("$checkdate 00:00:00") .
                ' AND votetime <= ' . $DB->quote("$checkdate 23:59:59"));
            push @results, { date => $checkdate, count => int($count || 0) };
        }
    }
    elsif ($voteday ne '') {
        $voteday  =~ s/[^\d-]//g;
        $voteday2 =~ s/[^\d-]//g;
        $voteday2 = $voteday if $voteday2 eq '';
        $search_type = 'date_range';
        my $count = $DB->sqlSelect('count(*)', 'vote',
            'votetime >= ' . $DB->quote("$voteday 00:00:00") .
            ' AND votetime <= ' . $DB->quote("$voteday2 23:59:59"));
        push @results, { start_date => $voteday, end_date => $voteday2, count => int($count || 0) };
    }

    return [$self->HTTP_OK, {
        success     => 1,
        search_type => $search_type,
        results     => \@results,
        voteday     => $voteday,
        voteday2    => $voteday2,
        votemonth   => $votemonth,
        voteyear    => $voteyear,
    }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut
