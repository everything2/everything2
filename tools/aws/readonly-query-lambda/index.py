"""
e2-readonly-query: AWS Lambda for ad-hoc read-only SQL queries against the
Everything2 production database. Designed for schema/data audits — finding
rows that would break under the MySQL 8.4 migration, etc.

Reads the DB password from S3 (`secrets.everything2.com/database_password_secret`),
matching the application's own bootstrap pattern in docker/e2app/apache2_wrapper.rb.
The S3 gateway endpoint is free; using Secrets Manager would have required a
~$7/mo Interface endpoint, so we mirror what the app already does.

DB host / port / user / name come from env vars (host is wired via CFN
Fn::GetAtt against the RDS instance, so it tracks the instance automatically).

Invoke:
    aws lambda invoke \\
        --function-name e2-readonly-query \\
        --payload '{"sql": "SELECT user, host, plugin FROM mysql.user LIMIT 50"}' \\
        --cli-binary-format raw-in-base64-out \\
        /tmp/out.json

Safety perimeter (handler-side, defense in depth on top of grant scope):
  - one statement only (no `;`-batches)
  - SELECT/SHOW/EXPLAIN/DESCRIBE/DESC only
  - banned constructs: INTO OUTFILE/DUMPFILE, LOAD_FILE(, SLEEP(, BENCHMARK(
  - bare SELECTs get LIMIT 1000 appended
  - session MAX_EXECUTION_TIME = 25s
  - response capped at ~5MB (Lambda limit is 6MB), truncation flag returned
"""

import base64
import datetime
import decimal
import json
import os
import re
import ssl
import time

import boto3
import pymysql

_S3 = boto3.client("s3")

# Where the DB password lives. Matches the app's bootstrap pattern —
# secrets.everything2.com bucket, raw-text object (no JSON wrapping).
_PASSWORD_BUCKET = os.environ["DB_PASSWORD_BUCKET"]
_PASSWORD_KEY = os.environ["DB_PASSWORD_KEY"]

_DB_HOST = os.environ["DB_HOST"]
_DB_PORT = int(os.environ.get("DB_PORT", "3306"))
_DB_NAME = os.environ.get("DB_NAME", "everything")
_DB_USER = os.environ.get("DB_USER", "everyuser")

# TLS context for the RDS connection. caching_sha2_password requires a secure
# transport to send credentials, so enabling TLS here lets the Lambda authenticate
# against a caching_sha2 user (e.g. everyuser2) without depending on the RSA-pubkey
# path (the `cryptography` package). We encrypt but don't verify the server cert --
# the goal is a secure channel to satisfy caching_sha2, not identity verification. (#4217)
_SSL_CTX = ssl.create_default_context()
_SSL_CTX.check_hostname = False
_SSL_CTX.verify_mode = ssl.CERT_NONE

# Cached at cold start; warm invocations skip the S3 GET.
_DB_PASSWORD = None

# Lambda response payload is hard-capped at 6MB by AWS. Leave headroom for
# the JSON envelope (rowCount, truncated, queryTimeMs, error fields).
_MAX_PAYLOAD_BYTES = 5 * 1024 * 1024

# Default LIMIT applied when a SELECT has no explicit LIMIT clause.
_DEFAULT_LIMIT = 1000

_ALLOWED_COMMANDS = ("SELECT", "SHOW", "EXPLAIN", "DESCRIBE", "DESC")

# Constructs we never want to see in a query, even though grants block most.
_BANNED_PATTERNS = (
    r"\bINTO\s+OUTFILE\b",
    r"\bINTO\s+DUMPFILE\b",
    r"\bLOAD_FILE\s*\(",
    r"\bSLEEP\s*\(",          # cheap denial of service against ourselves
    r"\bBENCHMARK\s*\(",      # same
)


def _get_db_password():
    """Load DB password from S3; cached for warm invocations."""
    global _DB_PASSWORD
    if _DB_PASSWORD is not None:
        return _DB_PASSWORD
    obj = _S3.get_object(Bucket=_PASSWORD_BUCKET, Key=_PASSWORD_KEY)
    _DB_PASSWORD = obj["Body"].read().decode("utf-8").strip()
    return _DB_PASSWORD


