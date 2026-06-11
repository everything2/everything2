# Production cleanup — orphaned htmlcode nodes (post htmlcode→Application extraction)

**Status:** PENDING — do AFTER the branch carrying the htmlcode extraction deploys to prod.

The June 2026 htmlcode→`Everything::Application` extraction factored three
`Everything::Delegation::htmlcode::*` snippets into real, unit-tested methods, removed
the delegation subs, and deleted their `nodepack/htmlcode/*.xml` source nodes. But
**deleting the nodepack XML only affects fresh DB builds** — the existing production DB
still has these now-orphaned `htmlcode` nodes (nothing calls them anymore). They should
be nuked from prod once the code is live.

| htmlcode | node_id | now lives at |
|---|---|---|
| `getGravatarMD5` | 2048927 | `Everything::Application->getGravatarMD5` |
| `DateTimeLocal`  | 1358138 | `Everything::Application->DateTimeLocal` |
| `isSpecialDate`  | 1002054 | `Everything::Application->isSpecialDate` |
| `coolcount`      | 2003804 | `Everything::Application->coolcount` |
| `usergroupToUserIds` | 1980272 | `Everything::Application->usergroupToUserIds` (+ internal `explode_ug`, no node) |

**Why it's safe:** all call sites were updated to `$self->APP->...` / `$this->...`, the
delegation subs are removed, and the node_ids are not referenced by id anywhere in the
codebase (verified). They are pure dead data in prod.

**Cleanup:** nuke each node via the app's node deletion (so the `htmlcode`/`document`/
`links` rows go too — not a bare `DELETE FROM node`). Confirm each is an `htmlcode` type
and has no inbound links first. Then delete this doc.
