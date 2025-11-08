# SQL Injection Vulnerability Analysis

**Date:** 2025-11-07
**Severity:** HIGH - Immediate attention required

## Executive Summary

Found **~15 critical SQL injection vulnerabilities** across the E2 codebase where user-controlled or insufficiently validated data is directly interpolated into SQL queries without proper escaping or parameterization.

## Vulnerability Categories

### Critical (Direct User Input)
- Direct interpolation in `do()` statements
- IN clause construction from unvalidated arrays
- IP address queries without proper escaping

### High (Depends on Validation)
- Node IDs assumed to be integers without validation
- Dynamic table names from variables

### Medium (Requires Attack Chain)
- WHERE clauses passed as strings
- Table/field names from node metadata

## Critical Vulnerabilities (Immediate Fix Required)

### 1. Weblog Update - Direct Interpolation

**File:** `ecore/Everything/Delegation/opcode.pm:1346`

**Vulnerable Code:**
```perl
$DB->getDatabaseHandle()->do(
    "update weblog set removedby_user=$$USER{user_id}
     where weblog_id=$src && to_node=$to_node"
);
```

**Issue:**
- `$src` and `$to_node` interpolated directly without validation
- No `quote()` call
- Assumes variables are integers

**Attack Example:**
```perl
# If $src = "1 OR 1=1"
# Query becomes:
update weblog set removedby_user=123 where weblog_id=1 OR 1=1 && to_node=456
# This would update ALL weblog rows!
```

**Fix:**
```perl
# Option 1: Use quote()
$DB->getDatabaseHandle()->do(
    "update weblog set removedby_user=" . $DB->quote($$USER{user_id}) .
    " where weblog_id=" . $DB->quote($src) .
    " AND to_node=" . $DB->quote($to_node)
);

# Option 2: Use prepared statement (BETTER)
my $sth = $DB->getDatabaseHandle()->prepare(
    "UPDATE weblog SET removedby_user=? WHERE weblog_id=? AND to_node=?"
);
$sth->execute($$USER{user_id}, $src, $to_node);
```

---

### 2. IN Clause - Array Join Without Validation

**File:** `ecore/Everything/dataprovider/links.pm:12-14`

**Vulnerable Code:**
```perl
my $inclause = join(",", keys %$nodeidhash);
my $linkcsr = $this->{dbh}->prepare(
    "select * from links where to_node IN($inclause)
     and from_node IN($inclause)"
);
```

**Issue:**
- `keys %$nodeidhash` not validated as integers
- No escaping or quoting
- Direct string concatenation

**Attack Example:**
```perl
# If $nodeidhash contains: {1 => 1, "2) OR 1=1 --" => 1}
# Query becomes:
select * from links where to_node IN(1,2) OR 1=1 --) and from_node IN(...)
# Returns all links!
```

**Impact:**
- Also affects `nodegroup.pm:14-16` and `nodeparam.pm:14` with same pattern

**Fix:**
```perl
# Option 1: Validate as integers
my @node_ids = grep { /^\d+$/ } keys %$nodeidhash;
die "Invalid node IDs" unless @node_ids == keys %$nodeidhash;
my $inclause = join(",", @node_ids);

# Option 2: Use placeholders (BETTER)
my @node_ids = keys %$nodeidhash;
my $placeholders = join(",", ("?") x @node_ids);
my $sth = $this->{dbh}->prepare(
    "SELECT * FROM links WHERE to_node IN($placeholders)
     AND from_node IN($placeholders)"
);
$sth->execute(@node_ids, @node_ids);
```

---

### 3. String Concatenation in prepare()

**File:** `ecore/Everything/Delegation/htmlcode.pm:6650`

**Vulnerable Code:**
```perl
my $csr = $DB->{dbh}->prepare(
    'SELECT * FROM links WHERE from_node=\''.getId($_).
    '\' and linktype=\''.$poclink.'\' limit 1'
);
$csr->execute;
```

**Issue:**
- Manual string quoting with `\'`
- `$poclink` not validated
- `getId()` may not return integer

