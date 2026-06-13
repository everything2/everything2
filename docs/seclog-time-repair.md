# seclog_time repair runbook (one-time)

The phase-3 backfill `UPDATE`s re-stamped `seclog.seclog_time` on ~2.07M rows because the column
had `ON UPDATE CURRENT_TIMESTAMP` (now removed in prod). `seclog_event` / `seclog_subject` are
correct; only `seclog_time` needs restoring from a pre-backfill copy.

- **Backfill window (what to restore *before*):** first `UPDATE` ran **2026-06-13 17:59:57 UTC**,
  rest through ~18:05. Restore to **17:58:00 UTC**.
- **Damaged rows:** everything created before 17:59:57 (`seclog_id` up to the backfill point).
- **Untouched:** rows written after the backfill (event>0, `seclog_node=0`) keep their real time.

## 1. Restore a pre-backfill copy (PITR — captures the 11:22→17:59 rows too)
```bash
aws rds restore-db-instance-to-point-in-time --region us-west-2 \
  --source-db-instance-identifier everything2vpc \
  --target-db-instance-identifier everything2vpc-tsfix \
  --restore-time 2026-06-13T17:58:00Z \
  --db-instance-class db.t4g.medium \
  --db-subnet-group-name e2-app-db-subnet-group \
  --vpc-security-group-ids sg-07d9b94306c2b530d sg-06c7e5b18dcb7709c \
  --no-publicly-accessible --no-multi-az
# (daily-snapshot alternative -- misses 11:22->17:59 rows:)
# aws rds restore-db-instance-from-db-snapshot --db-snapshot-identifier rds:everything2vpc-2026-06-13-11-22 ...

aws rds wait db-instance-available --db-instance-identifier everything2vpc-tsfix --region us-west-2
aws rds describe-db-instances --db-instance-identifier everything2vpc-tsfix --region us-west-2 \
  --query 'DBInstances[0].Endpoint.Address' --output text   # -> $TSFIX
```

## 2. Extract (seclog_id, seclog_time) — run from inside the VPC
```bash
mysql -h "$TSFIX" -u everyuser -p everything -B -N \
  -e "SELECT seclog_id, seclog_time FROM seclog" > seclog_time.tsv   # ~2M rows, ~40MB
```

## 3. Stage + load on PROD
```sql
CREATE TABLE seclog_time_restore (seclog_id INT PRIMARY KEY, seclog_time TIMESTAMP NULL);
```
```bash
mysql -h "$PROD" -u everyuser -p --local-infile=1 everything \
  -e "LOAD DATA LOCAL INFILE 'seclog_time.tsv' INTO TABLE seclog_time_restore (seclog_id, seclog_time)"
```

## 4. Repair, batched by PK (off-peak). ON UPDATE is already removed, so this won't re-stamp.
```bash
PROD=<prod-endpoint>
MAX=$(mysql -h "$PROD" -u everyuser -p -N everything -e "SELECT MAX(seclog_id) FROM seclog_time_restore")
LO=1; STEP=100000
while [ "$LO" -le "$MAX" ]; do
  HI=$((LO+STEP-1))
  mysql -h "$PROD" -u everyuser -p everything -e \
    "UPDATE seclog s JOIN seclog_time_restore r ON s.seclog_id=r.seclog_id
       SET s.seclog_time=r.seclog_time
     WHERE s.seclog_id BETWEEN $LO AND $HI AND s.seclog_time<>r.seclog_time"
  echo "batch $LO-$HI"; LO=$((HI+1)); sleep 1
done
```
Rows absent from `seclog_time_restore` (created after the restore point) are left alone.

## 5. Verify
```sql
SELECT seclog_id, seclog_time FROM seclog ORDER BY seclog_id ASC LIMIT 5;     -- back to ~2002, not 2026-06-13
SELECT seclog_id, seclog_time FROM seclog WHERE seclog_id IN (1,500000,2000000);  -- spread spot-check
```
(I can run these via the read-only lambda once the repair is done.)

## 6. Teardown
```sql
DROP TABLE seclog_time_restore;
```
```bash
aws rds delete-db-instance --db-instance-identifier everything2vpc-tsfix \
  --skip-final-snapshot --delete-automated-backups --region us-west-2
```
