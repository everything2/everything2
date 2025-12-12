# Writeup/E2Node/Draft React Migration Plan

**Status**: Planning
**Last Updated**: 2025-12-11
**Scope**: writeup_display_page, e2node_display_page, draft_display_page, and supporting APIs

## Executive Summary

This migration moves the core content display pages to React, enabling client-side content parsing to reduce server CPU usage. The migration includes:

- **e2node_display_page**: Parent page showing all writeups under a title
- **writeup_display_page**: Individual writeup view
- **draft_display_page**: Draft viewing/editing (path to publishing)
- **Vote/Cool APIs**: Move form submissions to REST APIs
- **Admin tools**: Consolidate into menus and modals

## Current Architecture

### Display Pages (All Delegation-Based)

| Page | Location | Complexity |
|------|----------|------------|
| e2node_display_page | htmlpage.pm:1056-1204 | High - voting, multiple writeups, admin tools, softlinks |
| writeup_display_page | htmlpage.pm:1206-1249 | Medium - single writeup, voting, edit form |
| draft_display_page | htmlpage.pm:4391-4500+ | Medium - permissions, status changes, delete, publish |
| draft_edit_page | htmlpage.pm | Medium - editor integration |
| drafts (superdoc) | document.pm:379 | Low - listing page |

### Content Rendering Pipeline (Server-Side)

```
show_content (htmlcode.pm:1141)
    ↓
breakTags() → screenTable() → htmlScreen() → parseLinks()
    ↓
HTML with <a> tags sent to browser
```

**Target**: Move `parseLinks()` to client-side using E2HtmlSanitizer.js

### Voting System (Form-Based)

```
votehead → opens <form op=vote>
voteit → renders vote buttons per writeup
votefoot → closes form, submit button
    ↓
opcode.pm:221 → castVote() in Application.pm
```

### Cool System (Form-Based)

```
Cool button in writeup display
    ↓
opcode.pm:730 → inserts coolwriteups record
```

## Migration Goals

1. **Client-side parsing**: Use E2HtmlSanitizer.js (DOMPurify + parseE2Links)
2. **Reduce CPU**: Move link parsing from Perl to JavaScript
3. **API-based voting**: Replace form submissions with fetch() calls
4. **Cleaner admin UI**: Modals instead of inline forms
5. **Consistent styling**: Inherit from existing stylesheets, maintain text sizing

## Pitfalls & Challenges

### 1. Content Parsing Differences

**Risk**: Client-side parsing may differ from server-side
**Mitigation**:
- E2HtmlSanitizer.js already matches APPROVED_TAGS from database
- parseE2Links() handles [link], [link|display], [link[type]] syntax
- Need to verify edge cases: nested brackets, malformed links, special characters

**Action Items**:
- Create test suite comparing server vs client parsing output
- Document any intentional differences
- Handle legacy content that may have edge cases

### 2. Vote/Cool Race Conditions

**Risk**: Multiple rapid clicks, stale vote counts
**Mitigation**:
- Optimistic UI updates with rollback on error
- Debounce vote buttons
- Return updated counts from API response
- Consider WebSocket for real-time count updates (future)

**API Design**:
```
POST /api/vote/:writeup_id
Body: { vote: 1 | -1 }
Response: { success, newRep, userVotesRemaining, error }

POST /api/cool/:writeup_id
Response: { success, coolCount, userCoolsRemaining, error }
```

### 3. Permissions Complexity

**Risk**: canSeeWriteup() and canSeeDraft() have many conditions
**Mitigation**:
- Server always validates permissions
- Client receives pre-filtered data
- Never trust client for permission decisions

**Hidden Writeup Categories** (from canseewriteup):
- Low reputation (below threshold)
- Unfavorite author (user preference)
- Unpublished draft (visibility rules)
- Author always sees own content

### 4. Admin Tool Migration

**Current Tools** (embedded in pages):
- e2nodetools (editors only)
- Kill buttons (in voteit)
- Draft status changes
- Draft nuke/delete
- Publish button

**Target Architecture**:
```
┌─────────────────────────────────────┐
│ Admin Menu (dropdown)               │
├─────────────────────────────────────┤
│ • Move writeup                      │
│ • Change parent                     │
│ • View history                      │
│ • Nodenotes                         │
│ ─────────────────                   │
│ • Kill writeup (modal confirmation) │
│ • Superbless (modal)                │
└─────────────────────────────────────┘
```