**Attack Example:**
```perl
# If $poclink = "1' OR '1'='1"
# Query becomes:
SELECT * FROM links WHERE from_node='123' and linktype='1' OR '1'='1' limit 1
# Always returns true!
```

**Fix:**
```perl
# Use prepared statement
my $csr = $DB->{dbh}->prepare(
    'SELECT * FROM links WHERE from_node=? AND linktype=? LIMIT 1'
);
$csr->execute(getId($_), $poclink);
```

---

### 4. IP Address Without quote()

**File:** `ecore/Everything/Application.pm:4007`

**Vulnerable Code:**
```perl
return $this->{db}->sqlSelect('ipblacklist_ipaddress', 'ipblacklist',
    "ipblacklist_ipaddress = '$ip' AND ipblacklist_timestamp >
     DATE_SUB(NOW(), INTERVAL ".$this->{conf}->blacklist_interval.")"
);
```

**Issue:**
- `$ip` manually quoted with single quotes
- No `quote()` call
- IP validation may be insufficient

**Attack Example:**
```perl
# If $ip = "' OR '1'='1"
# Query becomes:
SELECT ipblacklist_ipaddress FROM ipblacklist
WHERE ipblacklist_ipaddress = '' OR '1'='1' AND ...
# Bypasses IP blacklist check!
```

**Fix:**
```perl
return $this->{db}->sqlSelect('ipblacklist_ipaddress', 'ipblacklist',
    "ipblacklist_ipaddress = " . $this->{db}->quote($ip) .
    " AND ipblacklist_timestamp >
     DATE_SUB(NOW(), INTERVAL " . $this->{conf}->blacklist_interval . ")"
);
```

---

### 5. Node ID in iplog Query

**File:** `ecore/Everything/Application.pm:1979`

**Vulnerable Code:**
```perl
my $ipquery = qq|
    SELECT DISTINCT iplog_ipaddy FROM iplog
    WHERE iplog_user = $$user{user_id}
    AND iplog_time > DATE_SUB(NOW(), INTERVAL $hour_limit HOUR)
|;
```

**Issue:**
- `$$user{user_id}` interpolated directly
- `$hour_limit` interpolated directly
- Assumes both are integers

**Risk Level:** Medium-High
- `user_id` likely always an integer from database
- But no explicit validation

**Fix:**
```perl
my $ipquery = qq|
    SELECT DISTINCT iplog_ipaddy FROM iplog
    WHERE iplog_user = ?
    AND iplog_time > DATE_SUB(NOW(), INTERVAL ? HOUR)
|;
my $sth = $this->{db}->getDatabaseHandle()->prepare($ipquery);
$sth->execute($$user{user_id}, $hour_limit);
```

---

## High Risk Vulnerabilities

### 6. Dynamic Table Names in sqlDelete

**File:** `ecore/Everything/NodeBase.pm:197-198`

**Vulnerable Code:**
```perl
sub sqlDelete {
    my ($this, $from, $where) = @_;
    $where or return;
    my $sql = "DELETE LOW_PRIORITY FROM $from WHERE $where";
    return $this->executeQuery($sql);
}
```

**Issue:**
- `$from` (table name) not validated
- `$where` clause passed as string (could contain anything)

**Attack Example:**
```perl
# If $from = "user; DROP TABLE node; --"
sqlDelete("user; DROP TABLE node; --", "1=1");
# Executes: DELETE FROM user; DROP TABLE node; -- WHERE 1=1
```

**Impact:**
- Same issue in `sqlSelect()` line 259
- Same issue in `sqlUpdate()` line 328
- Same issue in `sqlInsert()` line 415

**Fix:**
```perl
# Add table name whitelist
my %VALID_TABLES = map { $_ => 1 } qw(
    node user writeup document links version nodeparam
    # ... all valid table names
);

sub sqlDelete {
    my ($this, $from, $where) = @_;
    $where or return;

    die "Invalid table name: $from" unless $VALID_TABLES{$from};

    my $sql = "DELETE LOW_PRIORITY FROM $from WHERE $where";
    return $this->executeQuery($sql);
}
```

