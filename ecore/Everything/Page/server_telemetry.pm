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

    # Memory analysis from /proc - works without special permissions
    # Reads VmRSS (resident set size) for each apache2 process
    my $memory_analysis = _get_apache_memory();

    return {
        type => 'server_telemetry',
        apache_processes => $apache_processes,
        apache_count => $apache_count,
        vmstat => $vmstat,
        uptime => $uptime,
        health_check => $health_check,
        apache_config => $apache_config,
        memory_analysis => $memory_analysis
    };
}

sub _get_apache_memory {
    my @results;
    my $total_rss = 0;

    # Get apache2 PIDs
    my @pids = split /\n/, `pgrep -f '/usr/sbin/apache2'`;

    push @results, sprintf("%-8s %12s %12s  %s", "PID", "VmRSS (KB)", "VmSize (KB)", "Command");
    push @results, "-" x 60;

    my $count = 0;
    for my $pid (@pids) {
        chomp $pid;
        next unless $pid =~ /^\d+$/;

        # Read /proc/<pid>/status for memory info
        my $status_file = "/proc/$pid/status";
        next unless -r $status_file;

        open my $fh, '<', $status_file or next;
        my %mem;
        while (<$fh>) {
            if (/^(VmRSS|VmSize):\s+(\d+)\s+kB/) {
                $mem{$1} = $2;
            }
        }
        close $fh;

        # Get command line
        my $cmdline = '';
        if (open my $cmd_fh, '<', "/proc/$pid/cmdline") {
            $cmdline = <$cmd_fh> // '';
            $cmdline =~ s/\0/ /g;
            $cmdline =~ s/^\s+|\s+$//g;
            close $cmd_fh;
        }

        # Only include actual apache2 processes
        next unless $cmdline =~ m{^/usr/sbin/apache2}smx;

        $cmdline = substr($cmdline, 0, 40) . '...' if length($cmdline) > 40;

        if ($mem{VmRSS}) {
            push @results, sprintf("%-8s %12d %12d  %s",
                $pid,
                $mem{VmRSS} || 0,
                $mem{VmSize} || 0,
                $cmdline || '(unknown)');
            $total_rss += $mem{VmRSS} || 0;
            $count++;
        }
    }

    push @results, "-" x 60;
    push @results, sprintf("Total RSS: %.1f MB (%d processes)", $total_rss / 1024, $count);

    return join("\n", @results);
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
