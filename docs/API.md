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

**Last Updated**: 2025-12-22

| API Module | Endpoints | Tested | Coverage | Test File |
|------------|-----------|--------|----------|-----------|
| **Core User & Content** |
| Sessions | 3 | 3 | ✅ 100% | [t/002_sessions_api.t](../t/002_sessions_api.t) (41 tests, integration) |
| Signup | 1 | 1 | ✅ 100% | [t/063_signup_api.t](../t/063_signup_api.t) (85 tests, MockRequest) |
| Users | 7 | 1 | ⚠️ 14% | [t/048_user_api.t](../t/048_user_api.t) (partial coverage) |
| User Search | 1 | 1 | ✅ 100% | [t/069_user_search_api.t](../t/069_user_search_api.t) (MockRequest) |
| Usergroups | 10 | 4 | ⚠️ 40% | [t/004_usergroups.t](../t/004_usergroups.t) (create, add, remove, leave) |
| Writeups | 7 | 7 | ✅ 100% | [t/056_writeups_api.t](../t/056_writeups_api.t) (33 tests, MockRequest) |
| E2nodes | 7 | 7 | ✅ 100% | [t/061_e2nodes_api.t](../t/061_e2nodes_api.t) (23 tests, MockRequest) |
| E2node | 8 | 8 | ✅ 100% | [t/072_e2node_api.t](../t/072_e2node_api.t) (101 tests, MockRequest) - firmlinks, repair, orderlock, title, lock, reorder, softlinks |
| Nodes | 7 | 2 | ⚠️ 29% | [t/022_nodes_api_clone.t](../t/022_nodes_api_clone.t), [t/025_nodes_api_delete.t](../t/025_nodes_api_delete.t) |
| **Editor Features** |
| Drafts | 7 | 7 | ✅ 100% | [t/065_drafts_api.t](../t/065_drafts_api.t) (238 tests, MockRequest) - list, get, create, update, delete, search, publish |
| Autosave | 5 | 5 | ✅ 100% | [t/074_autosave_api.t](../t/074_autosave_api.t) (45 tests, MockRequest) - create, get, delete, restore, history |
| Hide Writeups | 2 | 2 | ✅ 100% | [t/028_hidewriteups_api.t](../t/028_hidewriteups_api.t) (32 tests) |
| Node Notes | 3 | 3 | ✅ 100% | [t/021_nodenotes_api.t](../t/021_nodenotes_api.t) (66 tests) |
| Node Parameter | 3 | 3 | ✅ 100% | [t/081_node_parameter_api.t](../t/081_node_parameter_api.t) (21 tests, MockRequest) - get, set, delete with admin checks |
| Writeup Reparent | 1 | 1 | ✅ 100% | [t/053_writeup_reparent_api.t](../t/053_writeup_reparent_api.t) |
| Weblog | 1 | 1 | ✅ 100% | [t/073_weblog_api.t](../t/073_weblog_api.t) (MockRequest) - entry removal |
| **Messaging & Social** |
| Messages | 7 | 7 | ✅ 100% | [t/032_messages_api.t](../t/032_messages_api.t) (37 tests) + integration tests |
| Message Ignores | 4 | 4 | ✅ 100% | [t/059_messageignores_api.t](../t/059_messageignores_api.t) (62 tests, MockRequest) |
| User Interactions | 5 | 5 | ✅ 100% | [t/080_userinteractions_api.t](../t/080_userinteractions_api.t) (24 tests, MockRequest) - unified blocking API (hide_writeups, block_messages) |
| Notifications | 2 | 2 | ✅ 100% | [t/040_notifications_api.t](../t/040_notifications_api.t) + integration tests |
| Personal Links | 4 | 4 | ✅ 100% | [t/033_personallinks_api.t](../t/033_personallinks_api.t) (18 tests) |
| **Chat & Rooms** |
| Chatroom | 3 | 3 | ✅ 100% | [t/035_chatroom_api.t](../t/035_chatroom_api.t) |
| Chatter | 2 | 2 | ✅ 100% | [t/038_chatter_api.t](../t/038_chatter_api.t) + [t/027_chatterbox_cleanup.t](../t/027_chatterbox_cleanup.t) |
| Spamcannon | 1 | 1 | ✅ 100% | [t/052_spamcannon_api.t](../t/052_spamcannon_api.t) (bulk messaging) |
| Bouncer | 1 | 1 | ✅ 100% | [t/076_bouncer_api.t](../t/076_bouncer_api.t) (MockRequest) - bulk room management |
| **Voting & Reputation** |
| Vote | 1 | 1 | ✅ 100% | [t/064_vote_api.t](../t/064_vote_api.t) (37 tests, security-focused) |
| Cool | 3 | 3 | ✅ 100% | [t/062_cool_api.t](../t/062_cool_api.t) (MockRequest) |
| Cool Archive | 1 | 1 | ✅ 100% | [t/077_cool_archive_api.t](../t/077_cool_archive_api.t) (MockRequest) - browse, filter, paginate |
| Page of Cool | 2 | 2 | ✅ 100% | [t/083_page_of_cool_api.t](../t/083_page_of_cool_api.t) (14 tests, MockRequest) - coolnodes list, endorsements |
| Reputation | 1 | 1 | ✅ 100% | [t/068_reputation_api.t](../t/068_reputation_api.t) (MockRequest) - vote analysis with permission checks |
| Levels | 1 | 1 | ✅ 100% | [t/067_levels_api.t](../t/067_levels_api.t) (MockRequest) - level ranges, user level indicator |
| **Polls** |
| Poll | 2 | 2 | ✅ 100% | [t/034_poll_api.t](../t/034_poll_api.t) (62 tests) |
| Poll Creator | 1 | 1 | ✅ 100% | [t/084_poll_creator_api.t](../t/084_poll_creator_api.t) (17 tests, MockRequest) - create with validation |
| Polls | 3 | 3 | ✅ 100% | [t/070_polls_api.t](../t/070_polls_api.t) (65 tests, MockRequest) - list, set_current, delete with admin checks |
| **User Preferences & Settings** |
| Preferences | 4 | 4 | ✅ 100% | [t/029_preferences_api.t](../t/029_preferences_api.t) (50 tests) OR [t/057_preferences_api.t](../t/057_preferences_api.t) (32 tests, MockRequest) **DUPLICATE** |
| Developer Vars | 1 | 1 | ✅ 100% | [t/024_developervars_api.t](../t/024_developervars_api.t) (23 tests) OR [t/058_developervars_api.t](../t/058_developervars_api.t) (11 tests, MockRequest) **DUPLICATE** |
| Nodelets | 2 | 2 | ✅ 100% | [t/082_nodelets_api.t](../t/082_nodelets_api.t) (19 tests, MockRequest) - get/update nodelet order |
| **Discovery & Search** |
| New Writeups | 1 | 1 | ✅ 100% | [t/030_newwriteups_api.t](../t/030_newwriteups_api.t) (33 tests) |
| Between the Cracks | 1 | 1 | ✅ 100% | [t/075_betweenthecracks_api.t](../t/075_betweenthecracks_api.t) (MockRequest) - neglected writeups search |
| Trajectory | 1 | 1 | ✅ 100% | [t/085_trajectory_api.t](../t/085_trajectory_api.t) (12 tests, MockRequest) - site statistics by month |
| **Admin & Moderation** |
| Admin | 4 | 4 | ✅ 100% | [t/051_admin_api.t](../t/051_admin_api.t) (admin node editing) |
| System Utilities | 1 | 1 | ✅ 100% | [t/060_systemutilities_api.t](../t/060_systemutilities_api.t) (11 tests, MockRequest) |
| Superbless | 5 | 0 | ❌ 0% | None - **LOW PRIORITY** (admin grants) |
| Suspension | 3 | 3 | ✅ 100% | [t/071_suspension_api.t](../t/071_suspension_api.t) (50 tests, MockRequest) - get/suspend/unsuspend with permission checks |
| Easter Eggs | 1 | 1 | ✅ 100% | [t/079_easter_eggs_api.t](../t/079_easter_eggs_api.t) (MockRequest) - admin bestow feature |
| Teddy Bear | 1 | 0 | ❌ 0% | None - **LOW PRIORITY** (fun feature) |
| List Nodes | 1 | 1 | ✅ 100% | [t/078_list_nodes_api.t](../t/078_list_nodes_api.t) (MockRequest) - node listing by type |
| **Other** |
| Gift Shop | 10 | 10 | ✅ 100% | [t/049_giftshop_api.t](../t/049_giftshop_api.t) (20 tests, MockRequest) - stars, votes, chings, eggs, tokens, topic |
| Wheel | 1 | 1 | ✅ 100% | [t/045_wheel_api.t](../t/045_wheel_api.t) |
| Tests | 1 | 1 | ✅ 100% | [t/003_api_versions.t](../t/003_api_versions.t) (8 tests - version testing) |
| Catchall | 0 | 0 | ⚠️ N/A | Empty placeholder module |
| Writeuptypes | 1 | 0 | ❌ 0% | None - **LOW PRIORITY** (writeup type info) |

**Overall API Test Coverage: 91%** (48 of 53 modules have tests)

**Key Metrics:**
- Total API Modules: 53
- Fully Tested: 45 modules (85%)
- Partially Tested: 3 modules (6%)
- No Tests: 5 modules (10%)
- Test Files: 47 files
- Total Test Assertions: 2,878
- Modern MockRequest Tests: 26 files

### APIs Without Tests (5 remaining)

| API | Priority | Notes |
|-----|----------|-------|
| superbless | LOW | Admin blessing grants - rarely used |
| teddybear | LOW | Teddy bear fun feature |
| users | LOW | User listing (partial in user_api) |
| nodes | LOW | General node ops (partial coverage) |
| writeuptypes | LOW | Writeup type enumeration |