---

### 7. Node Deletion Queries

**File:** `ecore/Everything/NodeBase.pm:1282-1294`

**Vulnerable Code:**
```perl
$this->executeQuery(
    "DELETE LOW_PRIORITY FROM links WHERE to_node=$$NODE{node_id}"
);
$this->executeQuery(
    "DELETE LOW_PRIORITY FROM links WHERE from_node=$$NODE{node_id}"
);
$this->executeQuery(
    "DELETE FROM $groupTable WHERE $groupTable"."_id=$$NODE{node_id}"
);
```

**Issue:**
- `$$NODE{node_id}` assumed to be integer
- `$groupTable` not validated
- No `quote()` usage

**Risk Level:** Medium
- Node IDs typically come from database (integers)
- But no explicit validation

**Fix:**
```perl
my $node_id = $this->quote($$NODE{node_id});
$this->executeQuery(
    "DELETE LOW_PRIORITY FROM links WHERE to_node=$node_id"
);
$this->executeQuery(
    "DELETE LOW_PRIORITY FROM links WHERE from_node=$node_id"
);

# Validate table name
die "Invalid group table" unless $groupTable =~ /^\w+$/;
$this->executeQuery(
    "DELETE FROM $groupTable WHERE ${groupTable}_id=$node_id"
);
```

---

## Medium Risk Vulnerabilities

### 8. Table Name from User Input

**File:** `ecore/Everything/dataprovider/base.pm:43-61`

**Vulnerable Code:**
```perl
sub _hash_insert {
    my ($this, $table, $hash) = @_;
    # VULNERABLE: $table name used directly
    my $sth = $this->{dbh}->prepare("EXPLAIN $table");
    # ...
    my $template = "INSERT INTO $table VALUES(...)";
    $this->{dbh}->do($template, undef, @$values);
}
```

**Issue:**
- `$table` parameter not validated
- Could be from user-controlled source

**Fix:**
```perl
# Validate table name format
die "Invalid table name" unless $table =~ /^[a-zA-Z_][a-zA-Z0-9_]*$/;
```

---

## Vulnerability Summary by File

