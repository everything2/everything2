# Everything2 API Specification

Everything2 needs to evolve to keep up with the times. We've lived with the early 2000s era limitations of the Everything Engine as put together by the Everything Development Company, and a small army of volunteer coders has kept it moving and alive for some time. In order to move to the next level of usability and to embrace the mobile revolution that is now approximately half of our traffic, we need to move to a modern achitecture.

As a part of the future API-driven nature of the site, we need to start abstracting features away into APIs that a richer front-end can drive. I've all but settled on [React.js](http://reactjs.com/), Facebook's front-end framework for fast and responsive UIs. While a UI rewrite is not needed as a part of the API-ification, it is an easy way to start exercising the consumption part of the API and get feedback. It will also as a consequence, start to make the site more responsive as the features come in.

## API religion

* All E2 APIs will be available at https://everything2.com/api/$api. 
* APIs are versioned. To request a specific version of the API, send the accept header: ````Accept: application/vnd.e2.v$version+json````. Versions are all non-decimal numeric numbers. All APIs start at version 1 unless otherwise specified
* API requests that are not versioned are always assumed to be the current version.
* APIs will only be versioned if the fundamental agreements change. We will NOT increment the version if additional fields are returned. You cannot assume that the presence of keys not in your version will break.
* Objects are listed as their plural format and follow the general form: ````/api/$object/$id````
* Objects will embed both the node_id and the title for foreign keys for ease of display
* POSTS accept either JSON-encoded content (application/json) or Form-encoded content with the full JSON payload encoded as the data parameter: (application/x-www-form-urlencoded). 
* While in beta, only authorized API developers will have access to the APIs
* After beta has been eliminated, rate limiting will be imposed. Likely this is 5,000 requests in an hour, measured in 5 minute buckets.
* API endpoints are case-sensitive, which means calls to /API/ will correctly return a 404.

## Return codes and content

Successful APIs will always return 200 OK and well-formed JSON. If you pass a ````Accept-Encoding: gzip```` header, the server may at its discretion compress the output.

Content should always be assumed to be UTF-8 encoded.

Return codes follow basic HTTP conventions.

## Node references

All node references from inside another node are JSON objects containing two fields, regardless of type:
* **node_id** The internal node signifier id
* **title** The user-displayable title. The client is responsible for HTML-encoding it.
* **type** A user-readable type which eventually maps to an API endpoint which you can use to make further requests against it

Being able to see a node_id doesn't mean that you can request the displayable page for it.

If a node reference in the database is broken, you will see the following construct:
````{"node_id": 0, "title": "(unknown)", "type": "(unknown)"}````

There is no node_id 0, so you can key off of that to know that something is broken. The client should be able to handle that gracefully. In places inside of the data model where there is simply no reference in the database, the key won't be returned.

## Dates

All dates are encoded in ISO format:

YYYY-MM-DDT-HH:MM:SSZ

All times are in UTC

### Return codes:

No other content is expected to be returned in any situation other than 200 OK.

* 200 OK,  Request was successful, JSON follows
* 400 BAD REQUEST, The server did not understand the API call or did not have the proper parameters POSTed to it.
* 401 UNAUTHORIZED, The request is not available to users that are not logged in
* 403 FORBIDDEN, The logged in user account does not have the proper permissions on that object and action
* 404 NOT FOUND, The user requested an object which doesn't have a corresponding database entry
* 405 UNIMPLEMENTED, The API path that was specified does not match a valid route
* 410 GONE, The version of the API you requested is no longer available, but the path is valid.

## Retiring old interfaces

During the rapid development period, we may be changing the APIs, but we will be updating this document in git as much as possible. APIs with a version of 1 (beta) are not stable and should be consumed with caution.

# API Catalogue

## Test Coverage Overview

This section documents the automated test coverage for each API endpoint. Coverage indicates how many endpoints have dedicated test suites verifying their functionality.

