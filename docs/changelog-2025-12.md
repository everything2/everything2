# December 2025 Changelog

**Development Period**: December 1-2, 2025

## Overview

This month focused on improving message blocking notifications and cleaning up deprecated user preferences from the Settings interface.

---

## Message Blocking Notifications

### User-Facing Changes

**Immediate Block Notification Across All Messaging Methods**

Users now receive immediate, clear feedback when attempting to send messages to users who have blocked them, regardless of the delivery method:

1. **Chatterbox `/msg` commands** - Displays inline feedback with 5-second auto-dismiss:
   - **Red error** for complete blocks: "{username} is ignoring you"
   - **Yellow warning** for partial usergroup blocks: "Message sent, but N user(s) are blocking you"
2. **Message modal (Messages nodelet & Message Inbox)** - Displays feedback in modal:
   - **Red error box** for complete blocks (direct messages to blocking users)
   - **Yellow warning box** for partial blocks (usergroup messages where some members block you)
3. **Usergroup messages** - Partial delivery with warning: "Message sent, but N user(s) are blocking you"
4. **Deprecated preference removed** - Removed "If one of your messages is blocked, you will be informed" dropdown from Settings

**Before**: Users had to configure how they wanted to be notified about blocks (private message, chatterbox, both, or not at all). The default for new users was "do not inform", leading to confusing one-sided conversations.

**After**: All users always receive immediate inline notification regardless of preference setting. The legacy `informmsgignore` VARS setting is now deprecated and ignored.

### Technical Implementation

**Backend Changes**