**Test Infrastructure:**
- [t/001_api_routing.t](../t/001_api_routing.t) - General API routing (2 tests)
- [t/025_api_content_encoding.t](../t/025_api_content_encoding.t) - Content-Encoding headers (24 tests)
- [t/lib/MockUser.pm](../t/lib/MockUser.pm) - Shared mock user class
- [t/lib/MockRequest.pm](../t/lib/MockRequest.pm) - Shared mock request class (supports query_params, VARS, param())

### Recent Test Additions (December 2025)

| Test File | API | Tests | Description |
|-----------|-----|-------|-------------|
| t/067_levels_api.t | levels | ~20 | Level ranges, user level indicator, max limits |
| t/068_reputation_api.t | reputation | ~25 | Vote analysis with author/voter/admin permissions |
| t/069_user_search_api.t | user_search | ~15 | Username search, pagination, visibility rules |
| t/070_polls_api.t | polls | 65 | Poll listing, status filter, set_current, delete |
| t/071_suspension_api.t | suspension | 50 | User suspension with admin permission checks |
| t/072_e2node_api.t | e2node | 101 | Firmlinks, repair, orderlock, title, lock, reorder, softlinks |
| t/073_weblog_api.t | weblog | ~20 | Weblog entry removal with permission checks |
| t/074_autosave_api.t | autosave | 45 | Draft autosave CRUD with history |
| t/075_betweenthecracks_api.t | betweenthecracks | ~15 | Neglected writeup discovery |
| t/076_bouncer_api.t | bouncer | ~15 | Bulk chat room management |
| t/077_cool_archive_api.t | cool_archive | ~20 | Cool history browsing |
| t/078_list_nodes_api.t | list_nodes | ~15 | Node type listing |
| t/079_easter_eggs_api.t | easter_eggs | ~12 | Admin easter egg bestowing |
| t/080_userinteractions_api.t | userinteractions | 24 | Unified user blocking (hide_writeups, block_messages) |
| t/081_node_parameter_api.t | node_parameter | 21 | Node parameter CRUD with admin checks |
| t/082_nodelets_api.t | nodelets | 19 | Nodelet order get/update |
| t/083_page_of_cool_api.t | page_of_cool | 14 | Cool nodes list, editor endorsements |
| t/084_poll_creator_api.t | poll_creator | 17 | Poll creation with validation |
| t/085_trajectory_api.t | trajectory | 12 | Site trajectory statistics |

**Notes:**
- Duplicate test files exist for developervars (t/024 vs t/058) and preferences (t/029 vs t/057) - the newer MockRequest versions are preferred
- All remaining untested APIs are low priority (admin/fun features)

---

**Modernization Status**: ✅ All 52 modules use modern `routes()` method - No legacy `command_post` patterns remain!

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

### POST /api/user/edit

Updates a user's profile information. Requires authentication. Users can only edit their own profile unless they are an admin.

**Request Body (JSON):**

```json
{
  "node_id": 123456,
  "realname": "John Doe",
  "email": "john@example.com",
  "passwd": "newpassword",
  "user_doctext": "<p>My bio text</p>",
  "mission": "To node everything",
  "specialties": "Writing, coding",
  "employment": "Everything2 Inc",
  "motto": "Node all the things!",
  "remove_image": true,
  "bookmark_remove": [111, 222, 333],
  "bookmark_order": [444, 555, 666]
}
```

**Parameters:**

* **node_id** (required) - The node_id of the user to edit
* **realname** - User's real name
* **email** - User's email address
* **passwd** - New password (leave blank to keep current)
* **user_doctext** - Bio/homenode HTML text
* **mission** - Mission drive within everything
* **specialties** - User's specialties
* **employment** - School/company
* **motto** - User's motto
* **remove_image** - Set to true to remove the user's profile image
* **bookmark_remove** - Array of node_ids of bookmarks to remove
* **bookmark_order** - Array of node_ids in desired display order (reorders bookmarks)

**Response (200 OK):**

```json
{
  "success": true,
  "changes": ["realname", "email", "doctext", "bookmarks_reordered:5"]
}
```

**Error Response (200 OK with success=false):**

```json
{
  "success": false,
  "error": "You can only edit your own profile"
}
```

### GET /api/user/sanctity

Admin-only endpoint to get a user's sanctity value.

**Query Parameters:**

* **username** (required) - The username to look up

**Response (200 OK):**

```json
{
  "success": true,
  "username": "johndoe",
  "sanctity": 5
}
```

### GET /api/user/available/:username

Checks if a username is available for registration.

**Response (200 OK):**

```json
{
  "available": true,
  "username": "newuser"
}
```

or

```json
{
  "available": false,
  "username": "existinguser"
}
```

## Usergroups

**Test Coverage: ✅ 90%** (9/10 endpoints tested)

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

### /api/usergroups/:id/action/leave

**POST only**

Allows a logged-in user to leave a usergroup they are a member of. Unlike `removeuser`, this endpoint does not require admin permissions - any member can remove themselves from a group.

**Request:** No body required (empty POST)

**Response on success (200):**
```json
{
  "success": true,
  "message": "You have left [usergroup name]"
}
```

**Error responses:**
* **400 Bad Request** - User is not a member of this group
  ```json
  { "success": false, "error": "You are not a member of this group" }
  ```
* **403 Forbidden** - User is not logged in (guest)
  ```json
  { "success": false, "error": "Must be logged in to leave a group" }
  ```
* **404 Not Found** - Invalid usergroup ID
  ```json
  { "success": false, "error": "Usergroup not found" }
  ```

**Tests:** [t/004_usergroups.t](../t/004_usergroups.t) (Tests 5-8: leave success, not a member, guest forbidden, invalid group)

### /api/usergroups/:id/action/reorder

**POST only** - Requires admin, editor, or owner permission

Reorders members within a usergroup. This is useful for changing the leader (first member) or organizing members in a specific order.

**Request:** Array of node IDs in the desired order
```json
[123, 456, 789]
```

**Response on success (200):**
```json
{
  "success": true,
  "group": [/* enhanced member data with flags, is_owner, is_current */]
}
```

**Error responses:**
* **200 with error** - Node ID not in group
  ```json
  { "success": false, "error": "Node 999 is not in this group" }
  ```
* **403 Forbidden** - User doesn't have permission to manage this group

**Tests:** [t/004_usergroups.t](../t/004_usergroups.t) (Tests 9-11)

### /api/usergroups/:id/action/search

**GET only** - Requires admin, editor, or owner permission

Searches for users and usergroups that can be added to the group. Returns up to 20 results, excluding users already in the group.

**Query Parameters:**
* **q** - Search query (minimum 2 characters)

**Response on success (200):**
```json
{
  "success": true,
  "results": [
    { "node_id": 123, "title": "username", "type": "user" },
    { "node_id": 456, "title": "groupname", "type": "usergroup" }
  ]
}
```

**Tests:** [t/004_usergroups.t](../t/004_usergroups.t) (Tests 12-13)

### /api/usergroups/:id/action/description

**POST only** - Requires admin, editor, or owner permission

Updates the usergroup's description (doctext).

**Request:**
```json
{ "doctext": "New description content" }
```

**Response on success (200):**
```json
{
  "success": true,
  "doctext": "New description content"
}
```

**Error responses:**
* **200 with error** - Missing doctext parameter
  ```json
  { "success": false, "error": "Missing doctext parameter" }
  ```
* **403 Forbidden** - User doesn't have permission

**Tests:** [t/004_usergroups.t](../t/004_usergroups.t) (Tests 15-21)

### /api/usergroups/:id/action/transfer_ownership

**POST only** - Requires owner or admin permission

Transfers ownership of a usergroup to another member. The new owner must already be a member of the group.

**Request:**
```json
{ "new_owner_id": 12345 }
```

**Response on success (200):**
```json
{
  "success": true,
  "message": "Ownership transferred to username",
  "group": [/* enhanced member data */]
}
```

**Error responses:**
* **200 with error** - New owner is not a member
  ```json
  { "success": false, "error": "New owner must be a member of the group" }
  ```
* **200 with error** - Missing new_owner_id
  ```json
  { "success": false, "error": "Missing new_owner_id parameter" }
  ```
* **403 Forbidden** - Only owner can transfer (unless admin)
  ```json
  { "success": false, "error": "Only the owner can transfer ownership" }
  ```

**Tests:** [t/004_usergroups.t](../t/004_usergroups.t) (Tests 22-29)

### /api/usergroups/:id/action/weblogify

**POST only** - Requires admin permission

Sets the weblog display name for a usergroup, enabling the "post to usergroup" feature. When a usergroup is weblogified, members can post content to the group's weblog from the AdminModal. The display name appears as the button label (e.g., "Edevify" for E2 Development).

This also updates each member's `can_weblog` setting to include this group.

**Request:**
```json
{ "ify_display": "Edevify" }
```

**Response on success (200):**
```json
{
  "success": true,
  "message": "Weblog display set to 'Edevify' for E2 Development",
  "ify_display": "Edevify"
}
```

**Error responses:**
* **200 with error** - Missing ify_display parameter
  ```json
  { "success": false, "error": "Missing ify_display parameter" }
  ```
* **403 Forbidden** - Only admins can modify weblog settings
  ```json
  { "success": false, "error": "Only admins can modify weblog settings" }
  ```
* **404 Not Found** - Usergroup not found
  ```json
  { "success": false, "error": "Usergroup not found" }
  ```

**Tests:** [t/004_usergroups.t](../t/004_usergroups.t) (Tests 30-35)

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

**Test Coverage: ❌ 0%** (0/7 endpoints tested)

Current version: *1 (beta)*

Manages user drafts for the E2 Editor Beta. Drafts are nodes of type "draft" that allow users to compose and revise content before publishing. Supports CRUD operations, pagination, and publication status management.

All draft methods require logged-in users and return 401 Unauthorized for Guest User.

### GET /api/drafts

Returns a paginated list of the current user's drafts, ordered by most recently modified first.

**Query Parameters:**
* **limit** - Number of drafts to return (optional, default: 20, max: 100)
* **offset** - Number of drafts to skip for pagination (optional, default: 0)

**Returns:**

