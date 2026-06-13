#!/usr/bin/perl
#
# run_s3_job.pl -- one-off maintenance runner (#4282).
#
# Fetches a script from the SINGLE locked-down "jobs" S3 bucket (CONF->s3->{jobs}) by
# key and executes it inside a Fargate task -- in-VPC, with the DB ($DB) and the ECS
# task role available. This is how we run maintenance that must reach RDS when we have
# no direct VPC access (e.g. the seclog_time PITR repair).
#
# The security perimeter is *write* access to that one bucket: this runner only ever
# reads from CONF->s3->{jobs}, never a caller-supplied bucket. Lock s3:PutObject on the
# bucket to admins; the task role gets read-only. Every run logs the key + sha256.
#
# Launched by tools/aws/run-fargate-job.sh via `aws ecs run-task` with a command
# override. All output -> stdout/stderr -> the e2app CloudWatch log group.
#
# Env:
#   E2_JOB_S3_KEY   object key within the jobs bucket (required)
#
use strict;
use warnings;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5);
use Everything;
use Everything::S3;
use Digest::SHA qw(sha256_hex);

initEverything 'everything';

my $key = $ENV{E2_JOB_S3_KEY}
  or die "[run_s3_job] E2_JOB_S3_KEY is required\n";

# Bucket is fixed to CONF->s3->{jobs}; the caller only chooses the key.
my $s3 = Everything::S3->new('jobs')
  or die "[run_s3_job] the 'jobs' S3 bucket is not configured (CONF->s3->{jobs})\n";

my $body = $s3->get_key($key);
defined($body) && length("$body")
  or die "[run_s3_job] could not fetch '$key' from the jobs bucket\n";
$body = "$body";    # Paws Body -> scalar

printf STDERR "[run_s3_job] key=%s bytes=%d sha256=%s\n", $key, length($body), sha256_hex($body);

# Pick the interpreter from the script's shebang; default to perl. Only perl/bash.
my $interp = '/usr/bin/perl';
if ($body =~ m{\A\#!\s*(\S+)}) {
  $interp = '/bin/bash' if $1 =~ m{/(?:ba)?sh$};
}
my $ext  = ($interp =~ /perl/) ? 'pl' : 'sh';
my $path = "/tmp/e2job.$$.$ext";

open(my $fh, '>', $path) or die "[run_s3_job] cannot write $path: $!\n";
print $fh $body;
close $fh;
chmod 0700, $path;

print STDERR "[run_s3_job] exec $interp $path\n";
my $rc = system($interp, $path);
unlink $path;

my $exit = $rc == -1 ? 127 : ($rc >> 8);
printf STDERR "[run_s3_job] key=%s exit=%d\n", $key, $exit;
exit $exit;
