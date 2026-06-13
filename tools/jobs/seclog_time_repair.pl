#!/usr/bin/perl
#
# seclog_time_repair.pl -- ONE-OFF (#4280). Restore seclog.seclog_time from a
# pre-backfill PITR copy after the phase-3 backfill re-stamped it.
#
# Run via the maintenance-job facility so it executes inside the VPC and can reach
# BOTH prod ($DB) and the temporary restored instance:
#   tools/aws/run-fargate-job.sh tools/jobs/seclog_time_repair.pl \
#     E2_TSFIX_HOST=<restored-endpoint> [E2_DRYRUN=1] [E2_BATCH=100000]
#
# Prereqs (out of band):
#   - prod seclog_time already had ON UPDATE CURRENT_TIMESTAMP removed (else this
#     UPDATE would re-stamp it again).
#   - a PITR restore of everything2vpc to ~2026-06-13T17:58Z exists; pass its endpoint
#     as E2_TSFIX_HOST. The restore shares prod's creds.
#
use strict;
use warnings;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5);
use Everything;
use DBI;

initEverything 'everything';

my $tsfix = $ENV{E2_TSFIX_HOST} or die "E2_TSFIX_HOST (restored-instance endpoint) is required\n";
my $batch = int( $ENV{E2_BATCH} || 100000 );
my $dry   = $ENV{E2_DRYRUN} ? 1 : 0;

# The restore is the same database -- reuse prod's creds.
my ( $user, $pass, $port ) =
  ( $Everything::CONF->everyuser, $Everything::CONF->everypass, $Everything::CONF->everything_dbport );

my $prod = $DB->getDatabaseHandle();
my $rest = DBI->connect(
  "DBI:mysql:database=everything;host=$tsfix;port=$port;mysql_ssl=1;mysql_get_server_pubkey=1",
  $user, $pass,
  { RaiseError => 1, AutoCommit => 1, mysql_enable_utf8mb4 => 1 }
) or die "cannot connect to restore host $tsfix: $DBI::errstr\n";

my ( $lo, $max ) = $rest->selectrow_array("SELECT MIN(seclog_id), MAX(seclog_id) FROM seclog");
defined $lo or die "restore host has no seclog rows -- wrong instance?\n";
printf "[seclog_repair] restore ids %d..%d  batch=%d  dryrun=%d\n", $lo, $max, $batch, $dry;

my $sel = $rest->prepare("SELECT seclog_id, seclog_time FROM seclog WHERE seclog_id BETWEEN ? AND ?");
my $upd = $prod->prepare("UPDATE seclog SET seclog_time=? WHERE seclog_id=? AND seclog_time<>?");

my $fixed = 0;
for ( my $start = $lo ; $start <= $max ; $start += $batch ) {
  my $end = $start + $batch - 1;
  $sel->execute( $start, $end );
  my $rows = $sel->fetchall_arrayref;

  my $n = 0;
  if ($dry) {
    $n = scalar @$rows;    # upper bound; doesn't check current value
  }
  else {
    $prod->begin_work;
    for my $r (@$rows) { $n += $upd->execute( $r->[1], $r->[0], $r->[1] ); }
    $prod->commit;
  }
  $fixed += $n;
  printf "[seclog_repair] ids %d..%d : %d %s (total %d)\n",
    $start, $end, $n, ( $dry ? 'candidates' : 'fixed' ), $fixed;
}

my ($oldest) = $prod->selectrow_array("SELECT seclog_time FROM seclog ORDER BY seclog_id ASC LIMIT 1");
printf "[seclog_repair] done. %s=%d. oldest seclog_time now: %s\n",
  ( $dry ? 'candidates' : 'fixed' ), $fixed, ( $oldest // 'NULL' );
