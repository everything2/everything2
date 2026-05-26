# e2-readonly-query

AWS Lambda that runs read-only SQL queries against the Everything2 production
database. Built for ad-hoc audits — e.g., finding rows that would break under
the MySQL 8.4 migration.

## Architecture

- **Infra** (Lambda function, IAM role, security group, RDS SG ingress) lives
  in [cf/everything2-production.json](../../../cf/everything2-production.json).
  Deployed via the existing `tools/cf-deploy.rb production`.
- **Code** (`index.py` + `pymysql` bundled) is pushed separately via
  [`deploy-code.sh`](deploy-code.sh) using `aws lambda update-function-code`
  — direct API upload, no S3 round-trip, single-phase deploy.
- **DB password** is read from `s3://secrets.everything2.com/database_password_secret`
  — same channel the app uses (see `docker/e2app/apache2_wrapper.rb`). S3 has
  a free Gateway endpoint, so we avoid the ~$7/mo Interface endpoint that
  Secrets Manager would require. The Lambda runs as `everyuser` (the RDS
  master user), same as the app.
- **DB host/port** come from CFN `Fn::GetAtt` against the RDS instance, wired
  into the Lambda's env vars at deploy time.

## Safety perimeter

The Lambda is the only thing invokable here (IAM-authed, no public URL).
Within the handler, queries are filtered before they ever reach MySQL:

1. **One statement only** — `;`-separated batches rejected.
2. **Read-only commands** — only `SELECT`, `SHOW`, `EXPLAIN`, `DESCRIBE`, `DESC`.
3. **Banned constructs** — `INTO OUTFILE`, `INTO DUMPFILE`, `LOAD_FILE(`,
   `SLEEP(`, `BENCHMARK(`. (Most are also blocked by the absence of
   FILE/PROCESS privileges on `everyuser`, but defense in depth.)
4. **Auto-LIMIT** — bare `SELECT` queries get `LIMIT 1000` appended.
5. **Query timeout** — `SET SESSION MAX_EXECUTION_TIME = 25000` per invocation.
6. **Lambda timeout** — 30 seconds total.
7. **Response cap** — payloads truncated to ~5MB (Lambda's 6MB hard cap minus
   envelope). Truncation flag returned with the row count.
8. **Audit trail** — every query is logged to CloudWatch
   (`/aws/lambda/e2-readonly-query`) with elapsed ms and row count.

`everyuser` has full grants in production — meaning a handler bug *could* in
principle let a write through. The handler enforcement above is the second
guardrail; the operational practice of "only Jay can invoke this Lambda" is
the first.

## Deploy flow

### One-time setup

Deploy the CFN stack (creates Lambda, IAM role, security group, RDS SG
ingress, all with placeholder code):

```bash
./tools/cf-deploy.rb production
```

Then push the real code:

```bash
./tools/aws/readonly-query-lambda/deploy-code.sh
```

### Updating just the code

```bash
./tools/aws/readonly-query-lambda/deploy-code.sh
```

### Updating infra (env vars, IAM, timeout, etc.)

Edit `cf/everything2-production.json` and:

```bash
./tools/cf-deploy.rb diff production    # preview
./tools/cf-deploy.rb production         # apply
```

Note: code updates done via `deploy-code.sh` do **not** get reverted by future
CFN deploys. CFN only re-deploys a Lambda's `Code` property if the value in
the template changes, and the template only contains a tiny placeholder.

## Invocation

```bash
aws lambda invoke \
    --function-name e2-readonly-query \
    --payload '{"sql": "SELECT 1 AS ok"}' \
    --cli-binary-format raw-in-base64-out \
    /tmp/out.json && cat /tmp/out.json | jq
```

Response shape:
```json
{
  "rows": [{"ok": 1}],
  "rowCount": 1,
  "truncated": false,
  "queryTimeMs": 47
}
```

On error:
```json
{"error": "Rejected: Multiple statements not allowed"}
```

## MySQL 8.4 migration audit queries

The set below covers the main data-shaped concerns for the 8.0 → 8.4 jump.
Schema concerns are already covered by the dbtable XML in `nodepack/`; these
queries find *rows* that would break.

### Auth plugin holdouts (8.4 removes mysql_native_password)

```sql
SELECT user, host, plugin
FROM mysql.user
WHERE plugin != 'caching_sha2_password'
ORDER BY user;
```

### Columns with ON UPDATE CURRENT_TIMESTAMP (#4109-style bugs)

```sql
SELECT TABLE_NAME, COLUMN_NAME, EXTRA
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'everything'
  AND EXTRA LIKE '%on update CURRENT_TIMESTAMP%'
ORDER BY TABLE_NAME, COLUMN_NAME;
```

### utf8mb3 / utf8 columns (8.4 deprecates utf8mb3)

```sql
SELECT TABLE_NAME, COLUMN_NAME, CHARACTER_SET_NAME, COLLATION_NAME
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'everything'
  AND CHARACTER_SET_NAME IN ('utf8', 'utf8mb3')
ORDER BY TABLE_NAME;
```

### Zero-date rows (strict mode rejects these)

For any timestamp column you suspect, e.g.:
```sql
SELECT COUNT(*) AS bad_rows
FROM node
WHERE createtime = '0000-00-00 00:00:00';
```

To find candidate columns first:
```sql
SELECT TABLE_NAME, COLUMN_NAME, COLUMN_DEFAULT
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'everything'
  AND DATA_TYPE IN ('datetime', 'timestamp', 'date')
  AND (COLUMN_DEFAULT = '0000-00-00 00:00:00'
       OR COLUMN_DEFAULT = '0000-00-00');
```

### Reserved-word collisions in column names (8.4 adds keywords)

```sql
SELECT TABLE_NAME, COLUMN_NAME
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'everything'
  AND UPPER(COLUMN_NAME) IN (
    'RANK', 'SYSTEM', 'WINDOW', 'GROUPS', 'RECURSIVE',
    'CUBE', 'ROW', 'ROWS', 'EXCEPT', 'JSON_TABLE'
  );
```

### Largest tables (sizing for the migration window)

```sql
SELECT TABLE_NAME,
       TABLE_ROWS,
       ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024) AS size_mb
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'everything'
ORDER BY (DATA_LENGTH + INDEX_LENGTH) DESC
LIMIT 30;
```

## Operational notes

- **Cold start**: ~1-2s for a VPC-attached Lambda. Subsequent invocations
  within ~10 minutes reuse the container.
- **Cost**: free tier covers many invocations per month. At 256MB memory,
  each invocation costs fractions of a cent.
- **Reverting**: `aws lambda delete-function --function-name e2-readonly-query`
  removes the function but **not** the CFN-managed role/SG (those have
  `DeletionPolicy: Retain`). To remove the lot, edit `cf/everything2-production.json`
  to drop the four `ReadonlyQuery*` and `MainDBSecurityGroupReadonlyQueryIngress`
  resources, then deploy.

## Files

| File | Purpose |
|---|---|
| `index.py` | The Lambda function code (filename matches AWS Lambda convention — CFN inline ZipFile also lands as `index.py`, so the handler config stays `index.handler` whether code is placeholder or real) |
| `deploy-code.sh` | Build zip, upload to Lambda via API |
| `README.md` | This file |
| `.gitignore` | Skip build artifacts |
