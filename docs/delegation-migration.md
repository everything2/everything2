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
   - Use lowercase with underscores, replacing spaces and special characters
   - "Everything Statistics" → `sub everything_statistics`
   - "Usergroup Picks" → `sub usergroup_picks`
   - "News for Noders" → `sub news_for_noders`

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
