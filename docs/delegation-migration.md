# Database Node Delegation Migration

## Overview

This document describes the process of migrating embedded Perl code from database nodes (primarily superdocs and restricted_superdocs) to delegation functions in the filesystem.

## Purpose

Moving code from the database to delegation functions provides:
- Version control and git history tracking
- Easier code review through pull requests
- Ability to run tests on the code
- Modern development workflow
- Separation of code from data

## Nodetype System and Delegation Flow

### Nodetype Hierarchy

Everything2 uses a nodetype inheritance system via the `extends_nodetype` parameter. Most nodetypes chain up to `document`:

- **document** - Base type for user-managed documents and system pages
- **superdoc** - Extends document, system documentation pages
- **restricted_superdoc** - Extends document, adds permission control via `readers_user` (typically a usergroup)
- **oppressor_superdoc** - Extends document, readable only by Content Editors usergroup

### Display Function Resolution - Two-Level Delegation

All nodetypes have `display` and `edit` displaytypes by default. Since every nodetype chain ultimately extends `node`, they also inherit any displaytypes that exist on that nodetype (such as `basicedit`).

The system uses **two levels of delegation**:

#### Level 1: Nodetype Delegation (Everything::Delegation::htmlpage)

1. The system looks for a nodetype delegation function using the pattern: `$NODETYPE . '_' . $DISPLAYTYPE . '_page'`
   - Example: For a superdoc with displaytype 'display', it looks for `superdoc_display_page`

2. If the specific delegation function doesn't exist, it follows the `extends_nodetype` chain upward
   - Example: `restricted_superdoc` with displaytype 'display':
     - First looks for `restricted_superdoc_display_page`
     - Not found, so checks parent: restricted_superdoc extends superdoc
     - Looks for `superdoc_display_page`

#### Level 2: Node-Specific Delegation (Everything::Delegation::document)

