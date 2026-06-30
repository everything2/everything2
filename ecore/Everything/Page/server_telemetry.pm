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

    # The app runs under Starman (PSGI, app.psgi) -- the worker processes are where the
    # app and its memory actually live. apache2 is just the mpm_event reverse proxy out
    # front (a couple of tiny procs), so we report the Starman workers as the app view
    # and the apache front only as a count.
    my $app_workers = `ps -eo pid,rss,etimes,args 2>/dev/null | grep -E 'starman (master|worker)' | grep -v grep`;
    my $worker_count = `pgrep -fc 'starman worker' 2>/dev/null`;
    chomp($worker_count);
    my $apache_count = `pgrep -fc '/usr/sbin/apache2' 2>/dev/null`;
    chomp($apache_count);

    my $health_check = `/var/everything/tools/container-health-check.pl --debug-cloudwatch 2>&1`;

    # Memory analysis from /proc + the task cgroup. Per-process RSS overcounts
    # COW-shared pages (Starman --preload-app forks workers, so the interpreter +
    # preloaded app are counted once per worker), so the authoritative figure is the
    # cgroup total -- the only number that reflects the task's real memory budget
    # (and matches CloudWatch).
    my $memory_analysis = _get_app_memory();

    # In-webhead cron subsystem health: leader liveness + per-job state from the
    # cron_state/cron_leader tables, scored by Everything::Cron::Health. NB: the daily
    # generate-sitemap batch is NOT shown here -- it runs as a dedicated EventBridge
    # Fargate task (see CloudWatch /aws/fargate/fargate-cron-awslogs), not the sidecar.
    my $cron_status = _get_cron_status();

    return {
        type => 'server_telemetry',
        app_workers => $app_workers,
        worker_count => $worker_count,
        apache_count => $apache_count,
        health_check => $health_check,
        memory_analysis => $memory_analysis,
        cron_status => $cron_status
    };
}

