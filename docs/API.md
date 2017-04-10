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

Being able to see a node_id doesn't mean that you can request the displayable page for it.

If a node reference in the database is broken, you will see the following construct:
````{"node_id": 0, "title": "(unknown)"}````

There is no node_id 0, so you can key off of that to know that something is broken. The client should be able to handle that gracefully. In places inside of the data model where there is simply no reference in the database, the key won't be returned.

### Return codes:

No other content is expected to be returned in any situation other than 200 OK.

* 200 OK,  Request was successful, JSON follows
* 400 BAD REQUEST, The server did not understand the API call or did not have the proper parameters POSTed to it.
* 401 UNAUTHORIZED, The request is not available to users that are not logged in
* 403 FORBIDDEN, The logged in user account does not have the proper permissions on that object and action
* 405 UNIMPLEMENTED, The API path that was specified does not match a valid route
* 410 GONE, The version of the API you requested is no longer available, but the path is valid.

## Retiring old interfaces

During the rapid development period, we may be changing the APIs, but we will be updating this document in git as much as possible. APIs with a version of 1 (beta) are not stable and should be consumed with caution.

# API Catalogue

## Node requests

Node requests need to be able to accept any kind of return content, as dictated by the type parameter. The exact content of each of the type of request will be TBD.

### Users

### Writeups

### Drafts

### Documents

### Superdocument

## Messages

Current version: *1 (beta)*

Retrieves, sends, and sets status on messages

### /api/messages

Returns the top 15 messages ordered by newest first.

Messages have the following keys:

* **for_user** - The node reference of the receving user. This is almost certainly the logged in user, though in future versions, admins should be able to check system accounts (root, CME, Klaproth)
* **author_user** - The node reference of the sending user.
* **msgtext** - The text of the message
* **for_usergroup** - The node reference of the group the message was send to. Missing if not a usergroup message

Users who are not logged in should expect to receive 403 Forbidden

### /api/messages/:id

Returns the message at :id, formatted per the */api/messages* construct. Users who do not own the message should expect to receive 403 Forbidden.

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
* **user_id** - The user_id of the current user
* **username** - The username of the current user
* **is_guest** - 1 or 0 depending on whether the user is a "logged in user". This is the preferred check other than the internal user "Guest User"

If the user is logged in, it returns the following additional information:
* **level** - The user's experience level
* **leveltitle** - The user's experience level title
* **cools** - The user's current number of cools
* **votes** - The user's current number of remaining votes
* **bookmarks** - Array of bookmark objects. See the bookmarks API. This key is not shown if there are no bookmarks.
* **num_writeups** - Number of writeups a user has created. The key is not displayed if the amount is zero
* **powers** - Array of special powers the client can use to display more advanced tools. This is not shown if there are no special powers to display
  * **ed** - User is an editor
  * **admin** - User is an admin
  * **chanop** - User is a channel operator
  * **client** - User is a client developer (Not given to admins by default for UI clarity)
  * **dev** - User is a site developer (Same as **client**)

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

