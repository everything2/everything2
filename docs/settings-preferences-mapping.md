# Settings Page Preferences Mapping

Comprehensive mapping of all user preferences from legacy Settings page to modern React implementation.

**Last Updated**: 2025-12-01

## Overview

The legacy Settings page consists of three main sections:
1. **Settings** (`settings` function) - Basic appearance and writeup preferences
2. **Advanced Settings** (`advanced_settings` function) - Display, notifications, messages
3. **Nodelet Settings** (`nodelet_settings` function) - Nodelet order and per-nodelet configuration

---

## Tab 1: Settings (Basic Preferences)

### Look and Feel

#### Style
- **`userstyle`** (node_id) - Stylesheet selection
  - Dropdown with all stylesheets from `supported_sheet` parameter
  - Default: 'default' (system default style)

#### Style Options
- **`nogradlinks`** (checkbox inverse) - "Show the softlink color gradient"
  - Type: boolean (0/1)
  - Default: 0 (show gradient)

#### Quick Functions
- **`noquickvote`** (checkbox inverse) - "Enable quick functions (a.k.a. AJAX)"
  - Type: boolean (0/1)
  - Default: 0 (AJAX enabled)
  - Note: When enabled, voting/cooling/chatting don't require page reloads

- **`fxDuration`** - "On-page transitions"
  - Type: select (0, 100, 150, 300, 400, 600, 800, 1000)
  - Options: Off (instant)=1, Supersonic=100, Faster=150, Fast (default)=0, Less fast=300, Medium=400, Slow=600, Slower=800, Glacial=1000
  - Default: 0

- **`noreplacevotebuttons`** (checkbox inverse) - "Replace +/- voting buttons with Up/Down buttons"
  - Type: boolean (0/1)
  - Default: 0 (use Up/Down buttons)

- **`votesafety`** (checkbox) - "Ask for confirmation when voting"
  - Type: boolean (0/1)
  - Default: 0

- **`coolsafety`** (checkbox) - "Ask for confirmation when cooling writeups"
  - Type: boolean (0/1)
  - Default: 0

### Your Writeups

#### Editing
- **`HideWriteupOnE2node`** (checkbox) - "Only show your writeup edit box text on the writeup's own page"
  - Type: boolean (0/1)
  - Default: 0
  - Note: Useful for slow connections

- **`settings_useTinyMCE`** (checkbox) - "Use WYSIWYG content editor to format writeups"
  - Type: boolean (0/1)
  - Default: 0

- **`textareaSize`** - "Writeup edit box display size"
  - Type: select (0, 1, 2)
  - Options: 20x60 (Small) (Default)=0, 30x80 (Medium)=1, 50x95 (Large)=2
  - Default: 0

#### Writeup Hints
- **`nohints`** (checkbox inverse) - "Show critical writeup hints"
  - Type: boolean (0/1)
  - Default: 0 (show hints) - recommended

- **`nohintSpelling`** (checkbox inverse) - "Check for common misspellings"
  - Type: boolean (0/1)
  - Default: 0 (check spelling) - recommended

- **`nohintHTML`** (checkbox inverse) - "Show HTML hints"
  - Type: boolean (0/1)
  - Default: 0 (show HTML hints) - recommended

- **`hintXHTML`** (checkbox) - "Show strict HTML hints"
  - Type: boolean (0/1)
  - Default: 0

- **`hintSilly`** (checkbox) - "Show silly hints"
  - Type: boolean (0/1)
  - Default: 0

### Other Users

#### Other Users' Writeups
- **`anonymousvote`** - "Anonymous voting"
  - Type: select (0, 1, 2)
  - Options: Always show author's username=0, Hide author completely until I have voted on a writeup=1, Hide author's name until I have voted but still link to the author=2
  - Default: 0

#### Favorite Other Users
- Links management (not a VARS preference - stored in `links` table with `favorite` linktype)
- UI: List of favorite noders with checkboxes to remove

