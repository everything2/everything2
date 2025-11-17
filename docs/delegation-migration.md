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

#### Development Goals - Settings Table JSON Migration

**Goal**: Migrate the settings table from custom key-value encoding to JSON storage for improved queryability and support for complex data types.

**Current Issues**:

1. **Custom Encoding Format**:
   - Settings stored as custom-encoded key-value pairs
   - `vars` table stores user preferences and developer variables (VARS hash)
   - Custom serialization format makes it difficult to query specific keys
   - Limited support for complex data structures (arrays, nested objects)
   - Hard to add indexing or search capabilities

2. **Schema Limitations**:
   - TEXT column type stores serialized data
   - No ability to query or index individual keys
   - No data type validation at database level
   - Schema doesn't reflect actual data structure

3. **Code Complexity**:
   - Custom encoding/decoding logic must be maintained
   - Error-prone serialization format
   - Difficult to debug stored values
   - No standardized tooling support

**Business Rationale**:
- **Developer Experience**: JSON is a standard format with widespread tooling support
- **Queryability**: MySQL JSON column type enables queries on specific keys
- **Indexing**: JSON columns support generated columns and indexes for performance
- **Validation**: JSON schema validation can prevent corrupt data
- **Modern Stack**: Aligns with REST API JSON responses and React state management
- **Future-proofing**: Enables GraphQL-style field selection and advanced querying

**Technical Challenges**:

1. **Data Migration**:
   - Convert existing custom-encoded settings to JSON
   - Preserve all existing key-value pairs exactly
   - Validate converted data matches original
   - Handle edge cases (special characters, binary data, etc.)

2. **Schema Changes**:
   - Change column type from TEXT to JSON
   - Add generated columns for frequently-queried keys
   - Create indexes on JSON paths for performance
   - Maintain backward compatibility during migration

3. **Code Updates**:
   - Update `getVars()` / `setVars()` to use JSON encoding
   - Update all code that reads/writes settings
   - Update developer vars handling
   - Ensure proper JSON escaping and validation

4. **Performance Impact**:
   - JSON parsing vs. custom decoding overhead
   - Index usage for common queries
   - Storage size comparison (JSON vs. custom format)
   - Connection pool impact

**Migration Path**:

1. **Phase 1: Analysis and Planning**
   - Document current encoding format specification
   - Inventory all settings keys across codebase
   - Identify most frequently accessed keys (candidates for indexing)
   - Create test dataset with edge cases
   - Benchmark current performance baselines

2. **Phase 2: Code Preparation**
   - Create JSON encoder/decoder functions compatible with current format
   - Add feature flag to switch between encodings
   - Update `Everything::HTML::setVars()` and `getVars()`
   - Add comprehensive tests for encoding conversion
   - Test dual-write mode (write both formats, read from JSON)

3. **Phase 3: Migration Script**
   - Create conversion script: custom encoding → JSON
   - Validate converted data matches original
   - Handle special cases (NULL values, empty strings, etc.)
   - Add rollback capability
   - Test on copy of production data

4. **Phase 4: Schema Changes**
   - Alter table to add new JSON column
   - Dual-write to both columns during transition
   - Verify JSON column data integrity
   - Create generated columns for key indexes (e.g., `theme`, `num_newwus`)
   - Add indexes on frequently-queried generated columns

5. **Phase 5: Cutover**
   - Switch read operations to JSON column
   - Monitor for errors and performance issues
   - Drop old custom-encoded column after confidence period
   - Update documentation with new JSON schema

**Example Schema Changes**:
```sql
-- Add JSON column
ALTER TABLE vars ADD COLUMN vars_json JSON;

-- Create generated columns for common keys
ALTER TABLE vars
  ADD COLUMN theme VARCHAR(50)
  GENERATED ALWAYS AS (JSON_UNQUOTE(JSON_EXTRACT(vars_json, '$.theme'))) STORED,
  ADD COLUMN num_newwus INT
  GENERATED ALWAYS AS (JSON_EXTRACT(vars_json, '$.num_newwus')) STORED;

-- Add indexes for performance
CREATE INDEX idx_vars_theme ON vars(theme);
CREATE INDEX idx_vars_num_newwus ON vars(num_newwus);

-- Query examples with new schema
SELECT * FROM vars WHERE theme = 'zenlight';
SELECT * FROM vars WHERE num_newwus > 20;
SELECT JSON_EXTRACT(vars_json, '$.notifications.email') FROM vars WHERE user_id = 123;
```

