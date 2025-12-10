package Everything::Page::server_telemetry;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::server_telemetry - Server diagnostics and telemetry

=head1 DESCRIPTION

Displays server diagnostics including Apache processes, VM stats, uptime,
health checks, and Apache configuration.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns server telemetry data from shell commands.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    # Run diagnostic commands
    my $apache_processes = `ps aux | grep apache2 | grep -v grep`;
    my $apache_count = `ps aux | grep apache2 | grep -v grep | wc -l`;
    chomp($apache_count);

    my $vmstat = `vmstat`;
    my $uptime = `uptime`;
    my $health_check = `/var/everything/tools/container-health-check.pl --debug-cloudwatch 2>&1`;
    my $apache_config = `cat /etc/apache2/everything.conf`;

    return {
        type => 'server_telemetry',
        apache_processes => $apache_processes,
        apache_count => $apache_count,
        vmstat => $vmstat,
        uptime => $uptime,
        health_check => $health_check,
        apache_config => $apache_config
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