| API Module | Endpoints | Tested | Coverage | Test File |
|------------|-----------|--------|----------|-----------|
| Sessions | 3 | 3 | ✅ 100% | t/002_sessions_api.t (41 tests) |
| Node Notes | 3 | 3 | ✅ 100% | t/026_nodenotes_api.t (66 tests) |
| Tests | 1 | 1 | ✅ 100% | t/003_api_versions.t (8 tests) |
| Nodes | 7 | 1 | ⚠️ 14% | t/027_nodes_api_clone.t (45 tests for clone only) |
| Users | 7 | 0 | ❌ 0% | None |
| Usergroups | 9 | 0 | ❌ 0% | None |
| Writeups | 7 | 0 | ❌ 0% | None |
| E2nodes | 7 | 0 | ❌ 0% | None |
| Messages | 6 | 6 | ✅ 100% | t/032_messages_api.t (37 tests) |
| Message Ignores | 4 | 0 | ❌ 0% | None |
| System Utilities | 1 | 0 | ❌ 0% | None |
| Preferences | 2 | 2 | ✅ 100% | t/030_preferences_api.t (50 tests) |
| New Writeups | 1 | 1 | ✅ 100% | t/031_newwriteups_api.t (33 tests) |
| Hide Writeups | 2 | 2 | ✅ 100% | t/029_hidewriteups_api.t (32 tests) |
| Developer Variables | 1 | 1 | ✅ 100% | t/028_developervars_api.t (23 tests) |

**Overall API Test Coverage: ~35%** (21 of ~54 endpoints have dedicated tests)

**Infrastructure Tests:**
- t/001_api_routing.t - General API routing (2 tests)
- t/025_api_content_encoding.t - Content-Encoding headers (24 tests)

## Node requests

**Test Coverage: ⚠️ 14%** (1/7 endpoints tested - clone only)

The node requests form is good for looking up particular node_ids, but does not have actions on it.

Looking up the a node_id under a wrong type API throws a 404 NOT FOUND; for instance, looking up a user under /api/usergroups.

### /api/nodes

Always returns UNIMPLEMENTED

### /api/nodes/:id

Returns the readable form of a node. Always the following items:

* **node_id** The unique identifier of the object
* **author** A node reference of the creator of the object
* **creattime** ISO formatted date of when the node was created
* **type** Human readable version of the type. Pluralize to find the right API
* **title** The title of the node

Different types contain additional information.

### /api/nodes/:id/action/delete

Deletes the node if the user has permission to do so.

Returns 403 FORBIDDEN if the user does not have permission

Returns 404 NOT FOUND if the node does not exist

On success returns a has with one key:
* **deleted**: The node_id of the removed node 

### /api/nodes/:id/action/update

Updates the node if the user has permission to do so

Returns 403 FORBIDDEN if the user does not have permission

Returns 404 NOT FOUND if the node does not exist

On success, returns the json display of the newly updated node

The fields that are allowed to be updated work on a whitelist system. The following node type and field combinations are allowed:

* **users** - doctext
* **documents** - doctext
* **usergroups** - doctext

### /api/nodes/:id/action/clone

**POST only, admin-only endpoint**

Creates a complete copy of the specified node with a new title. Only administrators can clone nodes.

**Required POST data:**
* **title** - The title for the cloned node (must be unique)

**Returns:**

* **200 OK** - Clone successful
  * **message** - Success message
  * **original_node_id** - The node_id of the source node
  * **original_title** - The title of the source node
  * **cloned_node_id** - The node_id of the newly cloned node
  * **cloned_title** - The title of the newly cloned node
  * **cloned_node** - Full JSON display of the cloned node

* **400 BAD REQUEST** - Missing or empty title in request
  * **error** - Error message

* **403 FORBIDDEN** - User is not an administrator
  * **error** - "Only administrators can clone nodes"

* **404 NOT FOUND** - Node does not exist
  * **error** - Error message

* **409 CONFLICT** - A node with the specified title already exists
  * **error** - "A node with this title already exists"

* **500 INTERNAL SERVER ERROR** - Clone operation failed
  * **error** - Error message

**Example:**
```json
POST /api/nodes/123456/action/clone
{
  "title": "Clone of My Document"
}

Response (200 OK):
{
  "message": "Node cloned successfully",
  "original_node_id": 123456,
  "original_title": "My Document",
  "cloned_node_id": 789012,
  "cloned_title": "Clone of My Document",
  "cloned_node": {
    "node_id": 789012,
    "title": "Clone of My Document",
    "type": "document",
    ...
  }
}
```

**Implementation Notes:**
- Clones all node data fields except node_id, type, group, and title
- The cloned node receives a new node_id
- The cloning user becomes the creator of the cloned node
- This operation preserves all content and metadata from the original node

### /api/nodes/lookup/:type/:title

