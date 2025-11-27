# Phase 4a: Page Migration Plan - Mason2 to React

**Status**: In Progress - Tier 1 Complete
**Last Updated**: 2025-11-26
**Scope**: ALL remaining page templates

## Overview

This document outlines the strategy for migrating ALL remaining Mason2 page templates to React components using the Phase 4a pattern. This includes `online_only_msg` and `sign_up` which require special attention for architectural and security reasons.

## Migration Progress Summary

**Total Pages**: 29
- ✅ **Completed**: 14 pages (48%)
- ⏳ **Remaining**: 15 pages (52%)

## Already Migrated (14 pages) ✅

### Phase 4a Core Pages (6 pages)
- `about_nobody` - Static informational page
- `e2_staff` - Usergroup member lists
- `golden_trinkets` - User karma (blessings) display with admin lookup
- `sanctify` - GP granting form with admin lookup
- `silver_trinkets` - User sanctity display with admin lookup
- `wheel_of_surprise` - Interactive GP gambling game

### Tier 1: Simple Display Pages (7 pages) ✅ COMPLETE
- `your_gravatar` - Gravatar URL generation and display
- `manna_from_heaven` - Newest writeups feed (DataStash)
- `everything_s_obscure_writeups` - Obscure writeups list
- `nodeshells` - Nodeshell list display
- `what_to_do_if_e2_goes_down` - Static emergency instructions
- `oblique_strategies_garden` - Random strategy generator
- `list_html_tags` - HTML tag reference list

### Numbered Nodelist Family (5 pages) ✅ COMPLETE
- `25` - 25 newest nodes (uses NodeList component)
- `everything_new_nodes` - New nodes list (uses NodeList component)
- `e2n` - Everything2 New alias (uses NodeList component)
- `enn` - Everything New Nodes alias (uses NodeList component)
- `ekn` - Everything Cool Nodes (uses NodeList component)

### Tier 3: Text Generators/Utilities (3 pages) ✅ COMPLETE
- `fezisms_generator` - Random fezism text (uses RandomText component)
- `piercisms_generator` - Random piercism text (uses RandomText component)
- `wharfinger_s_linebreaker` - Line break formatting utility

**Key Achievements**:
- ✅ Created reusable **NodeList** component (serves 5 pages)
- ✅ Created reusable **RandomText** component (serves 2 pages)
- ✅ Content-only optimization pattern established
- ✅ All 561 React tests passing
- ✅ All 159 smoke tests passing

## Remaining Pages to Migrate (15 pages)

### Tier 2: Form-Based Pages (Moderate API needs) - 7 pages

These pages have forms that submit data and need corresponding API endpoints.

| Page | Complexity | API Needed | Data Operations | Estimated Effort |
|------|------------|------------|-----------------|------------------|
| `your_ignore_list` | Medium | Yes | Read/modify ignore list | 4-5 hours |
| `your_nodeshells` | Medium | Yes | List + delete operations | 4-5 hours |
| `your_insured_writeups` | Medium | Yes | List + insurance toggle | 4-5 hours |
| `node_tracker` | Medium | Yes | Add/remove tracked nodes | 4-5 hours |
| `ipfrom` | Medium | Yes (existing?) | IP lookup + ban operations | 5-6 hours |
| `recent_node_notes` | Medium | Yes (existing) | Uses existing node notes API | 3-4 hours |
| `a_year_ago_today` | Low-Medium | No | Date-based writeup lookup | 3-4 hours |

**Estimated Tier 2 Total**: 27-38 hours

### Tier 3: Complex/Special Pages - 6 pages

Pages requiring significant refactoring or special handling.

| Page | Complexity | Issues/Requirements | Estimated Effort |
|------|------------|---------------------|------------------|
| `e2_full_text_search` | High | Search UI, pagination, filters | 8-10 hours |
| `numbered_nodelist` | High | Dynamic list generation, complex filters | 6-8 hours |
| `everything2_elsewhere` | Medium | External links management | 4-5 hours |
| `chatterbox_help_topics` | Low-Medium | Static help with dynamic examples | 3-4 hours |
| ~~`list_html_tags`~~ | ~~Low~~ | ~~Static reference list~~ | ~~✅ COMPLETE~~ |
| ~~`fezisms_generator`~~ | ~~Low-Medium~~ | ~~Random text generation~~ | ~~✅ COMPLETE~~ |
| ~~`piercisms_generator`~~ | ~~Low-Medium~~ | ~~Random text generation~~ | ~~✅ COMPLETE~~ |
| ~~`wharfinger_s_linebreaker`~~ | ~~Low-Medium~~ | ~~Text processing utility~~ | ~~✅ COMPLETE~~ |

