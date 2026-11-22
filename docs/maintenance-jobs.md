# One-off maintenance jobs (Fargate + single S3 bucket)

**Last verified:** 2026-11-21

Some maintenance has to run **inside the VPC** (to reach RDS) but we have no direct VPC
access. This facility (#4282) runs a script inside a one-off Fargate task using the
deployed **e2app** image — so the job gets Perl, `$DB`, `Everything::S3`, the ECS task
role, and the same network as the app (RDS-reachable), with no infra changes.

## Shape
- **`cron/run_s3_job.pl`** — the in-container entrypoint. Pulls a script from the
  **single** `CONF->s3->{jobs}` bucket by `E2_JOB_S3_KEY`, logs `key + sha256`, execs
  it (perl/bash per shebang), exits with its status. It only ever reads from that one
  bucket — never a caller-supplied location.
- **`CONF->s3->{jobs}`** — the one bucket (`e2-maintenance-jobs`).
- **`tools/aws/run-fargate-job.sh <script> [KEY=VAL ...]`** — uploads the script to the
  bucket, `aws ecs run-task`s the `e2app-family` task def with a command override + env, in
  the service's subnets/SGs, then polls until the task stops (up to `E2_JOB_TIMEOUT`,
  default 5400 s) and reports the exit code. Override cluster/service/task def/bucket with
  `E2_CLUSTER`, `E2_SERVICE`, `E2_TASKDEF`, `E2_JOBS_BUCKET`.

For running an existing `cron/*.pl` script on demand, use `ops/cron-runner.rb --job <name>`
instead (see [cron-sidecar.md](cron-sidecar.md)). Long jobs already in the repo (`jobs/`) run
on `e2heavyjob-family`.

## Usage
```bash
tools/aws/run-fargate-job.sh path/to/some_job.pl FOO=bar
# -> s3://e2-maintenance-jobs/jobs/<ts>-some_job.pl, runs it in a Fargate task,
#    output in /aws/fargate/fargate-app-awslogs, stream e2-fargate/e2app/<task-id>.
```
A job script just needs `use lib qw(/var/everything/ecore /var/libraries/lib/perl5); use Everything; initEverything 'everything';` to get `$DB`/`$APP`, then do its work.

## Security model — the bucket IS the perimeter
`run_s3_job.pl` runs **arbitrary code with full DB + AWS (task-role) access**. There is
no handler-side validation (unlike the read-only-query lambda) — the control is **who
can write to the one bucket**:
- **Lock `s3:PutObject` on `e2-maintenance-jobs` to admins only.** That gate is the
  entire security boundary; treat bucket-write like prod shell access.
- The **e2app task role** gets **`s3:GetObject` only** on that bucket.
- Every run logs the key + sha256 it executed (audit trail in CloudWatch).
- Single bucket by design, so the blast radius is one controllable place.

## Infra (in CloudFormation — `cf/everything2-production.json`)
Provisioned as code: `MaintenanceJobsBucket` (`e2-maintenance-jobs` — versioned, public
access blocked, 90-day expiry) plus a read-only `s3:GetObject` grant on it in the
`E2AppS3Policy` managed policy (the e2app task role). Both are deployed.

**The PutObject perimeter:** no service role is granted `s3:PutObject`, so only IAM
principals with broad S3 access (admins, via the launcher's own credentials) can upload
job scripts — that's the control, matching the single-bucket model. For a hard lock you
can optionally add a bucket policy denying `PutObject` except from a named admin role ARN.

## Past jobs

The first job was `tools/jobs/seclog_time_repair.pl` (restored `seclog.seclog_time` from a
PITR copy). It ran once and was removed with the seclog retirement. See
`git log --all -- tools/jobs/seclog_time_repair.pl` for it as an example of the pattern (one
in-VPC script reaching both prod and a temporary restored instance).

## Current jobs

- **`tools/jobs/tomb_stale_rows.pl`** (#4715) prunes tomb rows that belong to live nodes
  (left behind by old resurrections). A row is deleted only once it's validated as an older
  copy of the live node: same type and createtime, and where both have an edittime, the live
  node's is no older. Rows that don't validate are listed with the reason and left alone. It
  does a dry run that only lists them unless `E2_APPLY=1`; `E2_TOMB_ONLY=<ids>` limits it to
  particular nodes. It never prints stored contents, and running it again finds nothing.
  Covered by `t/236_tomb_stale_rows.t`.
- **`tools/jobs/tomb_strip_credentials.pl`** (#4716, #4724, #4726) removes credentials (`passwd`, `salt`,
  `user_salt`, `validationkey`, `session_id`: NodeBase `%TOMB_NEVER_STORES`) from the tomb
  copies of deleted accounts written before tombstoneNode stopped storing them, along with the
  `_ORIGINAL_VALUES` snapshot some old copies hold (`@TOMB_NEVER_STORES_ANY`), which carries its own
  copy of them. Each copy is written back only after it reads back as exactly the original minus
  those keys; a copy that would still hold a credential field anywhere in its nested data is
  reported and left alone. The email address stays, since a resurrected account resets its
  password by email. Dry run unless
  `E2_APPLY=1`; `E2_TOMB_ONLY=<ids>` limits it. Prints only field names and counts. Covered by
  `t/237_tomb_credentials.t`.