Looks up the node by type and title. Note that this currently does not properly handle returning multiple nodes of the same title back.

If the title/type combination does not exist, this returns NOT FOUND

If the user cannot read the node details, this returns FORBIDDEN

## Users

**Test Coverage: ❌ 0%** (0/7 endpoints tested)

### /api/users

Always returns UNIMPLEMENTED

### /api/users/:id

Returns all of the items returned by /api/nodes/:id for that id, plus the following:

* **doctext** - The user's homenode text
* **numcools** - The number of C!s the user has spent
* **experience** - The experience of the user
* **GP** - The GP of the user
* **level** - The current level of the user
* **leveltitle** - The title of the level of the user
* **createtime** - The ISO formatted time when the user signed up
* **lasttime** - The ISO formatted time when the user was last online
* **bookmarks** - Array of bookmark objects. See the bookmarks API. This key is not shown if there are no bookmarks.
* **numwriteups** - Number of writeups a user has created. The key is not displayed if the amount is zero
* **specialties** - User-inputted text field for "specialties" as listed on homenode
* **missions** - User-inputted text field for "mission drive within everything" as listed on homenode
* **employment** - User-inputted text field for "school/company" as listed on homenode
* **motto** - User-inputted text field for "motto" as listed on homenode
* **is_online** - Whether the user is online. This is mostly used internally to send ONO messages, but could be used for other features in the future
* **message_forward_to** - Node reference to message recipient if this is a chatterbox forward

## Usergroups

**Test Coverage: ❌ 0%** (0/9 endpoints tested)

### /api/usergroups/

Always returns UNIMPLEMENTED

### /api/usergroups/:id

Returns all of the items returned by /api/nodes/:id, plus the following:

* **doctext** - Usergroup description
* **group** - An array of node references of group members

### /api/usergroups/create

Allows a user to create a usergroup if they are allowed to. This is currently restricted to admins only. Accepts two post parameters:

* **title** (required) - The title of the new usergroup
* **doctext** - The description of the group

Returns the usergroups/:id display function of the newly created usergroup

### /api/usergroups/:id/action/adduser

Adds users to the usergroup. Takes an array of node_ids to add as a POST parameter

Returns 403 FORBIDDEN if the user doesn't have permission to do this action

Returns 401 Unauthorized if the user is not logged in

Returns the node reference if successful

### /api/usergroups/:id/action/removeuser

Removes users to the usergroup. Takes an array of node_ids to remove

Returns 403 FORBIDDEN if the user doesn't have permission on this group

Returns 401 Unauthorized if the user is not logged in

Returns the node reference if successful

## Writeups

**Test Coverage: ❌ 0%** (0/7 endpoints tested)

### /api/writeups

Always returns UNIMPLEMENTED

### /api/writeups/:id

Returns all of the items in /api/nodes/:id, plus the following:

* **doctext** - Writeup text
* **cools** - Array of node references of users that have C!ed the writeup
* **softlinks** - The softlinks of the parent node for display purposes
* **writeuptype** - The text representation of the type of writeup, such as "thing","person","place","definition"
* **parent** - Node reference to the parent e2node if it exists. The lack of this field denotes an error that should be handled

If a user has voted on it:
* **vote** - Which way the user voted

If a user has voted on it or is the author:
* **reputation** - The reputation of the node if you have voted on it or if it is yours
* **upvotes** - The number of people who have voted up on a node
* **downvotes** - The number of people who have voted down on a node

If a user owns it
* **notnew** - Whether the node was hidden from New Writeups

### /api/writeups/create

Creates a writeup. Requires several parameters:

* **title** - Title that it is being filed under
* **writeuptype** - Type of the writeup (place, person, definition, etc)
* **doctext** - Text of the writeup
* **notnew** - Whether to hide the writeup from new writeups. Defaults to zero.

## E2nodes

**Test Coverage: ❌ 0%** (0/7 endpoints tested)

### /api/e2nodes

Always returns UNIMPLEMENTED

### /api/e2nodes/:id

Returns all of the items in /api/nodes/:id, plus the following:

* **group** - If there are writeups in the node, a listing of /api/writeups objects
* **softlinks** - An array of node references with an additional parameter: ``hits``. They are in hits order
* **createdby** - Node reference to the user that created the e2node. Internally, all e2nodes are owned by "Content Editors" so they cannot be retitled or deleted by random users.

### /api/e2nodes/create

