# Decoupling the security log from node identity (#4272)

**Status:** design / pre-implementation. Unblocks #4266 (opcode node retirement).

## The problem

`seclog` keys every event off `seclog_node` — a **node id** used as the event category:

```perl
$APP->securityLog($DB->getNode("lockaccount","opcode"), $user, $details);
```

Two concrete failures:

1. **Retiring a node breaks the log.** When an opcode whose node doubles as a seclog
   category is nuked, its historical rows dangle and live logging can silently stop.
   `Everything::Application` logs *every* node-parameter change through
   `getNode("parameter","opcode")` (`Application.pm:1145/1168`); nuke that node and
   `securityLog` hits `return unless defined($node)` — logging just stops. This is the
   thing **blocking** the nuke of `bless` / `bestow` / `parameter` in #4266.
2. **The column is overloaded.** Most callers use `seclog_node` as the event *type*, but
   several log the *affected* node instead — stylesheets on param changes, e2nodes on
   reparent, user nodes on XP. So it's neither a clean category nor a clean subject.

## Production data tree (read-only lambda, June 2026)

- **2,070,497 rows**, **72 distinct `seclog_node` values**.
- ~34 are real event types covering **99.3%** of rows.
- **7 categories are already dangling** (node nuked) — node identity was never reliable:

  | dangling id | rows | actually | maps to |
  |---|---|---|---|
  | 716619 | 13,796 | **"punch thyself"** GP-sink superdoc (tombed; ~2000–2008, retired for the Wheel of Surprise) | `PUNCH_THYSELF` (35) |
  | 2015009 | 11,796 | `"Deleted user X (node_id Y)"` | `USER_DELETION` |
  | 1162681 | 4,029 | `"X filled up with 500 votes"` | `VOTES_REFILL` |
  | 1668580 | 885 | `"X was raised from its tomb"` | `RESURRECTION` |
  | 1080591 | 15 | `"X was superblessed N XP by Y"` | `XP_SUPERBLESS` |
  | 1690592 | 13 | `"... create user [x] ..."` | `USER_SIGNUP` |
  | 1983796 | 10 | `"X by [Y] was moved to [Z]"` | `WRITEUP_REPARENT` |

- The long tail (cnt ≤ 9) is **subject leakage** — stylesheet ids (1973976, 1882070, …),
  e2nodes, users — callers that logged the affected node, not a category.

## Design

Split the overloaded column into two honest ones:

- **`seclog_event`** `smallint unsigned` — the event **type**, from the `Everything::SecurityLog`
  enum. The persisted value.
- **`seclog_subject`** `int NULL` — the **affected** node id when one exists (reparent target,
  XP recipient, …). Preserves the link; no longer a category.

`seclog_details` (free text) and `seclog_user` (the actor) stay as-is.

### `Everything::SecurityLog`

One frozen, **append-only** registry — ids are written into 2M rows, so **never renumber,
never reuse**; retire by marking deprecated, not by deleting.

```perl
package Everything::SecurityLog;
use strict; use warnings;

# id => persisted smallint. key => symbolic constant. desc => monitor label. group => monitor section.
my @EVENTS = (
  { id => 1,  key => 'USER_SIGNUP',       desc => 'User Signup',          group => 'accounts' },
  { id => 2,  key => 'USER_DELETION',     desc => 'User Deletions',       group => 'accounts' },
  { id => 3,  key => 'ACCOUNT_LOCK',      desc => 'Account Lockings',     group => 'accounts' },
  { id => 4,  key => 'ACCOUNT_UNLOCK',    desc => 'Account Unlockings',   group => 'accounts' },
  { id => 5,  key => 'MASSACRE',          desc => 'Kill reasons',         group => 'content'  },
  # ... full registry below ...
);

my (%BY_ID, %BY_KEY);
for my $e (@EVENTS) { $BY_ID{$e->{id}} = $e; $BY_KEY{$e->{key}} = $e; }

sub by_id   { $BY_ID{$_[1]} }
sub by_key  { $BY_KEY{$_[1]} }
sub id_for  { my $e = $BY_KEY{$_[1]}; $e ? $e->{id} : 0 }   # 0 = LEGACY_UNKNOWN
sub description { my $e = $BY_ID{$_[1]}; $e ? $e->{desc} : 'Unknown' }
sub all     { @EVENTS }
sub groups  { ... }   # for the monitor's sectioned view

# symbolic constants for writers: use Everything::SecurityLog qw(:events) -> SECLOG_ACCOUNT_LOCK ...
1;
```

`0` is reserved for `LEGACY_UNKNOWN` (catch-all; the `DEFAULT 0` of the column).

### The event registry (complete, from the data)