3. For nodetypes with embedded code (like superdocs), instead of calling the legacy `parseCode()` function:
   - The nodetype delegation checks if `Everything::Delegation::document` can handle this specific node
   - If a node-specific delegation function exists (based on the node's title), it calls that function
   - Example: A superdoc titled "Everything Statistics" would call `everything_statistics()`

4. The node-specific delegation function receives context variables: `($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP)`
   - These emulate the local symbols available inside `Everything::HTML`
   - Allows code to work the same as if running inside an eval() in the Everything::HTML context

5. The delegation function returns HTML (with bracket notation like `[node title]`)

6. Post-processing through `parseLinks` converts bracket notation to actual links
   - **Exception**: `superdocnolinks` nodetype skips link parsing (hence "nolinks" in name)

7. The final HTML is displayed to the user

### Permission Handling

Permissions are handled by the nodetype, not the delegation:
- **restricted_superdoc**: Uses `readers_user` field (usually a usergroup node_id)
- **oppressor_superdoc**: Hardcoded to Content Editors usergroup
- Delegation functions inherit these permission checks from the display function

## Migration Process

### 1. Locate the Node XML

Find the node XML file in the nodepack directory:
- superdocs: `nodepack/superdoc/`
- restricted_superdocs: `nodepack/restricted_superdoc/`
- documents: `nodepack/document/` (rarely need delegation - these are typically user-managed)

### 2. Extract the Code

Look for `[% ... %]` Mason-style Perl blocks in the `<doctext>` field.

### 3. Create Delegation Function

Since most nodetypes chain up to `document`, all delegation functions go in:
- **`ecore/Everything/Delegation/document.pm`**

This includes:
- superdocs (extends document)
- restricted_superdocs (extends document)
- oppressor_superdocs (extends document)
- documents

**Note**: `Everything::Delegation::superdoc` does not exist. All delegation functions are in `document.pm`.

#### Function Naming Convention

The system uses a two-tier lookup:

1. **Nodetype delegation pattern**: `$NODETYPE . '_' . $DISPLAYTYPE . '_page'`
   - Example: `superdoc_display_page`, `restricted_superdoc_display_page`
   - These are generic handlers for the nodetype

2. **Node-specific delegation**: Based on the node's title
   - Convert to lowercase
   - Replace spaces with underscores
   - Replace any characters not valid in Perl function names with underscores
   - Examples:
     - "Everything Statistics" → `sub everything_statistics`
     - "Usergroup Picks" → `sub usergroup_picks`
     - "News for Noders" → `sub news_for_noders`
     - "Everything's Most Wanted" → `sub everything_s_most_wanted` (apostrophe becomes underscore)
     - "User Settings (Advanced)" → `sub user_settings__advanced_` (parentheses become underscores)

**Important**: Valid Perl function name characters are: letters (a-z, A-Z), digits (0-9), and underscores. All other characters (apostrophes, hyphens, parentheses, etc.) are converted to underscores.

Most migrations create **node-specific delegations** based on the node title, which the nodetype delegation handler will call.

### 4. Function Structure

```perl
sub function_name
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    # Always initialize variables (critical for mod_perl)
    my $text = '';

    # Include static HTML text from doctext first
    $text .= '<p>Static text from the original doctext...</p>';

    # Add dynamic code logic
    # ...

    return $text;
}
```

### 5. Handle Static Text

**IMPORTANT**: Include all static HTML text from the node's doctext at the beginning of the function. The delegation function's output must match what `display_$TYPE` would produce.

Keep bracket notation as-is for links:
- `[usergroup]` - links to node titled "usergroup"
- `[nodelet settings|nodelet]` - links to "nodelet settings" with text "nodelet"

These will be converted to actual links when the output is passed through `parseLinks`.

### 6. Code Transformations

#### Variable Access
- Mason/XML uses hash dereferencing: `$$NODE{title}`
- Keep this style in delegation functions

#### Function Calls
- `getNode()`, `linkNode()`, `htmlcode()` remain the same
- Database queries: `$DB->sqlSelect()`, `$DB->sqlSelectMany()`, etc.

#### Module Imports (use statements)

**IMPORTANT**: When delegating code that requires Perl modules, add `use` statements at the top of `document.pm`, NOT inside the function.

**Why:**
- Functions are called repeatedly for every request
- `use` statements should be at compile time, not runtime
- Keeps imports organized and visible
- Better performance (modules loaded once)

**Pattern:**

```perl
# At top of ecore/Everything/Delegation/document.pm
use strict;
use warnings;
use Everything::Globals;

# Import symbols from Everything::HTML
our ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP);
*DB = \$Everything::HTML::DB;
# ... other symbol mappings ...

use DateTime;  # Used in: settings
use JSON::XS;  # Used in: api_response, json_export

# ... rest of file with delegation functions ...
```

**Adding a New Module:**

1. Add the `use` statement at the top with existing imports
2. Add a comment noting which function(s) use it: `# Used in: function_name`
3. If multiple functions use it, list them: `# Used in: settings, user_profile, preferences`

**Example - Wrong:**

```perl
sub settings
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    use DateTime;  # WRONG - don't use inside function
    my $time = DateTime->now();
    # ...
}
```

**Example - Correct:**

```perl
# At top of document.pm
use DateTime;  # Used in: settings

# ... later in file ...

sub settings
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $time = DateTime->now();  # Module already loaded
    # ...
}
```

**Common Modules:**
- `DateTime` - Date/time operations
- `JSON::XS` - JSON encoding/decoding
- `URI::Escape` - URL encoding
- `Digest::MD5` - Hashing
- `POSIX` - POSIX functions

#### Template Language: Htmlcode Calls

The Everything2 template language includes a special syntax for calling htmlcode functions:

**Syntax:** `[{htmlcode_name:arg1,arg2,arg3}]`

**Important:** This is **NOT a link** - it's a function call to an htmlcode function.

**In Delegation Functions:**
- These calls are made using the `htmlcode()` function
- Available due to symbol table mapping at the top of `document.pm`
- Arguments are comma-separated in template syntax, passed as separate parameters

**Examples:**

```perl
# Template syntax in static HTML
[{varcheckbox:settings_useTinyMCE,Use WYSIWYG content editor}]

# Equivalent delegation function call
htmlcode('varcheckbox', 'settings_useTinyMCE', 'Use WYSIWYG content editor')

# Template syntax with multiple arguments
[{varsComboBox:textareaSize,0, 0,Small, 1,Medium, 2,Large}]

# Equivalent delegation function call
htmlcode('varsComboBox', 'textareaSize', '0', '0', 'Small', '1', 'Medium', '2', 'Large')

# Template syntax in dynamic code
$text .= '[{openform:pagebody}]';

# Better: Direct call in delegation
htmlcode('openform', 'pagebody');
```

**When Migrating:**
- Keep `[{...}]` syntax in static HTML text strings (will be parsed)
- In dynamic code, prefer direct `htmlcode()` calls for clarity
- Arguments split on commas, so `arg1,arg2,arg3` becomes three parameters

**Common htmlcode Functions:**
- `openform`, `closeform` - Form helpers
- `varcheckbox`, `varcheckboxinverse` - User preference checkboxes
- `varsComboBox` - User preference dropdown selectors
- `verifyRequestForm` - CSRF protection
- `settingsDocs` - Settings page documentation

#### Bracket Links in Dynamic Code
Use bracket notation for links that will be parsed:
```perl
$text .= '<p>See [News Archives|archive] for more.</p>';
```

#### Remove Bug Attribution
Remove any lines like:
- "Bugs go to [username]"
- "Report bugs to [username]"

Defects are now tracked in GitHub, not assigned to individual developers.

#### Multiple Code Blocks

Many nodes contain multiple `[% ... %]` code blocks interleaved with static HTML text. When migrating these, create a **single delegation function** that combines all blocks and text in order.

**Challenges:**

1. **Variable Reuse**: Variables may be declared in one block and used in another
   - **CRITICAL**: Reinitialize variables between blocks to prevent mod_perl persistence issues
   - Track which variables are used across blocks
   - Example: If `my $str` appears in block 1 and block 3, reinitialize it: `$str = '';` at the start of block 3

2. **Early Returns**: Code blocks may have `return` statements to exit early
   - Convert early returns to conditional logic that skips subsequent code
   - Save return values to the main output variable
   - Only return at the very end of the function

3. **Conditional Display**: Blocks may conditionally add content
   - Preserve the conditional logic
   - Use the main output variable to accumulate all content
   - Append both static text and dynamic output in order

**Pattern for Multiple Blocks:**

```perl
sub function_name
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $text = '';

    # Block 1: Early check with return
    if ($APP->isGuest($USER)) {
        $text .= '<p>You need to sign in...</p>';
        return $text;  # Early exit is OK here
    }

    # Block 1 continued: Initialization code
    $PAGELOAD->{pageheader} = htmlcode('settingsDocs');
    htmlcode('openform', -id=>'pagebody');

    # Static HTML from doctext
    $text .= '<h2>Section Header</h2>';
    $text .= '<fieldset><legend>Subsection</legend>';

    # Block 2: Dynamic content
    my $str = '';  # Local variable for this block
    # ... block 2 logic ...
    $text .= $str;  # Append block output to main text

    # More static HTML
    $text .= '</fieldset>';
    $text .= '<h2>Another Section</h2>';

    # Block 3: More dynamic content
    $str = '';  # REINITIALIZE - critical for mod_perl
    my @list = ();  # Local variable for this block
    # ... block 3 logic ...
    $text .= $str;  # Append block output to main text

    # Final static HTML
    $text .= '<div>Footer</div>';

    return $text;
}
```

**Example - Converting Multiple Returns:**

Original code with early return:
```perl
[% return '<p>Error</p>' if $condition; %]
<p>Static text</p>
[% my $output = doSomething(); $output; %]
```

Converted to single function:
```perl
my $text = '';

if ($condition) {
    $text .= '<p>Error</p>';
    return $text;  # Early return OK
}

$text .= '<p>Static text</p>';

my $output = doSomething();
$text .= $output;

return $text;
```

**Variable Reinitialization Checklist:**

When a variable appears in multiple blocks:
- [ ] First occurrence: `my $var = '';` (declaration with initialization)
- [ ] Subsequent blocks: `$var = '';` (reinitialization without `my`)
- [ ] Check: Is the variable used across blocks intentionally, or should each block have its own scope?
- [ ] Common variables to watch: `$str`, `$csr`, `@list`, `%hash`

### 7. Variable Initialization and mod_perl Persistence

**CRITICAL SECURITY AND BEST PRACTICE CONCERN**

mod_perl optimizes Perl runtime performance by retaining the last values of lexical variables between executions within the same Apache process. This behavior differs significantly from the legacy `eval()` approach used in `parseCode()`:

- **In eval()**: Variables are created fresh for each execution
- **In Perl modules** (delegation functions): Variables persist between requests in the same Apache process

#### The Problem

When you declare a variable without initialization:
```perl
my $text;
$text .= "Content!";
```

This code will:
1. First request: `$text = "Content!"`
2. Second request: `$text = "Content!Content!"`
3. Third request: `$text = "Content!Content!Content!"`
4. Continues growing until the Apache process is reaped by limits

#### Security Implications

This is a **security vulnerability** because:
- Variables can store content from previous users' requests
- Data from one user can leak into another user's view
- Sensitive information may be exposed across sessions

#### The Solution

**Always initialize variables when declaring them:**

```perl
# Best practice - works for all types
my $text = undef;

# For strings specifically
my $text = '';

# For arrays
my @items = ();

# For hashes
my %data = ();
```

**Using `undef` is the safest default** as it matches Perl's natural default state and works for all variable types.

#### Code Review Checklist

When migrating code or reviewing delegations:
- [ ] Every `my` declaration should include an initializer
- [ ] Use `= undef` for general variables
- [ ] Use `= ''` only when you're certain it's a string
- [ ] Use `= ()` for arrays and hashes
- [ ] Check that variables aren't accumulating data across requests

#### Exceptions

The only time you intentionally avoid initialization is when using this behavior for caching, such as in `Everything::Nodecache`, where long-lived objects are deliberately persisted across requests.

#### Avoid Perl Magic Variables

**CRITICAL**: Now that delegation code is no longer isolated in `eval()` blocks, you must avoid using Perl's built-in magic variable names. These variables have special meanings in Perl and can cause unexpected behavior or conflicts.

**Common Magic Variables to Avoid:**

```perl
# Process and User IDs - AVOID THESE
$UID / $<    # Real user ID (causes conflicts!)
$EUID / $>   # Effective user ID
$GID / $(    # Real group ID
$EGID / $)   # Effective group ID

# Other special variables
$_           # Default scalar (avoid unless intentionally using)
$a, $b       # Used by sort() function
$&, $`, $'   # Regex match variables (deprecated, slow)
@_           # Subroutine arguments (only use in specific contexts)
%ENV         # Environment variables (read-only access OK)
$0           # Program name
$!           # System error
$?           # Child process status
$$           # Process ID
```

**Instead:**

```perl
# WRONG - uses magic variable
my $UID = $$USER{node_id} || 0;

# CORRECT - use descriptive name
my $user_id = $$USER{node_id} || 0;
my $current_uid = $$USER{node_id} || 0;
my $uid = $$USER{node_id} || 0;  # OK if lowercase and contextual
```

**Why This Matters:**

In `eval()` blocks, magic variables were somewhat isolated. In delegation functions:
- Magic variables are global to the Perl process
- They can cause hard-to-debug issues
- Some (like `$UID`) actively interfere with Perl's behavior
- Code becomes less portable and maintainable

**Rule of Thumb:**
- Use lowercase for regular variables: `$uid`, `$user_id`
- Avoid ALL-CAPS variable names except for constants
- Never use `$UID`, `$EUID`, `$GID`, `$EGID`
- Check against Perl's magic variable list if unsure

### 8. Update Node XML

Replace the `<doctext>` content with just the static HTML (keeping bracket notation):

```xml
<node>
  <doctext>&lt;p&gt;Static text with [bracket links].&lt;/p&gt;</doctext>
  <node_id>123456</node_id>
  <title>Node Title</title>
  <type_nodetype>14</type_nodetype>
</node>
```

### 9. Test

1. Build the Docker container: `./docker/devbuild.sh`
2. Access the node in the browser at `http://localhost:9080`
3. Verify the output matches the original functionality

## Examples

### Example 1: Everything Statistics (restricted_superdoc)

**Node Type**: `restricted_superdoc` (extends document)

**Original XML** (nodepack/restricted_superdoc/everything_statistics.xml):
```xml
<doctext>[%
  my $total = $DB->sqlSelect('count(*)', 'node');
  return "<p>Total: $total</p>";
%]</doctext>
```

**Delegation** (ecore/Everything/Delegation/document.pm):
```perl
sub everything_statistics
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $str = '';
    my $total_nodes = $DB->sqlSelect('count(*)', 'node');
    $str .= "<p>Total Number of Nodes: $total_nodes</p>";

    return $str;
}
```

**Updated XML**:
```xml
<doctext></doctext>
```

**Note**: Even though this is a `restricted_superdoc`, the delegation function goes in `document.pm` because restricted_superdoc extends document (most nodetypes chain up to document).

### Example 2: Usergroup Picks (superdoc)

**Node Type**: `superdoc` (extends document)

**Original XML** (nodepack/superdoc/usergroup_picks.xml):
```xml
<doctext>&lt;p&gt;Some text about [usergroup]s.&lt;/p&gt;
[%
  my $data = getData();
  return formatData($data);
%]</doctext>
```

**Delegation** (ecore/Everything/Delegation/document.pm):
```perl
sub usergroup_picks
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    # Include static text with bracket notation
    my $text = '<p>Some text about [usergroup]s.</p>';

    # Add dynamic code
    my $data = getData();
    $text .= formatData($data);

    return $text;
}
```

**Updated XML**:
```xml
<doctext>&lt;p&gt;Some text about [usergroup]s.&lt;/p&gt;</doctext>
```

## Common Patterns

### Variable Initialization

**ALWAYS initialize variables to prevent mod_perl persistence issues:**

```perl
# Strings
my $text = '';
my $html = undef;

# Numbers
my $count = 0;
my $id = undef;

# Arrays
my @items = ();

# Hashes
my %data = ();

# References
my $ref = undef;
```

### Permission Checks
```perl
my $isGod = $APP->isAdmin($USER);
my $isEd = $APP->isEditor($USER);
```

### Query Parameters
```perl
my $view_id = $query->param('view_id');
```

### Database Queries
```perl
my $count = $DB->sqlSelect('count(*)', 'table', 'condition');
my $cursor = $DB->sqlSelectMany('*', 'table', 'condition', 'order by field');
while(my $row = $cursor->fetchrow_hashref()) {
    # process row
}
```

### Links
```perl
# Dynamic node link
my $link = linkNode($NODE);
my $link = linkNode(getNode($node_id));

# Static bracket notation (parsed later)
$text .= '[Node Title|display text]';
```

## Checklist

- [ ] Locate node XML file
- [ ] Identify nodetype (superdoc, restricted_superdoc, oppressor_superdoc, document)
- [ ] Note: All delegation functions go in `document.pm` (most nodetypes chain up to document)
- [ ] Extract code from `[% ... %]` blocks
- [ ] Create delegation function in `ecore/Everything/Delegation/document.pm`
- [ ] **Add use statements at top of file** - if code requires modules, add `use Module;` at top with comment `# Used in: function_name`
- [ ] Include static HTML text at beginning of function
- [ ] Keep bracket notation for links (will be parsed by parseLinks)
- [ ] **Initialize all variables** - `my $text = undef;` or `my $text = '';` (critical for security)
- [ ] Remove "bugs go to" lines
- [ ] Update node XML with static text only
- [ ] Test in Docker environment
- [ ] Verify output matches original

## Delegation Pattern Details

The delegation pattern follows: `$NODETYPE . '_' . $DISPLAYTYPE . '_page'`

### Common Displaytypes

All nodetypes have these displaytypes by default:
- **display** - Standard display mode (most common)
- **edit** - Edit mode
- **basicedit** - Basic editing (inherited from node)

### Resolution Examples

- A superdoc node with displaytype 'display' looks for function: `superdoc_display_page` in `document.pm`
- A restricted_superdoc with displaytype 'display':
  - First tries: `restricted_superdoc_display_page` in `document.pm`
  - Falls back to: `superdoc_display_page` in `document.pm` (via extends_nodetype chain)

**Key point**: Even though the function name includes the nodetype (e.g., `superdoc_display_page`), all these functions are defined in `ecore/Everything/Delegation/document.pm` because most nodetypes chain up to document through the `extends_nodetype` parameter. Legacy display functions in `Everything::HTML` select and call these delegation functions.

## Related Files

- `ecore/Everything/Delegation/document.pm` - All delegation functions go here (superdocs, restricted_superdocs, documents, etc.)
- `ecore/Everything/HTML.pm` - Legacy display functions that call delegation functions; contains `parseLinks` function

**Important**: `Everything::Delegation::superdoc.pm` does not exist. Most nodetypes chain up to `document`, so all delegation functions are in `document.pm`.