Accepts a POST parameter with the following parameters:

* **title** - The title of the e2node to create

Note that due to a quirk in the security model of e2, all e2node owners are set to "Content Editors" in the system, with an additional owner set in a different table.

Returns the display of e2nodes/:id of the newly created object

## Drafts

## Documents

## Superdocument

## Messages

**Test Coverage: ✅ 100%** (6/6 endpoints tested - t/032_messages_api.t)

Current version: *1 (beta)*

Retrieves, sends, and sets status on messages

### /api/messages

Returns the top 15 messages ordered by newest first.

Takes two optional GET parameters for pagination
* *limit* - Number of messages to return at a time. If left blank defaults to 15. Maximum of 100
* *offset* - Offset of the number of messages to return from DESC sorting

Messages have the following keys:

* **message_id** - The internal message identifier
* **timestamp** - The creation time of the message in ISO format
* **for_user** - The node reference of the receving user. This is almost certainly the logged in user, though in future versions, admins should be able to check system accounts (root, CME, Klaproth)
* **author_user** - The node reference of the sending user.
* **msgtext** - The text of the message
* **for_usergroup** - The node reference of the group the message was send to. Missing if not a usergroup message

Users who are not logged in should expect to receive 401 Unauthorized

### /api/messages/:id

Returns the message at :id, formatted per the */api/messages* construct. Users who do not own the message should expect to receive 403 Forbidden.

### /api/messages/:id/action/delete

Deletes the message at :id. 

Returns 403 Forbidden if you don't own the message or the message does not exist.

On success returns a hash with the id of the deleted message.

### /api/messages/:id/action/archive

Archives the message at :id

Return parameters the same as action/delete

### /api/messages/:id/action/unarchive

Unarchives the message at :id

Return parameters the same as action/delete

### /api/messages/create

Sends a message. At this time, will accept a usergroup in "for", but will not deliver it.

Accepts a JSON post with the following parameters
* **for** - The name of the user to have the message delivered to
* **for_id** - More precise and preferred version of the user to be sent. Is ignored if this and **for** are sent at the same time.
* **message** - The message text to send

## Message Ignores

**Test Coverage: ❌ 0%** (0/4 endpoints tested)

Current version: *1 (beta)*

Sets message blocking preferences. If you block a user, you won't see messages from that user. If you block a usergroup, you won't see messages sent to that usergroup (that presumably you are a member of). Has no other practical effect in blocking non user or usergroup nodes from messaging you.

All methods return 401 Unauthorized for Guest

### /api/messageignores

Lists all of the nodes you are ignoring messages from in an array of nodes in standard node reference JSON format.

### /api/messageignores/create

Accepts a post with one of two parameters
* **ignore_id** - The node_id to ignore messages from
* **ignore** - The node to ignore messages from. Tries a usergroup first, then a user. If neither are found returns 400 Bad Request  

### /api/messageignores/:id

Retrives a node format if you are blocking messages from that node, 404 NOT FOUND otherwise

### /api/messageignores/:id/delete

Stops ignoring a particular node at :id

## Preferences

**Test Coverage: ✅ 100%** (2/2 endpoints tested - t/030_preferences_api.t)

Current version: *1 (beta)*

Manages user interface preferences and settings. Preferences control various display and behavior options for the user interface, such as which nodelets to hide, how many new writeups to display, and UI element collapse states.

All preference methods return 401 Unauthorized for Guest User.

### /api/preferences/get

Returns the current user's preferences as a JSON object containing all allowed preference keys and their values. If a preference has not been explicitly set by the user, the default value is returned.

Returns a JSON object with the following structure:

```json
{
  "vit_hidemaintenance": 0,
  "vit_hidenodeinfo": 0,
  "vit_hidenodeutil": 0,
  "vit_hidelist": 0,
  "vit_hidemisc": 0,
  "edn_hideutil": 0,
  "edn_hideedev": 0,
  "nw_nojunk": 0,
  "num_newwus": 15,
  "collapsedNodelets": ""
}
```

#### Allowed Preferences

**UI Visibility Preferences (0 = show, 1 = hide):**
* **vit_hidemaintenance** - Hide maintenance nodelet (default: 0)
* **vit_hidenodeinfo** - Hide node info nodelet (default: 0)
* **vit_hidenodeutil** - Hide node utilities nodelet (default: 0)
* **vit_hidelist** - Hide list nodelet (default: 0)
* **vit_hidemisc** - Hide miscellaneous nodelet (default: 0)
* **edn_hideutil** - Hide editor utilities (default: 0)
* **edn_hideedev** - Hide e2dev utilities (default: 0)
* **nw_nojunk** - Hide junk from new writeups (default: 0)