def _validate(sql):
    """Return normalized SQL or raise ValueError."""
    sql = (sql or "").strip().rstrip(";").strip()
    if not sql:
        raise ValueError("Empty query")

    # Single statement — one trailing semicolon was already stripped above.
    if ";" in sql:
        raise ValueError("Multiple statements not allowed")

    upper = sql.upper()
    cmd = upper.split(None, 1)[0]
    if cmd not in _ALLOWED_COMMANDS:
        raise ValueError(
            f"Only {', '.join(_ALLOWED_COMMANDS)} allowed (got {cmd!r})"
        )

    for pat in _BANNED_PATTERNS:
        if re.search(pat, upper):
            raise ValueError(f"Banned construct matched /{pat}/")

    return sql


def _ensure_limit(sql):
    """Auto-append LIMIT to bare SELECTs. SHOW/EXPLAIN/DESC don't take LIMIT."""
    if not sql.upper().startswith("SELECT"):
        return sql
    if re.search(r"\bLIMIT\s+\d+", sql, re.IGNORECASE):
        return sql
    return f"{sql} LIMIT {_DEFAULT_LIMIT}"


def _json_safe(v):
    if v is None or isinstance(v, (bool, int, float, str)):
        return v
    if isinstance(v, decimal.Decimal):
        return str(v)  # str preserves precision better than float
    if isinstance(v, (datetime.datetime, datetime.date, datetime.time)):
        return v.isoformat()
    if isinstance(v, datetime.timedelta):
        return str(v)
    if isinstance(v, bytes):
        try:
            return v.decode("utf-8")
        except UnicodeDecodeError:
            return "base64:" + base64.b64encode(v).decode("ascii")
    return str(v)


def _truncate_to_payload_cap(rows, elapsed_ms):
    """Binary-search the largest row prefix that fits in _MAX_PAYLOAD_BYTES."""
    body = {"rows": rows, "rowCount": len(rows), "truncated": False, "queryTimeMs": elapsed_ms}
    if len(json.dumps(body)) <= _MAX_PAYLOAD_BYTES:
        return body

    lo, hi = 0, len(rows)
    while lo < hi:
        mid = (lo + hi + 1) // 2
        trial = json.dumps({
            "rows": rows[:mid],
            "rowCount": mid,
            "totalRowsBeforeTruncation": len(rows),
            "truncated": True,
            "queryTimeMs": elapsed_ms,
        })
        if len(trial) <= _MAX_PAYLOAD_BYTES:
            lo = mid
        else:
            hi = mid - 1

    return {
        "rows": rows[:lo],
        "rowCount": lo,
        "totalRowsBeforeTruncation": len(rows),
        "truncated": True,
        "queryTimeMs": elapsed_ms,
    }


def handler(event, context):
    started = time.time()

    sql_in = event.get("sql")
    if not sql_in:
        return {"error": "Missing 'sql' in payload"}

    try:
        sql = _ensure_limit(_validate(sql_in))
    except ValueError as e:
        return {"error": f"Rejected: {e}"}

    password = _get_db_password()
    print(f"[e2-readonly-query] sql={sql!r}")

    conn = pymysql.connect(
        host=_DB_HOST,
        port=_DB_PORT,
        user=_DB_USER,
        password=password,
        database=_DB_NAME,
        connect_timeout=5,
        read_timeout=27,
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=True,
        charset="utf8mb4",
        ssl=_SSL_CTX,
    )
    try:
        with conn.cursor() as cur:
            # Cap query runtime at 25s server-side. MAX_EXECUTION_TIME is a
            # SESSION variable since MySQL 5.7.8 and applies to SELECT only;
            # SHOW/EXPLAIN are fast enough that we don't need to gate them.
            cur.execute("SET SESSION MAX_EXECUTION_TIME = 25000")
            cur.execute(sql)
            rows = cur.fetchall() or []
    except pymysql.err.MySQLError as e:
        elapsed_ms = int((time.time() - started) * 1000)
        print(f"[e2-readonly-query] mysql_error={e} ms={elapsed_ms}")
        return {"error": f"MySQL error: {e}", "queryTimeMs": elapsed_ms}
    finally:
        conn.close()

    rows = [{k: _json_safe(v) for k, v in row.items()} for row in rows]
    elapsed_ms = int((time.time() - started) * 1000)
    body = _truncate_to_payload_cap(rows, elapsed_ms)

    print(
        f"[e2-readonly-query] returned rows={body['rowCount']} "
        f"truncated={body.get('truncated', False)} ms={elapsed_ms}"
    )
    return body