# In-webhead cron health, formatted as a fixed-width status block. Reads the
# cron_state/cron_leader tables (Everything::Cron::State) and scores them with
# Everything::Cron::Health. eval-wrapped so a transient DB hiccup or a dev box
# without the cron tables degrades to a message instead of breaking the page.
sub _get_cron_status {
    my $out = eval {
        require Everything::Cron::State;
        require Everything::Cron::Health;
        require Everything::Cron::Schedule;

        my $schedule = Everything::Cron::Schedule->new;
        my $snapshot = Everything::Cron::State->new->snapshot;
        my $now      = time;
        my $verdict  = Everything::Cron::Health->new( schedule => $schedule )
            ->evaluate( $snapshot, $now );

        my @lines;
        push @lines, "Cron subsystem: " . uc( $verdict->{overall} // 'unknown' )
            . "  --  " . ( $verdict->{summary} // '' );

        my $ld = $verdict->{leader} || {};
        push @lines, sprintf( "Leader: %s  (%s, heartbeat %s)",
            $ld->{host} // '(none)',
            $ld->{state} // 'unknown',
            defined $ld->{age} ? _ago( $ld->{age} ) . " ago" : 'never' );
        push @lines, "";

        push @lines, sprintf( "%-22s %-9s %-12s %6s  %s",
            "JOB", "HEALTH", "LAST OK", "FAILS", "LAST RUN" );
        push @lines, "-" x 68;

        for my $entry ( @{ $schedule->entries } ) {
            my $name = $entry->{name};
            my $jv   = $verdict->{jobs}{$name} || {};
            my $js   = $snapshot->{jobs}{$name} || {};
            push @lines, sprintf( "%-22s %-9s %-12s %6d  %s",
                $name,
                uc( $jv->{state} // 'unknown' ),
                $js->{last_success} ? _ago( $now - $js->{last_success} ) . " ago" : 'never',
                $js->{consecutive_failures} || 0,
                defined $js->{duration_ms} ? sprintf( "%.1fs", $js->{duration_ms} / 1000 ) : '-' );
        }

        # Surface the captured output tail for anything wedged or failing.
        for my $name ( @{ $verdict->{wedged} || [] }, @{ $verdict->{failing} || [] } ) {
            my $tail = ( $snapshot->{jobs}{$name} || {} )->{last_output_tail};
            next unless defined $tail && length $tail;
            push @lines, "", "--- $name last output ---", $tail;
        }

        join( "\n", @lines );
    };
    return $out if defined $out && length $out;
    return "Cron status unavailable: " . ( $@ || 'unknown error' );
}

# Compact humanized age: 45s / 12m / 3h / 2d.
sub _ago {
    my ($secs) = @_;
    return 'now' if !defined $secs || $secs < 0;
    return "${secs}s" if $secs < 90;
    my $m = int( $secs / 60 );
    return "${m}m" if $m < 90;
    my $h = int( $m / 60 );
    return "${h}h" if $h < 48;
    return int( $h / 24 ) . "d";
}

sub _get_app_memory {
    my @results;
    my $total_rss = 0;

    # Get Starman master/worker PIDs (the PSGI app server -- where the app memory lives).
    my @pids = split /\n/, `pgrep -f 'starman'`;

    push @results, sprintf("%-8s %12s %12s  %s",
        "PID", "RSS (KB)", "VmSize (KB)", "Command");
    push @results, "-" x 60;

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

        # Only include actual Starman processes (master + workers) -- the cmdline
        # begins with "starman master"/"starman worker" (Starman rewrites $0); this
        # also excludes the bash supervisor loop whose args merely mention starman.
        next unless $cmdline =~ m{^starman}smx;
        next unless $mem{VmRSS};

        $cmdline = substr($cmdline, 0, 40) . '...' if length($cmdline) > 40;

        push @results, sprintf("%-8s %12d %12d  %s",
            $pid,
            $mem{VmRSS},
            $mem{VmSize} || 0,
            $cmdline || '(unknown)');
        $total_rss += $mem{VmRSS};
        $count++;
    }

    push @results, "-" x 60;
    push @results, sprintf(
        "Sum of RSS:  %.1f MB (%d procs) -- OVERCOUNTS: shared pages counted once per worker",
        $total_rss / 1024, $count);

    # Per-process PSS is intentionally not shown: the cgroup total below is the
    # authoritative real-RAM figure (COW-shared pages counted once), so a per-worker
    # PSS breakdown would add little over the RSS sum plus the cgroup truth.
    push @results, "(per-process PSS omitted -- the cgroup total below is the authoritative figure)";

    # Authoritative task memory from the cgroup. This is what the Fargate task
    # budget is measured against and what CloudWatch MemoryUtilization reports.
    my $cg = _get_cgroup_memory();
    if (defined $cg) {
        push @results, "";
        push @results, "Task memory (cgroup -- authoritative, matches CloudWatch):";
        push @results, $cg;
    }

    return join("\n", @results);
}

# Task memory from the cgroup (v2 preferred, v1 fallback). Returns a formatted
# multi-line string, or undef if no cgroup memory controller is readable.
sub _get_cgroup_memory {
    # cgroup v2
    if (-r '/sys/fs/cgroup/memory.current') {
        my $cur = _slurp_num('/sys/fs/cgroup/memory.current');
        return unless defined $cur;
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
        return unless defined $cur;
        my $max = _slurp_num('/sys/fs/cgroup/memory/memory.limit_in_bytes');
        my $line = sprintf("  used %.0f MB", $cur / 1048576);
        # v1 reports a huge sentinel (~2^63) when no limit is set
        if (defined $max && $max < 9_000_000_000_000_000_000) {
            $line .= sprintf(" / limit %.0f MB  (%.1f%%)",
                $max / 1048576, 100 * $cur / $max);
        }
        return $line;
    }
    return;
}

sub _slurp_raw {
    my ($f) = @_;
    open my $fh, '<', $f or return;
    my $v = <$fh>;
    close $fh;
    chomp $v if defined $v;
    return $v;
}

sub _slurp_num {
    my $v = _slurp_raw($_[0]);
    return unless defined $v && $v =~ /^\d+$/;
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