### 5. SEO & Initial Load

**Risk**: Client-side rendering may hurt SEO
**Mitigation**:
- Return raw doctext in initial page data (for crawlers)
- Server-rendered meta tags (title, description)
- Consider hybrid: server renders content, client enhances

**Recommendation**: Hybrid approach
- Server sends doctext as raw text + parsed HTML
- React hydrates and adds interactivity
- Crawlers get server-rendered content

### 6. Draft → Writeup Publishing

**Current Flow** (opcode-based):
```
publishdraft opcode
    ↓
Changes node type from 'draft' to 'writeup'
Inserts writeup record with parent_e2node
Clears publication_status
```

**Target Flow** (API-based):
```
POST /api/drafts/:id/publish
Body: { parent_e2node_id, writeup_type }
Response: { success, writeup_id, writeup_url }
```

**Complexity**:
- Must handle parent e2node creation if doesn't exist
- Writeup type selection (idea, person, place, thing, etc.)
- Title validation (no duplicates under same e2node by same author)

### 7. Stylesheet Integration

**Current**: Writeups use various CSS classes from legacy stylesheets
**Goal**: Maintain exact visual appearance

**Key Classes to Preserve**:
- `.writeup-body` - main content area
- `.writeup-header` - title, author, date
- `.writeup-footer` - vote counts, cool count
- `.softlinks` - related links section
- `.vote-button`, `.cool-button` - interactive elements

**Approach**:
- Keep existing CSS, don't rewrite styles
- React components use same class names
- Avoid inline styles for content (use for layout only)

### 8. State Management

**Challenge**: Multiple writeups on e2node page, each with own vote state

**Options**:
1. **Local state per component**: Simple, but no cross-component updates
2. **Context provider**: Share vote state across writeups
3. **URL-based state**: Vote updates refresh from server

**Recommendation**: Context provider for vote state
```jsx
<WriteupVoteProvider>
  <E2NodePage>
    <Writeup id={1} />
    <Writeup id={2} />
    ...
  </E2NodePage>
</WriteupVoteProvider>
```

### 9. Large Content Performance

**Risk**: Very long writeups may be slow to parse client-side
**Mitigation**:
- Lazy parsing: parse visible content first
- Web Worker for parsing (off main thread)
- Cache parsed content in memory

**Measurement Needed**:
- Benchmark parseE2Links() on large documents (10KB+)
- Profile DOMPurify sanitization time

### 10. Backward Compatibility

**Risk**: Old bookmarks, external links, search engine indexes
**Mitigation**:
- Keep same URLs (/title/Node+Name, /node/writeup/Title)
- Same query parameters work
- No breaking changes to URL structure

## Implementation Phases

### Phase 1: Vote/Cool APIs (Foundation)

**New Files**:
- `ecore/Everything/API/vote.pm`
- `ecore/Everything/API/cool.pm`

**Endpoints**:
```
POST /api/vote/:writeup_id     - Cast vote
GET  /api/vote/:writeup_id     - Get current vote state
POST /api/cool/:writeup_id     - Cool a writeup
GET  /api/cool/:writeup_id     - Get cool state
```

**Tests**: `t/0XX_vote_api.t`, `t/0XX_cool_api.t`

### Phase 2: writeup_display_page (Single Writeup)

**New Files**:
- `ecore/Everything/Page/writeup_display_page.pm`
- `react/components/Documents/WriteupDisplayPage.js`

**Data Shape**:
```javascript
{
  type: 'writeup_display_page',
  writeup: {
    node_id, title, author, createtime,
    doctext,           // Raw content for parsing
    parent_e2node,     // { node_id, title }
    writeup_type,      // idea, person, thing, etc.
    reputation,        // If visible to user
    cooled,            // Cool count
    notnew             // Is on front page
  },
  userVote: 1 | -1 | null,
  userCooled: boolean,
  canEdit: boolean,
  canKill: boolean,    // Editor permission
  votesRemaining: number,
  coolsRemaining: number
}
```

### Phase 3: e2node_display_page (Multiple Writeups)

**New Files**:
- `ecore/Everything/Page/e2node_display_page.pm`
- `react/components/Documents/E2NodeDisplayPage.js`

