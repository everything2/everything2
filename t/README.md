# Perl test suite (`t/`)

Run the whole suite (inside the `e2devapp` container):

```bash
prove -I/var/libraries/lib/perl5 -Iecore -j4 t/
```

`-j4` runs four files concurrently. A green `-j4` run is the trustworthy signal —
see the isolation rules below for why that used to be unreliable (#4267).

## Test isolation — the one rule that matters

**Do not mutate shared seed users or shared global state.** `tools/seeds.pl`
provides a fixed pool — `root`, `normaluser1..30`, `genericdev`,
`genericeditor`, `genericchanop`, and named singletons like `Cool Man Eddie`,
`guest user`. If a test boosts GP / experience / level, sets `sanctity`,
`acctlock`, `in_room` (online presence), adds `messageignore` rows, or sends
messages *as/to* one of these users, then under `-j4` another worker touching
the same user races it and one of them sees the other's mutation. Snapshot +
restore in an `END` block is **not** enough — the race window is the whole test.

### Instead: dedicated throwaway users

Create uniquely-named users in setup, nuke them in teardown. Use `$$` (the PID)
in the name so concurrent workers never collide.

```perl
my $root = $DB->getNode('root', 'user');     # privileged actor only
my $usuffix = 'mytest' . $$;
my @created_users;

my $mk_user = sub {
  my ($label, %o) = @_;
  # skip_maintenance=1 -> no user_create side effects (welcome PM, etc.)
  my $uid = $DB->insertNode("e2e_${usuffix}_$label", 'user', $root, undef, 1);
  push @created_users, $uid;
  # insertNode doesn't reliably materialize the aux rows on a cold cache, so
  # create the user row explicitly (only the PK is NOT NULL-without-default).
  $DB->sqlDelete('user', "user_id=$uid");
  $DB->sqlInsert('user', { user_id => $uid, GP => ($o{GP} // 0) });
  $DB->getNodeById($uid, 'force');
  return $DB->getNode($uid);
};

my $alice = $mk_user->('alice', GP => 100);
my $bob   = $mk_user->('bob');

# teardown (END block, or end of file). skip_maintenance avoids user_delete
# firing securityLog against the unset $Everything::HTML::USER global.
END {
  for my $uid (@created_users) {
    my $n = $DB->getNodeById($uid, 'force');
    $DB->nukeNode($n, -1, 0, 1) if $n;
    $DB->sqlDelete('user', "user_id=$uid");
  }
}
```

### Gotchas learned the hard way

- **Privileged node ops still need `root`.** A fresh user can't create a
  usergroup / nodegroup (`insertNode` enforces create-permission). Keep `root`
  (or another seed) as the *actor* for those calls, but make the test's data
  subjects (message sender/recipient, sanctify target, …) dedicated users.
- **Online presence is a `room` row.** Online-only delivery checks
  `COUNT(*) FROM room WHERE member_user=…`. To make a dedicated user "online",
  `sqlInsert('room', { member_user => $uid })` and delete it in teardown — never
  toggle a seed user's presence.
- **Deleting a `user` node needs a god.** `canDeleteNode` =
  `isApproved($USER, <type>{deleters_user})`; only the user type's deleters
  group (gods) may nuke a user. In teardown use `nukeNode($n, -1, 0, 1)` (`-1` =
  superuser) and `skip_maintenance=1`.
- **Destructive churn doesn't belong at the end of a big shared file.** If a
  test creates/deletes/locks nodes, put it in its own file rather than appending
  to a 100-test file — the prior tests' cache/state churn makes it flaky.
  (`t/157_admin_user_cleanup.t` was split out of `t/051` for exactly this.)

## Worked examples

- `t/157_admin_user_cleanup.t` — dedicated users, destructive ops in isolation.
- `t/036_online_only_messages.t` — dedicated users + scoped `room` presence.
- `t/043_message_ignores_delivery.t` — dedicated messaging users, `root` only
  for usergroup/nodegroup ops.
- `t/050_sanctify_api.t` — dedicated sanctifier (boosted level/GP) + recipient.
- `t/069_user_search_api.t` — dedicated writeups/e2nodes with `time()` names.

## Known-baseline failures (pre-existing, not regressions)

`t/010_in_usergroup`, `t/078_list_nodes_api`, `t/104_system_message_routing`,
`t/128_cron_schedule` have failed for ~a year and are tracked separately. A
`-j4` run is "clean" if only these fail.