200 OK with JSON object containing:

```json
{
  "success": 1,
  "drafts": [
    {
      "node_id": 2213271,
      "title": "Test draft to create",
      "createtime": "2025-12-01 06:46:52",
      "publication_status": 2035425,
      "status_title": "private"
    }
  ],
  "pagination": {
    "limit": 20,
    "offset": 0,
    "total": 12,
    "has_more": false
  }
}
```

**Response Keys:**
* **success** - Boolean (1/0) indicating operation succeeded
* **drafts** - Array of draft summary objects
* **pagination** - Pagination metadata object:
  * **limit** - Number of items requested
  * **offset** - Starting position in results
  * **total** - Total number of drafts user has
  * **has_more** - Boolean indicating if more drafts are available

**Draft Object Keys:**
* **node_id** - Draft's unique identifier
* **title** - Draft title
* **createtime** - When the draft was created (MySQL datetime format)
* **publication_status** - Node ID of the publication status
* **status_title** - Human-readable status (private, shared, findable, review)

**Example Request:**

```bash
curl https://everything2.com/api/drafts?limit=20&offset=0 \
  -H "Cookie: userpass=..."
```

**Implementation Notes:**

- Drafts are ordered by `createtime DESC` (newest first)
- Limit is clamped between 1 and 100
- Offset must be non-negative
- Total count query runs separately for accurate pagination metadata

### GET /api/drafts/:id

Retrieves the full content and metadata for a specific draft.

**URL Parameters:**
* **id** - The node_id of the draft (required)

**Returns:**

200 OK with JSON object containing:

```json
{
  "success": 1,
  "draft": {
    "node_id": 2213271,
    "title": "Test draft to create",
    "doctext": "<p>Draft content here</p>",
    "status": "private",
    "createtime": "2025-12-01 06:46:52"
  }
}
```

**Response Keys:**
* **success** - Boolean (1/0) indicating operation succeeded
* **draft** - Draft object with:
  * **node_id** - Draft's unique identifier
  * **title** - Draft title
  * **doctext** - Full HTML content of the draft
  * **status** - Human-readable publication status
  * **createtime** - Creation timestamp

**Error Responses:**

* **400 Bad Request** - Invalid draft ID
* **403 Forbidden** - User doesn't own the draft and is not an editor
* **404 Not Found** - Draft doesn't exist

**Example Request:**

```bash
curl https://everything2.com/api/drafts/2213271 \
  -H "Cookie: userpass=..."
```

### POST /api/drafts

Creates a new draft with the specified title and optional initial content.

**Request Body (JSON):**
* **title** - Draft title (required, will be cleaned via `cleanNodeName()`)
* **doctext** - Initial draft content (optional, defaults to empty string)

**Returns:**

200 OK with JSON object containing:

```json
{
  "success": 1,
  "draft": {
    "node_id": 2213272,
    "title": "My New Draft",
    "status": "private"
  }
}
```

**Response Keys:**
* **success** - Boolean (1/0) indicating operation succeeded
* **draft** - Newly created draft object with node_id, title, and status

**Validation:**
* Title is cleaned via `cleanNodeName()` - defaults to "untitled draft" if empty
* Duplicate titles are handled by appending " (N)" where N increments
* All new drafts default to "private" publication status
* Draft type and default status are looked up from the database (not hardcoded)

**Error Responses:**

* **400 Bad Request** - Invalid JSON in request body
* **401 Unauthorized** - User is not logged in
* **500 Internal Server Error** - Failed to create draft node

**Example Request:**

```bash
curl -X POST https://everything2.com/api/drafts \
  -H "Content-Type: application/json" \
  -H "Cookie: userpass=..." \
  -d '{"title": "My Draft", "doctext": "<p>Initial content</p>"}'
```

**Implementation Notes:**

- Uses `insertNode()` to create the draft node with proper type and ownership
- Document content is stored in the `document` table (joined on `document_id`)
- Publication status is stored in the `draft` table
- Title uniqueness check prevents conflicts for the same user

### PUT /api/drafts/:id

Updates an existing draft's content, title, or publication status.

**URL Parameters:**
* **id** - The node_id of the draft to update (required)

**Request Body (JSON):**

At least one of the following fields must be provided:
* **title** - New title (optional, will be cleaned and checked for uniqueness)
* **doctext** - New content (optional, current version is stashed before update)
* **status** - New publication status (optional, must be a valid publication_status node name)

**Returns:**

200 OK with JSON object containing:

```json
{
  "success": 1,
  "updated": {
    "title": "Updated Title",
    "doctext": 1,
    "status": "findable"
  },
  "draft_id": 2213271,
  "doctext": "<p>The current content...</p>"
}
```

**Response Keys:**
* **success** - Boolean (1/0) indicating operation succeeded
* **updated** - Object showing which fields were updated
* **draft_id** - The ID of the updated draft
* **doctext** - The current doctext content from the database (source of truth for keeping client state in sync)

**Version History:**

When updating `doctext`, the current content is automatically saved to version history before being overwritten:
- Saved to the `autosave` table with `save_type = 'manual'`
- Only saved if current content differs from new content
- Old versions are automatically pruned (keeps last 20)

**Status Change Notifications:**

When changing status to "review", a node note is automatically created:
- Note text: "author requested review"
- `noter_user` set to 0 (system note)
- Timestamp set to NOW()

**Error Responses:**

* **400 Bad Request** - Invalid draft ID or JSON
* **403 Forbidden** - User doesn't own the draft
* **404 Not Found** - Draft doesn't exist

**Example Request:**

```bash
curl -X PUT https://everything2.com/api/drafts/2213271 \
  -H "Content-Type: application/json" \
  -H "Cookie: userpass=..." \
  -d '{"title": "Updated Title", "status": "findable"}'
```

**Implementation Notes:**

- Title updates check for duplicates and auto-append " (N)" if needed
- Content updates trigger version history stashing
- Status changes validate against known publication_status nodes
- Multiple fields can be updated in a single request
- Updates use direct SQL (not `updateNode()`) for performance

### DELETE /api/drafts/:id

Permanently deletes a draft. This action cannot be undone.

**URL Parameters:**
* **id** - The node_id of the draft to delete (required)

**Returns:**

200 OK with JSON object containing:

```json
{
  "success": 1,
  "message": "Draft deleted successfully",
  "draft_id": 2213271
}
```

**Response Keys:**
* **success** - Boolean (1/0) indicating operation succeeded
* **message** - Human-readable confirmation message
* **draft_id** - The ID of the deleted draft

**Error Responses:**

* **400 Bad Request** - Invalid or missing draft ID
* **401 Unauthorized** - User is not logged in
* **403 Forbidden** - User doesn't own the draft (non-editors cannot delete others' drafts)
* **404 Not Found** - Draft doesn't exist

**Example Request:**

```bash
curl -X DELETE https://everything2.com/api/drafts/2213271 \
  -H "Cookie: userpass=..."
```

**Implementation Notes:**

- Editors can delete any user's drafts
- Regular users can only delete their own drafts
- Deletion removes the node and all associated data (document content, version history)
- Uses `nukeNode()` for complete removal

### GET /api/drafts/search

Searches the current user's drafts by title and content.

**Query Parameters:**
* **q** - Search query string (required, minimum 2 characters)
* **limit** - Maximum number of results to return (optional, default: 20, max: 50)

**Returns:**

200 OK with JSON object containing:

```json
{
  "success": 1,
  "drafts": [
    {
      "node_id": 2213271,
      "title": "My Draft About Cats",
      "createtime": "2025-12-01 06:46:52",
      "status": "private",
      "doctext": "<p>Content mentioning cats...</p>"
    }
  ],
  "query": "cats"
}
```

**Response Keys:**
* **success** - Boolean (1/0) indicating operation succeeded
* **drafts** - Array of matching draft objects (may be empty)
* **query** - The search query that was executed
* **message** - Only present when query is too short

**Draft Object Keys:**
* **node_id** - Draft's unique identifier
* **title** - Draft title
* **createtime** - When the draft was created (MySQL datetime format)
* **status** - Human-readable publication status
* **doctext** - Full HTML content of the draft

**Error Responses:**

* **401 Unauthorized** - User is not logged in

**Query Too Short Response:**

When the query is less than 2 characters:

```json
{
  "success": 1,
  "drafts": [],
  "message": "Search query too short (minimum 2 characters)"
}
```

**Example Requests:**

```bash
# Search for drafts containing "poetry"
curl "https://everything2.com/api/drafts/search?q=poetry" \
  -H "Cookie: userpass=..."

# Search with custom limit
curl "https://everything2.com/api/drafts/search?q=cats&limit=10" \
  -H "Cookie: userpass=..."
```

**Implementation Notes:**

- Searches both title and doctext fields using SQL LIKE
- Case-insensitive matching
- Special characters (%, _, \) are escaped to prevent SQL injection
- Results ordered by createtime descending (newest first)
- Returns full doctext content for each match (client can truncate for display)
- Uses the existing `authortype` composite index for efficient filtering by user

## Autosave

**Test Coverage: ❌ 0%** (0/4 endpoints tested)

Current version: *1 (beta)*

Handles automatic and manual saving of editor content with version history. The autosave system stores previous versions in the `autosave` table, keeping the last 20 versions per user+node combination. Used by the E2 Editor Beta for both autosave functionality and version history.

All autosave methods require logged-in users with edit permissions on the node.

### POST /api/autosave

Saves content for a node, automatically stashing the previous version to history.

**Request Body (JSON):**
* **node_id** - The node to save (required, must be positive integer)
* **doctext** - Content to save (required, can be empty string)

**Returns:**

200 OK with JSON object containing:

```json
{
  "success": 1,
  "saved": 1,
  "autosave_id": 123,
  "save_type": "auto"
}
```

**Response Keys:**
* **success** - Boolean (1/0) indicating operation succeeded
* **saved** - Boolean (1/0) indicating whether content was actually saved (0 if no changes detected)
* **autosave_id** - ID of the autosave history entry (only present if previous content was stashed)
* **save_type** - Always "auto" for this endpoint