**Note on Numbered Nodelist Family**:
- ~~`25.mc`~~ - ✅ **COMPLETE** - Migrated as part of numbered nodelist family
- ~~`numbered_nodelist`~~ - ✅ **COMPLETE** - Implemented as reusable NodeList component
- The NodeList component serves 5 pages: `25`, `everything_new_nodes`, `e2n`, `enn`, `ekn`
- All 5 pages share the same React component with different data

**Estimated Tier 3 Total**: 15-21 hours (reduced from 32-46 after completions)

### Tier 4: Documentation & Help Pages - 1 page

| Page | Complexity | Requirements | Estimated Effort |
|------|------------|--------------|------------------|
| `online_only_msg` | Low | Static help content + dynamic user VARS | 2-3 hours |

**Note**: This is a documentation/help page explaining the `/msg?` online-only feature. The messaging backend already supports `online_only => 1` parameter in `sendPrivateMessage()`. No API work needed - just convert documentation to React.

**User VARS to Display**:
- `getofflinemsgs` - Shows if user has "get online-only messages while offline" enabled

### Tier 5: Critical Security Path - 1 page

| Page | Complexity | Security Concerns | Estimated Effort |
|------|------------|-------------------|------------------|
| `sign_up` | Very High | User acquisition, email verification, anti-spam | 16-20 hours |