**Display Preferences:**
* **num_newwus** - Number of new writeups to display (default: 15, allowed: 1, 5, 10, 15, 20, 25, 30, 40)

**State Preferences:**
* **collapsedNodelets** - String containing collapsed nodelet state (default: empty string, accepts any string matching regex /.?/)

### /api/preferences/set

Sets one or more user preferences. Accepts a JSON POST body with preference key-value pairs to update. Multiple preferences can be set in a single request.

**POST Parameters:**

Accepts a JSON object with one or more preference keys and their new values:

```json
{
  "vit_hidenodeinfo": 1,
  "num_newwus": 25,
  "collapsedNodelets": "epicenter!readthis!"
}
```

**Validation:**
* All preference keys must be in the allowed preferences list
* All values must match their allowed values (specific list for List preferences, regex pattern for String preferences)
* If any key or value fails validation, the entire request is rejected with 401 Unauthorized
* No partial updates occur on validation failure

**Special Behavior:**
* Setting a List preference to its default value will delete the preference from the user's stored settings
* Setting a String preference to an empty string or whitespace-only string will delete the preference
* Deleted preferences will return their default values on subsequent GET requests

**Returns:**

On success (200 OK), returns the same structure as GET /api/preferences/get with all current preference values, including the newly updated ones.

On validation failure (401 Unauthorized), no preferences are updated.

**Example Request:**

```bash
curl -X POST https://everything2.com/api/preferences/set \
  -H "Content-Type: application/json" \
  -H "Cookie: userpass=..." \
  -d '{"vit_hidenodeinfo": 1, "num_newwus": 25}'
```

**Example Response (200 OK):**

```json
{
  "vit_hidemaintenance": 0,
  "vit_hidenodeinfo": 1,
  "vit_hidenodeutil": 0,
  "vit_hidelist": 0,
  "vit_hidemisc": 0,
  "edn_hideutil": 0,
  "edn_hideedev": 0,
  "nw_nojunk": 0,
  "num_newwus": 25,
  "collapsedNodelets": ""
}
```

## Node Notes

**Test Coverage: ✅ 100%** (3/3 endpoints tested - t/026_nodenotes_api.t)

Current version: *1 (beta)*

Retrieves editor notes attached to nodes. Node notes are annotations that editors can add to any node to track issues, coordinate work, or provide context. The API returns notes for the requested node and may include related notes (e.g., for writeups, includes parent e2node notes; for e2nodes, includes all child writeup notes).

All node notes methods require editor privileges and return 401 Unauthorized for non-editors.

### /api/nodenotes/:node_id

Returns all notes for the specified node, following the database relationship patterns:

- **For documents and other simple nodes**: Returns notes directly attached to the node
- **For writeups**: Returns notes for the writeup AND its parent e2node
- **For e2nodes**: Returns notes for the e2node AND all its child writeups

**URL Parameters:**
* **node_id** - The node_id to retrieve notes for (required, must be numeric)

**Returns:**

200 OK with JSON object containing:

```json
{
  "node_id": 123,
  "node_title": "Example Node",
  "node_type": "writeup",
  "count": 2,
  "notes": [
    {
      "nodenote_id": 456,
      "nodenote_nodeid": 123,
      "notetext": "This writeup needs cleanup",
      "noter_user": 789,
      "timestamp": "2025-11-21 12:34:56"
    },
    {
      "nodenote_id": 457,
      "nodenote_nodeid": 100,
      "notetext": "Parent e2node note",
      "noter_user": 790,
      "timestamp": "2025-11-20 10:15:30",
      "node_title": "Parent E2node Title",
      "node_type": "e2node"
    }
  ]
}
```

**Response Keys:**

Top-level keys:
* **node_id** - The requested node_id
* **node_title** - Title of the requested node
* **node_type** - Type of the requested node
* **count** - Total number of notes returned
* **notes** - Array of note objects