**Behavior:**

1. **Permission Check**: Verifies user can edit the node (owner, editor, or admin)
2. **Change Detection**: Compares new content with current content in `document` table
3. **No-Op If Unchanged**: Returns `success: 1, saved: 0` if content matches
4. **Stash Previous Version**: If content differs, saves current content to `autosave` table before updating
5. **Update Document**: Writes new content to `document` table
6. **Prune Old Versions**: Keeps only the last 20 autosave entries per user+node

**Error Responses:**

* **400 Bad Request** - Missing or invalid node_id
  ```json
  { "success": 0, "error": "invalid_node_id", "message": "..." }
  ```

* **403 Forbidden** - User doesn't have permission to edit
  ```json
  { "success": 0, "error": "permission_denied", "message": "..." }
  ```

* **404 Not Found** - Node doesn't exist
  ```json
  { "success": 0, "error": "node_not_found", "message": "..." }
  ```

* **500 Internal Server Error** - Database operation failed
  ```json
  { "success": 0, "error": "stash_failed", "message": "..." }
  { "success": 0, "error": "update_failed", "message": "..." }
  ```

**Example Request:**

```bash
curl -X POST https://everything2.com/api/autosave \
  -H "Content-Type: application/json" \
  -H "Cookie: userpass=..." \
  -d '{"node_id": 2213271, "doctext": "<p>Updated content</p>"}'
```

**Implementation Notes:**

- Used by E2 Editor Beta for autosave every 60 seconds
- Prevents unnecessary database writes by detecting unchanged content
- Version history is created BEFORE updating to preserve the previous state
- Autosave pruning runs after every save to maintain 20-version limit
- All autosaves are marked with `save_type = 'auto'` to distinguish from manual saves

### GET /api/autosave/:node_id

Retrieves all autosaved versions for a specific node, including full content.

**URL Parameters:**
* **node_id** - The node ID to get autosaves for (required)

**Returns:**

200 OK with JSON object containing:

```json
{
  "success": 1,
  "node_id": 2213271,
  "autosaves": [
    {
      "autosave_id": 456,
      "doctext": "<p>Version 3 content</p>",
      "createtime": "2025-12-01 14:30:00",
      "save_type": "auto"
    },
    {
      "autosave_id": 455,
      "doctext": "<p>Version 2 content</p>",
      "createtime": "2025-12-01 14:29:00",
      "save_type": "manual"
    }
  ]
}
```

**Response Keys:**
* **success** - Boolean (1/0) indicating operation succeeded
* **node_id** - The requested node ID
* **autosaves** - Array of autosave objects (max 20, most recent first)

**Autosave Object Keys:**
* **autosave_id** - Unique identifier for this version
* **doctext** - Full HTML content of this version
* **createtime** - When this version was saved (MySQL datetime)
* **save_type** - "auto" (autosave) or "manual" (explicit save/restore)

**Example Request:**

```bash
curl https://everything2.com/api/autosave/2213271 \
  -H "Cookie: userpass=..."
```

**Implementation Notes:**

- Only returns autosaves created by the current user for the specified node
- Results are ordered by `createtime DESC` (most recent first)
- Limit is enforced by `max_autosaves_per_node` (default: 20)
- Includes full `doctext` for restoration purposes

### GET /api/autosave/:node_id/history

Retrieves version history metadata without full content (optimized for list views).

**URL Parameters:**
* **node_id** - The node ID to get history for (required)

**Returns:**

200 OK with JSON object containing:

```json
{
  "success": 1,
  "node_id": 2213271,
  "versions": [
    {
      "autosave_id": 456,
      "createtime": "2025-12-01 14:30:00",
      "save_type": "auto",
      "content_length": 1234,
      "preview": "<p>Version 3 content</p>..."
    }
  ]
}
```

**Response Keys:**
* **success** - Boolean (1/0) indicating operation succeeded
* **node_id** - The requested node ID
* **versions** - Array of version metadata objects (max 20, most recent first)

**Version Object Keys:**
* **autosave_id** - Unique identifier for this version
* **createtime** - When this version was saved
* **save_type** - "auto" or "manual"
* **content_length** - Size of the doctext in bytes
* **preview** - First 100 characters of the doctext

**Error Responses:**

* **400 Bad Request** - Invalid node_id
* **403 Forbidden** - User doesn't own the draft
  ```json
  { "success": 0, "error": "permission_denied",
    "message": "You can only view history for your own drafts" }
  ```

**Example Request:**

```bash
curl https://everything2.com/api/autosave/2213271/history \
  -H "Cookie: userpass=..."
```

**Implementation Notes:**

- Optimized for version history UI - doesn't fetch full content
- Uses `LENGTH(doctext)` and `LEFT(doctext, 100)` in SQL for efficiency
- Verifies ownership before returning history
- Used by E2 Editor Beta's "Version History" modal

### POST /api/autosave/:autosave_id/restore

Restores a previous version from history to the main document.

**URL Parameters:**
* **autosave_id** - The autosave entry ID to restore (required)

**Request Body:**

None required - empty POST request.

**Returns:**

200 OK with JSON object containing:

```json
{
  "success": 1,
  "restored_from": 456,
  "node_id": 2213271
}
```

**Response Keys:**
* **success** - Boolean (1/0) indicating operation succeeded
* **restored_from** - The autosave_id that was restored
* **node_id** - The node that was updated

**Behavior:**

1. **Fetch Version**: Retrieves the autosave entry with full content
2. **Verify Ownership**: Ensures user owns the autosave
3. **Stash Current**: Saves current document content to autosave with `save_type = 'manual'` before restoring
4. **Restore Content**: Updates document table with the restored content
5. **Prune History**: Keeps only last 20 versions after stash

**Error Responses:**

* **400 Bad Request** - Invalid autosave_id
* **403 Forbidden** - User doesn't own the version
* **404 Not Found** - Version doesn't exist
* **405 Method Not Allowed** - Used GET/PUT/DELETE instead of POST

**Example Request:**

```bash
curl -X POST https://everything2.com/api/autosave/456/restore \
  -H "Content-Type: application/json" \
  -H "Cookie: userpass=..."
```

**Implementation Notes:**

- Current content is ALWAYS stashed before restoring (unless identical)
- Stashed content is marked `save_type = 'manual'` to indicate explicit user action
- After restore, the document table contains the restored version
- The restored version remains in autosave history
- Version history pruning maintains 20-version limit

### DELETE /api/autosave/:autosave_id

Deletes a specific autosave entry from version history.

**URL Parameters:**
* **autosave_id** - The autosave entry ID to delete (required)

**Returns:**

200 OK with JSON object containing:

```json
{
  "success": 1,
  "deleted": 456
}
```

**Response Keys:**
* **success** - Boolean (1/0) indicating operation succeeded
* **deleted** - The autosave_id that was deleted

**Error Responses:**

* **400 Bad Request** - Invalid autosave_id
* **403 Forbidden** - User doesn't own the autosave (unless admin)
* **404 Not Found** - Autosave entry doesn't exist

**Example Request:**

```bash
curl -X DELETE https://everything2.com/api/autosave/456 \
  -H "Cookie: userpass=..."
```

**Implementation Notes:**

- Only the autosave author can delete their own entries
- Admins can delete any autosave entry
- Deletion is permanent and cannot be undone
- Does not affect the main document content
- Useful for pruning unwanted versions from history

## Documents

## Superdocument

## Messages

**Test Coverage: ✅ 100%** (6/6 endpoints tested - t/032_messages_api.t)

Current version: *1 (beta)*

Retrieves, sends, and sets status on messages. Supports viewing bot inboxes (Cool Man Eddie, Klaproth, etc.) for authorized users and filtering by usergroup.

### /api/messages

Returns the top 15 messages ordered by newest first.