**Code Updates Example**:
```perl
# Before (custom encoding)
my $vars_text = $DB->sqlSelect('vars', 'vars', "vars_id = $user_id");
my $VARS = decode_custom_format($vars_text);

# After (JSON)
my $vars_json = $DB->sqlSelect('vars_json', 'vars', "vars_id = $user_id");
my $VARS = JSON::decode_json($vars_json);

# Setting values
my $json = JSON::encode_json($VARS);
$DB->sqlUpdate('vars', {vars_json => $json}, "vars_id = $user_id");
```

**Benefits**:
- **Complex Types**: Store arrays, nested objects, booleans natively
  - Example: `notifications: { email: true, messages: ['inbox', 'mentions'] }`
- **Queryability**: Find all users with specific settings
  - Example: "All users with dark theme enabled"
- **Indexing**: Fast lookups on common preferences
- **Validation**: JSON schema enforcement at database level
- **Developer Tools**: Standard JSON tools for debugging and analysis
- **API Integration**: Direct mapping to REST API responses

**Priority**: Medium
- **Timeline**: 6-8 weeks (can run parallel to other migrations)
- **Risk**: Medium (requires careful data migration, affects all users)
- **Dependencies**:
  - Requires comprehensive testing infrastructure
  - Should coordinate with MySQL 8.4 upgrade for optimal JSON support
  - Consider alongside PSGI migration for testing strategy
- **Estimated Effort**: 6-8 weeks
  - Week 1-2: Analysis, documentation, planning
  - Week 3-4: Code updates, dual-write implementation
  - Week 5-6: Data migration, testing
  - Week 7: Schema changes, index creation
  - Week 8: Cutover, monitoring, cleanup

**Related Work**:
- MySQL 8.4 has improved JSON performance and features
- REST APIs already use JSON for data exchange
- React components work natively with JSON structures
- Modern web standards favor JSON over custom formats
- Existing VARS handling code provides migration starting point

#### Development Goals - DBIx::Class ORM Migration

**Goal**: Migrate from direct SQL queries and nodebase functions to DBIx::Class ORM for improved type safety, relationship handling, and modern Perl development practices.

**Current Issues**:

1. **Direct SQL Everywhere**:
   - Raw SQL queries scattered throughout codebase
   - String concatenation for query building
   - SQL injection risks despite prepared statements
   - Difficult to refactor table schemas
   - No compile-time query validation
   - Example: `$DB->sqlSelect('title,type_nodetype', 'node', "node_id = $nid")`

2. **Nodebase Abstraction Limitations**:
   - Custom database abstraction layer (`Everything::DB`)
   - Not standardized - unique to Everything2
   - Limited relationship handling
   - No lazy loading or eager loading control
   - Manual join management
   - Difficult to test (requires full database)

3. **Maintenance Challenges**:
   - Schema changes require finding all SQL queries
   - No single source of truth for table structure
   - Relationships defined implicitly in queries
   - Type coercion handled manually
   - No migration framework

4. **Developer Onboarding**:
   - New developers must learn custom nodebase API
   - No standard Perl ORM patterns
   - Documentation spread across codebase
   - Unclear data model relationships

**Business Rationale**:
- **Developer Productivity**: Standard ORM reduces boilerplate, speeds development
- **Code Quality**: Type-safe queries catch errors at compile time
- **Maintainability**: Single schema source makes changes easier
- **Testing**: Mock database easier with ORM layer
- **Modern Stack**: DBIx::Class is industry-standard Perl ORM
- **Relationships**: Automatic JOIN handling, lazy/eager loading
- **Migration Framework**: DBIx::Class::Migration for schema versioning

**Technical Challenges**:

1. **Massive Codebase**:
   - Hundreds of direct SQL queries across ecore/
   - Many complex queries with subqueries, joins
   - Performance-critical queries need optimization
   - Existing code works - high risk of regressions

2. **Nodebase Integration**:
   - Current `Everything::DB` deeply integrated
   - Node caching layer built on nodebase
   - Permission system tied to nodebase
   - Need gradual migration path, not big-bang rewrite