| id | key | description (monitor) | group | source `seclog_node`(s) | rows |
|---|---|---|---|---|---|
| 1 | USER_SIGNUP | User Signup | accounts | 2072173, 1690592 | 1,550,033 |
| 2 | USER_DELETION | User Deletions | accounts | 2108998, 2015009 | 12,099 |
| 3 | ACCOUNT_LOCK | Account Lockings | accounts | 1203049 | 28,527 |
| 4 | ACCOUNT_UNLOCK | Account Unlockings | accounts | 1203054 | 201 |
| 5 | MASSACRE | Kill reasons | content | 648516 | 195,547 |
| 6 | PASSWORD_RESET | Password resets | accounts | 2072175 | 38,012 |
| 7 | WHEEL_OF_SURPRISE | Wheel of Surprise | giftshop | 1874886 | 143,171 |
| 8 | IP_BLACKLIST | IP Blacklist | abuse | 1948146 | 10,543 |
| 9 | IP_BLACKLIST_MASS | Mass IP Blacklist | abuse | 2007188 | 27,126 |
| 10 | NODENOTE | Node Notes | content | 1429619 | 12,845 |
| 11 | VOTES_PURCHASED | Votes Bought | giftshop | 1962460 | 6,274 |
| 12 | VOTES_GIVEN | Votes Given Away | giftshop | 1962436 | 793 |
| 13 | VOTES_REFILL | Vote refills | xp | 1162681 | 4,029 |
| 14 | CHINGS_PURCHASED | Chings Bought | giftshop | 1962461 | 1,702 |
| 15 | CHING_GIVEN | Chings Given Away | giftshop | 1962435 | 2,010 |
| 16 | STARS_AWARDED | Stars Awarded | giftshop | 1988325 | 713 |
| 17 | EGGS_GIVEN | Eggs Given Away | giftshop | 1962437 | 578 |
| 18 | BLESS | Blessings | xp | 444704 | 4,553 |
| 19 | BESTOW_VOTES | Vote bestowings | xp | 444712 | 2,000 |
| 20 | COOLS_BESTOWED | C! bestowings | xp | 605785 | 823 |
| 21 | SUPERBLESS | SuperBless | xp | 453574 | 3,423 |
| 22 | XP_SUPERBLESS | XP SuperBless | xp | 1959718, 1080591 | 43 |
| 23 | XP_RECALC | XP Recalculations | xp | 1959368 | 559 |
| 24 | SANCTIFY | Sanctifications | xp | 1927889 | 1,520 |
| 25 | RESURRECTION | Resurrections | content | 850865, 1668580 | 1,908 |
| 26 | PARAMETER_CHANGE | Parameter changes | system | 2071202 | 1,015 |
| 27 | CATBOX_FLUSH | Catbox flushes | chat | 1328318 | 447 |
| 28 | WRITEUP_INSURANCE | Writeup insurance | content | 1179550 | 354 |
| 29 | WRITEUP_REPARENT | Writeup reparentings | content | 1138488, 1983796 | 2,397 |
| 30 | SUSPENSION | Suspensions | accounts | 1399999 | 287 |
| 31 | GIFTSHOP_TOPIC | Topic changes | giftshop | 1872678 | 2,922 |
| 32 | WEBSTERBLESS | Websterbless | xp | 1526847 | 169 |
| 33 | ENRICHIFY | Enrichify | xp | 1956191 | 9 |
| 34 | NODE_REMOVE | Node removals | content | 2047058 | 21 |
| 35 | PUNCH_THYSELF | Self-punches (GP sink) | xp | 716619 | 13,796 |
| 0 | LEGACY_UNKNOWN | Legacy / unclassified | — | cnt≤9 subject-leakage tail (stylesheets/e2nodes/users) | 48 |

Coverage: events 1–35 = **99.998%**; `LEGACY_UNKNOWN` absorbs only the **48** subject-leakage
rows (32 ids), with `seclog_subject` set to the old node id so nothing is lost. (`716619` was
identified via the tomb as the retired **"punch thyself"** GP-sink superdoc → `PUNCH_THYSELF`.)

## Schema migration

```sql
ALTER TABLE seclog
  ADD COLUMN seclog_event   smallint unsigned NOT NULL DEFAULT 0 AFTER seclog_id,
  ADD COLUMN seclog_subject int               DEFAULT NULL        AFTER seclog_event,
  ADD KEY    seclog_event__seclog_id (seclog_event, seclog_id);
-- seclog_node kept through the transition; dropped in the final step.
```

## Backfill (idempotent; one indexed UPDATE per category)

`seclog_node` leads an index, so each is a fast ranged update:

```sql
UPDATE seclog SET seclog_event=1  WHERE seclog_node IN (2072173,1690592);  -- USER_SIGNUP
UPDATE seclog SET seclog_event=2  WHERE seclog_node IN (2108998,2015009);  -- USER_DELETION
UPDATE seclog SET seclog_event=5  WHERE seclog_node=648516;                -- MASSACRE
-- ... one statement per row of the registry table above ...

-- subject leakage + catch-all (run LAST): anything still unmapped becomes LEGACY_UNKNOWN,
-- and we keep the old node id as the subject link.
UPDATE seclog SET seclog_subject=seclog_node, seclog_event=0 WHERE seclog_event=0;
```

The only large statement is USER_SIGNUP (~1.55M rows) — a single indexed scan; run it
off-peak. Everything is re-runnable.

## Writer rework (dual-write, then key-only)

`securityLog` gains an event-id path and an optional subject:

```perl
# Application.pm
sub securityLog {
  my ($this, $event, $user, $details, $subject) = @_;
  # transition: accept a node (old) OR an integer event id (new); resolve $user; ...
  $this->{db}->sqlInsert('seclog', {
    seclog_event   => $event_id,
    seclog_subject => ($subject ? $$subject{node_id} : undef),
    seclog_node    => $legacy_node_id,   # dual-write during transition only
    seclog_user    => $$user{node_id},
    seclog_details => $details,
  });
}
```

Call sites to convert (event in parens) — found by `grep securityLog`:

| file | event |
|---|---|
| `Application.pm:1145/1168` | PARAMETER_CHANGE |
| `htmlcode.pm:3518` / `:3838` | ACCOUNT_LOCK / MASSACRE |
| `opcode.pm` insure/unlockaccount/flushcbox | WRITEUP_INSURANCE / ACCOUNT_UNLOCK / CATBOX_FLUSH |
| `API/admin.pm` (×7) | insure / remove / lock / unlock |
| `API/xp.pm:110` | (XP — subject = the user) |
| `API/sanctify.pm:157` | SANCTIFY |
| `API/resurrect.pm:91` | RESURRECTION |
| `API/wheel.pm:210` | WHEEL_OF_SURPRISE |
| `API/signup.pm:89` | USER_SIGNUP |
| `API/password.pm:114` | PASSWORD_RESET |
| `API/writeup_reparent.pm:264` | WRITEUP_REPARENT (subject = e2node) |
| `maintenance.pm:697` | USER_DELETION |
| `Page/mass_ip_blacklister.pm:184/257`, `Page/ip_blacklist.pm:174`, `htmlcode.pm:3427` | IP_BLACKLIST(_MASS) |
| `Page/websterbless.pm:114` | WEBSTERBLESS |

## Monitor rework (`Page/security_monitor.pm`)

Today it builds a 27-entry list of `{node_title, node_type}` and does
`getNode($title,$type)` per category, then queries `seclog_node = <that id>`. After:

```perl
# no getNode at all -- iterate the enum, query by event id, label from the enum
for my $e (Everything::SecurityLog->all) {
  my $rows = $DB->sqlSelectMany('...', 'seclog', "seclog_event = $e->{id} ORDER BY seclog_id DESC LIMIT ...");
  push @sections, { name => $e->{desc}, group => $e->{group}, rows => [...] };
}
```

It survives any node deletion, and gains the categories the old hand-list was missing
(Wheel of Surprise, Mass IP Blacklister, the gift-shop family, …).

## Rollout (reversible at each step)

1. **Enum + additive schema** — `Everything::SecurityLog` + the two columns + index. No-op.
2. **Dual-write** — `securityLog` writes `seclog_event` (+ subject) *and* `seclog_node`. Prove
   parity (new rows have a non-zero event matching the old node mapping).
3. **Backfill** — run the per-category updates + the catch-all.
4. **Monitor cutover** — switch `security_monitor.pm` to `seclog_event`; verify per-event counts
   equal the old node-based counts.
5. **Drop legacy** — stop writing `seclog_node`, soak, `DROP COLUMN seclog_node`.

After step 4, nuking `bless`/`bestow`/`parameter` (and any future category-doubling opcode) is
harmless — closing the #4266 loop.

## Open items

- ~~**716619** (13.8K null-detail rows)~~ **RESOLVED** — identified via the tomb as the retired
  **"punch thyself"** GP-sink superdoc; now its own event `PUNCH_THYSELF` (35). `LEGACY_UNKNOWN` is
  down to 48 subject-leakage rows.
- **PASSWORD_RESET** detail text — audit for tokens/IPs before re-exposing in a cleaner monitor.
- Decide whether `seclog_details` (`char(255)`) should become `varchar`/`text` while we're here.
