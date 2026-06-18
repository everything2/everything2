# Everything2 Modernization Priorities — FOLDED into the dependency tree

**Status:** Retired 2026-06-07. This was a ~2500-line 13-priority planning doc. The live work has
been **folded into [modernization-dependency-tree.md](modernization-dependency-tree.md)** — the
curated, epoch-organized, issue-linked successor. Use that as the single source of truth for "what's
left and when it's reachable." The original detail remains in git history.

## Where each priority went

| # | Priority | Status / home |
|---|----------|---------------|
| 1 | Remove executable code from DB | ✅ **Done** (eval-from-DB eliminated) |
| 2 | Object-oriented refactoring (delegation → Page/Controller) | 🔄 `epoch:perl-cleanup` in the tree (#629, #1443, retire-NodeBase cluster) |
| 3 | Database security (SQL injection) | ✅ **Done** — zero injection sites (Apr 2026 audit). Security *headers* = #4182 (`epoch:infra-cleanup`, ships now) |
| 4 | Web framework migration (PSGI/Plack) | ✅ Shipped (live in prod 2026-06-08); mod_perl removed |
| 5 | Mobile-first React frontend | ✅ **Done** — shipped Jan 2026 (PR #4020) |
| 5.5 | Guest static-page caching (S3) | ❌ **Rejected** — no new cache infrastructure (cost-conscious; PSGI connection-cut is the lever, not a cache tier) |
| 6 | Message opcode cleanup | 🔄 #4198 (`epoch:infra-cleanup`) |
| 7 | Testing infrastructure | ✅ **Done** — 123 `t/` files (72 API), jest + RTL for React |
| 8 | PSGI/Plack migration *(dup of #4)* | 🔄 `epoch:psgi` |
| 9 | Code coverage tracking | ✅ Tooling in place (Devel::Cover); #917 caches the perlcritic health check |
| 10 | Alternative login methods (OAuth) | 🔄 `epoch:social-login` in the tree |
| 11 | CSS asset pipeline | 🔄 Mostly done (DB→S3 CSS closed: #2845–#2869); residual #2832 customstyle (`epoch:react-cleanup`) |
| 12 | XML generation library rationalization | ✅ Largely self-resolved — custom `Everything::XML.pm` is gone; residual XML::Generator/Simple→LibXML consolidation is low-value, untracked |
| 13 | MySQL 8.0 → 8.4 upgrade | ✅ **Done** 2026-06-07 (#4226) |

## Rejected / explicitly not doing
- **Redis / Memcached / external shared cache** and **S3 guest-page caching** — cost-conscious; the
  binding constraint is RDS buffer-pool RAM, addressed by the PSGI connection cut, not new infra.
  (Same family as the rejected CloudFront and Aurora evaluations.)