Note object keys:
* **nodenote_id** - Unique identifier for this note
* **nodenote_nodeid** - The node_id this note is attached to (may differ from requested node_id for related notes)
* **notetext** - The text content of the note
* **noter_user** - The user_id of the editor who created the note (0 for system notes)
* **noter_username** - (Optional) The username of the editor who created the note (only present for modern format notes where noter_user > 1)
* **timestamp** - When the note was created (ISO 8601 format)
* **legacy_format** - (Optional) If set to 1, indicates this is a legacy format note where the author was encoded directly in the notetext string. When present, noter_username will NOT be included and the full notetext should be displayed as-is
* **node_title** - (Optional) Title of the node if this is a related note (e.g., parent e2node title when viewing writeup notes)
* **node_type** - (Optional) Type of the node if this is a related note
* **author_user** - (Optional) The author_user field when querying e2node notes (included for writeup author context)

**Error Responses:**

* **400 Bad Request** - Invalid node_id (not numeric)
  ```json
  { "error": "Invalid node_id" }
  ```

* **401 Unauthorized** - User is not an editor

* **404 Not Found** - Node does not exist
  ```json
  { "error": "Node not found" }
  ```

**Example Request:**

```bash
curl https://everything2.com/api/nodenotes/123 \
  -H "Cookie: userpass=..."
```

**Implementation Notes:**

- Node notes use specialized queries based on node type for efficiency
- System notes (noter_user = 0) are displayed with a bullet (•) instead of a deletion checkbox
- Notes are ordered by nodenote_nodeid, then timestamp
- The API leverages the same `getNodeNotes()` method used for HTML rendering to avoid extra database queries during page load
- **Legacy format notes**: In the early history of E2, node notes did not have a proper foreign key to the noter user. Instead, the author was encoded directly in the notetext string (e.g., "[username[user]]: note text"). These legacy notes have `noter_user = 1` as a placeholder value. When the API detects `noter_user = 1`, it sets `legacy_format = 1` and does NOT populate the `noter_username` field. Clients should display the full notetext as-is for legacy notes, as it contains the author attribution

### POST /api/nodenotes/:node_id/create

Adds a new note to the specified node and returns the updated list of all notes for that node.

**URL Parameters:**
* **node_id** - The node_id to add a note to (required, must be numeric)

**Request Body:**

JSON object with:

```json
{
  "notetext": "This is a new note"
}
```

**Request Keys:**
* **notetext** - The text content of the note (required, cannot be empty)

**Returns:**

200 OK with the same JSON structure as GET /api/nodenotes/:node_id, containing the updated list of all notes including the newly created note.

**Error Responses:**

* **400 Bad Request** - Invalid node_id, missing notetext, or empty notetext
  ```json
  { "error": "Invalid node_id" }
  { "error": "Missing notetext in request body" }
  { "error": "Note text cannot be empty" }
  ```

* **401 Unauthorized** - User is not an editor

* **404 Not Found** - Node does not exist
  ```json
  { "error": "Node not found" }
  ```

* **500 Internal Server Error** - Failed to create note in database
  ```json
  { "error": "Failed to create note" }
  ```

**Example Request:**

```bash
curl -X POST https://everything2.com/api/nodenotes/123/create \
  -H "Cookie: userpass=..." \
  -H "Content-Type: application/json" \
  -d '{"notetext": "Needs copyediting"}'
```

**Implementation Notes:**

- The noter_user is automatically set to the current logged-in editor
- The timestamp is automatically set to the current time (NOW())
- After creating the note, returns the full updated notes list for the node
- Notes are permanently stored in the nodenote table

### DELETE /api/nodenotes/:node_id/:note_id/delete

Deletes a specific note and returns the updated list of remaining notes for the node.

**URL Parameters:**
* **node_id** - The node_id the note belongs to (required, must be numeric)
* **note_id** - The nodenote_id to delete (required, must be numeric)

**Returns:**

200 OK with the same JSON structure as GET /api/nodenotes/:node_id, containing the updated list of remaining notes after deletion.

**Error Responses:**

* **400 Bad Request** - Invalid node_id or note_id (not numeric)
  ```json
  { "error": "Invalid node_id" }
  { "error": "Invalid note_id" }
  ```

* **401 Unauthorized** - User is not an editor

* **403 Forbidden** - User is not the note author and not an admin
  ```json
  { "error": "You can only delete your own notes" }
  ```

* **404 Not Found** - Node or note does not exist, or note is not associated with this node
  ```json
  { "error": "Node not found" }
  { "error": "Note not found" }
  { "error": "Note not associated with this node" }
  ```

