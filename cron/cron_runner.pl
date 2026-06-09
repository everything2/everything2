#!/usr/bin/perl

# cron_runner.pl -- the in-webhead cron sidecar entry point. Spawned (supervised)
# by docker/e2app/apache2_wrapper.rb next to the Starman supervisor; runs forever,
# contends for cron leadership via GET_LOCK, and drives the schedule. See
# docs/cron-sidecar-design.md and Everything::Cron::Runner.
#
# Usage:
#   cron_runner.pl              # normal: the leader runs due jobs
#   cron_runner.pl --dry-run    # shadow mode: elect + heartbeat, but only LOG
#                               # "would run X" instead of running -- used to
#                               # verify leadership/failover before cutover.

use strict;
use warnings;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5);
use Getopt::Long;
use Everything;
use Everything::Cron::Runner;

initEverything 'everything';

my $dry_run = 0;
GetOptions( 'dry-run' => \$dry_run );

# One pass and exit -- the supervised loop (or crond) re-invokes us each minute.
# E2_CRON_JITTER (seconds) spreads multiple webheads' attempts; 0/unset = no jitter.
Everything::Cron::Runner->new(
    dry_run    => $dry_run,
    jitter_max => ( $ENV{E2_CRON_JITTER} || 0 ),
)->run_once;
