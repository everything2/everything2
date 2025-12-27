# React Page Migration Guide

**Last Updated**: 2025-11-25
**Purpose**: Reference documentation for migrating Mason2 pages to React

## Table of Contents

1. [MVC Architecture Pattern](#mvc-architecture-pattern)
2. [Global E2 Object Reference](#global-e2-object-reference)
3. [Creating Page Controllers](#creating-page-controllers)
4. [Best Practices](#best-practices)
5. [Common Patterns](#common-patterns)
6. [Examples](#examples)

---

## MVC Architecture Pattern

### Principle: Separation of Concerns

**Models** (`Everything::Node::*`)
- Provide **simple getter methods** with data validation
- Return validated, typed data (use `int()`, type coercion)
- NO React-specific data assembly
- NO business logic for views

**Controllers** (`Everything::Page::*`)
- Call model methods to retrieve data
- Assemble data structures for React consumption
- Handle request routing and user context
- Put data in namespaced `contentData` structure

**Views** (React Components)
- Consume data from `window.e2.contentData`
- Handle presentation logic only
- Access global user data from `window.e2.user`
- NO direct backend data access

### Critical Rules

1. ✅ **Always use method calls**, never hash access
   ```perl
   # ✅ CORRECT
   my $gp = $USER->GP;
   my $sanctity = $target_user->sanctity;

   # ❌ WRONG
   my $gp = $USER->{GP};
   my $sanctity = $target_user->{sanctity};
   ```

2. ✅ **Data validation in models**, not controllers
   ```perl
   # Model (Everything::Node::user)
   sub GP {
     my ($self) = @_;
     return int($self->NODEDATA->{GP} || 0);  # Validation here
   }

   # Controller (Everything::Page::*)
   my $gp = $USER->GP;  # Just use it, no wrapping
   ```

3. ✅ **No redundant data** - Don't duplicate what's in `window.e2.user`
   ```perl
   # ❌ WRONG - isAdmin already in e2.user
   contentData => {
     isAdmin => $USER->is_admin ? \1 : \0
   }

   # ✅ CORRECT - React uses e2.user.admin
   contentData => {
     viewingSelf => ($target_user->node_id == $REQUEST->user->node_id) ? \1 : \0
   }
   ```

---

## Global E2 Object Reference

The `window.e2` object is built in `Everything::Application::buildNodeInfoStructure()` and provides global data available to **all React components**.

### Core Properties

```javascript
window.e2 = {
  // Current node being viewed
  node_id: 123456,
  title: "Node Title",
  nodetype: "writeup",

  // Node details
  node: {
    title: "Node Title",
    type: "writeup",
    node_id: 123456,
    createtime: 1234567890  // Unix timestamp
  },

  // Current user (REQUEST user)
  user: {
    node_id: 789,
    title: "username",
    admin: true,        // Boolean
    editor: false,      // Boolean
    chanop: false,      // Boolean
    developer: false,   // Boolean
    guest: false,       // Boolean
    in_room: 42,        // Current chat room ID

    // Core user properties (not available for guests)
    gp: 100,            // Gold Points
    gpOptOut: false,    // GP visibility opt-out
    experience: 5432,   // Experience points
    level: 5            // User level
  },

  // Guest user flag (top-level)
  guest: false,  // Boolean

  // Display preferences (collapsed sections, etc.)
  display_prefs: {
    "readthis_hidenews": 0,
    "epicenter_hideborgcheck": 1,
    // ... other preferences
  },

  // Asset configuration
  use_local_assets: true,
  assets_location: "",

  // User preferences
  noquickvote: false,
  nonodeletcollapser: false,

  // Build information
  lastCommit: "abc123def",
  architecture: "production"
}
```

### Chatterbox Data

Available when user is in a chat room:

```javascript
e2.chatterbox = {
  roomName: "Outside",
  roomTopic: "General discussion",
  messages: [
    {
      message_id: 123,
      author: "username",
      author_id: 456,
      msgtext: "Hello world",
      tstamp: "2025-11-25 12:34:56"
    }
    // ... up to 30 most recent messages (last 5 minutes)
  ]
}
```

### Nodelet-Specific Data

#### Epicenter Nodelet (node_id: 262)

Available when Epicenter nodelet is present:

```javascript
e2.epicenter = {
  votesLeft: 10,
  cools: 2,
  // Note: gp, gpOptOut, experience, level moved to e2.user (always available)
  localTimeUse: true,
  userId: 789,
  userSettingsId: 12345,
  helpPage: "Everything2 Help",

  // Optional: if user is borged
  borgcheck: {
    borged: 1732567890,     // Unix timestamp
    numborged: 3,
    currentTime: 1732567900
  },

  // Optional: if user gained XP
  experienceGain: 25,

  // Optional: if user gained GP
  gpGain: 5,

  // Server time strings
  serverTime: "2025-11-25 12:34:56",
  localTime: "2025-11-25 07:34:56"  // If localTimeUse enabled
}
```

**Important**: Core user properties (gp, gpOptOut, experience, level) are now in `e2.user` (always available), not `e2.epicenter` (only when nodelet loads).

**Architectural Benefit**: By placing these in global `e2.user`, individual components can update the global state (e.g., after spinning the wheel), and the entire page reloads as an atomic unit. All components watching `e2.user.gp` will re-render automatically, maintaining consistency across the entire UI.

#### Master Control Nodelet (node_id: 1687135)

Available to editors/admins only:

```javascript
e2.masterControl = {
  isEditor: true,
  isAdmin: true,

  adminSearchForm: {
    nodeId: 123456,
    nodeType: "writeup",
    nodeTitle: "Current Node",
    serverName: "everything2.com",
    scriptName: "/index.pl"
  },

  ceSection: {
    currentMonth: 10,      // 0-11
    currentYear: 2025,
    isUserNode: false,
    nodeId: 123456,
    nodeTitle: "Current Node",
    showSection: true
  },

  nodeNotesData: {
    node_id: 123456,
    node_title: "Current Node",
    node_type: "writeup",
    notes: [
      {
        nodenote_id: 789,
        noter_user: 456,
        noter_username: "editor_name",
        notetext: "Editorial note here",
        timestamp: "2025-11-25 12:34:56"
      }
    ],
    count: 1
  }
}

e2.currentUserId = 789;  // For note creation
```

#### New Writeups Data

Available to guests and users with New Writeups/New Logs nodelets:

```javascript
e2.newWriteups = [
  {
    node_id: 123,
    title: "Writeup Title",
    type: "writeup",
    parent_title: "Parent Node"
  }
  // ... filtered based on user's writeup filter settings
]

// New Logs only
e2.daylogLinks = [/* daylog navigation data */]
```

#### Recommended Reading / ReadThis Data

Available to guests and users with these nodelets:

```javascript
e2.coolnodes = [
  {
    node_id: 123,
    title: "Cool Node",
    type: "writeup"
  }
  // ... Editor's Cool picks
]

e2.staffpicks = [
  {
    node_id: 456,
    title: "Staff Pick",
    type: "writeup"
  }
  // ... Staff recommendations
]

e2.news = [
  {
    node_id: 789,
    title: "News Entry"
  }
  // ... from "News For Noders" usergroup weblog
]
```

---

## Creating Page Controllers

### File Structure

```
ecore/Everything/Page/
  ├── wheel_of_surprise.pm
  ├── silver_trinkets.pm
  └── sanctify.pm
```

### Basic Template

```perl
package Everything::Page::my_page;

use Moose;
extends 'Everything::Page';

# Security mix-in (choose one, or omit for public access):
# with 'Everything::Security::Permissive';   # Default: Allow everyone (superdoc)
# with 'Everything::Security::NoGuest';      # Require login (redirect guests)
# with 'Everything::Security::StaffOnly';    # Editors only (restricted_superdoc)

# Optional: Add form validation helpers
# with 'Everything::Form::username';

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  # Get the requesting user
  my $USER = $REQUEST->user;

  # Assemble page-specific data
  # Namespace under page key for organization
  return {
    myPage => {
      # ... page-specific data here
    }
  };
}

__PACKAGE__->meta->make_immutable;
1;
```

**Detection Pattern:**
```perl
# In Everything::HTML or page dispatcher
if ($page->can('buildReactData')) {
  # This is a React page
  my $data = $page->buildReactData($REQUEST);
  # Render React template with data in window.e2.contentData
} else {
  # This is a Mason2 page
  my $data = $page->display($REQUEST);
  # Render Mason2 template
}
```

### Security Mix-ins

Page modules use Moose roles for declarative security, replacing the old superdoc/restricted_superdoc pattern:

**Available Security Mix-ins:**

```perl
# 1. Permissive (default) - Allow everyone
with 'Everything::Security::Permissive';
# Maps to: superdoc (public access)
# Behavior: All users can access
# Example: Help pages, public information

# 2. NoGuest - Require authenticated user
with 'Everything::Security::NoGuest';
# Maps to: authenticated-only pages
# Behavior: Guests redirected to login
# Returns: PermissionResult::RedirectLogin
# Example: User settings, personal pages

# 3. StaffOnly - Editors/admins only
with 'Everything::Security::StaffOnly';
# Maps to: restricted_superdoc
# Behavior: Non-editors get 403 Forbidden
# Returns: PermissionResult::PermissionDenied
# Example: Editorial tools, admin interfaces
```

**Benefits:**
- ✅ **Declarative security** - No manual permission checks in code
- ✅ **Automatic handling** - Framework redirects/denies automatically
- ✅ **Clean code** - No `if ($user->is_guest) { ... }` scattered throughout
- ✅ **Type safety** - Compile-time role checking
- ✅ **Legacy mapping** - Replaces superdoc type system

**Example Usage:**
```perl
package Everything::Page::user_settings;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::NoGuest';  # Require login

sub buildReactData {
  my ($self, $REQUEST) = @_;

  # No need to check is_guest - security mix-in handles it
  my $USER = $REQUEST->user;

  return {
    type => 'user_settings',
    settings => $USER->get_settings
  };
}
```

### Method Signature

```perl
sub buildReactData
{
  my ($self, $REQUEST) = @_;
  # ...
}
```

**Parameters:**
- `$self` - The Page instance (Moose object)
- `$REQUEST` - The request object containing:
  - `$REQUEST->user` - The authenticated user making the request
  - `$REQUEST->get_param($name)` - Get query/form parameters

### Return Structure

```perl
return {
  pageNamespace => {    # Namespace key (camelCase convention)
    # ... page-specific data
  }
};
```

**Conventions:**
- **Namespace key**: Use camelCase version of page name (e.g., `wheel`, `silverTrinkets`, `sanctify`)
- **Purpose**: Organizes data, prevents collisions, improves clarity
- **React access**: `window.e2.contentData.pageNamespace.field`
- **Boolean conversion**: `\1` creates JSON `true`, `\0` creates JSON `false`
- **Detection**: React mode detected by `$page->can('buildReactData')`

---

## Best Practices

### 1. User Context

```perl
# ✅ CORRECT: Distinguish between requesting user and target user
my $USER = $REQUEST->user;           # Who's making the request
my $target_user = $USER;              # Default: viewing your own data

# Admin lookup pattern
if ($USER->is_admin) {
  my $form_result = $self->validate_username($REQUEST);
  if ($form_result->{result}) {
    $target_user = $form_result->{result};  # Admin viewing someone else
  }
}

# Include target user info in response
return {
  myPage => {
    targetUserId => $target_user->node_id,
    data => $target_user->some_method
  }
};
# React: const { targetUserId, data } = e2.contentData.myPage;
# React derives: const viewingSelf = (targetUserId === e2.user.node_id);
```

### 2. Boolean Conversion

```perl
# ✅ CORRECT: Convert to JSON booleans
hasFeature => $USER->some_check ? \1 : \0

# ❌ WRONG: Perl truthiness doesn't translate to JSON properly
hasFeature => $USER->some_check
```

### 3. Data Types

```perl
# Model methods should return proper types
sub GP {
  my ($self) = @_;
  return int($self->NODEDATA->{GP} || 0);  # Always an integer
}

# Controller just uses the validated data
contentData => {
  userGP => $USER->GP  # No wrapping needed
}
```

### 4. Namespace Your Data

```perl
# ✅ CORRECT: Page data namespaced under page key
return {
  wheel => {
    userGP => $USER->GP,
    hasGPOptout => $USER->gp_optout ? \1 : \0
  }
};
# Available as: window.e2.contentData.wheel.userGP

# ❌ WRONG: Flat structure without namespace
return {
  userGP => $USER->GP,
  hasGPOptout => $USER->gp_optout ? \1 : \0
};

# ❌ WRONG: Polluting top-level e2 namespace
$e2->{userGP} = $USER->GP;
```

### 5. Don't Duplicate Global Data

```perl
# ❌ WRONG: These are already in e2.user
return {
  myPage => {
    isAdmin => $USER->is_admin ? \1 : \0,
    isEditor => $USER->is_editor ? \1 : \0,
    userName => $USER->title,
    gp => $USER->GP,  # Don't duplicate!
    experience => $USER->experience  # Don't duplicate!
  }
};

# ✅ CORRECT: React accesses e2.user directly
return {
  myPage => {
    pageSpecificData => $USER->some_unique_method
  }
};
```

**Why This Matters**: Global properties in `e2.user` allow any component to update the global state, and all other components react automatically. This maintains page consistency as a single atomic unit. For example, when a user spins the wheel and loses GP, updating `e2.user.gp` causes all components displaying GP to re-render instantly.

### 6. Let React Derive Computed Values

```perl
# ❌ WRONG: Backend computes what React can derive
return {
  myPage => {
    targetUserId => $target_user->node_id,
    viewingSelf => ($target_user->node_id == $REQUEST->user->node_id) ? \1 : \0
  }
};

# ✅ CORRECT: Send only raw data, React derives the rest
return {
  myPage => {
    targetUserId => $target_user->node_id,
    targetUserName => $target_user->title
  }
};
# React: const { targetUserId } = e2.contentData.myPage;
# React derives: const viewingSelf = (targetUserId === e2.user.node_id);
```

---

## Common Patterns

### Pattern 1: Simple User Page

Page that shows data for the requesting user only.

```perl
package Everything::Page::my_stats;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::NoGuest';  # Require login

sub buildReactData
{
  my ($self, $REQUEST) = @_;
  my $USER = $REQUEST->user;

  return {
    myStats => {
      experience => $USER->experience,
      writeupCount => $USER->numwriteups,
      coolCount => $USER->numcools
    }
  };
}

__PACKAGE__->meta->make_immutable;
1;
```

**React Access:**
```javascript
const { experience, writeupCount, coolCount } = window.e2.contentData.myStats;
const userName = window.e2.user.title;  // From global data
```

### Pattern 2: Admin Lookup Page

Page where admins can look up data for other users.

```perl
package Everything::Page::user_lookup;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::NoGuest';
with 'Everything::Form::username';

sub buildReactData
{
  my ($self, $REQUEST) = @_;
  my $USER = $REQUEST->user;
  my $target_user = $USER;

  # Admin can specify target user
  if ($USER->is_admin) {
    my $form_result = $self->validate_username($REQUEST);
    if ($form_result->{result}) {
      $target_user = $form_result->{result};
    }
  }

  return {
    userLookup => {
      targetUserId => $target_user->node_id,
      targetUserName => $target_user->title,
      targetUserData => $target_user->some_method
    }
  };
}

__PACKAGE__->meta->make_immutable;
1;
```

**React Access:**
```javascript
const { targetUserId, targetUserName, targetUserData } = window.e2.contentData.userLookup;
const { admin, node_id } = window.e2.user;

// Derive computed values
const viewingSelf = (targetUserId === node_id);

if (admin && !viewingSelf) {
  // Show admin controls for viewing other user's data
}
```

### Pattern 3: Feature Toggle Based on Settings

Page behavior changes based on user preferences.

```perl
package Everything::Page::customizable;

use Moose;
extends 'Everything::Page';

sub buildReactData
{
  my ($self, $REQUEST) = @_;
  my $USER = $REQUEST->user;

  return {
    customizable => {
      mainData => $USER->some_data,
      enableFeatureX => $USER->setting_feature_x ? \1 : \0,
      optionY => $USER->setting_option_y
    }
  };
}

__PACKAGE__->meta->make_immutable;
1;
```

**Model Method:**
```perl
# In Everything::Node::user
sub setting_feature_x {
  my ($self) = @_;
  return $self->VARS->{feature_x_enabled} || 0;
}
```

### Pattern 4: Conditional Data Loading

Only load expensive data if needed.

```perl
package Everything::Page::conditional;

use Moose;
extends 'Everything::Page';

sub buildReactData
{
  my ($self, $REQUEST) = @_;
  my $USER = $REQUEST->user;

  my $data = {
    basicData => $USER->cheap_method
  };

  # Only load expensive data if user has permission
  if ($USER->is_editor) {
    $data->{editorData} = $USER->expensive_editor_method;
  }

  # Only load if feature enabled
  if ($USER->has_beta_feature) {
    $data->{betaFeatureData} = $USER->beta_data;
  }

  return { conditional => $data };
}

__PACKAGE__->meta->make_immutable;
1;
```

---

## Examples

### Example 1: Wheel of Surprise

**File:** `ecore/Everything/Page/wheel_of_surprise.pm`

```perl
package Everything::Page::wheel_of_surprise;

use Moose;
extends 'Everything::Page';

sub buildReactData
{
  my ($self, $REQUEST) = @_;
  my $USER = $REQUEST->user;

  return {
    wheel => {
      result => undef,  # No initial result
      isHalloween => 0   # TODO: Check for Halloween date
      # Note: GP and GPOptout available in e2.user (global)
    }
  };
}

__PACKAGE__->meta->make_immutable;
1;
```

**Model Methods Used:**
- None required - all data is page-specific or global

**React Component:**
```javascript
// Access page data
const { result, isHalloween } = window.e2.contentData.wheel;

// Access global user data (reactive state)
const { admin, title, gp, gpOptOut } = window.e2.user;

// Spin the wheel
async function spinWheel() {
  if (gp < 10) {
    alert('You need at least 10 GP to spin the wheel');
    return;
  }

  const response = await fetch('/api/wheel/spin', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' }
  });
  const result = await response.json();

  // Update global state - entire page reacts atomically
  window.e2.user.gp = result.newGP;
  window.e2.user.experience = result.newExperience;

  // All components watching e2.user will re-render automatically
}
```

**Key Pattern**: Updating `window.e2.user` properties triggers reactive updates across all components, maintaining UI consistency as a single atomic unit.

### Example 2: Silver Trinkets (Admin Lookup)

**File:** `ecore/Everything/Page/silver_trinkets.pm`

```perl
package Everything::Page::silver_trinkets;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::NoGuest';
with 'Everything::Form::username';

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  # Determine which user's trinkets to show
  my $target_user = $REQUEST->user;

  # Admins can look up other users
  if ($REQUEST->user->is_admin) {
    my $form_result = $self->validate_username($REQUEST);
    if ($form_result->{result}) {
      $target_user = $form_result->{result};
    }
  }

  return {
    silverTrinkets => {
      targetUserId => $target_user->node_id,
      targetUserName => $target_user->title,
      sanctity => $target_user->sanctity
    }
  };
}

__PACKAGE__->meta->make_immutable;
1;
```

**Model Methods Used:**
- `$target_user->sanctity` → Returns `int($NODEDATA->{sanctity} || 0)`
- `$target_user->node_id` → Returns `$NODEDATA->{node_id}`
- `$target_user->title` → Returns `$NODEDATA->{title}`
- `$REQUEST->user->is_admin` → Returns boolean (checked during lookup)

**React Component:**
```javascript
// Access page data
const { targetUserId, targetUserName, sanctity } = window.e2.contentData.silverTrinkets;

// Access global user data
const { admin, node_id } = window.e2.user;

// Derive computed values
const viewingSelf = (targetUserId === node_id);

// Show different UI based on context
if (admin && !viewingSelf) {
  // Admin viewing someone else - show admin tools
  return <AdminSilverTrinketView
    userName={targetUserName}
    sanctity={sanctity}
  />;
} else {
  // User viewing their own - show user tools
  return <UserSilverTrinketView sanctity={sanctity} />;
}
```

### Example 3: Sanctify (Simple User Page)

**File:** `ecore/Everything/Page/sanctify.pm`

```perl
package Everything::Page::sanctify;

use Moose;
extends 'Everything::Page';

sub buildReactData
{
  my ($self, $REQUEST) = @_;
  my $USER = $REQUEST->user;

  return {
    sanctify => {
      sanctity => $USER->sanctity
      # Note: GP and GPOptout available in e2.user (global)
    }
  };
}

__PACKAGE__->meta->make_immutable;
1;
```

**Model Methods Used:**
- `$USER->sanctity` → Returns `int($NODEDATA->{sanctity} || 0)`

**React Component:**
```javascript
// Access page data
const { sanctity } = window.e2.contentData.sanctify;

// Access global user data
const { gp, gpOptOut } = window.e2.user;

// Sanctify a node
async function sanctifyNode(nodeId) {
  if (sanctity < 1) {
    alert('You need sanctity points to bless a node');
    return;
  }

  const response = await fetch('/api/sanctify', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ node_id: nodeId })
  });

  const result = await response.json();
  // Update UI with result
}
```

---

## Migration Checklist

When migrating a Mason2 page to React:

### Backend (Perl)
- [ ] Create `Everything::Page::my_page` module
- [ ] Add appropriate security mix-in:
  - [ ] Public page? Use `with 'Everything::Security::Permissive';` (or omit)
  - [ ] Requires login? Use `with 'Everything::Security::NoGuest';`
  - [ ] Editors only? Use `with 'Everything::Security::StaffOnly';`
- [ ] Implement `buildReactData()` method
- [ ] Identify required data from user/node
- [ ] Add simple getter methods to `Everything::Node::user` if needed
- [ ] Ensure all getters return validated data (types)
- [ ] Use `$REQUEST->user` for authenticated user
- [ ] Handle admin lookup if applicable (with `Everything::Form::username`)
- [ ] Convert booleans with `? \1 : \0`
- [ ] Don't duplicate data from `window.e2.user` (gp, gpOptOut, experience, level, etc.)
- [ ] Let React derive computed values (don't pre-compute)
- [ ] Namespace data under page key (camelCase convention)

### Frontend (React)
- [ ] Create React component to consume `window.e2.contentData`
- [ ] Access global data from `window.e2.user`, not duplicated in contentData
- [ ] Derive computed values in React (e.g., `viewingSelf`)
- [ ] Handle different user roles appropriately
- [ ] Test with different user contexts:
  - [ ] Guest user (if applicable)
  - [ ] Authenticated user
  - [ ] Editor (if applicable)
  - [ ] Admin (if applicable)

### Documentation
- [ ] Update CLAUDE.md with any new patterns
- [ ] Document new model methods if added
- [ ] Update this guide if new patterns emerge

---

## Current Migration Status

**Last Updated**: 2025-11-29

### Summary

| Component | Count | Status |
|-----------|-------|--------|
| Document delegation functions | 225 | Legacy (in document.pm) |
| HTMLpage delegation functions | 100 | Legacy (in htmlpage.pm) |
| Page classes created | 48 | ✅ Migrated to Page pattern |
| React components | ~45 | ✅ Rendering via React |
| DocumentComponent routes | 48 | ✅ Registered in router |

### Document Delegation Categories

The 225 document functions fall into these categories:

#### 1. XML/JSON Tickers (27 functions) - **Deprecation Candidates**
Legacy API endpoints that predate REST. Many can be deprecated or converted to proper `/api/` endpoints.

```
available_rooms_xml_ticker, chatterbox_xml_ticker, client_version_xml_ticker,
cool_archive_atom_feed, cool_nodes_xml_ticker, cool_nodes_xml_ticker_ii,
e2_xml_search_interface, editor_cools_xml_ticker, everything_s_best_users_xml_ticker,
maintenance_nodes_xml_ticker, my_votes_xml_ticker, new_nodes_xml_ticker,
new_writeups_atom_feed, new_writeups_xml_ticker, node_heaven_xml_ticker,
other_users_xml_ticker_ii, personal_session_xml_ticker, podcast_rss_feed,
random_nodes_xml_ticker, raw_vars_xml_ticker, time_since_xml_ticker,
universal_message_xml_ticker, universal_message_json_ticker, user_information_xml,
user_search_xml_ticker, user_search_xml_ticker_ii, xml_interfaces_ticker
```

**Strategy**: Audit usage, deprecate unused, convert essential ones to `/api/` endpoints.

#### 2. Admin/Editor Tools (27 functions) - **Low Priority**
Staff-only tools with limited user base. Migrate last.

```
e2_bouncer, e2node_reparenter, enrichify, faq_editor, feed_edb, fiery_teddy_bear_suit,
gp_optouts, ip_blacklist, ip_hunter, klaproth_van_lines, mass_ip_blacklister,
nate_s_secret_unborg_doc, new_user_images, node_forbiddance, node_heaven_title_search,
node_notes_by_editor, nodetype_changer, renunciation_chainsaw, security_monitor,
server_telemetry, spam_cannon, sql_prompt, the_borg_clinic, the_killing_floor,
the_killing_floor_ii, the_node_crypt, the_old_hooked_pole, the_oracle,
the_oracle_classic, usergroup_press_gang, users_with_infravision, viewvars,
who_killed_what, yet_another_secret_laboratory
```

**Strategy**: Keep as Mason2 until end of migration, then batch convert.

#### 3. User Settings/Personal Pages (20 functions) - **HIGH PRIORITY**
Frequently accessed by users. Good migration candidates.

```
admin_settings, advanced_settings, confirm_password, drafts, drafts_for_review,
message_inbox, message_inbox_2, message_outbox, my_achievements, my_big_writeup_list,
my_recent_writeups, nodelet_settings, notelet_editor, old_writeup_settings,
reset_password, settings, super_mailbox, your_filled_nodeshells
```

**Already migrated**: sign_up, login, your_gravatar, your_ignore_list, your_insured_writeups, your_nodeshells

**Strategy**: Migrate these next - high user impact, moderate complexity.

#### 4. Content Browse/Archive Pages (31 functions) - **MEDIUM PRIORITY**
Read-mostly pages, good for React's strengths.

```
alphabetizer, between_the_cracks, bounty_hunters_wanted, cool_archive, display_categories,
duplicates_found_, everything_data_pages, everything_document_directory, everything_finger,
everything_poll_archive, everything_poll_directory, everything_s_best_users,
everything_s_best_writeups, everything_user_search, findings_, fresh_blood, freshly_bloodied,
level_distribution, list_nodes_of_type, news_archives, node_backup, nodes_of_the_year,
page_of_cool, popular_registries, random_nodeshells, recent_registry_entries,
recent_users, registry_information, the_catwalk, the_registries, the_well_of_cool,
topic_archive, writeup_search, writeups_by_type
```

**Strategy**: Good candidates for batching - many share similar "list of nodes" patterns.

#### 5. Fun/Games/Interactive (15 functions) - **MEDIUM PRIORITY**
User engagement features.

```
ask_everything__do_i_have_the_swine_flu_, blind_voting_booth, buffalo_generator,
buffalo_haiku_generator, do_you_c__what_i_c_, e2_color_toy, e2_gift_shop,
e2_marble_shop, e2_penny_jar, e2_sperm_counter, e2_word_counter, everything_i_ching,
teddisms_generator, the_tokenator, word_messer_upper
```

**Already migrated**: e2_rot13_encoder, everything_quote_server, wheel_of_surprise, fezisms_generator, piercisms_generator

**Strategy**: Fun quick wins - often simple, high engagement value.

#### 6. Chat/Messaging (10 functions) - **PARTIALLY DONE**

```
available_rooms, create_room, go_outside, inboxlight, squawkbox, squawkbox_update
```

**Already migrated**: chatterlight, chatterlight_classic, chatterlighter, online_only_msg, chatterbox_help_topics

**Strategy**: Complete chat ecosystem migration.

#### 7. Statistics/Graphs (10 functions) - **LOW PRIORITY**
Data visualization pages.

```
database_lag_o_meter, everything_statistics, noding_speedometer, reputation_graph,
reputation_graph_horizontal, site_trajectory, site_trajectory_2, user_statistics,
voting_data, voting_oracle
```

**Strategy**: May need charting library integration. Defer until core pages done.

### HTMLpage Delegation Functions (100 functions)

These handle display/edit pages for different node types. Categories:

#### Display Pages (node type viewers)
```
*_display_page functions (achievement, category, collaboration, container,
datastash, dbtable, debatecomment, document, draft, e2client, e2node, e2poll,
edevdoc, fullpage, htmlcode, htmlpage, jsonexport, mail, maintenance, mysqlproc,
node, node_forward, node_help, nodegroup, nodelet, nodetype, notification,
plaindoc, podcast, recording, registry, room, setting, stylesheet, superdoc,
superdocnolinks, ticker, user, usergroup, writeup)
```

**Strategy**: Most can remain as-is. Focus on `superdoc_display_page` which drives most content.

#### Edit Pages (node type editors)
```
*_edit_page functions - Staff/admin use only
```

**Strategy**: Low priority - admin tools, keep in Mason2 until late in migration.

### Recommended Migration Order

#### Phase 1: User Settings (High Impact)
1. `settings` / `admin_settings` / `advanced_settings` - User preferences
2. `message_inbox` / `message_inbox_2` / `message_outbox` - Messaging
3. `drafts` / `drafts_for_review` - Writing workflow
4. `nodelet_settings` - Sidebar customization

#### Phase 2: Content Discovery
1. `cool_archive` - Historical cooled content
2. `writeup_search` - Content search (already have full_text_search)
3. `everything_user_search` - User search
4. `writeups_by_type` - Browse by category

#### Phase 3: Engagement Features
1. `e2_gift_shop` / `e2_penny_jar` - GP system
2. `e2_color_toy` / `the_costume_shop` / `theme_nirvana` - Theming
3. `available_rooms` / `create_room` - Chat management

#### Phase 4: Admin Tools (Last)
- Migrate staff tools in batch
- Consider keeping some as Mason2 if rarely used

### Quick Wins (Simple Pages)

These have minimal logic and can be migrated quickly:

```perl
# Simple static/display pages
permission_denied, nothing_found, welcome_to_everything

# Simple generators (pattern: random text output)
buffalo_generator, buffalo_haiku_generator, teddisms_generator

# Simple info pages
e2_acceptable_use_policy, edev_faq, macro_faq
```

### Deprecated/Unused Candidates

Audit these for removal rather than migration:

```
# Legacy XML tickers - check if any clients still use them
# Old versions of pages (e.g., if message_inbox_2 replaces message_inbox)
# Seasonal/event pages that may be defunct
```

---

## Additional Resources

- [React Migration Strategy](react-migration-strategy.md) - Overall migration roadmap
- [Mason2 Elimination Plan](mason2-elimination-plan.md) - Phase-by-phase plan
- [API Documentation](API.md) - REST API endpoint reference
- [Nodelet Migration Status](nodelet-migration-status.md) - Nodelet migration tracking

---

## Questions?

When in doubt:
1. Check existing Page controllers for patterns
2. Ensure models are simple getters with validation
3. Ensure controllers assemble data structures
4. Don't duplicate global `e2.user` data
5. Use methods, never hash access
6. Test with different user contexts

**Maintainer**: Jay Bonci
**Last Review**: 2025-11-29