**Why Complex**:
- **Critical user acquisition path** - Bugs directly impact new user signups
- **Email verification system** - "inherently hard to test" (user's words)
- **Security sensitive** - Password hashing, CAPTCHA, rate limiting
- **Anti-abuse measures** - Spam prevention, username validation, IP blocking
- **ReCAPTCHA v3 integration** - Already implemented but needs React adaptation

**Current Implementation Details** (from sign_up.pm analysis):
- Field hashing for CSRF protection (`Everything::Form::field_hashing` role)
- Username validation (regex-based, rejects special chars and spaces/underscores mix)
- Email confirmation (double-entry with hashing)
- Password confirmation (double-entry with hashing)
- ReCAPTCHA v3 verification (Google API integration)
- "Infected" user detection (locked account cookie check)
- Security logging for suspicious activity
- 10-day email verification link expiry
- Activation email sending

**Required Work**:
1. **React Form Component** - Complex multi-field form with validation
2. **Registration API** - New `ecore/Everything/API/registration.pm`
   - `POST /api/registration/signup` - Create account + send verification email
   - `GET /api/registration/verify/{token}` - Verify email and activate account
   - `POST /api/registration/resend` - Resend verification email
3. **ReCAPTCHA Integration** - Frontend token generation + backend verification
4. **Email Service** - Activation email template + sending
5. **Testing Strategy** - How to test email verification in dev/CI
   - Mock SMTP server for dev
   - Test users with pre-verified emails
   - Manual verification bypass for E2E tests
6. **Security Audit** - Review username/email/password validation logic
7. **Rate Limiting** - Prevent signup spam (may already exist)

**Email Verification Testing Challenges**:
- Cannot rely on real email delivery in dev/CI
- Need mock SMTP server or email capture tool (MailHog, Mailpit)
- Need bypass mechanism for automated tests
- Need to test expiry logic (10-day timeout)

**Recommended Approach**:
1. **Phase 1**: Create API endpoint with existing logic from sign_up.pm (8-10 hours)
2. **Phase 2**: Build React form component with validation (4-5 hours)
3. **Phase 3**: Set up email testing infrastructure (2-3 hours)
4. **Phase 4**: Comprehensive test suite + manual QA (2-3 hours)

**Acceptance Criteria**:
- New users can register successfully
- Email verification works end-to-end
- ReCAPTCHA prevents automated signups
- Invalid usernames/emails properly rejected
- Security logging captures suspicious activity
- Tests cover all validation rules
- Dev environment has working email testing

## Required New API Endpoints

### Priority 1 (Tier 2 Pages)

1. **Ignore List API** (`ecore/Everything/API/ignore.pm`)
   - `GET /api/ignore/` - Fetch user's ignore list
   - `POST /api/ignore/add` - Add user to ignore list
   - `POST /api/ignore/remove` - Remove user from ignore list
   - Uses existing `ignoring_messages_from()` and `messages_ignored_by()` user methods

2. **Nodeshell API** (`ecore/Everything/API/nodeshell.pm`)
   - `GET /api/nodeshell/mine` - Fetch user's nodeshells
   - `POST /api/nodeshell/delete` - Delete a nodeshell (admin/owner only)
   - Uses existing nodeshell node type

3. **Insurance API** (`ecore/Everything/API/insurance.pm`)
   - `GET /api/insurance/` - Fetch user's insured writeups
   - `POST /api/insurance/toggle` - Toggle insurance on writeup
   - Uses existing writeup insurance field

4. **Node Tracker API** (`ecore/Everything/API/nodetracker.pm`)
   - `GET /api/nodetracker/` - Fetch tracked nodes
   - `POST /api/nodetracker/add` - Add node to tracker
   - `POST /api/nodetracker/remove` - Remove node from tracker
   - Uses existing node tracker system

5. **IP Lookup API** (`ecore/Everything/API/iplookup.pm`)
   - `GET /api/iplookup/{ip}` - Lookup IP address info
   - May already exist in some form - needs investigation

### Priority 2 (Search & Complex Features)

6. **Full-Text Search API** (`ecore/Everything/API/search.pm`)
   - `GET /api/search/?q={query}&type={type}&page={n}` - Full-text search
   - Uses existing search infrastructure
   - Pagination support

7. **Numbered Nodelist API** (`ecore/Everything/API/nodelist.pm`)
   - `GET /api/nodelist/?type={type}&sort={field}&page={n}` - Dynamic node lists
   - Complex filtering and sorting

### Priority 3 (Tier 5 - Security Critical)

8. **Registration API** (`ecore/Everything/API/registration.pm`)
   - `POST /api/registration/signup` - Create new user account
     - Validates username (special chars, spaces/underscores, uniqueness)
     - Validates email format and confirmation match
     - Validates password and confirmation match
     - Verifies ReCAPTCHA v3 token
     - Checks for "infected" users (locked account cookies)
     - Creates user node with unverified status
     - Generates verification token (expires in 10 days)
     - Sends activation email
     - Security logs all attempts
     - Returns success or detailed error messages
   - `GET /api/registration/verify/{token}` - Verify email and activate account
     - Validates token format and expiry
     - Activates user account
     - Returns success page or error
   - `POST /api/registration/resend` - Resend verification email
     - For users who didn't receive email
     - Rate limited to prevent abuse
   - Uses existing sign_up.pm logic but as API endpoints

## Refactoring Opportunities

### 1. Username Selector Pattern

**Current**: Mason component `<& username_selector, node => $.node &>`
**New Pattern**: React `<UsernameSelector />` component with autocomplete

**Pages Using This**:
- `golden_trinkets`
- `your_ignore_list`
- `your_nodeshells`
- `your_insured_writeups`
- `ipfrom`

**Action**: Create shared `UsernameSelector.js` component with:
- API-driven autocomplete (already exists via `userComplete` class)
- Validation
- Error handling
- Consistent styling

### 2. Admin User Lookup Pattern

**Pattern**:
```perl
if ($REQUEST->user->is_admin) {
  <& username_selector &>
  if (defined $.for_user) {
    # Show data for looked-up user
  }
}
```

**New Pattern**: React component checks `user.admin` prop and conditionally renders selector

### 3. List Display Patterns

**Common Pattern**: Many pages display lists of nodes/writeups with:
- Empty state ("no items")
- Numbered/bulleted lists
- LinkNode for each item
- Metadata (dates, authors)

**Action**: Create reusable `NodeList.js` component

## Migration Order Recommendation

### Phase 1: Quick Wins (Week 1)
1. `what_to_do_if_e2_goes_down` - Static content
2. `is_it_holiday` - Simple date logic
3. `golden_trinkets` - Simple karma display
4. `your_gravatar` - Simple email display
5. `list_html_tags` - Static reference

**Result**: 5 pages migrated, ~8-10 hours

### Phase 2: Read-Only Lists (Week 2)
6. `manna_from_heaven`
7. `everything_s_obscure_writeups`
8. `nodeshells` (read-only view)
9. `a_year_ago_today`
10. `oblique_strategies_garden`
11. `fezisms_generator`
12. `piercisms_generator`
13. `wharfinger_s_linebreaker`
14. `chatterbox_help_topics`

**Result**: 9 pages migrated, ~22-28 hours

### Phase 3: API-Driven Pages (Week 3-4)
15. `recent_node_notes` (uses existing API)
16. `your_ignore_list` + Ignore API
17. `your_nodeshells` + Nodeshell API
18. `your_insured_writeups` + Insurance API
19. `node_tracker` + Node Tracker API
20. `everything2_elsewhere`
21. `ipfrom` + IP Lookup API

**Result**: 7 pages migrated, ~27-38 hours

### Phase 4: Complex Pages (Week 5)
22. `e2_full_text_search` + Search API
23. `numbered_nodelist` + Nodelist API
24. `25.mc` (investigate first)

**Result**: 3 pages migrated, ~32-46 hours

## Total Estimated Effort

- **Tier 1** (Simple Display): 12-18 hours
- **Tier 2** (Form-Based): 27-38 hours
- **Tier 3** (Complex/Special): 32-46 hours
- **Tier 4** (Documentation): 2-3 hours
- **Tier 5** (Security Critical): 16-20 hours

**Grand Total**: 89-125 hours (11-16 days of full-time work)

**Priority Order for User Acquisition**:
1. Tiers 1-3 first (standard pages) - 71-102 hours
2. `sign_up` (Tier 5) ASAP - Critical for new users - 16-20 hours
3. `online_only_msg` (Tier 4) last - Documentation only - 2-3 hours

## Nodelet Template Cleanup

Once all nodelets are using React components with `react_handled => 1`, the Mason2 nodelet templates can be removed:

**Analysis Required**:
1. ✅ Verify all 26 nodelets have React components
2. ✅ Verify all nodelets set `react_handled => 1` in Controller
3. ✅ Verify Mason2 templates only render placeholder divs
4. ✅ Test that nodelet display works without templates

**If all checks pass**:
```bash
git rm templates/nodelets/*.mi
```

**Expected Files to Remove** (27 templates):
- categories.mi
- chatterbox.mi
- current_user_poll.mi
- epicenter.mi
- everything_developer.mi
- favorite_noders.mi
- for_review.mi
- master_control.mi
- messages.mi
- most_wanted.mi
- neglected_drafts.mi
- new_logs.mi
- new_writeups.mi
- node_statistics.mi
- notelet.mi
- notifications.mi
- other_users.mi
- personal_links.mi
- quick_reference.mi
- random_nodes.mi
- readthis.mi
- recent_nodes.mi
- recommended_reading.mi
- sign_in.mi
- statistics.mi
- usergroup_writeups.mi
- vitals.mi

## Success Criteria

### Per-Page Checklist
- [ ] Page class has `buildReactData()` method
- [ ] React component created in `react/components/Documents/`
- [ ] Component registered in `DocumentComponent.js` router
- [ ] Comprehensive test suite (10+ tests)
- [ ] Old Mason template removed (`git rm`)
- [ ] API endpoints created (if needed)
- [ ] API tests written (if applicable)
- [ ] Smoke test passing
- [ ] Manual browser testing complete

### Overall Project Success
- [ ] 22 pages migrated to React
- [ ] All new APIs documented in docs/API.md
- [ ] All tests passing (React + Perl + E2E)
- [ ] CLAUDE.md updated with session notes
- [ ] No regressions in existing functionality
- [ ] Performance maintained or improved

## Risk Factors

### High Risk
1. **Search Functionality** - Full-text search is complex, high user impact
2. **IP Lookup** - Security-sensitive, admin-only tool
3. **User Registration** (deferred) - Critical security path

### Medium Risk
1. **Ignore List** - Privacy implications, must not leak data
2. **Node Tracker** - User expectations for real-time updates
3. **Insurance** - Affects C! nominations, must preserve data

### Low Risk
1. Static content pages
2. Display-only pages
3. Utility generators

## Open Questions

1. ~~**25.mc**~~ - ✅ **ANSWERED**: Legacy page displaying "25 newest nodes", shares `numbered_nodelist` template
2. **node_tracker.mc** - Currently placeholder, is feature incomplete?
3. **IP Lookup** - Does an API already exist?
4. ~~**Nodelet Templates**~~ - ✅ **ANSWERED**: All 27 files removed successfully (Phase 3 complete)
5. **Search** - Use existing search or build new?
6. **Numbered Nodelist** - What are the use cases and requirements?

## Next Steps

1. ~~**Review this plan**~~ - ✅ **COMPLETE**: Plan reviewed and approved
2. ~~**Verify nodelet template status**~~ - ✅ **COMPLETE**: All 27 templates removed
3. **Continue Tier 1 migrations** - Next: `your_gravatar`, `is_it_holiday`, `what_to_do_if_e2_goes_down`
4. **Start Phase 1** - Begin with quick wins (static pages)
5. **Create shared components** - UsernameSelector, NodeList, etc.

---

**Note**: This plan assumes Phase 3 (nodelet Portal elimination) is complete and all nodelets use React. Plan should be updated as work progresses and requirements become clearer.
