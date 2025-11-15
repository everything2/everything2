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
- **All nodetypes** have a `readers_user` field that controls who can read the node
- **restricted_superdoc**: Uses `readers_user` field (typically set to the 'gods' usergroup node_id)
  - The 'gods' usergroup is Everything2's administrative user group
  - Only members of the usergroup specified in `readers_user` can access these nodes
- **oppressor_superdoc**: Hardcoded to Content Editors usergroup
- Delegation functions inherit these permission checks from the display function

**Note**: "Gods" is the historical name for Everything2's administrative user group. Administrative functions check membership using `$APP->isAdmin($USER)`.

#### Development Goals - Permission Simplification

**Goal**: Reduce dependency on administrative ('gods') permissions and transition user management functions to the 'Content_Editors' usergroup.

**Rationale**:
- Administrative permissions should be reserved for system-level operations
- Most content and user management tasks don't require full admin access
- Content Editors already handle editorial workflow and can be trusted with expanded responsibilities
- Distributing permissions improves security through principle of least privilege

**Target Changes**:
- Migrate user management functions currently requiring admin to Content Editors
- Review restricted_superdocs to identify candidates for reclassification to oppressor_superdoc
- Create new permission checking patterns that distinguish between system admin and editorial admin
- Document which operations genuinely require 'gods' access vs. editorial oversight

#### Development Goals - Template System Migration to React

**Goal**: Eliminate server-side template rendering and replace with modern React-based UI components.

**Important Context - Two Distinct Template Systems**:

Everything2 has **two separate templating systems** that must be understood:

1. **Legacy E2 Templates** (parsed by `Everything::HTML::parseCode`):
   - `[% perl %]` blocks embedded in database nodes (superdocs, restricted_superdocs, etc.)
   - eval() execution of database-stored code
   - **Current migration target**: Moving these to delegation functions
   - Located in: Database nodes (nodepack/*.xml files)

2. **Mason2 Templates** (used by `Everything::Page`, `Everything::Mason`):
   - Modern Mason2 templating framework
   - Filesystem-based templates in `templates/` directory
   - Already version-controlled and testable
   - Separate from the legacy E2 template system
   - **Not part of current delegation migration**

**This migration focuses on Legacy E2 Templates only.** Mason2 templates are a separate, already-modernized system.

**Rationale for React Migration**:
- Server-side template rendering is being phased out in favor of client-side React
- Current delegation to Perl functions is an interim step, not the final architecture
- React provides better user experience with dynamic updates, no page reloads
- Separation of concerns: API backend (Perl) + UI frontend (React)
- Modern development workflow with component reusability and testing
- Both legacy E2 templates (after delegation) and Mason2 templates are candidates for eventual React conversion

**Migration Path (Legacy E2 Templates)**:

1. **Phase 1 (Current)**: Migrate legacy E2 templates to Perl delegation functions
   - Moves code from database (`[% perl %]` blocks) to version-controlled filesystem
   - Enables testing, profiling, and code review
   - Maintains existing server-side rendering temporarily
   - **Status**: In progress (4/129 superdocs migrated this week)

2. **Phase 2 (Future)**: Replace delegation functions with React components + REST APIs
   - Convert delegation functions to REST API endpoints
   - Build React components that consume the APIs
   - Progressive enhancement: Start with high-value, frequently-used features
   - Maintain delegation functions for gradual migration
   - Eventually, Mason2 templates can also be replaced with React where appropriate

3. **Phase 3 (Long-term)**: Full React migration
   - Complete replacement of server-rendered content with React SPA
   - Retire delegation functions as corresponding React components are deployed
   - Retire or minimize Mason2 template usage where React provides better UX
   - Modern, responsive, mobile-first user interface

**Target Changes**:
- **Current focus**: Complete Phase 1 (legacy E2 template → delegation migration)
- Prioritize delegations that are good candidates for React conversion
- Design REST APIs alongside delegation functions where practical
- Document which delegations are temporary vs. long-term
- Create React component architecture that mirrors Everything2's node structure
- Build progressive enhancement strategy (works without JS, better with JS)
- Consider Mason2 templates separately for future React conversion planning

**Example Flow (Legacy E2 Templates)**:
```
Today:        Database [% code %] → parseCode eval() → HTML
Phase 1:      Delegation function → HTML (current migration)
Phase 2-3:    REST API → JSON → React component → Dynamic UI
```

**Example Flow (Mason2 Templates)**:
```
Today:        templates/*.mi → Mason2 → HTML
Future:       REST API → JSON → React component → Dynamic UI (where beneficial)
```

#### Development Goals - Opcode Framework Migration to REST APIs

**Goal**: Migrate the legacy opcode framework from server-side delegation functions to modern REST API endpoints once pages transition to React.

**What are Opcodes?**

Opcodes are Everything2's operation handlers, triggered by the `op={operation}` URL parameter:
- **Examples**: `op=login`, `op=vote`, `op=message`, `op=new`
- **Location**: `Everything::Delegation::opcode` module
- **Current State**: 47 opcode delegation functions (already migrated from database)
- **Function**: Handle form submissions, user actions, state changes
- **Pattern**: Server receives `op=login` → calls `opcode::login()` → processes → redirects/renders

**Why This Matters**:
- Opcodes are **action handlers**, not display functions
- Perfect candidates for REST API conversion: `POST /api/login` instead of `?op=login`
- Currently tightly coupled to server-side HTML rendering
- React apps need API endpoints, not opcode query parameters
- Modern web architecture separates API (backend) from UI (frontend)

**Current Architecture**:
```perl
# Everything::Delegation::opcode
sub login {
    my ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP) = @_;
    # Validate credentials
    # Set session cookie
    # Redirect to page
}
```

**Challenges - Deeper Refactoring Required**:

Unlike superdocs (which just render HTML), opcodes require deeper changes:

1. **HTML/Template Support**: Current templates and HTML generation assume opcodes exist
   - Forms use `<form action="?op=login">`
   - Links use `?op=vote&node_id=123`
   - Redirects use `?op=message&for_user=456`

2. **Session Management**: Opcodes handle authentication, cookies, redirects
   - Need to separate session logic from rendering logic
   - API endpoints need stateless authentication (JWT/tokens)
   - Current approach mixes authentication with page rendering

3. **Error Handling**: Opcodes redirect or render error pages
   - REST APIs return JSON error responses
   - React components handle error display
   - Need standard error response format

4. **CSRF Protection**: Forms currently use `op=` with session validation
   - Need modern CSRF token approach for APIs
   - API authentication separate from form submission

**Migration Path**:

1. **Phase 1 (Completed)**: Migrate opcodes from database to delegation functions
   - **Status**: ✅ Complete (47 nodes migrated)
   - Enables testing, profiling, code review
   - Still uses legacy server-side pattern

2. **Phase 2 (Requires React Migration)**: Design REST API equivalents
   - Map opcodes to RESTful endpoints:
     - `op=login` → `POST /api/auth/login`
     - `op=vote` → `POST /api/nodes/{id}/vote`
     - `op=message` → `POST /api/messages`
     - `op=new` → `POST /api/nodes`
   - Design JSON request/response formats
   - Implement authentication middleware (JWT/session tokens)
   - Maintain opcode delegation for gradual migration

3. **Phase 3 (React Components)**: Update HTML/templates to use APIs
   - React forms call REST APIs instead of `?op=` URLs
   - Remove opcode query parameter handling from templates
   - Implement client-side error handling
   - Progressive enhancement: Forms work with/without JavaScript

4. **Phase 4 (Cleanup)**: Retire opcode delegation functions
   - Once all forms/actions use REST APIs
   - Remove `Everything::Delegation::opcode` module
   - Clean up legacy HTML generation code
   - Simplify request routing

**Target Changes**:
- **Prerequisite**: React migration must be substantially complete
- Design RESTful API architecture alongside React component development
- Maintain backward compatibility during transition
- Document API endpoints as opcodes are converted
- Create API client library for React components
- Implement proper HTTP status codes (200, 201, 400, 401, 403, 404, etc.)
- Use JSON for all API responses (no HTML generation in API handlers)

**Example Flow Evolution**:
```
Today (Legacy):
User submits form → ?op=login → opcode::login() → HTML redirect → Page render

Phase 2-3 (Transition):
User submits form → ?op=login OR POST /api/auth/login
Both paths supported during migration

Phase 4 (Future):
React component → POST /api/auth/login → JSON response → React update
```

**Priority**: This migration should begin **after** substantial React frontend conversion is complete, as it requires:
- React components ready to consume APIs
- API authentication infrastructure
- Client-side routing and state management
- HTML templates no longer generating opcode forms

**Related Work**:
- REST API infrastructure already exists (15+ endpoints for React nodelets)
- Can use existing patterns as templates for opcode conversion
- Opcode delegation functions provide clean starting point for API logic extraction

#### Development Goals - MySQL Modernization (8.0 → 8.4)

**Goal**: Upgrade from MySQL 8.0 to MySQL 8.4 to avoid extended support charges and deprecated features.

**Business Rationale**:
- **Amazon RDS**: MySQL 8.0 support is being deprecated, will incur extended support charges
- **Security**: MySQL 8.4 includes important security patches and improvements
- **Performance**: Newer optimizer improvements and query performance enhancements
- **Long-term viability**: Stay on supported MySQL versions to avoid forced migrations

**Current Issues**:

1. **sql_mode=ALLOW_INVALID_DATES dependency**:
   - MySQL 8.0.x tolerates invalid dates like '0000-00-00' with this mode enabled
   - MySQL 8.4 deprecates this mode and enforces stricter date validation
   - Current database schema relies on invalid date defaults
   - Code may assume invalid dates are possible

2. **Deprecated authentication plugins**:
   - Legacy mysql_native_password authentication method being phased out
   - Need to migrate to caching_sha2_password or auth_socket
   - May require connection library updates (DBD::mysql)

3. **Schema defaults**:
   - DATE/DATETIME columns with '0000-00-00' defaults
   - TIMESTAMP columns with invalid default values
   - Need to identify all affected columns across all tables

**Technical Challenges**:

1. **Date Column Audit**:
   - Identify all DATE, DATETIME, TIMESTAMP columns in schema
   - Find columns with '0000-00-00' or invalid defaults
   - Determine business logic meaning of "invalid" dates (unknown? not set? legacy data?)

2. **Code Audit**:
   - Search codebase for assumptions about invalid dates
   - Check for comparisons with '0000-00-00'
   - Identify code that inserts/updates with invalid dates
   - Review date parsing and validation logic

3. **Default Value Strategy**:
   - NULL for unknown dates (most common approach)
   - Sentinel values like '1970-01-01' (epoch) for special cases
   - NOT NULL with valid defaults (e.g., '2000-01-01', CURRENT_TIMESTAMP)
   - Application-level handling of "no date set" state

4. **Authentication Migration**:
   - Update database user authentication methods
   - Test connection pooling (Apache::DBI compatibility)
   - Update deployment scripts and connection strings
   - Verify DBD::mysql version supports new auth methods

**Migration Path**:

1. **Phase 1: Audit and Assessment**
   - Run schema audit to identify all date columns with invalid defaults
   - Grep codebase for '0000-00-00', date comparisons, date insertions
   - Document all tables/columns affected
   - Categorize by risk (high-traffic tables, critical business logic)
   - Test current code against MySQL 8.4 in development environment
   - Document breaking changes and errors

2. **Phase 2: Schema Migration**
   - Create ALTER TABLE statements to fix invalid defaults
   - Decide NULL vs. valid default strategy per column
   - Test schema changes in development
   - Create rollback plan
   - Update existing rows with invalid dates:
     - `UPDATE table SET date_column = NULL WHERE date_column = '0000-00-00'`
   - Create migration scripts with comprehensive testing

3. **Phase 3: Code Updates**
   - Fix code that inserts invalid dates
   - Update date validation logic
   - Replace '0000-00-00' comparisons with IS NULL checks
   - Add proper date handling for "not set" states
   - Update ORMs/query builders if needed
   - Run test suite to catch regressions

4. **Phase 4: Authentication Update**
   - Update MySQL users to caching_sha2_password
   - Test all database connections (web app, scripts, cron jobs)
   - Update DBD::mysql if needed (minimum version 4.050)
   - Test Apache::DBI connection pooling
   - Document new authentication requirements

5. **Phase 5: MySQL Upgrade**
   - Test full application stack on MySQL 8.4 in staging
   - Performance testing and query plan analysis
   - Deploy schema changes to production
   - Upgrade RDS instance to MySQL 8.4
   - Monitor for errors and performance issues
   - Have rollback plan ready

**Target Changes**:
- Remove sql_mode=ALLOW_INVALID_DATES dependency
- All date columns have valid defaults (NULL or proper dates)
- Code uses NULL checks instead of '0000-00-00' comparisons
- Modern authentication methods (caching_sha2_password)
- Full compatibility with MySQL 8.4 LTS
- Documentation of date handling conventions

**SQL Audit Commands**:
```sql
-- Find columns with invalid date defaults
SELECT TABLE_NAME, COLUMN_NAME, COLUMN_DEFAULT, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'everything2'
  AND DATA_TYPE IN ('date', 'datetime', 'timestamp')
  AND (COLUMN_DEFAULT = '0000-00-00'
       OR COLUMN_DEFAULT = '0000-00-00 00:00:00'
       OR COLUMN_DEFAULT LIKE '%0000-00-00%')
ORDER BY TABLE_NAME, COLUMN_NAME;

-- Find rows with invalid dates
-- Run per table: SELECT COUNT(*) FROM table WHERE date_column = '0000-00-00';
```

**Code Audit Patterns**:
```bash
# Find invalid date literals
grep -r "0000-00-00" ecore/ --include="*.pm"

# Find sql_mode references
grep -ri "ALLOW_INVALID_DATES" .

# Find date insertions/updates
grep -r "INSERT\|UPDATE" ecore/ --include="*.pm" | grep -i "date\|timestamp"
```

**Priority**: Medium-High
- **Timeline**: Must complete before MySQL 8.0 extended support charges begin
- **Risk**: High (breaking schema changes, potential data loss if mishandled)
- **Dependencies**: Requires comprehensive testing infrastructure
- **Estimated Effort**: 4-6 weeks
  - Week 1: Audit (schema + code)
  - Week 2-3: Schema migration + testing
  - Week 3-4: Code updates + testing
  - Week 5: Authentication updates
  - Week 6: Production upgrade + monitoring

**Related Work**:
- Testing infrastructure already in place (t/*.t files)
- Can add specific date handling tests
- Schema is already documented in database migrations
- Docker development environment can test MySQL 8.4 locally

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
- [ ] **Check for module dependencies** - identify any `use Module;` statements in the original code
- [ ] Create delegation function in `ecore/Everything/Delegation/document.pm`
- [ ] **Add use statements at TOP of file** - if code requires modules (e.g., Time::HiRes, JSON::XS):
  - Add `use Module;  # Used in: function_name` at the top of document.pm (after `use DateTime;`)
  - **NEVER put `use` statements inside the function** (wrong: causes compile-time statements at runtime)
  - Remove any `use` statements from inside the function body
- [ ] Include static HTML text at beginning of function
- [ ] Keep bracket notation for links (will be parsed by parseLinks)
- [ ] **Initialize all variables** - `my $text = undef;` or `my $text = '';` (critical for security)
- [ ] Remove "bugs go to" lines
- [ ] Update node XML with static text only
- [ ] Run Perl::Critic verification: `perlcritic --severity 1 --theme bugs ecore/Everything/Delegation/document.pm`
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