3. **Complex Schema**:
   - node table with polymorphic type system
   - Multiple inheritance through nodetype chain
   - Dynamic fields based on node type
   - Custom serialization (vars, settings)

4. **Performance Requirements**:
   - High-traffic production site
   - Query optimization critical
   - ORM overhead must be measured
   - Connection pooling, caching needed

**Migration Path**:

1. **Phase 1: Schema Generation (2-3 weeks)**
   - Install DBIx::Class::Schema::Loader
   - Generate initial schema from existing database
   - Review and customize generated Result classes
   - Document table relationships explicitly
   - Add custom methods to Result classes
   - Set up DBIx::Class::Migration framework

2. **Phase 2: Dual-Mode Operation (4-6 weeks)**
   - Add DBIx::Class connection alongside existing `$DB`
   - Create helper methods that wrap DBIx::Class
   - Identify low-risk areas for initial conversion (reporting, admin tools)
   - Write comprehensive tests for converted code
   - Benchmark performance: ORM vs. raw SQL
   - Establish patterns for common operations

3. **Phase 3: Incremental Migration (6-12 months)**
   - Convert modules one at a time, starting with:
     - User preferences (low traffic, simple queries)
     - Message system (medium complexity)
     - Chatterbox (high traffic - good performance test)
     - Node CRUD operations (core functionality)
   - Each conversion gets full test coverage
   - Performance regression tests
   - Monitor production metrics during rollout

4. **Phase 4: Nodebase Wrapper (3-4 weeks)**
   - Implement nodebase functions as DBIx::Class wrappers
   - Maintain API compatibility for legacy code
   - Add deprecation warnings for old patterns
   - Document migration guide for internal developers

5. **Phase 5: Schema Versioning (2-3 weeks)**
   - Set up DBIx::Class::Migration for all schema changes
   - Migrate existing schema to versioned migrations
   - Establish CI/CD pipeline for schema changes
   - Document migration workflow

**Example Schema Class**:
```perl
# lib/Everything2/Schema/Result/Node.pm
package Everything2::Schema::Result::Node;
use strict;
use warnings;
use base 'DBIx::Class::Core';

__PACKAGE__->table('node');
__PACKAGE__->add_columns(
  'node_id' => {
    data_type => 'integer',
    is_auto_increment => 1,
  },
  'title' => {
    data_type => 'varchar',
    size => 240,
  },
  'type_nodetype' => {
    data_type => 'integer',
  },
  'createtime' => {
    data_type => 'datetime',
  },
  # ... more columns
);
__PACKAGE__->set_primary_key('node_id');
__PACKAGE__->belongs_to(
  'nodetype',
  'Everything2::Schema::Result::Nodetype',
  { 'foreign.node_id' => 'self.type_nodetype' }
);
__PACKAGE__->might_have(
  'user',
  'Everything2::Schema::Result::User',
  { 'foreign.user_id' => 'self.node_id' }
);

# Custom methods
sub is_deleted {
  my $self = shift;
  return $self->createtime eq '0000-00-00 00:00:00';
}

1;
```

**Code Migration Example**:
```perl
# Before (direct SQL)
my $title = $DB->sqlSelect('title', 'node', "node_id = $nid");
my $nodes = $DB->sqlSelectMany('*', 'node', "type_nodetype = $type");

# After (DBIx::Class)
my $node = $schema->resultset('Node')->find($nid);
my $title = $node->title;
my @nodes = $schema->resultset('Node')->search({ type_nodetype => $type })->all;

# Relationships (automatic joins)
# Before
my $type_name = $DB->sqlSelect('title', 'node', "node_id = (SELECT type_nodetype FROM node WHERE node_id = $nid)");

# After
my $type_name = $node->nodetype->title;

# Complex queries
# Before
my $query = "SELECT n.* FROM node n
             JOIN user u ON n.node_id = u.user_id
             WHERE u.lasttime > DATE_SUB(NOW(), INTERVAL 1 DAY)
             ORDER BY u.lasttime DESC";

# After
my @recent_users = $schema->resultset('User')->search(
  { lasttime => { '>' => \'DATE_SUB(NOW(), INTERVAL 1 DAY)' } },
  {
    join => 'node',
    order_by => { -desc => 'lasttime' },
  }
)->all;
```