#### Less Favorite Other Users
- **Message blocking** (stored in `messageignore` table, not VARS)
- **`informmsgignore`** - "If one of your messages is blocked, you will be informed"
  - Type: select (0, 1, 2, 3)
  - Options: by private message=0, in the chatterbox=1, both ways=2, do not inform (bad idea)=3
  - Default: 0

---

## Tab 2: Advanced Settings

### Page Display

#### Writeup Headers
- **`info_authorsince_off`** (checkbox inverse) - "Show how long ago the author was here"
  - Type: boolean (0/1)
  - Default: 0 (show)

- **`wuhead`** - Writeup header configuration string
  - Special format: comma-separated like "c:type,c:author,c:audio,c:length,c:hits,r:dtcreate"
  - Individual checkboxes control presence of:
    - `wuhead_audio` - "Show links to any audio files"
    - `wuhead_length` - "Show approximate word count of writeup"
    - `wuhead_hits` - "Show a hit counter for each writeup" (default ON)
    - `wuhead_dtcreate` - "Show time of creation" (default ON)

#### Writeup Footers
- **`nokillpopup`** (special) - "Admin tools always visible, no pop-up"
  - Type: boolean (value=4 when set)
  - Default: not set
  - Note: Only for specific gods (mauler, riverrun, Wiccanpiper, DonJaime)

- **`wufoot`** - Writeup footer configuration string
  - Special format: comma-separated like "l:kill,c:vote,c:cfull,c:sendmsg,c:addto,r:social"
  - Individual checkboxes control presence of:
    - `wufoot_sendmsg` - "Show a box to send messages to the author" (default ON)
    - `wufoot_addto` - "Show a tool to add the writeup to your bookmarks, a usergroup page or a category" (default ON)
    - `wufoot_social` - "Show social bookmarking buttons" (default ON)

- **`nosocialbookmarking`** (checkbox inverse) - "Allow others to see social bookmarking buttons on my writeups"
  - Type: boolean (0/1)
  - Default: 0 (allow)
  - Note: When unchecked, also hides social bookmarking buttons on other people's writeups

#### Homenodes
- **`hidemsgme`** (checkbox) - "I am anti-social. (So don't display the user /msg box in users' homenodes.)"
  - Type: boolean (0/1)
  - Default: 0

- **`hidemsgyou`** (checkbox) - "No one talks to me either, so on homenodes, hide the '/msgs from me' link to Message Inbox"
  - Type: boolean (0/1)
  - Default: 0

- **`hidevotedata`** (checkbox) - "Not only that, but I'm careless with my votes and C!s (so don't show them on my homenode)"
  - Type: boolean (0/1)
  - Default: 0

- **`hidehomenodeUG`** (checkbox) - "I'm a loner, Dottie, a rebel. (Don't list my usergroups on my homenode.)"
  - Type: boolean (0/1)
  - Default: 0

- **`hidehomenodeUC`** (checkbox) - "I'm a secret librarian. (Don't list my categories on my homenode.)"
  - Type: boolean (0/1)
  - Default: 0

- **`showrecentwucount`** (checkbox) - "Let the world know, I'm a fervent noder, and I love it! (show recent writeup count in homenode.)"
  - Type: boolean (0/1)
  - Default: 0

- **`hidelastnoded`** (checkbox inverse) - "Link to user's most recently created writeup on their homenode"
  - Type: boolean (0/1)
  - Default: 0 (show link)

#### Other Display Options
- **`hideauthore2node`** (checkbox inverse) - "Show who created a writeup page title (a.k.a. e2node)"
  - Type: boolean (0/1)
  - Default: 0 (show author)

