# One-off maintenance jobs (Fargate + single S3 bucket)

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
  bucket, `aws ecs run-task`s the e2app task def with a command override + env, in the
  service's subnets/SGs, then waits + reports the exit code.

## Usage
```bash
tools/aws/run-fargate-job.sh tools/jobs/some_job.pl FOO=bar
# -> s3://e2-maintenance-jobs/jobs/<ts>-some_job.pl, runs it in a Fargate task,
#    output in the e2app CloudWatch log group.
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
`E2AppS3Policy` managed policy (the e2app task role). **Deploy the prod stack** to create
them.

**The PutObject perimeter:** no service role is granted `s3:PutObject`, so only IAM
principals with broad S3 access (admins, via the launcher's own credentials) can upload
job scripts — that's the control, matching the single-bucket model. For a hard lock you
can optionally add a bucket policy denying `PutObject` except from a named admin role ARN.

## First job: `tools/jobs/seclog_time_repair.pl`
Restores `seclog.seclog_time` from a PITR copy after the phase-3 backfill re-stamped it
(see `docs/seclog-time-repair.md` for the restore mechanics). Because the task is
in-VPC, one script reaches both prod and the restored instance:
```bash
# 1. (out of band) PITR-restore everything2vpc to 2026-06-13T17:58Z as a temp instance.
# 2. dry-run, then real:
tools/aws/run-fargate-job.sh tools/jobs/seclog_time_repair.pl E2_TSFIX_HOST=<endpoint> E2_DRYRUN=1
tools/aws/run-fargate-job.sh tools/jobs/seclog_time_repair.pl E2_TSFIX_HOST=<endpoint>
# 3. (out of band) delete the temp instance.
```