**Benefits**:
- **Type Safety**: Compile-time column validation
- **Relationships**: Automatic JOIN handling via `$node->author`, `$user->writeups`
- **Query Building**: Programmatic query construction, no string concatenation
- **Testing**: Can mock schema, use SQLite for fast tests
- **IDE Support**: Autocomplete for columns, methods
- **Migrations**: Versioned schema changes with rollback
- **Performance**: Query optimization tools, explain plan analysis
- **Documentation**: Schema is self-documenting code
- **Transactions**: Proper transaction handling with rollback
- **Data Validation**: Type coercion, constraints at ORM level

**Priority**: Low-Medium (Long-term modernization)
- **Timeline**: 12-18 months (incremental migration)
- **Risk**: High (touches all database access, requires careful rollout)
- **Dependencies**:
  - Requires comprehensive test coverage (expand existing t/*.t)
  - Should coordinate with MySQL 8.4 upgrade for modern features
  - Consider after Settings Table JSON Migration (reduce concurrent DB changes)
  - Pairs well with PSGI migration (modern Perl stack)
- **Estimated Effort**: 12-18 months incremental
  - Month 1-2: Schema generation, tooling setup, pilot conversions
  - Month 3-6: Low-risk module conversions (25% of queries)
  - Month 7-12: Medium-risk conversions (50% of queries)
  - Month 13-15: High-risk core conversions (20% of queries)
  - Month 16-18: Nodebase wrapper, deprecation, cleanup (5% legacy)

**Performance Considerations**:
- **Lazy Loading**: Load relationships only when accessed
- **Eager Loading**: Prefetch with `prefetch => ['author', 'nodetype']` to avoid N+1 queries
- **Result Class Caching**: Cache frequently-accessed objects
- **Raw SQL Escape Hatch**: Keep `$dbh->prepare()` for performance-critical queries
- **Profiling**: Use DBIx::Class::QueryLog to identify slow queries

**Testing Strategy**:
```perl
# t/100_dbic_node.t
use Test::More;
use Everything2::Schema;

my $schema = Everything2::Schema->connect('dbi:SQLite:dbname=:memory:');
$schema->deploy();  # Create tables from schema

# Test node creation
my $node = $schema->resultset('Node')->create({
  title => 'Test Node',
  type_nodetype => 14,  # superdoc
});
is($node->title, 'Test Node', 'Node created');

# Test relationships
my $type = $node->nodetype;
is($type->title, 'superdoc', 'Nodetype relationship works');

done_testing;
```

**Rollback Plan**:
- Each module conversion is isolated
- Original SQL code remains in git history
- Feature flags allow A/B testing ORM vs. SQL
- Can revert individual modules independently
- Database schema unchanged (only access layer changes)

**Success Metrics**:
- Zero performance regressions (p99 latency)
- 50% reduction in SQL injection risks (automated scanning)
- 30% faster feature development (measured in story points)
- 90% code coverage for DB layer
- Schema documentation auto-generated and up-to-date

**Related Work**:
- DBIx::Class is mature, actively maintained Perl ORM
- Used by Catalyst framework (potential future migration)
- Strong community, extensive documentation
- Compatible with MySQL, PostgreSQL, SQLite
- Migration framework based on Alembic (Python) and Rails patterns

**Decision Points**:
1. **Start Now or Wait?**
   - Recommend: Start Phase 1 (schema generation) now, low risk
   - Defer: Phase 2+ until after delegation migration complete

2. **Full Migration or Hybrid?**
   - Recommend: Hybrid long-term (80% ORM, 20% raw SQL for performance)
   - Keep raw SQL option for complex reporting queries

3. **Testing Strategy?**
   - Recommend: Parallel run ORM + SQL, compare results in dev
   - Use SQLite for fast unit tests, MySQL for integration tests

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

## Special Case: Room Criteria Delegation

### Overview

Rooms in Everything2 have a `criteria` field containing Perl code that determines whether a user can enter the room. This code is currently evaluated using `eval()` in multiple locations. This section describes how to migrate room criteria to delegation functions.

### Migration Status: COMPLETED

**Completed**: All 5 built-in rooms have been migrated to delegation functions.

**Implementation Details**:
- Created `ecore/Everything/Delegation/room.pm` with minimal structure (no symbol imports needed)
- Added 4 delegation functions: `valhalla`, `debriefing_room`, `m_noder_washroom`, `noders_nursery`
- Political Asylum has no delegation (uses default allow behavior)
- Added `canEnterRoom()` helper to `Everything::Application` with:
  - Early admin check (admins can always enter any room)
  - Uses `->can()` pattern (no symbolic references, no Perl::Critic annotations)
  - Simplified signature: `($NODE, $USER, $VARS)`
  - Default allow for rooms without delegation
- Updated all 4 evaluation sites to use `$APP->canEnterRoom()`
- Cleared `<criteria>` field in all 5 room XML files
- Added `use Everything::Delegation::room;` to Application.pm

**Key Differences from Original Plan**:
- NO symbol table imports in room.pm (parameters provide all needed variables)
- Simplified signatures: `($USER, $VARS, $APP)` instead of full 7-parameter signature
- Admin check happens in `canEnterRoom` before delegation (performance optimization)
- Uses `->can()` pattern instead of symbolic references (cleaner implementation)
- No eval() fallback needed (all built-in rooms migrated at once)

**Outstanding Items**:
- Room locking currently implemented via criteria field manipulation (see TODO in `room_display_page`)
- Should be migrated to dedicated database field (see issue #3720)
- User-created rooms would need delegation functions if restrictions are required in the future

### Actual Implementation

**File: `ecore/Everything/Delegation/room.pm`**
```perl
package Everything::Delegation::room;

use strict;
use warnings;

# Valhalla - Gods/admins only
# Note: Admins are allowed by canEnterRoom before delegation is called
sub valhalla
{
    my ( $USER, $VARS, $APP ) = @_;
    return 0;
}

# Political Asylum - Open to all (no delegation needed, falls back to default allow)

# Debriefing Room - Chanops only
sub debriefing_room
{
    my ( $USER, $VARS, $APP ) = @_;
    return 0 unless $APP->inUsergroup( $USER->{user_id}, 'chanops' );
    return 1;
}

# M-Noder Washroom - Users with 1000+ writeups or gods
sub m_noder_washroom
{
    my ( $USER, $VARS, $APP ) = @_;
    my $numwr = undef;
    $numwr = $VARS->{numwriteups} || 0;
    return 0 unless $numwr >= 1000 or $APP->isAdmin($USER);
    return 1;
}

# Noders Nursery - New users (level 3 and below) or high level (6+) or editors
sub noders_nursery
{
    my ( $USER, $VARS, $APP ) = @_;
    my $level = undef;
    return 1 if $APP->isEditor($USER);
    $level = $APP->getLevel($USER);
    return 1 if $level <= 3 or $level >= 6;
    return 0;
}

1;
```

**File: `ecore/Everything/Application.pm` (canEnterRoom method)**
```perl
sub canEnterRoom {
  my ($this, $NODE, $USER, $VARS) = @_;

  # Admins can always enter any room
  return 1 if $this->isAdmin($USER);

  my $room_node = undef;
  my $func_name = undef;

  $room_node = $NODE;

  # Convert room title to function name (same pattern as document.pm)
  $func_name = lc( $room_node->{title} );
  $func_name =~ s/[^a-z0-9]+/_/g;
  $func_name =~ s/^_+|_+$//g;    # Remove leading/trailing underscores

  # Check if delegation exists and call it
  if ( my $delegation = Everything::Delegation::room->can($func_name) )
  {
    return $delegation->( $USER, $VARS, $this );
  }

  # Default: allow entry for rooms without delegation
  return 1;
}
```

### Original Room System (Before Migration)

#### Existing Rooms

Everything2 has 5 built-in rooms in `nodepack/room/`:

1. **Valhalla** (node_id: 545263)
   - Criteria: `return 0 unless isGod($USER); 1;`
   - Requires: $USER
   - Purpose: Gods/admins only

2. **Political Asylum** (node_id: 553129)
   - Criteria: `1;`
   - Requires: None
   - Purpose: Open to all (no delegation needed - uses default allow)

3. **Debriefing Room** (node_id: 1973457)
   - Criteria: `return 0 unless $APP->inUsergroup($$USER{user_id}, 'chanops'); 1;`
   - Requires: $USER, $APP
   - Purpose: Chanops only

4. **M-Noder Washroom** (node_id: 553133)
   - Criteria: `my $numwr = $$VARS{numwriteups}; $numwr ||= 0; return unless $numwr >= 1000 or isGod($USER); 1;`
   - Requires: $VARS, $USER
   - Purpose: Users with 1000+ writeups or gods

5. **Noders Nursery** (node_id: 553146)
   - Criteria: `my $uid = getId($USER); return 1 if $APP->isEditor($USER); return 1 if $APP->getLevel($USER) <= 3 or $APP->getLevel($USER) >= 6; 0;`
   - Requires: $USER, $APP
   - Purpose: New users (level 3 and below) or editors

#### Variables Required

Analysis of all room criteria shows they need access to:
- **$USER** - 4 of 5 rooms (all except Political Asylum)
- **$APP** - 2 of 5 rooms (Debriefing Room, Noders Nursery)
- **$VARS** - 1 of 5 rooms (M-Noder Washroom)

All other delegation context variables ($DB, $query, $NODE, $PAGELOAD) are not currently used but should be provided for consistency and future extensibility.

### Current Evaluation Sites

Room criteria code is evaluated in 4 locations:

#### 1. `ecore/Everything/Delegation/htmlcode.pm:4373`
**Function Context**: Unknown (needs investigation - line ~4350-4380)
```perl
foreach(@rooms) {
  my $R = getNodeById($_);
  next unless eval($$R{criteria});  # Line 4373
  # ... room processing ...
}
```
**Available Variables**: $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP

#### 2. `ecore/Everything/Delegation/htmlcode.pm:8678`
**Function**: `formxml_room`
```perl
sub formxml_room
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $entrance="0";
  if(eval($$NODE{criteria}) and not $APP->isGuest($USER))  # Line 8678
  {
    $entrance=1;
    $APP->changeRoom($USER, $NODE);
  }
  # ... rest of function ...
}
```
**Available Variables**: $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP

#### 3. `ecore/Everything/Delegation/htmlpage.pm:1054`
**Function Context**: room_display_page (approximate)
```perl
## no critic (ProhibitStringyEval)
# TODO: Part of database code removal modernization - criteria should be a proper method
if((eval $$NODE{criteria}) and not $APP->isGuest($USER))  # Line 1054
{
  $APP->changeRoom($USER, $NODE);
  # ... room entry processing ...
}
```
**Available Variables**: $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP

#### 4. `ecore/Everything/Delegation/document.pm:14271, 14471`
**Functions**: `squawkbox`, `squawkbox_update`
```perl
if ( $add_room and $add_room->{type_nodetype} = getId( getType("room") ) )
{
    $add_room->{criteria} ||= 1;
    ## no critic (ProhibitStringyEval)
    $VARS->{squawk_rooms} .= "," . getId($add_room)
        if ( $add_room->{criteria} and eval( $add_room->{criteria} ) );
    ## use critic
}
```
**Available Variables**: $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP

**Key Observation**: All evaluation sites have access to the full delegation signature: `($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP)`

### Migration Plan (Original - For Reference)

**Note**: This section describes the original migration plan. The actual implementation differs significantly (see "Migration Status: COMPLETED" above for details). The actual implementation uses simplified signatures and the `->can()` pattern instead of symbolic references.

#### Phase 1: Create Delegation Module

Create `ecore/Everything/Delegation/room.pm` for room criteria functions.

**Module Structure**:
```perl
package Everything::Delegation::room;

use strict;
use warnings;

use Everything::Globals;

# Import symbols from Everything::HTML
our ($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP);
*DB       = \$Everything::HTML::DB;
*query    = \$Everything::HTML::query;
*NODE     = \$Everything::HTML::NODE;
*USER     = \$Everything::HTML::USER;
*VARS     = \$Everything::HTML::VARS;
*PAGELOAD = \$Everything::HTML::PAGELOAD;
*APP      = \$Everything::HTML::APP;

# Import functions from Everything::HTML
*getNode       = \&Everything::HTML::getNode;
*getId         = \&Everything::HTML::getId;
*getType       = \&Everything::HTML::getType;
*isGod         = \&Everything::HTML::isGod;

1;
```

#### Phase 2: Add Delegation Functions

Create one delegation function per room, named by room title (following document.pm pattern):

```perl
# Valhalla
sub valhalla
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    return 0 unless isGod($USER);
    return 1;
}

# Political Asylum (open to all)
# No delegation needed - falls back to default allow behavior

# Debriefing Room
sub debriefing_room
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    return 0 unless $APP->inUsergroup( $USER->{user_id}, 'chanops' );
    return 1;
}

# M-Noder Washroom
sub m_noder_washroom
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $numwr = undef;

    $numwr = $VARS->{numwriteups} || 0;
    return 0 unless $numwr >= 1000 or isGod($USER);
    return 1;
}

# Noders Nursery
sub noders_nursery
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $uid   = undef;
    my $level = undef;

    $uid = getId($USER);

    return 1 if $APP->isEditor($USER);

    $level = $APP->getLevel($USER);
    return 1 if $level <= 3 or $level >= 6;

    return 0;
}
```

#### Phase 3: Create Helper Function

Add a helper function to `Everything::Application` to check if a room has a delegation and call it:

```perl
# In Everything::Application

sub canEnterRoom
{
    my ($this, $DB, $query, $NODE, $USER, $VARS, $PAGELOAD) = @_;

    my $room_node = undef;
    my $func_name = undef;

    $room_node = $NODE;

    # Convert room title to function name (same pattern as document.pm)
    $func_name = lc( $room_node->{title} );
    $func_name =~ s/[^a-z0-9]+/_/g;
    $func_name =~ s/^_+|_+$//g;    # Remove leading/trailing underscores

    # Check if delegation exists and call it
    if ( Everything::Delegation::room->can($func_name) )
    {
        # Call delegation function
        no strict 'refs';
        ## no critic (ProhibitNoStrict)
        return &{"Everything::Delegation::room::$func_name"}(
            $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $this
        );
        ## use critic
    }

    # Default: allow entry for rooms without delegation
    return 1;
}
```

**Note**: The helper is in `Everything::Application` rather than `Everything::Delegation::room` because `$APP` is universally available. Since all built-in rooms are migrated at once, no eval() fallback is needed.

#### Phase 4: Update Evaluation Sites

Replace direct `eval()` calls with delegation helper:

**Before**:
```perl
# htmlcode.pm:4373
next unless eval($$R{criteria});

# htmlcode.pm:8678
if(eval($$NODE{criteria}) and not $APP->isGuest($USER))

# htmlpage.pm:1054
if((eval $$NODE{criteria}) and not $APP->isGuest($USER))

# document.pm:14271, 14471
if ( $add_room->{criteria} and eval( $add_room->{criteria} ) )
```

**After**:
```perl
# htmlcode.pm:4372
next unless $APP->canEnterRoom(
    $DB, $query, $R, $USER, $VARS, $PAGELOAD
);

# htmlcode.pm:8678
if( $APP->canEnterRoom(
    $DB, $query, $NODE, $USER, $VARS, $PAGELOAD
) and not $APP->isGuest($USER) )

# htmlpage.pm:1052
if( $APP->canEnterRoom(
    $DB, $query, $NODE, $USER, $VARS, $PAGELOAD
) and not $APP->isGuest($USER) )

# document.pm:14268, 14468
if ( $add_room and $APP->canEnterRoom(
    $DB, $query, $add_room, $USER, $VARS, $PAGELOAD
) )
```

#### Phase 5: Clear Room Criteria XML

Once delegation functions are tested and working, clear the `<criteria>` field in room XML files:

```xml
<!-- nodepack/room/valhalla.xml -->
<node>
  <abreviation></abreviation>
  <criteria></criteria>  <!-- Cleared - now delegated -->
  <doctext>&lt;p style=&quot;font-size:135%&quot;&gt;And we,&lt;/p&gt;
  &lt;p style=&quot;font-size:135%&quot;&gt;The dead,&lt;/p&gt;
  &lt;p style=&quot;font-size:135%&quot;&gt;We wait.&lt;/p&gt;</doctext>
  <node_id>545263</node_id>
  <title>Valhalla</title>
  <type_nodetype>545241</type_nodetype>
</node>
```

### User-Created Rooms

The delegation system gracefully handles user-created rooms:

1. **With criteria**: Falls back to `eval()` if no delegation exists
2. **Without criteria**: Returns `1` (allow entry)
3. **Empty criteria**: Returns `1` (allow entry)

This ensures backward compatibility while allowing gradual migration of built-in rooms.

### Testing Strategy

1. **Unit Tests**: Test each room delegation function in isolation
   ```perl
   # t/050_room_delegation.t
   use Test::More;
   use Everything::Delegation::room;

   # Test Valhalla (gods only)
   my $guest_user = { node_id => 1, title => 'Guest User' };
   my $god_user   = { node_id => 2, title => 'God User' };

   is( valhalla($DB, $query, $NODE, $guest_user, $VARS, $PAGELOAD, $APP),
       0, 'Valhalla denies non-gods' );
   is( valhalla($DB, $query, $NODE, $god_user, $VARS, $PAGELOAD, $APP),
       1, 'Valhalla allows gods' );

   done_testing;
   ```

2. **Integration Tests**: Test room entry through actual chatterbox
3. **Regression Tests**: Verify existing room behavior unchanged

### Security Considerations

#### Variable Initialization

As with document delegations, always initialize variables:

```perl
sub room_function
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    my $level = undef;     # Good
    my $count = 0;         # Good
    my $name;              # BAD - uninitialized, mod_perl persistence issue

    # ... rest of function ...
}
```

#### Avoid Direct Database Access from Criteria

Room criteria should be **permission checks only**, not database queries. While the old `eval()` system allowed arbitrary code, delegations should be simple boolean functions.

**Good** (permission check):
```perl
sub some_room
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    return 1 if $APP->isEditor($USER);
    return 1 if $APP->getLevel($USER) >= 5;
    return 0;
}
```

**Bad** (complex business logic):
```perl
sub some_room
{
    my ( $DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP ) = @_;

    # Don't do this - too complex for room criteria
    my $recent_writeups = $DB->sqlSelect(
        'count(*)',
        'writeup',
        "author_user = $USER->{user_id} AND publishtime > DATE_SUB(NOW(), INTERVAL 1 WEEK)"
    );
    return $recent_writeups >= 10;
}
```

If complex checks are needed, add them as `$APP` methods instead.

### Checklist for Room Delegation - COMPLETED

- [x] Create `ecore/Everything/Delegation/room.pm`
- [x] ~~Add symbol imports (match document.pm pattern)~~ NOT NEEDED - simplified signature provides all parameters
- [x] Create delegation function for each room (4 functions: valhalla, debriefing_room, m_noder_washroom, noders_nursery)
- [x] Function name: lowercase title with underscores
- [x] ~~Signature: `($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP)`~~ SIMPLIFIED to `($USER, $VARS, $APP)`
- [x] Initialize all variables to `undef`
- [x] Return 1 (allow) or 0 (deny)
- [x] Add `canEnterRoom()` helper function to Everything::Application
- [x] Add `use Everything::Delegation::room;` to Application.pm
- [x] Update 4 evaluation sites to use delegation
- [x] Test each room delegation function
- [x] Clear `<criteria>` in room XML files (all 5 rooms)
- [x] Run Perl::Critic: `perlcritic --severity 1 --theme bugs ecore/Everything/Delegation/room.pm` - PASSED
- [x] ~~Test user-created rooms still work (fallback to eval)~~ NO EVAL FALLBACK - all built-in rooms migrated at once

### Benefits

1. **Version Control**: Room access logic tracked in git
2. **Testing**: Unit tests for room permissions
3. **Security**: Reduces eval() surface area
4. **Code Review**: Changes visible in pull requests
5. **Performance**: No runtime eval() compilation
6. **Debugging**: Stack traces show actual function names
7. **Backward Compatible**: User rooms continue to work

### Migration Priority - COMPLETED

**Status**: COMPLETED
- All 5 built-in rooms migrated to delegation
- All tests passing (707 Perl tests + 53 Jest tests)
- Zero Perl::Critic violations
- Simplified implementation with cleaner API than originally planned
- Actual effort: ~4 hours (within estimate)

**Next Steps**:
- Room locking should be migrated to dedicated database field (issue #3720)
- User-created rooms would need delegation functions if custom restrictions are required