- **`repThreshold`** - "Hide low-reputation writeups in New Writeups and e2nodes"
  - Type: integer or 'none'
  - Activates with checkbox, text input for threshold value
  - Default: none (don't hide)
  - Max: 50
  - System default threshold: $Everything::CONF->writeuplowrepthreshold

- **`noSoftLinks`** (checkbox) - "Hide softlinks"
  - Type: boolean (0/1)
  - Default: 0

### Information

#### Writeup Maintenance
- **`no_notify_kill`** (checkbox inverse) - "Tell me when my writeups are deleted"
  - Type: boolean (0/1)
  - Default: 0 (notify)

- **`no_editnotification`** (checkbox inverse) - "Tell me when my writeups get edited by an editor or administrator"
  - Type: boolean (0/1)
  - Default: 0 (notify)

#### Writeup Response
- **`no_coolnotification`** (checkbox inverse) - "Tell me when my writeups get C!ed ('cooled')"
  - Type: boolean (0/1)
  - Default: 0 (notify)

- **`no_likeitnotification`** (checkbox inverse) - "Tell me when Guest Users like my writeups"
  - Type: boolean (0/1)
  - Default: 0 (notify)

- **`no_bookmarknotification`** (checkbox inverse) - "Tell me when my writeups get bookmarked on E2"
  - Type: boolean (0/1)
  - Default: 0 (notify)

- **`no_bookmarkinformer`** (checkbox inverse) - "Tell others when I bookmark a writeup on E2"
  - Type: boolean (0/1)
  - Default: 0 (inform others)

- **`anonymous_bookmark`** (checkbox) - "but do it anonymously"
  - Type: boolean (0/1)
  - Default: 0
  - Note: Only applicable when `no_bookmarkinformer` is enabled

#### Social Bookmarking
- **`nosocialbookmarking`** (checkbox inverse) - "Allow others to see social bookmarking buttons on my writeups"
  - Type: boolean (0/1)
  - Default: 0 (allow)
  - Note: Unchecking also hides social bookmarking buttons on other people's writeups

- **`no_socialbookmarknotification`** (checkbox inverse) - "Tell me when my writeups get bookmarked on a social bookmarking site"
  - Type: boolean (0/1)
  - Default: 0 (notify)

- **`no_socialbookmarkinformer`** (checkbox inverse) - "Tell others when I bookmark a writeup on a social bookmarking site"
  - Type: boolean (0/1)
  - Default: 0 (inform)

#### Other Information
- **`no_discussionreplynotify`** (checkbox inverse) - "Tell me when someone replies to my usergroup discussion posts"
  - Type: boolean (0/1)
  - Default: 0 (notify)

- **`hidelastseen`** (checkbox) - "Don't tell anyone when I was last here"
  - Type: boolean (0/1)
  - Default: 0

### Messages

#### Message Inbox
- **`sortmyinbox`** (checkbox) - "Sort my messages in message inbox"
  - Type: boolean (0/1)
  - Default: 0

#### Usergroup Messages
- **`getofflinemsgs`** (checkbox) - "Get online-only messages, even while offline"
  - Type: boolean (0/1)
  - Default: 0

### Miscellaneous

#### Chatterbox
- **`noTypoCheck`** (checkbox inverse) - "Check for chatterbox command typos"
  - Type: boolean (0/1)
  - Default: 0 (check typos)
  - Note: /mgs etc. When enabled, some messages that aren't typos may be flagged

#### Nodeshells
- **`hidenodeshells`** (checkbox) - "Hide nodeshells in search results and softlink tables"
  - Type: boolean (0/1)
  - Default: 0
  - Note: A nodeshell is a page on Everything2 with a title but no content

#### GP System
- **`GPoptout`** (checkbox) - "Opt me out of the GP System"
  - Type: boolean (0/1)
  - Default: 0
  - Note: GP is a points reward system

#### Little-needed
- **`defaultpostwriteup`** (checkbox) - "Publish immediately by default"
  - Type: boolean (0/1)
  - Default: 0
  - Note: Older users may appreciate having 'publish immediately' initially selected instead 'post as draft'

- **`noquickvote`** (checkbox) - "Disable quick functions (a.k.a. AJAX)"
  - Type: boolean (0/1)
  - Default: 0
  - Note: Voting, cooling, chatting, etc will all require complete pageloads

- **`nonodeletcollapser`** (checkbox) - "Disable nodelet collapser"
  - Type: boolean (0/1)
  - Default: 0
  - Note: Clicking on a nodelet title will not hide its content

- **`HideNewWriteups`** (checkbox) - "Hide your new writeups by default"
  - Type: boolean (0/1)
  - Default: 0
  - Note: Some writeups (daylogs, maintenance) always default to hidden

- **`nullvote`** (checkbox) - "Show null vote button"
  - Type: boolean (0/1)
  - Default: 0
  - Note: Some old browsers needed at least one radio-button to be selected

### Unsupported Options

#### Experimental/In Development
- **`localTimeUse`** (checkbox) - "Use my time zone offset"
  - Type: boolean (0/1)
  - Default: 0
  - Note: Does not currently affect display of all times on the site

- **`localTimeOffset`** - Time zone offset
  - Type: select (-43200 to +46800 in 1800-second increments)
  - Extensive timezone dropdown with named locations
  - Default: 0

- **`localTimeDST`** (checkbox) - "I am currently in daylight saving time (so add an hour to my normal offset)"
  - Type: boolean (0/1)
  - Default: 0

- **`localTime12hr`** (checkbox) - "I am from a backwards country that uses a 12 hour clock (show AM/PM instead of 24-hour format)"
  - Type: boolean (0/1)
  - Default: 0

---

## Tab 3: Nodelet Settings

### Nodelet Order
- **`nodelets`** - Comma-separated list of nodelet node_ids
  - Type: string (comma-separated node IDs)
  - UI: Drag-and-drop reordering of dropdown menus
  - Available nodelets from: `$Everything::CONF->supported_nodelets`
  - Note: If 'Epicenter' nodelet is not selected, its functions are placed in the page header

### Per-Nodelet Settings
Dynamic settings based on which nodelets are active. For each active nodelet, if an htmlcode named `{nodelet_title} nodelet settings` exists, display that settings form.

Examples:
- "Notifications nodelet settings"
- "New Writeups nodelet settings"
- etc.

---

## Implementation Notes

### Checkbox Types
- **Regular checkbox** (`varcheckbox`): Checked = 1, Unchecked = 0 (or absent)
- **Inverse checkbox** (`varcheckboxinverse`): Checked = 0 (or absent), Unchecked = 1

### Special VARS Patterns
- **wuhead/wufoot**: Custom format strings that encode multiple boolean flags
- **repThreshold**: Can be integer or string 'none'
- **userstyle**: Node ID reference to stylesheet node
- **nodelets**: Comma-separated node ID list

### Data Storage
- Most preferences: Stored in user VARS
- Favorite noders: Stored in `links` table with `favorite` linktype
- Message blocking: Stored in `messageignore` table
- Notification preferences: Stored in VARS `settings` JSON field

### Default Values
- Many checkboxes default to 0 (unchecked)
- Inverse checkboxes default to 0 (which means feature is ON)
- Some features default to ON (like quick functions, writeup hits display)

---

## Modern React Implementation Strategy

1. **Tab 1: Settings** - Focus on common user preferences
   - Style selection
   - Quick functions (AJAX, transitions, voting)
   - Writeup editing (size, TinyMCE, hints)
   - Anonymous voting
   - Message blocking UI

2. **Tab 2: Advanced** - Power user preferences
   - Writeup header/footer customization
   - Homenode visibility options
   - Notification preferences (split into logical groups)
   - Display thresholds
   - Time zone settings

3. **Tab 3: Nodelets** - Sidebar configuration
   - Drag-and-drop nodelet ordering
   - Add/remove nodelets from sidebar
   - Per-nodelet configuration panels

### API Updates Required
All preferences listed above must be added to `allowed_preferences` in [preferences.pm](../ecore/Everything/API/preferences.pm)

### Validation Rules
- Boolean preferences: 0 or 1
- Select preferences: Must match allowed_values list
- Integer preferences: Validate range (e.g., repThreshold max 50)
- String preferences: Special validation for format strings (wuhead/wufoot)