* **500 Internal Server Error** - Failed to delete note from database
  ```json
  { "error": "Failed to delete note" }
  ```

**Example Request:**

```bash
curl -X DELETE https://everything2.com/api/nodenotes/123/456/delete \
  -H "Cookie: userpass=..."
```

**Implementation Notes:**

- Editors can only delete their own notes unless they are admins
- Admins can delete any note regardless of author
- The API verifies that the note actually belongs to the specified node (including e2node/writeup relationships)
- After deletion, returns the full updated notes list for the node
- Deletion is permanent and cannot be undone

## Chats

## Bookmarks

## Votes

## Cools

## New Writeups

**Test Coverage: ✅ 100%** (1/1 endpoints tested - t/031_newwriteups_api.t)

### /api/newwriteups

Returns a JSON array of new writeups. 

Parameters:
* **limit** - Limit the number of items returned. Non-guest users can specify this. This defaults to 15, and has a maximum of 40. If you are an editor, this is the effective display limit, not only just visible writeups. 

New writeups keys:
* **node_id** - Node ID
* **title** - Title of the writeup
* **writeuptype** - Type of the writeup (person, place, thing, how-to, etc)
* **author** - Node reference for the author
* **parent** - Node reference for the parent e2node
* **is_log** - Whether the node is a log of some type (daylog, ed log, etc)
* **notnew** - If you are an editor, whether the node was hidden from new writeups

## Hide Writeups

**Test Coverage: ✅ 100%** (2/2 endpoints tested - t/029_hidewriteups_api.t)

Current version: *1 (beta)*

Controls visibility of writeups in the New Writeups list. Editors can hide writeups from appearing in New Writeups (useful for removing junk, spam, or placeholder writeups) or show them again if they were previously hidden. This toggles the `notnew` flag on writeup nodes.

All hide writeups methods require editor privileges and return 401 Unauthorized for non-editors.

### POST /api/hidewriteups/:id/action/hide

Hides the specified writeup from the New Writeups list by setting its `notnew` flag to 1.

**URL Parameters:**
* **id** - The node_id of the writeup to hide (required, must be a writeup type)

**Returns:**

200 OK with JSON object containing:

```json
{
  "node_id": 123456,
  "notnew": true
}
```

**Response Keys:**
* **node_id** - The node_id of the writeup
* **notnew** - Boolean indicating the writeup is now hidden (always `true` for this endpoint)

**Error Responses:**

* **401 Unauthorized** - User is not an editor, or the node doesn't exist or is not a writeup type

**Example Request:**

```bash
curl -X POST https://everything2.com/api/hidewriteups/123456/action/hide \
  -H "Cookie: userpass=..."
```

**Implementation Notes:**

- Only works on writeup type nodes
- Updates the New Writeups data cache immediately after hiding
- Hidden writeups will no longer appear in the public New Writeups list
- Editors can still see hidden writeups in New Writeups with the `notnew` flag displayed
- This is commonly used to filter out junk, spam, or very short writeups from New Writeups

### POST /api/hidewriteups/:id/action/show

Shows the specified writeup in the New Writeups list by setting its `notnew` flag to 0.

**URL Parameters:**
* **id** - The node_id of the writeup to show (required, must be a writeup type)

**Returns:**

200 OK with JSON object containing:

```json
{
  "node_id": 123456,
  "notnew": false
}
```

**Response Keys:**
* **node_id** - The node_id of the writeup
* **notnew** - Boolean indicating the writeup is now visible (always `false` for this endpoint)

**Error Responses:**

* **401 Unauthorized** - User is not an editor, or the node doesn't exist or is not a writeup type

**Example Request:**

```bash
curl -X POST https://everything2.com/api/hidewriteups/123456/action/show \
  -H "Cookie: userpass=..."
```

**Implementation Notes:**