- [Application.pm:4812-4822](../ecore/Everything/Application.pm#L4812-L4822) - Individual user blocking check in `sendUsergroupMessage()`
- [Application.pm:4719-4723](../ecore/Everything/Application.pm#L4719-L4723) - Error tracking for blocked usergroup members
- [Application.pm:4261-4275](../ecore/Everything/Application.pm#L4261-L4275) - Returns warning for partial blocks, error for complete blocks in `handlePrivateMessageCommand()`
- [chatter.pm:74-75](../ecore/Everything/API/chatter.pm#L74-L75) - Passes through warnings from message commands to chatterbox
- [messages.pm:123-138](../ecore/Everything/API/messages.pm#L123-L138) - Transforms usergroup blocking response to frontend-compatible format (converts `ignores` count to `errors` array)

**Frontend Changes**

- [MessageModal.js:31](../react/components/MessageModal.js#L31) - Added warning state support
- [MessageModal.js:413-425](../react/components/MessageModal.js#L413-L425) - Yellow warning display for partial blocks
- [Messages.js:221-234](../react/components/Nodelets/Messages.js#L221-L234) - Returns warning for usergroup partial blocks
- [MessageInbox.js:360-375](../react/components/Documents/MessageInbox.js#L360-L375) - Returns warning for usergroup partial blocks
- [Chatterbox.js:171](../react/components/Nodelets/Chatterbox.js#L171) - Added messageWarning state
- [Chatterbox.js:275-330](../react/components/Nodelets/Chatterbox.js#L275-L330) - Mini-messages modal checks for warnings
- [Chatterbox.js:523-540](../react/components/Nodelets/Chatterbox.js#L523-L540) - Chatterbox submit checks data.warning
- [Chatterbox.js:972-991](../react/components/Nodelets/Chatterbox.js#L972-L991) - Yellow warning display in chatterbox
- Complete blocks (direct messages) show red errors, partial blocks (usergroups) show yellow warnings

**Settings UI Update**

- [Settings.js:739-743](../react/components/Documents/Settings.js#L739-L743) - Removed deprecated `informmsgignore` preference selector
- Replaced with informational note: "When you try to send a message to someone who has blocked you, you'll be notified immediately with an error message in the chatterbox or message compose window."

**Documentation**

- [user-vars-reference.md:120](../docs/user-vars-reference.md#L120) - Marked `informmsgignore` as **DEPRECATED**
- Values 1 (chatterbox) and 2 (both) now treated as 0 (direct message equivalent - inline notification)

### Testing

Comprehensive test suite: [t/047_message_block_notifications.t](../t/047_message_block_notifications.t)

**37 tests across 5 scenarios**:
- Direct message blocking (7 tests)
- Usergroup with individual blockers (10 tests)
- `/msg` command blocking (6 tests)
- Multiple blockers in usergroup (8 tests)
- Distinction between usergroup vs individual blocks (5 tests)

---

## Message Inbox Sorting

### User-Facing Changes

**Removed Obsolete Sorting Preference**

The "Sort my messages in message inbox" checkbox has been removed from Settings > Advanced > Messages.

**Before**: Users could toggle message sorting in the inbox, but the modern Message Inbox (introduced in previous work) already hardcodes sorting by most recent first.

**After**: Settings now displays an informational note: "The Message Inbox now always displays messages sorted by most recent first (newest at top)."

### Technical Implementation

**Settings UI Update**

- [Settings.js:1241-1249](../react/components/Documents/Settings.js#L1241-L1249) - Removed `sortmyinbox` checkbox
- Added informational note explaining fixed sorting behavior

**Documentation**

- [user-vars-reference.md:121](../docs/user-vars-reference.md#L121) - Marked `sortmyinbox` as **DEPRECATED**
- Note: "Modern Message Inbox always sorts by most recent first (newest at top). Setting no longer has any effect."

**Backend Verification**

- [Application.pm:3901](../ecore/Everything/Application.pm#L3901) - `get_messages()` uses hardcoded `ORDER BY tstamp DESC`
- The `sortmyinbox` VARS setting is never checked or used by modern code

---

## Chatterbox Command Validation

### User-Facing Changes

**Removed Obsolete Typo Checking Preference**

The "Check for chatterbox command typos" checkbox has been removed from Settings > Advanced > Miscellaneous > Chatterbox.

**Before**: Users could toggle typo checking for chatterbox commands (e.g., warning if they typed `/mgs` instead of `/msg`).

**After**: Settings now displays an informational note: "The modern chatterbox automatically validates all commands. Messages starting with '/' are processed as commands and will show an error if the command is invalid."

### Technical Implementation

**Settings UI Update**

- [Settings.js:1263-1271](../react/components/Documents/Settings.js#L1263-L1271) - Removed `noTypoCheck` checkbox
- Added informational note explaining built-in command validation

**Backend Verification**

- Modern chatterbox processes all messages through `/api/chatter/create` endpoint
- Backend `processMessageCommand()` in Application.pm validates all commands
- Invalid commands return `{success: 0, error: "..."}` which displays in chatterbox
- No explicit typo checking logic needed - validation is inherent to command processing

**Documentation**

- [user-vars-reference.md:122](../docs/user-vars-reference.md#L122) - Marked `noTypoCheck` as **DEPRECATED**
- Note: "Modern chatterbox automatically validates all commands - messages starting with '/' are processed as commands and show errors if invalid. Protection is now built-in."

---

## Nodelet Collapsing

### User-Facing Changes

**Removed Obsolete Nodelet Collapser Preference**

The "Disable nodelet collapser" checkbox has been removed from Settings > Advanced > Miscellaneous > Other Options.

**Before**: Users could toggle whether clicking nodelet titles would collapse/expand content.

**After**: Modern React nodelets always have collapsing enabled as a core UX feature - clicking any nodelet title toggles its content visibility. This is a built-in feature that cannot be disabled.

### Technical Implementation

**Settings UI Update**

- [Settings.js:1315-1326](../react/components/Documents/Settings.js#L1315-L1326) - Removed `nonodeletcollapser` checkbox (no replacement note needed)

**Backend Verification**

- [NodeletContainer.js:8](../react/components/NodeletContainer.js#L8) - Uses react-collapsible Collapsible component unconditionally
- No check for window.e2.nonodeletcollapser or VARS preference
- Collapsing is always enabled in modern implementation

**Documentation**

- [user-vars-reference.md:123](../docs/user-vars-reference.md#L123) - Marked `nonodeletcollapser` as **DEPRECATED**
- Note: "Modern React nodelets always have collapsing enabled - clicking nodelet titles toggles content visibility. This is a core UX feature that cannot be disabled."

---

## Summary of Deprecated VARS

Four user preferences deprecated this month:

| VARS Key | Reason | Replacement |
|----------|--------|-------------|
| `informmsgignore` | Always show inline notifications | Automatic inline errors in all message interfaces |
| `sortmyinbox` | Modern inbox always sorts by most recent | Hardcoded DESC timestamp sort in `get_messages()` |
| `noTypoCheck` | Modern chatterbox validates all commands | Built-in command validation in `processMessageCommand()` |
| `nonodeletcollapser` | Modern nodelets always collapsible | Built-in Collapsible component in NodeletContainer |

All four settings remain in the database for backward compatibility with legacy code paths, but no longer appear in the modern Settings interface.

---

## Files Modified

### Backend (Perl)
- `ecore/Everything/Application.pm` - Message blocking error/warning handling for all delivery methods
- `ecore/Everything/API/chatter.pm` - Passes through warnings from message commands
- `ecore/Everything/API/messages.pm` - Transforms usergroup blocking responses to errors array
- `ecore/Everything/Page/settings.pm` - Passes advanced preferences to React
- `ecore/Everything/API/preferences.pm` - Maintains `informmsgignore` in allowed list for legacy compatibility

### Frontend (React)
- `react/components/Documents/Settings.js` - Removed deprecated preference selectors, added informational notes
- `react/components/MessageModal.js` - Added warning state support (yellow box for partial blocks)
- `react/components/Nodelets/Messages.js` - Error/warning handling for blocking (red for complete, yellow for partial)
- `react/components/Documents/MessageInbox.js` - Error/warning handling for blocking (red for complete, yellow for partial)
- `react/components/Nodelets/Chatterbox.js` - Yellow warning support for `/msg` partial blocks, handles mini-messages modal warnings

### Documentation
- `docs/user-vars-reference.md` - Documented both deprecated VARS keys
- `docs/changelog-2025-12.md` - This file

### Tests
- `t/047_message_block_notifications.t` - Comprehensive test coverage (37 tests)

---

## Announcement Notes

**For user announcement:**

> **Message Blocking Improvements**
>
> We've improved how Everything2 handles message blocking:
>
> - You'll now always be notified immediately when trying to message someone who has blocked you
> - Direct messages to blocking users show a red error box
> - Usergroup messages where some members block you show a yellow warning (message still delivered to other members)
> - Errors appear directly in the chatterbox or message compose window - no more silent failures
> - Removed the confusing "how do you want to be notified" preference - it's automatic now
>
> **Message Inbox Sorting**
>
> The Message Inbox now always shows your newest messages first. The "sort messages" checkbox has been removed from Settings since this is now the standard behavior.
>
> **Chatterbox Command Validation**
>
> The modern chatterbox now automatically validates all commands. The "check for command typos" setting has been removed since protection against typos like `/mgs` is now built-in - all messages starting with "/" are validated and will show an error if the command is invalid.
>
> **Nodelet Collapsing**
>
> Modern nodelets now always support collapsing (clicking the title to hide/show content). The "disable nodelet collapser" setting has been removed since this is a core usability feature.

---

**Last Updated**: 2025-12-02