Takes the following optional GET parameters:
* **limit** - Number of messages to return at a time. If left blank defaults to 15. Maximum of 100
* **offset** - Offset of the number of messages to return from DESC sorting
* **for_user** - Node ID of user whose inbox to view. Used for viewing bot inboxes. Requires authorization (user must have access to that bot's inbox via the `bot inboxes` setting - see Bot Inbox Access below)
* **for_usergroup** - Node ID of usergroup to filter by. Only returns messages sent to the specified usergroup. Must be 0 or a valid usergroup ID
* **archived** - Set to 1 to retrieve archived messages instead of active messages (default: 0)
* **box** - Message box type: "inbox" (default) or "outbox" for sent messages

Messages have the following keys:

* **message_id** - The internal message identifier
* **timestamp** - The creation time of the message in ISO format
* **for_user** - The node reference of the receiving user. This is the logged in user, or when viewing a bot inbox, the bot user
* **author_user** - The node reference of the sending user
* **msgtext** - The text of the message
* **for_usergroup** - The node reference of the group the message was sent to. Missing if not a usergroup message

Users who are not logged in should expect to receive 401 Unauthorized

#### Bot Inbox Access

Authorized users can view the inboxes of system bots (Cool Man Eddie, Klaproth, EDB, etc.) using the `for_user` parameter. Authorization is controlled by the `bot inboxes` setting node, which maps bot usernames to required usergroups:

```
Cool Man Eddie → Content Editors
Klaproth → Content Editors
EDB → Content Editors
Content_Salvage → CST_Group
Virgil → e2docs
```

Admins have access to all bot inboxes regardless of usergroup membership.

**Example - View Cool Man Eddie's inbox:**
```bash
curl https://everything2.com/api/messages?for_user=51&limit=25 \
  -H "Cookie: userpass=..."
```

**Error Responses:**
* **403 Forbidden** - User doesn't have access to the requested bot inbox

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

Sends a message. Supports sending messages to users, usergroups, and sending as a bot (for authorized users).

Accepts a JSON POST with the following parameters:
* **for** - The name of the user or usergroup to have the message delivered to
* **for_id** - More precise and preferred version of the user to be sent. Takes precedence over **for** if both are provided
* **message** - The message text to send (max 512 characters)
* **send_as** - (Optional) Node ID of a bot user to send the message as. Requires authorization (user must have access to that bot's inbox via the `bot inboxes` setting). If not provided, message is sent as the current user

**Send-as-Bot Feature:**

Authorized users (editors, admins, etc.) can send messages as system bots using the `send_as` parameter. This is useful for bot operators who need to respond to messages received in bot inboxes.

**Example - Send message as Cool Man Eddie:**
```bash
curl -X POST https://everything2.com/api/messages/create \
  -H "Content-Type: application/json" \
  -H "Cookie: userpass=..." \
  -d '{"for": "someuser", "message": "Hello from CME!", "send_as": 51}'
```

**Message Blocking Responses:**

The API returns different responses based on whether messages are blocked:

* **Complete block** (direct message to blocking user):
  ```json
  {"ignores": 1}
  ```
  Frontend should display error: "{recipient} is ignoring you"

* **Partial block** (usergroup message where some members block you):
  ```json
  {"successes": 2, "errors": ["User is blocking you"], "ignores": 0}
  ```
  Frontend should display warning: "Message sent, but 1 user is blocking you" (or "N users" for multiple)

* **Success** (no blocks):
  ```json
  {"successes": 3}
  ```

The `errors` array contains one entry per blocked member in a usergroup. The message is still delivered to non-blocking members (tracked in `successes`).

**Error Responses:**
* **403 Forbidden** - User doesn't have permission to send as the specified bot

### /api/messages/count

Returns the count of messages in the user's inbox or outbox. Useful for pagination and showing unread counts.

Takes the following optional GET parameters:
* **for_user** - Node ID of user whose inbox to count. Used for viewing bot inbox counts. Requires authorization (see Bot Inbox Access above)
* **for_usergroup** - Node ID of usergroup to filter by. Only counts messages sent to the specified usergroup
* **archived** - Set to 1 to count archived messages instead of active messages (default: 0)
* **box** - Message box type: "inbox" (default) or "outbox" for sent messages

**Returns:**

200 OK with JSON object containing:

```json
{
  "count": 42,
  "box": "inbox",
  "archived": 0
}
```

**Response Keys:**
* **count** - Number of messages matching the criteria
* **box** - The box type counted ("inbox" or "outbox")
* **archived** - Whether archived messages were counted (0 or 1)

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

## Chatroom

**Test Coverage: ✅ 100%** (3/3 endpoints tested - t/035_chatroom_api.t)

Current version: *1 (beta)*

Manages chatroom operations including room changes, visibility (cloak) status, and room creation. All endpoints return full `otherUsersData` structure to enable real-time UI updates without page reloads.

All chatroom methods require logged-in users and return 401 Unauthorized for Guest User.

### POST /api/chatroom/change_room

Changes the current user's chatroom. Users can move between different chat rooms or go "outside" (the main lobby).

**POST Data (JSON):**
* **room_id** - The node_id of the room to enter, or 0 for "outside" (required)

**Returns:**

200 OK with JSON object containing:

```json
{
  "success": 1,
  "message": "Changed to room: The Living Room",
  "room_id": 12345,
  "room_title": "The Living Room",
  "otherUsersData": {
    "userCount": 42,
    "currentRoom": "The Living Room",
    "currentRoomId": 12345,
    "rooms": [...],
    "availableRooms": [...],
    "canCloak": 1,
    "isCloaked": 0,
    "suspension": null,
    "canCreateRoom": 1,
    "createRoomSuspended": 0
  }
}
```

**Response Keys:**
* **success** - Boolean (1/0) indicating operation succeeded
* **message** - Success message with room name
* **room_id** - The room_id the user is now in
* **room_title** - The title of the room, or "outside"
* **otherUsersData** - Complete Other Users nodelet data structure (see below)

**Error Responses:**

* **400 Bad Request** - Missing room_id
  ```json
  { "error": "room_id is required" }
  ```

* **401 Unauthorized** - User is not logged in
  ```json
  { "error": "Guests cannot change rooms" }
  ```

* **403 Forbidden** - User doesn't have permission or is suspended
  ```json
  { "error": "This user cannot change rooms" }
  { "error": "You cannot enter this room" }
  { "error": "You are locked here for 3600 seconds" }
  { "error": "You are locked here indefinitely" }
  ```

* **404 Not Found** - Room doesn't exist
  ```json
  { "error": "Room not found" }
  ```

**Example Request:**

```bash
curl -X POST https://everything2.com/api/chatroom/change_room \
  -H "Content-Type: application/json" \
  -H "Cookie: userpass=..." \
  -d '{"room_id": 12345}'
```

**Implementation Notes:**

- Room ID 0 is a special value meaning "outside" (main lobby)
- Checks `canEnterRoom()` permissions before allowing room change
- Checks for room change suspensions (temporary or indefinite)
- Returns full `otherUsersData` to enable UI refresh without page reload
- Updates user's `in_room` field in database

### POST /api/chatroom/set_cloaked

Toggles the user's visibility status in the chatroom. Cloaked (invisible) users can only be seen by editors, chanops, and users with infravision.

**POST Data (JSON):**
* **cloaked** - Boolean (1/0) for invisible/visible status (required)

**Returns:**

200 OK with JSON object containing:

```json
{
  "success": 1,
  "message": "You are now cloaked",
  "cloaked": 1,
  "otherUsersData": {
    "userCount": 42,
    "currentRoom": "The Living Room",
    "currentRoomId": 12345,
    "rooms": [...],
    "availableRooms": [...],
    "canCloak": 1,
    "isCloaked": 1,
    "suspension": null,
    "canCreateRoom": 1,
    "createRoomSuspended": 0
  }
}
```

**Response Keys:**
* **success** - Boolean (1/0) indicating operation succeeded
* **message** - Success message indicating new status
* **cloaked** - Boolean (1/0) confirming new cloak status
* **otherUsersData** - Complete Other Users nodelet data structure (see below)

**Error Responses:**

* **400 Bad Request** - Missing cloaked parameter
  ```json
  { "error": "cloaked parameter is required" }
  ```

* **401 Unauthorized** - User is not logged in
  ```json
  { "error": "Guests cannot cloak" }
  ```

* **403 Forbidden** - User doesn't have cloak permission
  ```json
  { "error": "You do not have permission to cloak" }
  ```

**Example Request:**

```bash
curl -X POST https://everything2.com/api/chatroom/set_cloaked \
  -H "Content-Type: application/json" \
  -H "Cookie: userpass=..." \
  -d '{"cloaked": 1}'
```

**Implementation Notes:**

- Only users with cloak permission can use this endpoint (checked via `userCanCloak()`)
- Updates the user's `visible` field in the room table
- Returns full `otherUsersData` to enable UI refresh without page reload
- Cloaked users are hidden from normal users but visible to editors/chanops/infravision users

### POST /api/chatroom/create_room

Creates a new chatroom and automatically moves the creating user into it.

**POST Data (JSON):**
* **room_title** - Title for the new room (required, max 80 characters)
* **room_doctext** - Optional description for the room (optional)

**Returns:**

200 OK with JSON object containing:

```json
{
  "success": 1,
  "message": "Room created successfully",
  "room_id": 67890,
  "room_title": "My New Chat Room",
  "otherUsersData": {
    "userCount": 1,
    "currentRoom": "My New Chat Room",
    "currentRoomId": 67890,
    "rooms": [...],
    "availableRooms": [...],
    "canCloak": 1,
    "isCloaked": 0,
    "suspension": null,
    "canCreateRoom": 1,
    "createRoomSuspended": 0
  }
}
```

**Response Keys:**
* **success** - Boolean (1/0) indicating operation succeeded
* **message** - Success message
* **room_id** - The node_id of the newly created room
* **room_title** - The title of the newly created room
* **otherUsersData** - Complete Other Users nodelet data structure with user now in new room

**Validation:**
* `room_title` is required and cannot be empty or whitespace-only
* `room_title` must be 80 characters or less
* `room_title` must be unique (no existing room with same title)
* User must have sufficient level or be admin/chanop
* User must not be suspended from creating rooms

**Error Responses:**

* **400 Bad Request** - Invalid request data
  ```json
  { "error": "Request body is required" }
  { "error": "room_title is required and cannot be empty" }
  { "error": "Room title must be 80 characters or less" }
  ```

* **401 Unauthorized** - User is not logged in
  ```json
  { "error": "Guests cannot create rooms" }
  ```

* **403 Forbidden** - User doesn't have permission or is suspended
  ```json
  { "error": "This user cannot create rooms" }
  { "error": "Too young, my friend. You need level 5 to create rooms." }
  { "error": "You have been suspended from creating new rooms" }
  ```

* **409 Conflict** - Room title already exists
  ```json
  { "error": "A room with this title already exists" }
  ```

* **500 Internal Server Error** - Room creation failed
  ```json
  { "error": "Room nodetype not found" }
  { "error": "Failed to create room" }
  ```

**Example Request:**

```bash
curl -X POST https://everything2.com/api/chatroom/create_room \
  -H "Content-Type: application/json" \
  -H "Cookie: userpass=..." \
  -d '{"room_title": "Poetry Corner", "room_doctext": "A place for poetry lovers"}'
```

**Implementation Notes:**

- Checks user level against `create_room_level` configuration (default 0)
- Admins and chanops can always create rooms regardless of level
- Checks for room creation suspension via `isSuspended($USER, 'room')`
- Creates room node with type "room"
- Sets `roomlocked` to 0 (unlocked) by default
- Automatically moves creating user into the new room via `changeRoom()`
- Returns full `otherUsersData` to enable UI refresh without page reload
- New room is immediately added to available rooms list

### otherUsersData Structure

All chatroom endpoints return the complete `otherUsersData` object to enable real-time UI updates. This structure contains all information needed to render the Other Users nodelet:

```json
{
  "userCount": 42,
  "currentRoom": "The Living Room",
  "currentRoomId": 12345,
  "rooms": [
    {
      "title": "The Living Room",
      "users": [
        {
          "userId": 100,
          "username": "alice",
          "displayName": "alice",
          "isCurrentUser": 0,
          "flags": [
            {"type": "god"},
            {"type": "newuser", "days": 5, "veryNew": 1}
          ],
          "action": {
            "type": "action",
            "verb": "juggling",
            "noun": "a carrot"
          }
        }
      ]
    },
    {
      "title": "Outside",
      "users": [...]
    }
  ],
  "availableRooms": [
    {"room_id": 0, "title": "outside"},
    {"room_id": 12345, "title": "The Living Room"},
    {"room_id": 67890, "title": "Poetry Corner"}
  ],
  "canCloak": 1,
  "isCloaked": 0,
  "suspension": null,
  "canCreateRoom": 1,
  "createRoomSuspended": 0
}
```

**otherUsersData Keys:**
* **userCount** - Total number of users visible to current user
* **currentRoom** - Title of user's current room (empty string if outside)
* **currentRoomId** - node_id of current room (0 if outside)
* **rooms** - Array of room objects with user lists
* **availableRooms** - Array of rooms user can enter
* **canCloak** - Boolean (1/0) whether user can toggle invisibility
* **isCloaked** - Boolean (1/0) current cloak status
* **suspension** - Object with suspension details or null
  * **type** - "temporary" or "indefinite"
  * **seconds_remaining** - Seconds until suspension ends (temporary only)
* **canCreateRoom** - Boolean (1/0) whether user can create rooms
* **createRoomSuspended** - Boolean (1/0) whether user is suspended from creating rooms

**User Object Keys:**
* **userId** - User's node_id
* **username** - User's account name
* **displayName** - Display name (may differ for Halloween costumes)
* **isCurrentUser** - Boolean (1/0) if this is the current user
* **flags** - Array of flag objects:
  * **type** - "newuser", "god", "editor", "chanop", "borged", "invisible", "room"
  * Additional fields vary by flag type (e.g., "days" for newuser, "roomId" for room)
* **action** - Optional user action object:
  * **type** - "action" or "recent"
  * For "action": **verb** and **noun** fields
  * For "recent": **nodeId**, **nodeTitle**, **parentTitle** fields

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

## Polls

**Test Coverage: ✅ 100%** (2/2 endpoints tested - t/034_poll_api.t)

Current version: *1 (beta)*

Enables interactive poll voting functionality. Users can vote on active polls and administrators can manage poll votes for testing and maintenance purposes.

### POST /api/poll/vote

Submits a vote on an active poll. Users can only vote once per poll unless the poll allows multiple votes.

**POST Data (JSON):**
* **poll_id** - The node_id of the poll (required)
* **choice** - The zero-based index of the selected option (required, must be a valid integer within the poll's option range)

**Returns:**

200 OK with JSON object containing:

```json
{
  "success": true,
  "message": "Vote recorded successfully",
  "poll": {
    "node_id": 2205828,
    "title": "What is your favorite programming language?",
    "poll_author": 113,
    "author_name": "root",
    "question": "What is your favorite programming language?",
    "options": ["Perl", "JavaScript", "Python", "Ruby", "Go", "Rust"],
    "poll_status": "current",
    "e2poll_results": [5, 4, 6, 1, 2, 2],
    "totalvotes": 21,
    "userVote": 0
  }
}
```

**Response Keys:**
* **success** - Boolean indicating vote was recorded
* **message** - Success message
* **poll** - Updated poll object with:
  * **node_id** - Poll node ID
  * **title** - Poll title
  * **poll_author** - Author's node_id
  * **author_name** - Author's username
  * **question** - Poll question text
  * **options** - Array of poll option strings
  * **poll_status** - Poll status (current, open, closed, new)
  * **e2poll_results** - Array of vote counts for each option
  * **totalvotes** - Total number of votes cast
  * **userVote** - The user's vote (0-based index)

**Error Responses:**

* **400 Bad Request** - Missing required fields, invalid choice, poll not open for voting, or user has already voted
  ```json
  {
    "error": "You have already voted on this poll",
    "previous_vote": 0
  }
  ```
* **403 Forbidden** - User is not logged in
* **404 Not Found** - Poll doesn't exist

**Example Request:**

```bash
curl -X POST https://everything2.com/api/poll/vote \
  -H "Content-Type: application/json" \
  -H "Cookie: userpass=..." \
  -d '{"poll_id": 2205828, "choice": 0}'
```

**Implementation Notes:**

- Validates user is logged in before accepting votes
- Checks poll status (must be "current" or "open")
- Validates choice is within valid range (0 to number of options - 1)
- Prevents duplicate voting unless poll has `multiple` flag set
- Uses `updateNode()` to properly invalidate cache after updating vote counts
- Returns updated poll data so UI can refresh without additional request
- Vote existence check uses `COUNT(*)` to avoid false positives from `sqlSelect` returning `0`

### POST /api/poll/delete_vote

**Admin-only endpoint** for deleting poll votes. Useful for testing, maintenance, and correcting vote data.

**Authorization Required:** God-level permissions (admin access)

**POST Data (JSON):**
* **poll_id** - The node_id of the poll (required)
* **voter_user** - The node_id of the user whose vote to delete (optional - if omitted, deletes ALL votes for the poll)

**Returns:**

200 OK with JSON object containing:

```json
{
  "success": true,
  "message": "Deleted 1 vote(s)",
  "deleted_count": 1,
  "poll_id": 2205828,
  "new_total": 20
}
```

**Response Keys:**
* **success** - Boolean indicating operation succeeded
* **message** - Description of deletion
* **deleted_count** - Number of votes deleted
* **poll_id** - Poll node ID
* **new_total** - Updated total vote count after deletion

**Error Responses:**

* **400 Bad Request** - Missing required `poll_id` field
* **403 Forbidden** - User does not have admin permissions
* **404 Not Found** - Poll doesn't exist

**Example Request:**

```bash
# Delete specific user's vote
curl -X POST https://everything2.com/api/poll/delete_vote \
  -H "Content-Type: application/json" \
  -H "Cookie: userpass=..." \
  -d '{"poll_id": 2205828, "voter_user": 2205741}'

# Delete all votes for a poll
curl -X POST https://everything2.com/api/poll/delete_vote \
  -H "Content-Type: application/json" \
  -H "Cookie: userpass=..." \
  -d '{"poll_id": 2205828}'
```

**Implementation Notes:**

- Requires admin permissions via `isAdmin()` check
- Automatically recalculates vote counts after deletion
- Uses `updateNode()` to properly invalidate cache
- Can delete a single user's vote or all votes for a poll
- Commonly used in test suites to ensure idempotent test runs
- Useful for correcting accidental votes or cleaning up test data

## Wheel of Surprise

**Test Coverage: ✅ 100%** (1/1 endpoints tested - t/047_wheel_api.t)

Current version: *1 (beta)*

The Wheel of Surprise API enables users to spin a virtual wheel and receive random prizes. Users spend 5 GP per spin (free on Halloween) and can win GP, easter eggs, tokens, C!s, or nothing. All endpoints return updated user stats to enable real-time UI updates without page reloads.

All wheel methods require logged-in users and return 403 Forbidden for Guest User.

### POST /api/wheel/spin

Spins the Wheel of Surprise and awards a random prize. Deducts spin cost (5 GP, or free on Halloween), increments spin counter, and returns the prize result along with updated user stats.

**POST Data:**

No request body required - this endpoint accepts an empty POST request.

**Returns:**

200 OK with JSON object containing:

```json
{
  "success": 1,
  "message": "100 GP! Sweet!",
  "prizeType": "gp",
  "user": {
    "GP": 145,
    "spinCount": 42
  },
  "vars": {
    "cools": 3,
    "tokens": 7,
    "easter_eggs": 12
  }
}
```

**Response Keys:**
* **success** - Boolean (1/0) indicating operation succeeded
* **message** - Prize result message for display (may contain E2 link syntax like `[node|text]`)
* **prizeType** - Type of prize awarded: "gp", "easter_egg", "token", "cool", "refund", or "nothing"
* **user** - Updated user stats object:
  * **GP** - User's current GP balance after the spin
  * **spinCount** - Total number of times user has spun the wheel
* **vars** - Updated user inventory:
  * **cools** - Number of C!s user currently has
  * **tokens** - Number of tokens user currently has
  * **easter_eggs** - Number of easter eggs user currently has

**Prize Distribution:**

The wheel uses a random number generator (0-9999) to determine prizes:

* **38.0%** - Nothing (values 0-3799)
* **10.0%** - Easter eggs (values 3930-4000, 4000-4950)
* **20.0%** - Refund/small GP gains (values 6750-9000)
* **15.0%** - 10 GP (values 6500-6750)
* **3.5%** - 25 GP (values 5500-6500)
* **2.6%** - Various special prizes (values 3800-3930, 5240-5500)
* **1.0%** - Tokens (values 5200-5240)
* **0.5%** - C!s (values 4950-5000)
* **Rare** - Jackpots (500 GP at value 5000, 158 GP at values 5000-5006, etc.)

**Error Responses:**

* **403 Forbidden** - User is not logged in, has GP opt-out, or has insufficient GP
  ```json
  { "success": 0, "error": "You must be logged in to spin the wheel." }
  { "success": 0, "error": "Your vow of poverty does not allow you to gamble. You need to opt in to the GP System in order to spin the wheel." }
  { "success": 0, "error": "You need at least 5 GP to spin the wheel. Come back when you have GP to burn." }
  ```

**Example Request:**

```bash
curl -X POST https://everything2.com/api/wheel/spin \
  -H "Content-Type: application/json" \
  -H "Cookie: userpass=..."
```

**Implementation Notes:**

- Spin cost is 5 GP normally, 0 GP on Halloween (checked via `isSpecialDate('halloween')`)
- User must have GP opt-out disabled (`GPoptout` VARS setting)
- Prize messages are the same as the legacy delegation/document implementation
- Easter eggs, tokens, and C!s are stored in user VARS (persistent inventory)
- GP changes are saved to the user node immediately via `updateNode()`
- Spin count is tracked in `spin_wheel` VARS
- Achievement system is triggered after successful spin (if available)
- Security logging records each spin to the Wheel of Surprise node
- **Returns updated stats** so UI can refresh without page reload - client should update displayed GP, inventory counts, and spin counter from the response

**Frontend Integration:**

The response includes all data needed for the React component to update the UI:
- Update GP display from `user.GP`
- Update spin counter from `user.spinCount`
- Update inventory displays from `vars.cools`, `vars.tokens`, `vars.easter_eggs`
- Display prize message from `message` (use ParseLinks component for E2 link syntax)
- No page reload needed - all state updates from API response

**Prize Types:**

* **gp** - User won GP (various amounts from 1 to 500)
* **easter_egg** - User won one or more easter eggs
* **token** - User won a token
* **cool** - User won C!s (1 or 5)
* **refund** - User got their GP back (no net change)
* **nothing** - User won nothing (various humorous messages)

## Gift Shop

**Test Coverage: ✅ 100%** (10/10 endpoints tested - t/049_giftshop_api.t)

Current version: *1 (beta)*

The Gift Shop API enables users to purchase and give gifts using GP (Gold Points). Users can give stars, votes, C!s, easter eggs, and buy topic tokens. Different actions have different level requirements and costs.

All gift shop methods require logged-in users and return 403 Forbidden for Guest User.

### GET /api/giftshop/status

Gets the user's current gift shop status including GP, inventory, and level.

**Returns:**

200 OK with JSON object:

```json
{
  "success": 1,
  "gp": 150,
  "level": 7,
  "votesLeft": 10,
  "coolsLeft": 2,
  "tokens": 1,
  "easterEggs": 3,
  "starCost": 45,
  "canBuyChing": true,
  "chingCooldownMinutes": 0,
  "topicSuspended": false,
  "gpOptOut": false
}
```

### POST /api/giftshop/star

Give a star to another user. Costs 25-75 GP based on user level (higher levels pay less).

**Level Requirement:** 1+

**Cost:** `75 - ((level - 1) * 5)` GP, minimum 25 GP

**POST Data:**

```json
{
  "recipient": "username",
  "color": "Gold",
  "reason": "Great writeup about tomatoes!"
}
```

**Returns:**

```json
{
  "success": 1,
  "message": "a Gold Star has been awarded to username.",
  "newGP": 105
}
```

**Notes:**
- Sends Cool Man Eddie message to recipient
- Recipient's star count is incremented
- Security logged

### POST /api/giftshop/buyvotes

Buy additional votes with GP.

**Level Requirement:** 2+

**Cost:** 1 GP per vote

**POST Data:**

```json
{
  "amount": 5
}
```

**Returns:**

```json
{
  "success": 1,
  "message": "You purchased 5 votes.",
  "newGP": 95,
  "votesLeft": 15
}
```

**Notes:**
- Purchased votes expire at midnight like normal votes

### POST /api/giftshop/givevotes

Give votes to another user (up to 25 at a time).

**Level Requirement:** 9+

**Cost:** None (uses your existing votes)

**POST Data:**

```json
{
  "recipient": "username",
  "amount": 5,
  "anonymous": true
}
```

**Returns:**

```json
{
  "success": 1,
  "message": "5 votes given to username.",
  "votesLeft": 5
}
```

**Notes:**
- Recipient's sanctity is incremented
- Sends Cool Man Eddie message (anonymous optional)

### POST /api/giftshop/giveching

Give a C! to another user.

**Level Requirement:** 4+ (giver), 1+ (recipient)

**Cost:** None (uses your existing C!)

**POST Data:**

```json
{
  "recipient": "username",
  "anonymous": true
}
```

**Returns:**

```json
{
  "success": 1,
  "message": "A C! has been given to username.",
  "coolsLeft": 1
}
```

### POST /api/giftshop/buyching

Buy a C! for 100 GP. 24-hour cooldown between purchases.

**Level Requirement:** 12+

**Cost:** 100 GP

**POST Data:**

No request body required.

**Returns:**

```json
{
  "success": 1,
  "message": "You purchased a C!",
  "newGP": 50,
  "coolsLeft": 3
}
```

**Error Response (cooldown active):**

```json
{
  "success": 0,
  "error": "You can only buy one C! every 24 hours. You can buy another in 3 hours, 45 minutes."
}
```

### POST /api/giftshop/buytoken

Buy a topic token for 25 GP.

**Level Requirement:** 6+

**Cost:** 25 GP

**POST Data:**

No request body required.

**Returns:**

```json
{
  "success": 1,
  "message": "You purchased a token.",
  "newGP": 75,
  "tokens": 2
}
```

### POST /api/giftshop/settopic

Set the room topic using a token.

**Level Requirement:** 6+ (or Editor)

**Cost:** 1 token (free for Editors)

**POST Data:**

```json
{
  "topic": "Welcome to Everything2!"
}
```

**Returns:**

```json
{
  "success": 1,
  "message": "The topic has been updated.",
  "tokens": 0,
  "newTopic": "Welcome to Everything2!"
}
```

**Notes:**
- The `newTopic` field contains the sanitized topic that was set
- The frontend dispatches an `e2:roomTopicUpdate` event to immediately update the chatterbox display

**Error Response (suspended):**

```json
{
  "success": 0,
  "error": "Your topic privileges have been suspended."
}
```

### POST /api/giftshop/buyeggs

Buy easter eggs (1-5 at a time).

**Level Requirement:** 7+

**Cost:** 25 GP per egg

**POST Data:**

```json
{
  "amount": 5
}
```

**Returns:**

```json
{
  "success": 1,
  "message": "You purchased 5 easter eggs.",
  "newGP": 75,
  "easterEggs": 8
}
```

### POST /api/giftshop/giveegg

Give an easter egg to another user.

**Level Requirement:** 7+

**Cost:** None (uses your existing eggs)

**POST Data:**

```json
{
  "recipient": "username",
  "anonymous": true
}
```

**Returns:**

```json
{
  "success": 1,
  "message": "An easter egg has been given to username.",
  "easterEggs": 2
}
```

**Notes:**
- Sends Cool Man Eddie message (anonymous optional)

### Gift Shop Level Requirements Summary

| Action | Level | Cost |
|--------|-------|------|
| Give Star | 1+ | 25-75 GP |
| Buy Votes | 2+ | 1 GP/vote |
| Give C! | 4+ | 0 (uses your C!) |
| Buy Token | 6+ | 25 GP |
| Set Topic | 6+ | 1 token (free for editors) |
| Buy Eggs | 7+ | 25 GP/egg |
| Give Eggs | 7+ | 0 (uses your eggs) |
| Give Votes | 9+ | 0 (uses your votes) |
| Sanctify | 11+ | (via Sanctify page) |
| Buy C! | 12+ | 100 GP (24hr cooldown) |

**GPoptout Note:** Users with GP opt-out enabled cannot use GP-spending features but can still give away existing inventory (votes, C!s, eggs).

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

## Personal Links

**Test Coverage: ✅ 100%** (4/4 endpoints tested - t/033_personallinks_api.t, 18 total tests)

Current version: *1 (beta)*

Manages user personal links - a customizable list of node titles displayed in the Personal Links nodelet. Personal links are separate from bookmarks and provide quick navigation to frequently visited pages. Each user can maintain their own ordered list with a maximum of 20 items OR 1000 characters total storage.

All personal links methods return 401 Unauthorized for Guest User.

### Business Logic: Limits and Validation

Personal Links enforces **dual limits** to prevent excessive storage:
- **Item Limit**: Maximum 20 links
- **Character Limit**: Maximum 1000 total characters across all link titles

**Limit Enforcement Strategy:**

The API uses "reduction-while-over-limit" logic to help users who are over limits get back under:

1. **Under Limits** (normal case)
   - Adding new links: ✅ Allowed
   - Updating links: ✅ Allowed
   - Deleting links: ✅ Allowed

2. **Over Limits BUT Reducing Usage**
   - Adding new links: ❌ Rejected (would increase usage)
   - Updating links: ✅ Allowed if new count/chars ≤ current count/chars
   - Deleting links: ✅ Always allowed (reduces usage)

3. **Over Limits AND Increasing Usage**
   - Adding new links: ❌ Rejected
   - Updating links: ❌ Rejected (would make it worse)
   - Deleting links: ✅ Always allowed

**Why This Matters:**

Users who are over the limit (e.g., from before limits were introduced) can still manage their links by:
- Deleting individual links via DELETE endpoint
- Updating the full list via UPDATE endpoint, as long as they reduce the count/characters

**Example Scenario:**
```
Current state: 25 links, 1200 characters (over both limits)

✅ DELETE /api/personallinks/delete/0        → Allowed (reduces to 24 links)
✅ POST /api/personallinks/update             → Allowed if new list has ≤25 items and ≤1200 chars
   {"links": ["link1", ..., "link22"]}         (reduced to 22 links, still over but improving)
❌ POST /api/personallinks/update             → Rejected (trying to increase)
   {"links": ["link1", ..., "link26"]}         (would go from 25 to 26 links)
❌ POST /api/personallinks/add                → Rejected (would increase count)
   {"title": "New Link"}
```

### GET /api/personallinks/get

Retrieves all personal links for the current user.

**Returns:**

200 OK with JSON object containing:

```json
{
  "links": ["Everything", "homenode", "Writeups By Type"],
  "count": 3,
  "total_chars": 42,
  "item_limit": 20,
  "char_limit": 1000,
  "can_add_more": 1
}
```

**Response Keys:**
* **links** - Array of node title strings in display order
* **count** - Number of links in the user's list
* **total_chars** - Total character count across all links
* **item_limit** - Maximum number of items allowed (20)
* **char_limit** - Maximum total character count allowed (1000)
* **can_add_more** - Boolean (1/0) indicating whether the user can add more links (under both limits)

**Error Responses:**

* **401 Unauthorized** - User is not logged in (guest user)

**Example Request:**

```bash
curl https://everything2.com/api/personallinks/get \
  -H "Cookie: userpass=..."
```

**Implementation Notes:**

- Links are stored in the user's `personal_nodelet` VARS as a `<br>` separated string
- Empty and whitespace-only entries are automatically filtered
- Links are node titles, not node IDs, for flexibility
- Enforces dual limits: 20 items OR 1000 total characters (whichever is reached first)

### POST /api/personallinks/update

Replaces all personal links with a new list. This is an atomic operation - the entire list is replaced, not merged.

**Request Body:**

JSON object with:

```json
{
  "links": ["new link 1", "new link 2", "new link 3"]
}
```

**Request Keys:**
* **links** - Array of node title strings (required, must be an array)

**Returns:**

200 OK with the same JSON structure as GET /api/personallinks/get, containing the updated link list.

**Validation:**
* `links` must be an array
* Number of links must not exceed 20 items
* Total character count must not exceed 1000 characters
* Empty strings and whitespace-only strings are automatically filtered out
* Brackets in titles are escaped as HTML entities (`[` → `&#91;`, `]` → `&#93;`)
* Additional sanitization via `htmlScreen()` for security

**Error Responses:**

* **400 Bad Request** - Invalid request data or limit violations
  ```json
  { "error": "Missing links array in request body" }
  { "error": "links must be an array" }
  { "error": "Cannot add more links. You are over the 20 item limit. Please remove items to get back under the limit.",
    "item_limit": 20, "current_count": 25, "new_count": 26 }
  { "error": "Cannot add more characters. You are over the 1000 character limit. Please remove items to get back under the limit.",
    "char_limit": 1000, "current_chars": 1200, "new_chars": 1250 }
  ```

* **401 Unauthorized** - User is not logged in

**Note:** When over limits, the API only rejects updates that would INCREASE usage. Updates that maintain or reduce usage are allowed to help users get back under the limit.

**Example Request:**

```bash
curl -X POST https://everything2.com/api/personallinks/update \
  -H "Cookie: userpass=..." \
  -H "Content-Type: application/json" \
  -d '{"links": ["Everything", "homenode", "Writeups By Type"]}'
```

**Implementation Notes:**

- This completely replaces the existing link list
- To reorder links, send the full list in the new order
- To remove specific links, send the full list without those links
- Bracket escaping prevents link syntax from being interpreted as E2 links
- Updates are stored immediately in the user's VARS
- **Reduction Logic**: If you're over the limit, you can still update as long as the new list has ≤ items and ≤ characters than your current list. This allows users to gradually reduce their usage back under the limit.

### POST /api/personallinks/add

Adds a new link to the end of the user's personal links list. Commonly used to add the current page being viewed.

**Request Body:**

JSON object with:

```json
{
  "title": "Node Title To Add"
}
```

**Request Keys:**
* **title** - The node title to add (required, cannot be empty)

**Returns:**

200 OK with the same JSON structure as GET /api/personallinks/get, containing the updated link list with the new link appended.

**Validation:**
* `title` must be present and non-empty
* User must not be at their link limit (returns error if at limit)
* Brackets in title are escaped as HTML entities
* Additional sanitization via `htmlScreen()` for security

**Error Responses:**

* **400 Bad Request** - Invalid request data or limit reached
  ```json
  { "error": "Missing title in request body" }
  { "error": "Title cannot be empty" }
  { "error": "Cannot add more links. Maximum is 20 items.", "item_limit": 20 }
  { "error": "Cannot add link. Would exceed 1000 character limit.",
    "char_limit": 1000, "current_chars": 950, "new_title_length": 100 }
  ```

* **401 Unauthorized** - User is not logged in

**Example Request:**

```bash
curl -X POST https://everything2.com/api/personallinks/add \
  -H "Cookie: userpass=..." \
  -H "Content-Type: application/json" \
  -d '{"title": "Current Page Title"}'
```

**Implementation Notes:**

- Appends to the end of the existing list
- Does not check for duplicates - users can add the same link multiple times
- Title is the node title as displayed, not a node ID
- Useful for "add current page" functionality in the UI
- **Enforces both limits**: Checks item count (≤20) AND total character count (≤1000) before adding
- If user is already at or over either limit, the add operation is rejected

### DELETE /api/personallinks/delete/:index

Removes a link at the specified index position from the user's personal links list.

**URL Parameters:**
* **index** - The zero-based array index of the link to remove (required, must be numeric and in range)

**Returns:**

200 OK with the same JSON structure as GET /api/personallinks/get, containing the updated link list after deletion.

**Validation:**
* `index` must be numeric (returns 400 if non-numeric)
* `index` must be in range [0, count-1] (returns 400 if out of range)

**Error Responses:**

* **400 Bad Request** - Invalid index
  ```json
  { "error": "Invalid index" }
  { "error": "Index out of range", "count": 5 }
  ```

* **401 Unauthorized** - User is not logged in

**Example Request:**

```bash
curl -X DELETE https://everything2.com/api/personallinks/delete/2 \
  -H "Cookie: userpass=..."
```

**Implementation Notes:**

- Uses zero-based array indexing (first link is index 0)
- Remaining links shift down after deletion
- Updates the user's VARS immediately
- To remove multiple links, call this endpoint multiple times or use `/update` with the desired final list
- **Always allowed**: Delete operations are permitted even when the user is over the limits, since deletion always reduces usage

## Categories

Category APIs allow users to manage categories and their membership. Categories can be:
- **Private**: Owned by a specific user or usergroup
- **Public**: Owned by Guest User (any logged-in user can add to them)

### GET /api/category/list

Returns categories the user can add nodes to, separated into "your categories" (user-owned or usergroup-owned) and "public categories".

**Query Parameters:**
* **node_id** - Optional. If provided, excludes categories that already contain this node

**Returns:**

200 OK with JSON object containing:

```json
{
  "success": 1,
  "your_categories": [
    {
      "node_id": 12345,
      "title": "My Category",
      "author_user": 67890,
      "author_username": "username"
    }
  ],
  "public_categories": [
    {
      "node_id": 23456,
      "title": "Public Category",
      "author_user": 779713,
      "author_username": "Guest User"
    }
  ]
}
```

**Response Keys:**
* **success** - Boolean (1/0) indicating operation succeeded
* **your_categories** - Array of categories owned by the user or their usergroups
* **public_categories** - Array of categories owned by Guest User (public)

**Error Responses:**

* **401 Unauthorized** - User is not logged in
  ```json
  { "success": 0, "error": "Must be logged in" }
  ```

### POST /api/category/add_member

Adds a node to a category. User must have permission to add to the category.

**POST Data (JSON):**
* **category_id** - Node ID of the category (required)
* **node_id** - Node ID of the node to add (required)

**Returns:**

200 OK with JSON object containing:

```json
{
  "success": 1,
  "message": "Node added to category",
  "category_title": "Category Name"
}
```

**Error Responses:**

* **401 Unauthorized** - User is not logged in
* **403 Forbidden** - User cannot add to this category
  ```json
  { "success": 0, "error": "You cannot add to this category" }
  ```
* **409 Conflict** - Node is already in the category
  ```json
  { "success": 0, "error": "Node is already in this category" }
  ```

### POST /api/category/remove_member

Removes a node from a category. Only category owners (or editors) can remove members.

**POST Data (JSON):**
* **node_id** - Node ID of the category (required)
* **member_id** - Node ID of the member to remove (required)

**Returns:**

200 OK with JSON object containing:

```json
{
  "success": 1,
  "message": "Member removed from category"
}
```

**Error Responses:**

* **401 Unauthorized** - User is not logged in
* **403 Forbidden** - User cannot manage this category
  ```json
  { "success": 0, "error": "You cannot manage members of this category" }
  ```

### POST /api/category/reorder_members

Reorders members within a category. Only category owners (or editors) can reorder.

**POST Data (JSON):**
* **node_id** - Node ID of the category (required)
* **member_ids** - Array of member node IDs in desired order (required)

**Returns:**

200 OK with JSON object containing:

```json
{
  "success": 1,
  "message": "Member order updated"
}
```

**Error Responses:**

* **401 Unauthorized** - User is not logged in
* **403 Forbidden** - User cannot manage this category

### POST /api/category/update

Updates a category's description. User must have permission to edit the category.

**POST Data (JSON):**
* **node_id** - Node ID of the category (required)
* **doctext** - New description text (can be empty)

**Returns:**

200 OK with JSON object containing:

```json
{
  "success": 1,
  "message": "Category updated successfully"
}
```

**Error Responses:**

* **401 Unauthorized** - User is not logged in
* **403 Forbidden** - User cannot edit this category

### POST /api/category/update_meta

Updates a category's title and/or owner. **Editors only.**

**POST Data (JSON):**
* **node_id** - Node ID of the category (required)
* **title** - New title (optional)
* **author_user** - New owner's node ID (optional)

**Returns:**

200 OK with JSON object containing:

```json
{
  "success": 1,
  "message": "Category settings updated"
}
```

**Error Responses:**

* **401 Unauthorized** - User is not logged in
* **403 Forbidden** - Only editors can change category settings
* **409 Conflict** - A category with that title already exists

### GET /api/category/lookup_owner

Looks up a user or usergroup by name for the owner field. **Editors only.**

**Query Parameters:**
* **name** - Username or usergroup name to look up (required)

**Returns:**

200 OK with JSON object containing:

```json
{
  "success": 1,
  "found": 1,
  "node_id": 12345,
  "title": "username",
  "type": "user"
}
```

Or if not found:

```json
{
  "success": 1,
  "found": 0
}
```

**Error Responses:**

* **401 Unauthorized** - User is not logged in
* **403 Forbidden** - Only editors can lookup owners

## Searches

## Tests

### /api/tests (version 2)
returns ````{"v": 2}````

### /api/tests (version 3)
returns ````{"version": 3}````
Test-only API which is to validate version-acceptance

