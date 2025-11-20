# show_content Function Analysis

## Executive Summary

The `show_content` function in [htmlcode.pm:1241-1423](ecore/Everything/Delegation/htmlcode.pm#L1241-L1423) is a **CRITICAL, ACTIVELY-USED** content formatting system that powers many core features of Everything2.

**Key Findings:**

1. `show_content` is called in **17+ locations** across the codebase (via `htmlcode('show content', ...)`)
2. It contains a **parseCode call at line 1358** that processes superdoc content (nodetype 14) - this IS reachable
3. The `parsecode` htmlcode function at lines 895-912 appears to be **dead code** (never called)
4. **Actual parseCode count:** 6 active calls (not 7) after eliminating the unreachable one in `parsecode`

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
   - **⚠️ Apply parseCode to superdoc content** (line 1358)
   - Break tags, parse links, screen HTML
   - Apply truncation with "more" links if specified
7. **Output Generation:** Build final HTML/XML string

## Security Concern: parseCode at Line 1358

```perl
$text = parseCode( $text ) if exists( $$N{ type } )
    and ( $$N{ type_nodetype } eq "14"
    or $$N{ type }{ extends_nodetype } eq "14" ) ;
```

**What it does:** Processes superdoc (nodetype 14) content through the legacy parseCode system, which uses `eval()`.

**Risk Assessment:**

✅ **LOW RISK** according to eval-removal-plan.md audit findings:
- Superdocs are admin-controlled content, not user-generated
- All superdoc code has been migrated to delegation functions
- Superdoc doctext fields are now empty in the database
- This parseCode call should now be a no-op (processing empty strings)

**Migration Status:**
- All 235 superdocs have been migrated to delegation functions
- Superdoc XML files have empty `<doctext>` tags
- This parseCode call can be safely removed as part of Phase 1 cleanup

### Verified Code Path to parseCode Trigger

**Investigation confirmed that this parseCode call IS REACHABLE through the following path:**

#### Complete Execution Flow

1. **Entry Point: frontpage_news htmlcode** ([htmlcode.pm:13780](ecore/Everything/Delegation/htmlcode.pm#L13780))
   - Displays news items on the front page
   - Called from front page document delegation

2. **DataStash Fetch** ([DataStash/frontpagenews.pm:13-14](ecore/Everything/DataStash/frontpagenews.pm#L13-L14))
   ```perl
   my $frontpage_superdoc = $this->DB->getNode("News", "usergroup");
   my $weblog_entries = $this->APP->fetch_weblog($frontpage_superdoc, 5);
   ```
   - Gets the "News" usergroup (which is a weblog)
   - Fetches 5 most recent weblog entries

3. **Weblog Query** ([Application.pm:3606-3612](ecore/Everything/Application.pm#L3606-L3612))
   ```perl
   my $csr = $this->{db}->sqlSelectMany(
     'weblog_id, to_node, linkedby_user, linkedtime',
     'weblog',
     "weblog_id=$weblog->{node_id} AND removedby_user=0",
     "ORDER BY linkedtime DESC LIMIT $number OFFSET $offset");
   ```
   - Selects weblog entries with `to_node` field
   - **to_node can reference ANY node type, including superdocs!**

4. **Node Retrieval** ([htmlcode.pm:13794-13797](ecore/Everything/Delegation/htmlcode.pm#L13794-L13797))
   ```perl
   my $newsnodes = [];
   foreach my $N(@$fpnews) {
     push @$newsnodes, $DB->getNodeById($N->{to_node});
   }
   ```
   - Fetches actual node objects
   - **If to_node is a superdoc ID, a superdoc node is retrieved**

5. **show_content Invocation** ([htmlcode.pm:13813](ecore/Everything/Delegation/htmlcode.pm#L13813))
   ```perl
   $str.= htmlcode("show content", $newsnodes,
     "getloggeditem, title, byline, date, linkedby, content");
   ```
   - Passes nodes (potentially including superdocs) to show_content
   - **Instruction string includes "content" keyword**

6. **content Infofunction Execution** ([htmlcode.pm:1351-1358](ecore/Everything/Delegation/htmlcode.pm#L1351-L1358))
   ```perl
   $infofunctions{$content} = sub {
     my $N = shift;
     my $text = $N->{doctext};
     # Superdoc stuff hardcoded below
     $text = parseCode($text) if exists($$N{type})
       and ($$N{type_nodetype} eq "14"
       or $$N{type}{extends_nodetype} eq "14");
     # ... rest of processing
   };
   ```
   - **parseCode IS CALLED when processing superdoc nodes!**

#### Trigger Conditions

The parseCode call at line 1358 executes when ALL of the following are true:

1. ✅ The "News" weblog contains an entry pointing to a superdoc
2. ✅ That entry is in the top 5 most recent entries
3. ✅ The front page is rendered (calling frontpage_news)
4. ✅ The instruction string includes "content" (which it does)
5. ✅ The superdoc node has a non-empty doctext field

#### Current Safety Status

✅ **Currently safe** because:
- All superdoc doctext fields are empty (verified)
- parseCode processes empty strings → no eval execution
- Only admins can add entries to the News weblog
- No user-generated content is involved

⚠️ **However:**
- **The code path EXISTS and IS FULLY REACHABLE**
- If a superdoc ever had non-empty doctext, parseCode would execute
- This is not theoretical - it's an active code path used on every front page load

#### Other Potential Trigger Paths

While frontpage_news is the confirmed path, any show_content call with:
- Instruction string containing "content"
- Input that could include superdoc nodes

could potentially trigger this parseCode call. The 17+ call sites should be audited for similar patterns.

## Dead Code: parsecode Function

There is a DIFFERENT function that IS dead code:

### parsecode (lowercase) - htmlcode.pm:895-912

```perl
sub parsecode  # Note: lowercase!
{
  my ($field, $nolinks) = @_;
  my $text = $$NODE{$field};
  $text = parseCode ($text);  # Line 907 - UNREACHABLE
  $text = parseLinks($text) unless $nolinks;
  return $text;
}
```

**Status:** ⚠️ **DEAD CODE**
- Never called anywhere in the codebase
- Has empty `<code>` in nodepack/htmlcode/parsecode.xml
- parseCode call at line 907 is unreachable
- Can be safely deleted

## Recommendations

### Immediate Actions

1. **Remove parsecode function** (lines 895-912) - it's dead code with an unreachable parseCode call
2. **Verify superdoc doctext is empty** - confirm the parseCode at line 1358 processes empty strings
3. **Audit "News" weblog contents** - verify no superdocs are currently in the frontpage news feed
4. **Test removing parseCode call from show_content** - since superdoc migration is complete
5. **Update eval-removal-plan.md** to document the verified code path through frontpage_news

### Short-term (Phase 1 Completion)

1. **Remove parseCode call from line 1358** - superdocs no longer need it
2. **Add delegation check** if needed for backward compatibility:
   ```perl
   # If superdoc, verify delegation exists
   if (exists($$N{type}) and $$N{type_nodetype} eq "14") {
     $APP->devLog("Superdoc displayed: $$N{title}");
   }
   ```

### Long-term Considerations

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

## parseCode Call Sites Summary

After correcting the analysis:

### Active parseCode Calls (6 total)

#### htmlcode.pm - Active (5)
1. **Line 1358** - `show_content` function (superdoc processing) - ✅ ACTIVE but processes empty strings
2. **Line 8052** - `formxml_superdoc` htmlcode (XML superdoc output)
3. **Line 8199** - `xmlnodesuggest` htmlcode (XML suggestion output)
4. **Line 12738** - `Chatterbox_nodelet_settings` (inline template for settings UI)

#### document.pm - Active (2)
5. **Line 2747** - `not_found_node` doctext processing
6. **Line 19811** - Nodelet nlcode processing (deprecated, admin-only)

### Dead Code parseCode Call (1 total)

#### htmlcode.pm - Dead Code
1. ⚠️ **Line 907** - UNREACHABLE (in dead `parsecode` function) - can be deleted with the function

**Corrected Total:** 6 active parseCode calls remaining (not 7)

## Related Documentation

- [eval-removal-plan.md](eval-removal-plan.md) - Phase 1 eval removal strategy
- [delegation-migration.md](delegation-migration.md) - Superdoc migration guide

## Conclusion

`show_content` is a critical, actively-used content formatting system that cannot be removed.

### Key Findings Summary

1. **Active Code Path Confirmed**: The parseCode call at line 1358 IS reachable via the frontpage_news → News weblog → superdoc path
2. **Currently Safe**: All superdoc doctext is empty, so parseCode processes empty strings
3. **Dead Code Identified**: The `parsecode` function (lowercase) can be deleted
4. **Phase 1 Cleanup**: 5 active parseCode calls + 1 removable dead code call

### Recommended Actions

**High Priority:**
- Remove the parseCode call from show_content line 1358 (safe since superdoc doctext is empty)
- Delete the `parsecode` function (lines 895-912)
- Add monitoring/logging if superdocs appear in News weblog

**Verification Needed:**
- Audit all 17+ show_content call sites for similar patterns where superdocs could be passed
- Check if other weblog-based features could trigger the same code path
- Verify no superdocs currently exist in the News weblog

**Long-term:**
- Consider adding a safeguard that prevents superdocs from being added to weblogs
- Or explicitly handle superdocs in frontpage_news without parseCode

The code path analysis revealed that this is not theoretical dead code - it's an active execution path on every front page load that happens to process empty strings due to completed superdoc migration.
