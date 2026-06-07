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
    my $apache_config = `cat /etc/apache2/apache2.conf`;

    # Memory analysis from /proc + the task cgroup. Per-process RSS overcounts
    # COW-shared pages (interpreter + preloaded modules counted once per worker),
    # so we also report PSS where readable and the cgroup total -- the only
    # figure that reflects the task's real memory budget (and matches CloudWatch).
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
    my $total_pss = 0;
    my $pss_complete = 1;   # cleared if any worker's PSS is unreadable

    # Get apache2 PIDs
    my @pids = split /\n/, `pgrep -f '/usr/sbin/apache2'`;

    push @results, sprintf("%-8s %12s %12s %12s  %s",
        "PID", "RSS (KB)", "PSS (KB)", "VmSize (KB)", "Command");
    push @results, "-" x 72;

    my $count = 0;
    for my $pid (@pids) {
        chomp $pid;
        next unless $pid =~ /^\d+$/;

        # Read /proc/<pid>/status for RSS/VmSize
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
        next unless $mem{VmRSS};

        $cmdline = substr($cmdline, 0, 40) . '...' if length($cmdline) > 40;

        # PSS (proportional set size): real per-process RAM with COW-shared
        # pages divided across sharers. Readable for our own worker; sibling
        # workers dropped privileges (root -> www-data) and are non-dumpable,
        # so theirs return EACCES without CAP_SYS_PTRACE -- show "-" there and
        # lean on the cgroup total below for the authoritative figure.
        my $pss = _read_pss("/proc/$pid/smaps_rollup");
        if (defined $pss) {
            $total_pss += $pss;
        }
        else {
            $pss_complete = 0;
        }

        push @results, sprintf("%-8s %12d %12s %12d  %s",
            $pid,
            $mem{VmRSS},
            (defined $pss ? $pss : '-'),
            $mem{VmSize} || 0,
            $cmdline || '(unknown)');
        $total_rss += $mem{VmRSS};
        $count++;
    }

    push @results, "-" x 72;
    push @results, sprintf(
        "Sum of RSS:  %.1f MB (%d procs) -- OVERCOUNTS: shared pages counted once per worker",
        $total_rss / 1024, $count);
    if ($total_pss > 0) {
        push @results, sprintf(
            "Sum of PSS:  %.1f MB%s -- real RAM (COW-shared pages counted once)",
            $total_pss / 1024,
            ($pss_complete ? '' : ' [partial: some workers non-dumpable]'));
    }

    # Authoritative task memory from the cgroup. This is what the Fargate task
    # budget is measured against and what CloudWatch MemoryUtilization reports.
    # NOTE: vmstat/free elsewhere on this page report the underlying HOST, not
    # this task -- ignore them for task-memory questions.
    my $cg = _get_cgroup_memory();
    if (defined $cg) {
        push @results, "";
        push @results, "Task memory (cgroup -- authoritative, matches CloudWatch):";
        push @results, $cg;
    }

    return join("\n", @results);
}

# Pull the single rollup Pss: line from smaps_rollup (kB). Returns undef if the
# file is unreadable (non-dumpable sibling) or absent (old kernel).
sub _read_pss {
    my ($file) = @_;
    return undef unless -r $file;
    open my $fh, '<', $file or return undef;
    my $pss;
    while (<$fh>) {
        if (/^Pss:\s+(\d+)\s+kB/) { $pss = $1; last; }
    }
    close $fh;
    return $pss;
}

# Task memory from the cgroup (v2 preferred, v1 fallback). Returns a formatted
# multi-line string, or undef if no cgroup memory controller is readable.
sub _get_cgroup_memory {
    # cgroup v2
    if (-r '/sys/fs/cgroup/memory.current') {
        my $cur = _slurp_num('/sys/fs/cgroup/memory.current');
        return undef unless defined $cur;
        my $max = _slurp_raw('/sys/fs/cgroup/memory.max');
        my %stat = _read_kv('/sys/fs/cgroup/memory.stat');
        my $line = sprintf("  used %.0f MB", $cur / 1048576);
        if (defined $max && $max ne 'max' && $max > 0) {
            $line .= sprintf(" / limit %.0f MB  (%.1f%%)",
                $max / 1048576, 100 * $cur / $max);
        }
        my @extra;
        push @extra, sprintf("anon %.0f MB", $stat{anon} / 1048576) if $stat{anon};
        push @extra, sprintf("file %.0f MB", $stat{file} / 1048576) if $stat{file};
        $line .= "\n  (" . join(", ", @extra) . ")" if @extra;
        return $line;
    }
    # cgroup v1
    if (-r '/sys/fs/cgroup/memory/memory.usage_in_bytes') {
        my $cur = _slurp_num('/sys/fs/cgroup/memory/memory.usage_in_bytes');
        return undef unless defined $cur;
        my $max = _slurp_num('/sys/fs/cgroup/memory/memory.limit_in_bytes');
        my $line = sprintf("  used %.0f MB", $cur / 1048576);
        # v1 reports a huge sentinel (~2^63) when no limit is set
        if (defined $max && $max < 9_000_000_000_000_000_000) {
            $line .= sprintf(" / limit %.0f MB  (%.1f%%)",
                $max / 1048576, 100 * $cur / $max);
        }
        return $line;
    }
    return undef;
}

sub _slurp_raw {
    my ($f) = @_;
    open my $fh, '<', $f or return undef;
    my $v = <$fh>;
    close $fh;
    chomp $v if defined $v;
    return $v;
}

sub _slurp_num {
    my $v = _slurp_raw($_[0]);
    return undef unless defined $v && $v =~ /^\d+$/;
    return $v + 0;
}

sub _read_kv {
    my ($f) = @_;
    my %h;
    open my $fh, '<', $f or return %h;
    while (<$fh>) {
        if (/^(\w+)\s+(\d+)/) { $h{$1} = $2; }
    }
    close $fh;
    return %h;
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