**Data Shape**:
```javascript
{
  type: 'e2node_display_page',
  e2node: { node_id, title },
  writeups: [...],           // Array of writeup objects
  hiddenWriteups: {          // Categorized hidden writeups
    lowRep: [...],
    unfavoriteAuthor: [...],
    unpublished: [...]
  },
  softlinks: [...],
  canAddWriteup: boolean,
  isEditor: boolean,
  votesRemaining: number,
  coolsRemaining: number
}
```

### Phase 4: Editor Beta Publish Workflow

**Goal**: Add publishing capability to Editor Beta, making it the complete draft-to-writeup tool.

**Changes to Existing Files**:
- `ecore/Everything/Page/e2_editor_beta.pm` - Add writeup types to buildReactData
- `react/components/Documents/EditorBeta.js` - Add publish UI panel

**New Components**:
- `react/components/Editor/PublishPanel.js` - Parent node search, type picker, publish button
- `react/components/Editor/E2NodeSearch.js` - Autocomplete for existing e2nodes

**UI Flow**:
1. User completes draft
2. Clicks "Publish" tab/button
3. Searches for or enters parent e2node title
4. Selects writeup type (idea, person, thing, etc.)
5. Confirms publish
6. Redirected to new writeup page

**Data Addition to buildReactData**:
```javascript
{
  // Existing fields...
  writeupTypes: [
    { id: 123, title: 'idea' },
    { id: 124, title: 'person' },
    // ...
  ],
  canPublish: boolean  // User has permission to publish
}
```

### Phase 5: Publish API & Legacy Redirects

**New Endpoints**:
```
POST /api/drafts/:id/publish
Body: {
  parent_e2node_id | parent_e2node_title,
  writeup_type_id
}

GET /api/writeup-types
Response: [{ id, title, description }]

GET /api/e2nodes/search?q=title
Response: [{ node_id, title, writeup_count }]
```

**Legacy Page Redirects**:
- `ecore/Everything/Page/draft_display_page.pm` - Redirect to Editor Beta with ?draft_id=X
- `ecore/Everything/Page/drafts.pm` - Redirect to Editor Beta (superdoc listing)
- Update htmlpage.pm delegation to return redirect responses for draft pages

**Tests**: `t/0XX_publish_api.t`

### Phase 6: Admin Tools (Modals)

**Components**:
- `react/components/Modals/KillWriteupModal.js`
- `react/components/Modals/MoveWriteupModal.js`
- `react/components/Modals/NodenotesModal.js`
- `react/components/Modals/WriteupHistoryModal.js`
- `react/components/Menus/AdminMenu.js`

## Testing Strategy

### Unit Tests
- E2HtmlSanitizer parsing edge cases
- Vote/Cool API permission checks
- Draft permission matrix

### Integration Tests
- Full vote flow (click → API → UI update)
- Draft publish flow
- Hidden writeup filtering

### E2E Tests (Playwright)
- Vote as logged-in user
- Cool a writeup
- View hidden writeups toggle
- Admin kill writeup flow
- Draft to publish flow

### Performance Tests
- Parse 10KB writeup client-side
- Render page with 20 writeups
- Vote API response time

## Migration Checklist

- [ ] Vote API implemented and tested
- [ ] Cool API implemented and tested
- [ ] E2HtmlSanitizer edge cases verified
- [ ] writeup_display_page Page class
- [ ] WriteupDisplayPage.js React component
- [ ] e2node_display_page Page class
- [ ] E2NodeDisplayPage.js React component
- [ ] draft_display_page Page class
- [ ] DraftDisplayPage.js React component
- [ ] Publish API implemented
- [ ] Admin modals implemented
- [ ] CSS class compatibility verified
- [ ] SEO meta tags working
- [ ] E2E tests passing
- [ ] Performance benchmarks met
- [ ] Legacy delegation functions marked deprecated

## Architectural Decision: Editor Beta Becomes Drafts

**Decision**: Editor Beta will be renamed to "Drafts" and become the primary draft management interface.

The current "E2 Editor Beta" is the future; the legacy draft pages will be removed. Transition plan:

1. **Editor Beta gains publish workflow**: Add parent e2node selection, writeup type picker, publish button
2. **Editor Beta renamed to "Drafts"**: Takes over /title/Drafts URL
3. **draft_display_page**: Redirects to Drafts with ?draft_id=X
4. **E2 Editor Beta URL**: Redirects to /title/Drafts (backwards compatibility)
5. **Legacy draft delegation removed**: Once transition complete

### Publish Workflow in Drafts (née Editor Beta)

**Current State**: Can create/edit/save drafts, change status, view history
**Missing**: Parent e2node selection, writeup type, publish action

**UI Addition** (when draft is ready to publish):
```
┌─────────────────────────────────────────────────┐
│ Publish This Draft                              │
├─────────────────────────────────────────────────┤
│ Parent Node: [____________] [Search]            │
│   └─ "Node Title" (3 existing writeups)         │
│                                                 │
│ Writeup Type: [idea ▼]                          │
│   • idea     • thing                            │
│   • person   • place                            │
│   • event    • review (essay)                   │
│                                                 │
│ [Publish Writeup]                               │
│                                                 │
│ ⚠ This will make your draft publicly visible   │
│   and cannot be undone.                         │
└─────────────────────────────────────────────────┘
```

**API Endpoint**:
```
POST /api/drafts/:id/publish
Body: {
  parent_e2node_id: number | null,    // Existing e2node
  parent_e2node_title: string | null, // Create new e2node
  writeup_type_id: number
}
Response: {
  success: boolean,
  writeup_id: number,
  writeup_url: string,
  error: string | null
}
```

### URL Transitions

| URL | Before | After |
|-----|--------|-------|
| /title/Drafts | Legacy delegation (superdoc) | React Drafts page (primary) |
| /title/E2+Editor+Beta | React Editor Beta | Redirect to /title/Drafts |
| /node/draft/Title | Legacy delegation | Redirect to /title/Drafts?draft_id=X |

**E2 Editor Beta node**: Will be removed from database once transition complete.

## Open Questions

1. **Hybrid rendering**: Should we server-render content and client-enhance, or full client-render?
2. **Real-time updates**: Do we need WebSocket for vote count updates on busy pages?
3. **Softlinks**: Keep server-generated or make dynamic?
4. **Vote history**: Should users see their past votes on a writeup?
5. **New e2node creation**: Allow creating parent e2node during publish, or require it exists?

## Dependencies

- DOMPurify (already in package.json)
- E2HtmlSanitizer.js (exists, may need enhancements)
- Vote opcode logic (to be extracted to Application.pm)
- Cool opcode logic (to be extracted to Application.pm)

## Testing Tools

### Writeup Content Extraction (Production Data)

A cron job exports production writeup content to S3 for parsing comparison tests:

**Cron Script**: `cron/cron_extract_writeup_content.pl`

**S3 Output** (requires `writeup_export` bucket in everything.conf.json):
- `writeup-content-sample.json` - Random 1000 writeups for quick testing
- `writeup-content-recent.json` - Last 30 days of writeups
- `writeup-content-full.json.gz` - Complete corpus (compressed)
- `manifest.json` - Export metadata and statistics

**Analysis Tool**: `tools/compare-link-parsing.js`

```bash
# Download sample from S3
aws s3 cp s3://e2-writeup-exports/writeup-content-sample.json ./sample.json

# Analyze for edge cases
node tools/compare-link-parsing.js sample.json

# Detailed analysis with mismatch output
node tools/compare-link-parsing.js -v -o mismatches.json sample.json
```

**Edge Cases Detected**:
- `nested_brackets` - `[[` patterns that may confuse parser
- `unbalanced_brackets` - Mismatched `[` and `]` counts
- `special_chars_in_link` - Links containing `<>"'`
- `html_entities_in_link` - Links with `&amp;` etc.
- `multiple_pipes_in_link` - Ambiguous `[a|b|c]` syntax
- `brackets_in_code` - Links inside `<code>` blocks (should not parse)
- `brackets_in_pre` - Links inside `<pre>` blocks
- `very_long_link_title` - Titles >100 characters

## Risks Summary

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Parsing differences | High | Medium | Test suite, document differences |
| Performance regression | High | Low | Benchmark, Web Workers |
| Permission bugs | High | Medium | Server-side validation always |
| Admin tool breakage | Medium | Low | Gradual migration, feature flags |
| SEO impact | Medium | Medium | Hybrid rendering |

---

*This document should be updated as implementation progresses.*
