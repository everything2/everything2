# Everything2 API Specification v2.0

Everything2 needs to evolve to keep up with the times. We've lived with the early 2000s era limitations of the Everything Engine as put together by the Everything Development Company, and a small army of volunteer coders has kept it moving and alive for some time. In order to move to the next level of usability and to embrace the mobile revolution that is now approximately half of our traffic, we need to move to a modern achitecture.

As a part of the future API-driven nature of the site, we need to start abstracting features away into APIs that a richer front-end can drive. I've all but settled on [React.js](http://reactjs.com/), Facebook's front-end framework for fast and responsive UIs. While a UI rewrite is not needed as a part of the API-ification, it is an easy way to start exercising the consumption part of the API and get feedback. It will also as a consequence, start to make the site more responsive as the features come in.

This API is version 2, as the old xmltrue nodetype is considered version 1.0.

## API religion

* All E2 APIs will be available at https://everything2.com/api/$api. 
* APIs are versioned. To request a specific version of the API, send the accept header: ````Accept: application/vnd.e2.v$version+json````. Versions are all non-decimal numeric numbers.
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

## Node requests

The node requests form is good for looking up particular node_ids, but does not have actions on it.

### /api/nodes

Always returns UNIMPLEMENTED

### /api/nodes/:id

Returns the readable form of a node. Always the following items:

* **node_id** The unique identifier of the object
* **author** A node reference of the creator of the object
* **type** Human readable version of the type. Pluralize to find the right API
* **title** The title of the node

Different types contain additional information.

## Users

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

## Usergroups

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

## Writeups

### /api/writeups

Always returns UNIMPLEMENTED

### /api/writeups/:id

Returns all of the items in /api/nodes/:id, plus the following:

* **doctext** - Writeup text
* **cools** - Array of node references of users that have C!ed the writeup

If a user has voted on it:
* **vote** - Which way the user voted

If a user has voted on it or is the author:
* **reputation** - The reputation of the node if you have voted on it or if it is yours
* **upvotes** - The number of people who have voted up on a node
* **downvotes** - The number of people who have voted down on a node

## E2nodes

### /api/e2nodes

Always returns UNIMPLEMENTED

### /api/e2nodes/:id

Returns all of the items in /api/nodes/:id, plus the following:

* **group** - If there are writeups in the node, a listing of /api/writeups objects

### /api/e2nodes/create

Accepts a POST parameter with the following parameters:

* **title** - The title of the e2node to create

Note that due to a quirk in the security model of e2, all e2node owners are set to "Content Editors" in the system, with an additional owner set in a different table.

Returns the display of e2nodes/:id of the newly created object

## Drafts

## Documents

## Superdocument

## Messages

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
* **for** - The name of 
* **for_id** - More precise and preferred version of for_id. Is ignored if this and **for** are sent at the same time.
* **message** - The message text to send

## Message Ignores

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

## Chats

## Bookmarks

## Votes

## Cools

## Sessions

Current version: *1 (beta)*

Logs a user in

### /api/sessions

Returns the JSON encoded values associated with the current session

Keys:
* **display** - Contains private information about the session
  * **is_guest** - 1 or 0 depending on whether the user is a "logged in user". This is the preferred check other than the internal user "Guest User"
  * **powers** - Array of special powers the client can use to display more advanced tools. This is not shown if there are no special powers to display 
    * **ed** - User is an editor
    * **admin** - User is an admin
    * **chanop** - User is a channel operator
    * **client** - User is a client developer (Not given to admins by default for UI clarity)
    * **dev** - User is a site developer (Same as **client**)
  * **votesleft** - How many votes left the user has
  * **coolsleft** - How many C!s left the user has
* *user** - If the user is not a guest, the output of /api/user for the user_id

### /api/sessions/create
Accepts a POST with two parameters
* **username** - Username of the user
* **passwd** - Password of the user

If the login was unsuccessful, a 403 Forbidden is returned.

If the login was successful, the output of /api/sessions is returned, along with the cookie in the headers as Set-Cookie to continue the authentication. The cookie does not have an expiration.

### /api/sessions/destroy
Destroys the current session. Not explicitly needed since no on-server state is kept for sessions. Simply deletes the cookie. Regardless of its current use, we recommend calling this in case any backend server state does need to be cleaned.

Returns the output of /api/sessions for the new current user, which is probably Guest User. Logging out Guest User has no other effect.

## Searches

## Tests

### /api/tests (version 2)
returns ````{"v": 2}````

### /api/tests (version 3)
returns ````{"version": 3}````
Test-only API which is to validate version-acceptance

