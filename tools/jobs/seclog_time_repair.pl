#!/usr/bin/perl
#
# seclog_time_repair.pl -- ONE-OFF (#4280 / #4283). Restore seclog.seclog_time from a
# pre-backfill PITR copy after the phase-3 backfill re-stamped it.
#
# Runs via the maintenance-job facility (cron/run_s3_job.pl) so it executes inside the
# VPC and reaches BOTH prod ($DB) and the temporary restored instance:
#   run-fargate-job.sh tools/jobs/seclog_time_repair.pl \
#     E2_TSFIX_HOST=<restored-endpoint> [E2_DRYRUN=1] [E2_BATCH=200000]
#
# Prereqs: prod seclog_time already had ON UPDATE CURRENT_TIMESTAMP removed; a PITR
# restore to ~2026-06-13T17:58Z exists (endpoint -> E2_TSFIX_HOST; same creds as prod).
#
# Strategy: stream (seclog_id, seclog_time) from the restore into a prod staging table,
# then set-based UPDATE prod by PK range (fast -- avoids 2M per-row updates). Idempotent
# (only updates where the time differs; the staging table is rebuilt each run).
#
use strict;
use warnings;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5);
use Everything;
use DBI;

initEverything 'everything';

my $tsfix = $ENV{E2_TSFIX_HOST} or die "E2_TSFIX_HOST (restored-instance endpoint) is required\n";
my $batch = int( $ENV{E2_BATCH} || 200000 );
my $dry   = $ENV{E2_DRYRUN} ? 1 : 0;

my ( $user, $pass, $port ) =
  ( $Everything::CONF->everyuser, $Everything::CONF->everypass, $Everything::CONF->everything_dbport );

my $prod = $DB->getDatabaseHandle();
my $rest = DBI->connect(
  "DBI:mysql:database=everything;host=$tsfix;port=$port;mysql_ssl=1;mysql_get_server_pubkey=1",
  $user, $pass, { RaiseError => 1, AutoCommit => 1, mysql_enable_utf8mb4 => 1 }
) or die "cannot connect to restore host $tsfix: $DBI::errstr\n";

# Fast preflight: range + count + the restore's oldest timestamp (must be ~2002).
my ( $lo, $max, $cnt ) =
  $rest->selectrow_array("SELECT MIN(seclog_id), MAX(seclog_id), COUNT(*) FROM seclog");
defined $lo or die "restore host has no seclog rows -- wrong instance?\n";
my ($r_oldest) = $rest->selectrow_array("SELECT seclog_time FROM seclog ORDER BY seclog_id ASC LIMIT 1");
printf "[seclog_repair] restore ids %d..%d rows=%d oldest_time=%s (expect ~2002, NOT 2026-06-13) batch=%d dryrun=%d\n",
  $lo, $max, $cnt, ( $r_oldest // 'NULL' ), $batch, $dry;

if ($dry) {
  my ($p_oldest) = $prod->selectrow_array("SELECT seclog_time FROM seclog ORDER BY seclog_id ASC LIMIT 1");
  printf "[seclog_repair] DRY RUN: would restore %d rows. prod oldest seclog_time now: %s\n",
    $cnt, ( $p_oldest // 'NULL' );
  exit 0;
}

# --- real run: stage from restore, then set-based UPDATE on prod ----------------
$prod->do("DROP TABLE IF EXISTS seclog_time_restore");
$prod->do("CREATE TABLE seclog_time_restore (seclog_id INT PRIMARY KEY, seclog_time TIMESTAMP NULL)");

my $staged = 0;
for ( my $start = $lo ; $start <= $max ; $start += $batch ) {
  my $end  = $start + $batch - 1;
  my $rows = $rest->selectall_arrayref(
    "SELECT seclog_id, seclog_time FROM seclog WHERE seclog_id BETWEEN $start AND $end");
  next unless @$rows;
  $prod->begin_work;
  my $CH = 1000;    # multi-row INSERT chunk
  for ( my $i = 0 ; $i < @$rows ; $i += $CH ) {
    my $j = $i + $CH - 1; $j = $#$rows if $j > $#$rows;
    my @slice = @{$rows}[ $i .. $j ];
    my $ph    = join( ",", ("(?,?)") x scalar(@slice) );
    $prod->do( "INSERT INTO seclog_time_restore (seclog_id, seclog_time) VALUES $ph",
      undef, map { @$_ } @slice );
  }
  $prod->commit;
  $staged += @$rows;
  printf "[seclog_repair] staged %d..%d : %d (total %d)\n", $start, $end, scalar(@$rows), $staged;
}

my $fixed = 0;
for ( my $start = $lo ; $start <= $max ; $start += $batch ) {
  my $end = $start + $batch - 1;
  my $n   = $prod->do(
    "UPDATE seclog s JOIN seclog_time_restore r ON s.seclog_id=r.seclog_id
       SET s.seclog_time=r.seclog_time
     WHERE s.seclog_id BETWEEN $start AND $end AND s.seclog_time<>r.seclog_time");
  $n = 0 if !$n || $n eq '0E0';
  $fixed += $n;
  printf "[seclog_repair] fixed %d..%d : %d (total %d)\n", $start, $end, $n, $fixed;
}

$prod->do("DROP TABLE seclog_time_restore");

my ($oldest) = $prod->selectrow_array("SELECT seclog_time FROM seclog ORDER BY seclog_id ASC LIMIT 1");
printf "[seclog_repair] done. staged=%d fixed=%d. prod oldest seclog_time now: %s\n",
  $staged, $fixed, ( $oldest // 'NULL' );
