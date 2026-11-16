#!/usr/bin/perl -w
#
# One-time migration of pre-salt password storage. Everything::PasswordMigration has the
# details; this is the command line (and what the ECS task runs).
#
use strict;
use warnings;
use lib qw(/var/everything/ecore);
use lib qw(/var/libraries/lib/perl5);
use Getopt::Long;
use Everything;
use Everything::PasswordMigration;

my %opt = (batch_size => 500, pause => 0.2, limit => 0);
GetOptions(
  'apply'        => \$opt{apply},
  'batch-size=i' => \$opt{batch_size},
  'pause=f'      => \$opt{pause},
  'limit=i'      => \$opt{limit},
  'ids=s'        => \$opt{ids},
  'help'         => \$opt{help},
) or usage(2);
usage(0) if $opt{help};

sub usage {
  print <<'USAGE';
Usage: migrate_legacy_passwords.pl [--apply] [--batch-size N] [--pause SECONDS] [--limit N] [--ids 1,2,3]

Migrates accounts whose password predates salting (user.salt empty or NULL). Without --apply
it only reports what it would do. Safe to stop and rerun: migrated accounts aren't selected
again.

  --apply          write the changes (default: dry run)
  --batch-size N   rows per batch / transaction (default 500)
  --pause SECONDS  pause between batches (default 0.2)
  --limit N        stop after N rows (a trial run)
  --ids 1,2,3      only these user_ids (testing)

Prints one "MIGRATION {json}" line per batch and a final status=done line with remaining=0
when everything is migrated. Exit status: 0 done, 1 error (that batch was rolled back).
USAGE
  exit $_[0];
}

initEverything 'everything';
local $| = 1;

my $result = Everything::PasswordMigration->new(
  apply      => $opt{apply},
  batch_size => $opt{batch_size},
  pause      => $opt{pause},
  limit      => $opt{limit},
  ids        => $opt{ids} ? [ split /\s*,\s*/, $opt{ids} ] : undef,
)->run;

exit($result->{ok} ? 0 : 1);