- Only works on writeup type nodes
- Updates the New Writeups data cache immediately after showing
- Writeup will reappear in the New Writeups list (if it's still within the time/count window)
- This can be used to undo an accidental hide operation

## Sessions

**Test Coverage: ✅ 100%** (3/3 endpoints tested - t/002_sessions_api.t)

Current version: *1 (beta)*

Logs a user in

### /api/sessions

Returns the JSON encoded values associated with the current session

Keys:
* **display** - Contains private information about the session
  * **is_guest** - 1 or 0 depending on whether the user is a "logged in user". This is the preferred check other than the internal user "Guest User"
  * **infravision** - Person can see cloaked users
  * **powers** - Array of special powers the client can use to display more advanced tools. This is not shown if there are no special powers to display 
    * **ed** - User is an editor
    * **admin** - User is an admin
    * **chanop** - User is a channel operator
    * **client** - User is a client developer (Not given to admins by default for UI clarity)
    * **dev** - User is a site developer (Same as **client**)
  * **votesleft** - How many votes left the user has
  * **coolsleft** - How many C!s left the user has
  * **newxp** - Any new xp the user has gotten. Once this message is seen once, it goes away
  * **newgp** - Any new gp the user has gotten. Once this message is seen once, it goes away
  * **xp_to_level** - The amount of xp until the user reaches the next level
  * **writeups_to_level** - The number of writeups until the user reaches the next level
* *user** - If the user is not a guest, the output of /api/user for the user_id

### /api/sessions/create
Accepts a POST with two parameters
* **username** - Username of the user
* **passwd** - Password of the user

If the login was unsuccessful, a 403 Forbidden is returned.

If the login was successful, the output of /api/sessions is returned, along with the cookie in the headers as Set-Cookie to continue the authentication. The cookie does not have an expiration.

### /api/sessions/delete
Tears down the current session. Not explicitly needed since no on-server state is kept for sessions. Simply deletes the cookie. Regardless of its current use, we recommend calling this in case any backend server state does need to be cleaned.

Returns the output of /api/sessions for the new current user, which is probably Guest User. Logging out Guest User has no other effect.

## System Utilities

**Test Coverage: ❌ 0%** (0/1 endpoints tested)

### /api/systemutilities/roompurge

(Admin only) Kicks all users "offline" for the purposes of ONO messages. Desirable mostly for testing

## Developer Variables

**Test Coverage: ✅ 100%** (1/1 endpoints tested - t/028_developervars_api.t)

Current version: *1 (beta)*

Provides access to user preference variables (VARS) for developers. This endpoint is used in production by the Everything Developer nodelet, which displays a modal dialog showing the user's $VARS information for debugging and system visibility purposes.

All developer variables methods require developer privileges and return 401 Unauthorized for non-developers.

### GET /api/developervars/

Returns all user VARS (preferences/settings) for the currently logged-in user as a JSON object.

**Returns:**

200 OK with JSON object containing all user VARS as key-value pairs:

```json
{
  "vit_hidenodeinfo": "1",
  "num_newwus": "25",
  "collapsedNodelets": "epicenter!readthis!",
  "theme": "dark",
  "custom_setting_1": "value1",
  "custom_setting_2": "value2"
}
```

**Response Structure:**

The response is a flat JSON object where:
* **Keys** - Variable names from the user's VARS hash
* **Values** - Variable values (typically strings, but can be any JSON-serializable type)

**Error Responses:**

* **401 Unauthorized** - User is not a developer

**Example Request:**

```bash
curl https://everything2.com/api/developervars/ \
  -H "Cookie: userpass=..."
```

**Implementation Notes:**

- This endpoint returns ALL variables stored in the user's VARS hash, not just the standard preferences exposed through `/api/preferences`
- VARS can contain various system-internal settings, user preferences, UI state, and custom variables
- This is a read-only endpoint - it does not provide a way to set variables (use `/api/preferences/set` for standard preferences)
- Developer privileges are required to access this endpoint to prevent unauthorized inspection of user settings
- **Production Usage**: Powers the Everything Developer nodelet's modal dialog that displays $VARS information for system visibility
- Useful for:
  - Real-time inspection of user settings and preferences
  - Debugging preference-related issues
  - Understanding what settings a user has configured
  - Verifying correct preference storage and retrieval
  - Development and testing of preference-dependent features

**Common VARS keys you might see:**

- **vit_hide*** - Visibility preferences for nodelets
- **edn_hide*** - Editor-specific visibility preferences
- **num_newwus** - Number of new writeups to display
- **nw_nojunk** - Hide junk from new writeups
- **collapsedNodelets** - State of collapsed nodelets
- **theme** - User theme preference
- Various other system and custom settings

## Searches

## Tests

### /api/tests (version 2)
returns ````{"v": 2}````

### /api/tests (version 3)
returns ````{"version": 3}````
Test-only API which is to validate version-acceptance

