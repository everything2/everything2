# show_content Function Analysis

**Last Updated:** 2025-11-20
**Status:** Updated post-parseCode removal

## Executive Summary

The `show_content` function in [htmlcode.pm:1241-1423](ecore/Everything/Delegation/htmlcode.pm#L1241-L1423) is a **CRITICAL, ACTIVELY-USED** content formatting system that powers many core features of Everything2.

**Key Findings:**

1. `show_content` is called in **17+ locations** across the codebase (via `htmlcode('show content', ...)`)
2. ✅ **parseCode and embedCode have been removed** - Phase 1 eval removal complete (2025-11-20)
3. Superdoc content now uses delegation pattern exclusively
4. This function continues to work correctly with delegated superdoc rendering

## Function Location

- **File:** `ecore/Everything/Delegation/htmlcode.pm`
- **Lines:** 1241-1423 (183 lines)
- **Type:** htmlcode delegation function
- **Status:** ✅ **ACTIVELY USED** - Core formatting function

## Call Site Analysis

The function is invoked via `htmlcode('show content', ...)` in these locations:

### Core Content Display
1. **nodelet.pm:1117** - Draft display in nodelets
2. **htmlpage.pm:1098** - Writeup display (with canseewriteup filtering)
3. **htmlpage.pm:1152** - Low reputation content display
4. **htmlpage.pm:1168** - Unpublished content display

### Content Formatting Functions
5. **htmlcode.pm:485** - `displaydebatecomment` (debate comment display)
6. **htmlcode.pm:3637** - Weblog list display
7. **htmlcode.pm:3681** - Weblog content with instructions
8. **htmlcode.pm:8948** - Atom feed generation
9. **htmlcode.pm:11605** - General content display
10. **htmlcode.pm:13173** - Content with custom instructions
11. **htmlcode.pm:13711** - "Cream of the Cool" display
12. **htmlcode.pm:13813** - News node display
13. **htmlcode.pm:13837** - Content with truncation

### Document Display
14. **document.pm:2573** - SQL result display
15. **document.pm:2689** - Draft display in documents
16. **document.pm:16694** - User writeup list display
17. **document.pm:16984** - Another user writeup list

**Impact:** This is a core utility function used throughout the site for consistent content presentation.

## Function Purpose and Features

`show_content` is a sophisticated content formatting system designed to provide flexible, consistent display of node lists and database results.

### Input Handling

Accepts multiple input types:
- **Single node:** Hash reference to a node
- **Array of nodes:** Array reference containing node hashes
- **DBI result set:** Database cursor from sqlSelectMany

### Standard Info Functions

Built-in formatters available in instruction strings:

| Function | Purpose | Typical Output |
|----------|---------|----------------|
| `author` | Display node author | Link to author's homenode |
| `byline` | Full byline with date | "by [author] on [date]" |
| `title` | Node title | Formatted title with link |
| `parenttitle` | Parent node title | Title of parent node |
| `type` | Node type | Display node's type |
| `date` | Publication date | Formatted date string |
| `listdate` | List-style date | Compact date format |
| `oddrow` | Alternating row styling | CSS class for table rows |
| `content` | Node doctext | Full content with optional truncation |
| `getloggeditem` | Weblog-specific | Custom formatting for weblogs |
| `atominfo` | Atom feed data | XML formatting for feeds |
| `linkedby` | Backlink info | Shows nodes linking here |

### Instruction Parsing System

The second parameter is an instruction string that controls output format:

**Format:** `"<wrapper_tag> function1, function2, length"`

**Examples:**
- `"<li> getloggeditem, title, byline"` - List items with title and byline
- `"xml <entry> atominfo, 1024"` - XML output with 1024 char limit
- `"parenttitle, type, byline, 512"` - Standard fields with truncation
- `"getloggeditem, title, byline, date"` - Full weblog entry display

**Special Modes:**
- `xml` - Generate XML output instead of HTML
- `<tagname>` - Wrap each item in specified HTML tag
- Number at end - Truncate content to N characters

### Custom Info Functions

Third parameter allows passing custom formatters:

```perl
my %customFuncs = (
  atominfo => sub { # custom atom formatter },
  linkedby => sub { # custom backlink display }
);
htmlcode('show content', $nodes, $instructions, %customFuncs);
```

This extensibility allows specialized formatting for different contexts.

## Content Processing Pipeline

1. **Input Normalization:** Convert DBI results or arrays to uniform format
2. **Info Function Setup:** Register standard formatters + custom ones
3. **Instruction Parsing:** Parse comma-separated instruction string
4. **Loop Over Items:** Process each node in input
5. **Apply Functions:** Execute requested info functions for each node
6. **Content Processing:**
   - Extract doctext or specified fields
   - Break tags, parse links, screen HTML
   - Apply truncation with "more" links if specified
7. **Output Generation:** Build final HTML/XML string

## Historical Note: parseCode Removal (Completed 2025-11-20)

**Previous Concern:** The `show_content` function previously called `parseCode()` when processing superdoc (nodetype 14) content at line 1358.

**Resolution:** ✅ **REMOVED** - Both `parseCode()` and `embedCode()` functions have been completely removed from the codebase as part of Phase 1 eval removal (2025-11-20).

**Why it was safe to remove:**
- All 235 superdocs migrated to delegation functions
- Superdoc doctext fields are empty in the database
- No eval-based template processing needed anymore
- Superdoc rendering now uses delegation pattern exclusively

**Historical Context:**
The parseCode call in show_content was reachable through the frontpage_news code path when displaying weblog entries that might reference superdocs. However, since all superdoc content has been migrated to delegation functions and their doctext fields emptied, the parseCode processing was only processing empty strings before removal.

## Recommendations

### ✅ Completed Actions (2025-11-20)

1. ✅ **Removed parseCode and embedCode functions** from Everything/HTML.pm
2. ✅ **Verified all superdoc doctext is empty** - confirmed via migration
3. ✅ **Removed parseCode export declarations** from @EXPORT list

### Ongoing Considerations

**show_content is a critical system** - any changes must be thoroughly tested:
- Used in 17+ locations across core functionality
- Powers writeup display, weblogs, feeds, drafts, news
- Custom infofunction mechanism is heavily used
- Instruction parsing is complex but flexible

## Usage Examples from Codebase

### Weblog Display
```perl
htmlcode('show content', $csr, '<li> getloggeditem, title, byline', %weblogspecials)
```
Displays weblog entries as list items with title and author.

### Atom Feed Generation
```perl
htmlcode('show content', $input, "xml <entry> atominfo, $length", (atominfo => $atominfo))
```
Generates XML entries for Atom feeds with custom formatting.

### Draft Display
```perl
htmlcode('show content', $drafts, '<div class="draft"> title, byline, content, 512')
```
Shows drafts with truncated content.

### Cream of the Cool
```perl
htmlcode('show content', $DB->stashData("creamofthecool"), 'parenttitle, type, byline, 1024')
```
Displays curated content with parent context.

## ✅ parseCode Removal Complete (2025-11-20)

**Status:** All parseCode and embedCode functions have been completely removed from the codebase.

**What was removed:**
- `parseCode()` function from Everything/HTML.pm (lines 719-745)
- `embedCode()` function from Everything/HTML.pm (lines 684-715)
- Export declarations from @EXPORT list
- All calls to these functions throughout the codebase

**Verification:** Build successful with all 27 Perl tests + 53 React tests passing.

## Related Documentation

- [eval-removal-plan.md](eval-removal-plan.md) - Phase 1 eval removal strategy
- [delegation-migration.md](delegation-migration.md) - Superdoc migration guide

## Conclusion

`show_content` is a critical, actively-used content formatting system that powers content display across Everything2.

### Summary (Updated 2025-11-20)

1. ✅ **parseCode Removal Complete**: Both parseCode and embedCode functions have been removed from the codebase as part of Phase 1 eval removal
2. ✅ **No Breaking Changes**: All 27 Perl tests + 53 React tests pass after removal
3. ✅ **Superdoc Migration Complete**: All 235 superdocs use delegation pattern, no eval-based processing needed
4. 🎯 **Active System**: show_content continues to work correctly, used in 17+ locations for writeup display, weblogs, feeds, drafts, and news

### Current Status

**Phase 1 Complete:**
- parseCode and embedCode removed
- Superdoc doctext fields empty
- Delegation pattern fully functional
- System tested and verified

**Next Phase:**
- Continue with evalCode removal (notification system, achievements complete)
- Maintain show_content as-is - critical infrastructure, no changes needed