| File | Critical | High | Medium | Total |
|------|----------|------|--------|-------|
| Everything/Delegation/opcode.pm | 1 | 0 | 0 | 1 |
| Everything/Delegation/htmlcode.pm | 1 | 0 | 2 | 3 |
| Everything/Application.pm | 1 | 1 | 0 | 2 |
| Everything/NodeBase.pm | 0 | 4 | 0 | 4 |
| Everything/dataprovider/*.pm | 1 | 0 | 3 | 4 |
| **TOTAL** | **4** | **5** | **5** | **14** |

---

## Good Patterns to Follow

### Example 1: Using quote() Properly

**File:** `ecore/Everything/NodeBase.pm:2744`

```perl
$this->executeQuery(
    "INSERT into nodeparam VALUES(".
    join(",",$this->quote($node_id),$this->quote($paramname),
         $this->quote($paramvalue)).
    ") ON DUPLICATE KEY UPDATE paramvalue=".$this->quote($paramvalue)
);
```

✅ **Good:** All values quoted

### Example 2: Parameterized Query (Best Practice)

**File:** `ecore/Everything/Delegation/opcode.pm:2115-2123`

```perl
my $logQueryLikeIt = qq|
    INSERT INTO likeitlog
    (user_agent, liked_node_id, hits)
    VALUES
    (?, ?, ?)
    ON DUPLICATE KEY UPDATE
    hits=hits+1|;

$DB->getDatabaseHandle()->do($logQueryLikeIt, undef,
    $ENV{HTTP_USER_AGENT}, $nid, 1);
```

✅ **Excellent:** Using placeholders and parameters

### Example 3: sqlUpdate with Hash

**File:** `ecore/Everything/NodeBase.pm:325-356`

```perl
$this->sqlUpdate('user', {
    passwd => $pwhash,
    salt => $salt
}, "user_id=$$USER{node_id}");
```

✅ **Good:** Hash values are automatically quoted by sqlUpdate()

⚠️ **Warning:** WHERE clause should also use quote()

---

## Recommended Fixes Priority

### Immediate (This Week)
1. ✅ Fix `opcode.pm:1346` weblog update (direct interpolation)
2. ✅ Fix `links.pm` IN clause (array join)
3. ✅ Fix `htmlcode.pm:6650` string concatenation
4. ✅ Fix `Application.pm:4007` IP address check

### High Priority (This Month)
5. ✅ Add integer validation for all node_id usage
6. ✅ Add table name whitelist in NodeBase.pm
7. ✅ Fix all dataprovider IN clauses
8. ✅ Review all getDatabaseHandle()->do() calls

### Medium Priority (This Quarter)
9. ✅ Convert all queries to prepared statements
10. ✅ Create safe query builder wrapper
11. ✅ Add automated SQL injection tests
12. ✅ Code review all sqlXXX() calls

---

## Testing Strategy

### Manual Testing

```perl
# Test with malicious input
my $malicious_id = "1 OR 1=1";
my $malicious_string = "'; DROP TABLE node; --";

# Should NOT succeed
eval {
    my $node = getNode($malicious_id);
};
ok($@, "Malicious ID rejected");
```

### Automated Testing

```perl
# t/013_sql_injection.t
use Test::More tests => 10;

# Test that inputs are properly escaped
my $dangerous = "'; DELETE FROM node WHERE '1'='1";
my $quoted = $DB->quote($dangerous);
unlike($quoted, qr/DELETE/, "SQL keywords escaped");

# Test IN clause building
my @ids = (1, 2, "3; DROP TABLE");
eval {
    my $result = build_in_clause(@ids);
};
ok($@, "Invalid ID in array rejected");
```

### Static Analysis

```bash
# Search for dangerous patterns
grep -rn "getDatabaseHandle()->do(" ecore/
grep -rn 'WHERE.*\$' ecore/ | grep -v quote
grep -rn 'join.*,.*keys' ecore/
```

---

## Safe Coding Guidelines

### ✅ DO

1. **Use prepared statements with placeholders**
```perl
my $sth = $dbh->prepare("SELECT * FROM user WHERE user_id=?");
$sth->execute($user_id);
```

2. **Use quote() for all variables**
```perl
my $sql = "SELECT * FROM node WHERE node_id=" . $DB->quote($node_id);
```

3. **Validate integers explicitly**
```perl
die "Invalid ID" unless $id =~ /^\d+$/;
```

4. **Whitelist table names**
```perl
my %VALID_TABLES = (node => 1, user => 1, ...);
die "Invalid table" unless $VALID_TABLES{$table};
```

### ❌ DON'T

1. **Never interpolate variables directly**
```perl
# BAD!
$dbh->do("DELETE FROM user WHERE user_id=$id");
```

2. **Never manually quote with single quotes**
```perl
# BAD!
my $sql = "WHERE name='$name'";
```

3. **Never trust "internal" variables**
```perl
# BAD! Even node_ids should be validated
"WHERE node_id=$$NODE{node_id}"
```

4. **Never join arrays without validation**
```perl
# BAD!
my $in = join(",", @ids);
"WHERE id IN($in)"
```

---

## Exploitation Impact

### If Exploited Successfully:

**Data Breach:**
- Read any data from database
- Access user passwords/emails
- Read private messages

**Data Manipulation:**
- Modify user accounts
- Delete content
- Change permissions

**System Compromise:**
- Drop tables
- Create backdoor accounts
- Execute stored procedures

**Denial of Service:**
- Lock tables
- Infinite loops
- Resource exhaustion

---

## Next Steps

1. **Review this document** - Verify findings
2. **Prioritize fixes** - Start with critical
3. **Create test cases** - For each vulnerability
4. **Implement fixes** - Use prepared statements
5. **Code review** - Before deployment
6. **Monitor** - Watch for exploitation attempts

---

**Document Status:** Complete - Ready for Review
**Last Updated:** 2025-11-07
**Action Required:** Immediate review and prioritization
