# contentData ↔ global-`e2` duplication audit

**Generated:** 2026-06-27 (Explore fan-out over 73 candidate Page controllers)
**Spec:** [e2-global-state.md](e2-global-state.md) — defines the canonical global state and the "contentData is page-specific only" convention this audit enforces.
**Issue:** the React-side half of #3981 ("de-duplicate react states for elements already available on the global object").

## The anti-pattern

`contentData` re-emits the **viewer's** state that already lives in global `e2` — almost always under a **renamed key**, which is why a key-exact grep finds nothing. The chrome already ships `e2.user.{admin,editor,chanop,developer,guest,node_id,title,gp,level}`, `e2.guest`, and `e2.node.{node_id,title}`; a page that also emits `is_admin` / `isEditor` / `is_guest` / `user_id` / `username` / `node_id` in `contentData` is shipping the same bytes twice and forcing the React component to read viewer state from the wrong place.

## The fix (per page, cross-stack)

1. **Perl:** delete the duplicating key from the `buildReactData` `contentData` return.
2. **React:** the Document component already receives a `user` prop (and can read `window.e2`). Replace `data.is_admin` → `user.admin`, `data.is_guest` → `user.guest`, `data.user_id` → `user.node_id`, `data.node_id` → `window.e2.node_id`, etc.
3. Update the component's fixture/test to drop the key and assert the prop path.

Mechanical and low-risk per page; the volume is the cost.

## Scope

| | count |
|---|---|
| Candidate pages audited | 73 |
| **Pages with real violations** | **~50** |
| Clean (per-item lists only) | 20 |
| Page-specific false positives (leave) | ~5 |

## Violations — viewer ROLE/GUEST flags (the bulk)
Each emits the **viewer's** flag; consume the matching `e2.user.*` / `e2.guest`.

| Page | keys | → consume |
|---|---|---|
| bad_spellings_listing | is_admin, is_editor | user.admin, user.editor |
| between_the_cracks | is_guest | guest |
| create_a_registry | is_guest | guest |
| create_room | is_admin, is_chanop | user.admin, user.chanop |
| display_categories | isGuest | guest |
| drafts_for_review | is_editor | user.editor |
| e2_bouncer | is_chanop | user.chanop |
| e2_gift_shop | isEditor | user.editor |
| e2node_reparenter | is_admin, is_editor | user.admin, user.editor |
| everything_document_directory | is_admin, is_editor, is_developer | user.admin, user.editor, user.developer |
| everything_poll_directory | is_admin | user.admin |
| feed_edb | is_admin | user.admin |
| findings | is_guest | guest |
| golden_trinkets | isAdmin | user.admin |
| guest_front_page | is_guest | guest |
| list_nodes_of_type | is_admin, is_editor | user.admin, user.editor |
| macro_faq | isGuest, isEditor | guest, user.editor |
| magical_writeup_reparenter | is_admin, is_editor | user.admin, user.editor |
| mark_all_discussions_as_read | is_admin, is_editor | user.admin, user.editor |
| my_big_writeup_list | is_admin, is_editor | user.admin, user.editor |
| news_archives | isAdmin | user.admin |
| node_backup | isAdmin | user.admin |
| nothing_found | is_guest, is_admin, is_editor | guest, user.admin, user.editor |
| random_nodeshells | is_guest | guest |
| recalculate_xp | is_admin | user.admin |
| reputation_graph | is_admin | user.admin |
| reputation_graph_horizontal | is_admin | user.admin |
| settings | is_editor | user.editor |
| show_user_vars | is_admin, is_developer | user.admin, user.developer |
| simple_usergroup_editor | is_admin, is_editor | user.admin, user.editor |
| spam_cannon | is_editor | user.editor |
| super_mailbox | is_editor | user.editor |
| the_catwalk | is_guest | guest |
| the_costume_shop | is_admin | user.admin |
| the_old_hooked_pole | is_editor | user.editor |
| the_oracle | is_admin, is_editor | user.admin, user.editor |
| the_oracle_classic | is_admin, is_editor | user.admin, user.editor |
| theme_nirvana | is_guest | guest |
| usergroup_discussions | is_guest | guest |
| usergroup_message_archive | is_admin (×5 — embedded in every message row) | user.admin |
| usergroup_picks | is_admin, is_editor, isAdmin | user.admin, user.editor |
| viewvars | is_admin, is_developer | user.admin, user.developer |
| what_does_what | isAdmin | user.admin |

## Violations — viewer IDENTITY
| Page | keys | → consume |
|---|---|---|
| create_category | user_id, user_title, user_level | user.node_id, user.title, user.level |
| drafts | username | user.title |
| e2_editor_beta | username | user.title |
| list_nodes_of_type | user_id | user.node_id |
| macro_faq | username | user.title |
| my_recent_writeups | user_id, username | user.node_id, user.title |
| settings | currentUser.node_id, currentUser.title | user.node_id, user.title |
| spam_cannon | username | user.title |
| the_costume_shop | userGP | user.gp |
| viewvars | inspect_user.{node_id,title} (viewvars-mode = self) | user.node_id, user.title |
| who_is_doing_what | username | user.title |

## Violations — current NODE identity
| Page | keys | → consume |
|---|---|---|
| node_forbiddance | node_id | e2.node.node_id |
| renunciation_chainsaw | node_id | e2.node.node_id |
| the_old_hooked_pole | node_id | e2.node.node_id |
| usergroup_discussions | node_id | e2.node.node_id |
| usergroup_message_archive | node_id (×4) | e2.node.node_id |

## Nuanced — global FEEDS (not a simple key-removal)
- **welcome_to_everything** emits `daylogs`/`coolnodes`/`staffpicks`/`news` — the front page's *rich* display of feeds whose *thin* versions are `e2.daylogLinks`/`coolnodes`/`staffpicks`/`news`. The **fetch is already deduped** (cached_stash, #3981/blob-key-dedup); the shapes genuinely differ, so this is shared-source, not key-removal. Track under the cache work, not this cleanup.

## Page-specific false positives — LEAVE (audited, not violations)
- `golden_trinkets.karma` (not a global `e2.user` field), `historical_iron_noder_stats.is_participant`, `iron_noder_progress.is_participant`/`is_iron_leader`, `reputation_graph(_horizontal).can_view`, `usergroup_discussions.access_denied` — all **computed page-specific** flags about the viewer-in-this-context, not duplicates of a global key. Leave them.

## Clean (per-item lists only) — do NOT re-audit
bounty_hunters_wanted, confirm_password, everything_finger, everything_s_richest_noders, fresh_blood, freshly_bloodied, gp_optouts, ip_hunter, manna_from_heaven, new_user_images, node_tracker, noding_speedometer, recent_registry_entries, recent_users, registry_information, the_registries, the_tokenator, usergroup_attendance_monitor, users_with_infravision, voting_oracle.

(These emit `is_admin`/`user_id`/etc. *per listed user/node* in a loop — legitimate page data, not viewer dup.)

## Execution plan
Mechanical, batchable per page (Perl drop + React prop-read + fixture). Suggested order: the **role-flag** table first (largest, most uniform — `is_admin`/`is_editor`/`is_guest` → `user.*`), then identity, then node_id. `usergroup_message_archive` (viewer `is_admin` × 5 rows) and `settings` are the densest single-file wins.
