package Everything::Page::database_lag_o_meter;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::database_lag-o-meter - Database Lag-o-meter page

=head1 DESCRIPTION

Displays MySQL database performance statistics including uptime, query counts,
and slow query metrics.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns data about database performance metrics.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;

    my %stats = ();
    my %vars = ();

    # Get MySQL status variables
    my $csr = $DB->{dbh}->prepare('show status');
    $csr->execute;
    while (my ($key, $val) = $csr->fetchrow) {
        $stats{$key} = $val;
    }
    $csr->finish;

    # Get MySQL configuration variables
    $csr = $DB->{dbh}->prepare('show variables');
    $csr->execute;
    while (my ($key, $val) = $csr->fetchrow) {
        $vars{$key} = $val;
    }
    $csr->finish;

    # Calculate slow queries per million
    my $slow_per_million = 0;
    if ($stats{Queries} && $stats{Queries} > 0) {
        $slow_per_million = sprintf("%.2f", 1000000 * $stats{Slow_queries} / $stats{Queries});
    }

    # Format uptime as days+hours:minutes:seconds
    my $uptime_seconds = $stats{Uptime} || 0;
    my $d = int($uptime_seconds / (60 * 60 * 24));
    my $remaining = $uptime_seconds % (60 * 60 * 24);
    my $h = int($remaining / (60 * 60));
    $remaining = $remaining % (60 * 60);
    my $m = int($remaining / 60);
    my $s = $remaining % 60;

    my $uptime_formatted = sprintf("%d+%02d:%02d:%02d", $d, $h, $m, $s);

    return {
        type => 'database_lag_o_meter',
        uptime => $uptime_formatted,
        queries => $stats{Queries} + 0,
        slow_queries => $stats{Slow_queries} + 0,
        slow_query_threshold => $vars{long_query_time},
        slow_per_million => $slow_per_million + 0
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
