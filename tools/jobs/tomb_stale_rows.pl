#!/usr/bin/perl
#
# tomb_stale_rows.pl -- ONE-OFF cleanup (#4715). Prunes tomb rows that belong to live nodes.
#
# Old resurrections left the tomb row behind, so a few live nodes still have a tomb copy from
# an earlier deletion. The live node is the newer version; tombstoneNode now replaces such a
# copy when the node is deleted again, so these rows are only out-of-date history.
#
# A row is pruned only once it's validated as an older copy of the live node:
#   - the live node has the same type and createtime (the same node, not a reused id), and
#   - where both have an edittime, the live node's is no older than the copy's.
# Anything that doesn't validate is listed with the reason and left alone.
#
# Runs via the maintenance-job facility (cron/run_s3_job.pl; see docs/maintenance-jobs.md):
#   tools/aws/run-fargate-job.sh tools/jobs/tomb_stale_rows.pl              # dry run: lists them
#   tools/aws/run-fargate-job.sh tools/jobs/tomb_stale_rows.pl E2_APPLY=1   # prunes them
#
# Env:
#   E2_APPLY=1        delete the validated rows (otherwise a dry run that changes nothing)
#   E2_TOMB_ONLY=a,b  limit to these node_ids
#
# Stored contents are never printed. Running it again finds nothing to prune.
#
use strict;
use warnings;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5);
use Everything;
use Everything::Serialization qw(safe_deserialize_dumper);

initEverything 'everything';

my $apply = $ENV{E2_APPLY} ? 1 : 0;
my @only  = grep { /\A\d+\z/ } split /\s*,\s*/, ($ENV{E2_TOMB_ONLY} // '');
die "[tomb_stale_rows] E2_TOMB_ONLY must be a comma-separated list of node ids\n"
  if length($ENV{E2_TOMB_ONLY} // '') && !@only;

my $dbh = $DB->getDatabaseHandle();
local $dbh->{RaiseError} = 1;
local $dbh->{PrintError} = 0;

my $limit = @only ? ' AND t.node_id IN (' . join(',', map { int } @only) . ')' : '';
my $rows  = $dbh->selectall_arrayref(
  "SELECT t.node_id, t.type_nodetype AS tomb_type, n.type_nodetype AS live_type,
          lt.title AS live_type_title, t.killa_user,
          t.createtime AS tomb_created, n.createtime AS live_created,
          d.edittime AS live_edited, t.data
     FROM tomb t
     JOIN node n ON n.node_id = t.node_id
     LEFT JOIN node lt ON lt.node_id = n.type_nodetype AND lt.type_nodetype = 1
     LEFT JOIN document d ON d.document_id = n.node_id
    WHERE 1=1 $limit
    ORDER BY t.node_id",
  { Slice => {} }
);

my (@prune, @keep);
for my $r (@$rows) {
  my $copy = safe_deserialize_dumper('my ' . ($r->{data} // '')) || {};
  my $copy_edited = ref $copy eq 'HASH' ? $copy->{edittime} : undef;
  delete $r->{data};

  my @problems;
  push @problems, 'the live node has a different type' if $r->{tomb_type} != $r->{live_type};
  push @problems, 'the live node has a different createtime'
    if ($r->{tomb_created} // '') ne ($r->{live_created} // '');
  push @problems, "the copy's edittime ($copy_edited) is newer than the live node's ($r->{live_edited})"
    if defined $copy_edited && defined $r->{live_edited} && $copy_edited gt $r->{live_edited};

  my $type = defined $r->{live_type_title} ? $r->{live_type_title} : "type $r->{live_type}, which no longer exists";
  my $line = sprintf 'node %d (%s, created %s, deleted by %d)',
    $r->{node_id}, $type, $r->{live_created} // '?', $r->{killa_user};

  if (@problems) {
    push @keep, $r;
    print "[tomb_stale_rows] keep  $line: " . join('; ', @problems) . "\n";
  } else {
    push @prune, $r;
    print "[tomb_stale_rows] prune $line: older copy of the live node\n";
  }
}

printf "[tomb_stale_rows] %d tomb row(s) of live nodes: %d to prune, %d kept%s\n",
  scalar(@$rows), scalar(@prune), scalar(@keep), $apply ? '' : ' (dry run: nothing deleted)';

exit 0 unless $apply;

my $pruned = 0;
for my $r (@prune) {
  my $id = int $r->{node_id};
  # Only while the node is still alive.
  my $deleted = $dbh->do(
    'DELETE FROM tomb WHERE node_id = ? AND EXISTS (SELECT 1 FROM node n WHERE n.node_id = ?)',
    undef, $id, $id);
  if ($deleted == 1) {
    $pruned++;
  } else {
    print "[tomb_stale_rows] node $id: not pruned (its live node is gone)\n";
  }
}

printf "[tomb_stale_rows] pruned %d of %d\n", $pruned, scalar(@prune);
exit($pruned == @prune ? 0 : 1);
