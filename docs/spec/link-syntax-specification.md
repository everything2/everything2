# E2 Link Syntax Specification

This document describes all supported link syntax in Everything2.

**Source of Truth:** `react/utils/linkParser.js`

## Overview

E2 uses bracket-based link syntax `[...]` for creating both internal and external links. The parser processes links in a specific order to handle overlapping patterns correctly.

## Link Types

### 1. External Links

Links to external websites using HTTP or HTTPS protocols.

#### Simple External Link
```
[https://example.com]
```
**Output:**
```html
<a href="https://example.com" rel="nofollow" class="externalLink" target="_blank">https://example.com</a>
```

#### External Link with Display Text
```
[https://example.com|Example Site]
```
**Output:**
```html
<a href="https://example.com" rel="nofollow" class="externalLink" target="_blank">Example Site</a>
```

#### External Link with Empty Pipe (Uses "[link]" as Display)
```
[https://example.com|]
```
**Output:**
```html
<a href="https://example.com" rel="nofollow" class="externalLink" target="_blank">[link]</a>
```

#### External Link with Query String
```
[https://example.com/search?q=hello&lang=en]
```
**Output:**
```html
<a href="https://example.com/search?q=hello&lang=en" rel="nofollow" class="externalLink" target="_blank">https://example.com/search?q=hello&lang=en</a>
```

---

### 2. Writeup by Author Links

Links to a specific author's writeup.

#### Basic Syntax
```
[My Writeup[by username]]
```
**Output:**
```html
<a href="/user/username/writeups/My%20Writeup" class="e2-link">My Writeup</a>
```

#### With Custom Display Text
```
[My Writeup[by username]|click here]
```
**Output:**
```html
<a href="/user/username/writeups/My%20Writeup" class="e2-link">click here</a>
```

#### With Spaces in Username
```
[My Writeup[by user with spaces]]
```
**Output:**
```html
<a href="/user/user%20with%20spaces/writeups/My%20Writeup" class="e2-link">My Writeup</a>
```

---

### 3. Typed Links

Links to specific node types.

#### User Link
```
[username[user]]
```
**Output:**
```html
<a href="/user/username" class="e2-link">username</a>
```

#### Usergroup Link
```
[gods[usergroup]]
```
**Output:**
```html
<a href="/usergroup/gods" class="e2-link">gods</a>
```

#### Superdoc Link
```
[User Settings[superdoc]]
```
**Output:**
```html
<a href="/superdoc/User%20Settings" class="e2-link">User Settings</a>
```

#### Room Link
```
[Everything Noder Picks[room]]
```
**Output:**
```html
<a href="/room/Everything%20Noder%20Picks" class="e2-link">Everything Noder Picks</a>
```

---

### 4. Comment Links

Links to discussion comments using numeric IDs.

#### Basic Syntax
```
[Discussion Title[42]]
```
**Output:**
```html
<a href="/title/Discussion%20Title#debatecomment_42" class="e2-link">Discussion Title</a>
```

---

### 5. Internal Links (Standard E2 Links)

Links to E2 nodes by title.

#### Simple Link
```
[node title]
```
**Output:**
```html
<a href="/title/node%20title" class="e2-link">node title</a>
```

#### Pipelink with Custom Display
```
[actual node title|shown text]
```
**Output:**
```html
<a href="/title/actual%20node%20title" class="e2-link">shown text</a>
```

#### Link with Special Characters
```
[Tom & Jerry]
```
**Output:**
```html
<a href="/title/Tom%20%26%20Jerry" class="e2-link">Tom &amp; Jerry</a>
```

---

## Edge Cases

### Empty Brackets
```
[]
```
**Output:** `[]` (left unchanged - not a valid link)

### Whitespace-Only Brackets
```
[   ]
```
**Output:** `[   ]` (left unchanged - not a valid link)

### HTML Inside Brackets
```
[<b>formatted</b> title]
```
**Output:**
```html
<a href="/title/formatted%20title" class="e2-link">formatted title</a>
```
Note: HTML tags are stripped from both the URL and display text.

### Nested Brackets
```
[[nested]]
```
**Output:**
```html
<a href="/title/%5Bnested%5D" class="e2-link">[nested]</a>
```
Note: Treated as a link to "[nested]" (literal brackets in title).

### URLs Without Brackets
```
Visit https://example.com for more
```
**Output:** `Visit https://example.com for more` (not converted - must be in brackets)

---

## Processing Order

The parser processes patterns in this order to handle overlapping cases:

1. **External Links** - `[http://...]` or `[https://...]`
2. **Writeup by Author** - `[title[by author]]`
3. **Typed Links** - `[title[type]]`
4. **Comment Links** - `[title[123]]` (numeric ID)
5. **Pipelinks** - `[title|display]`
6. **Simple Links** - `[title]`

This order ensures that external URLs are not accidentally treated as internal links.

---

## Character Handling

### URL Encoding
All special characters in node titles are URL-encoded:
- Space → `%20`
- `&` → `%26`
- `"` → `%22`
- `[` → `%5B`
- `]` → `%5D`

### HTML Escaping
Display text is HTML-escaped:
- `&` → `&amp;`
- `<` → `&lt;`
- `>` → `&gt;`
- `"` → `&quot;`
- `'` → `&#039;`

---

## Implementation Files

- **Shared Parser:** `react/utils/linkParser.js`
- **React Component:** `react/components/ParseLinks.js`
- **HTML Sanitizer:** `react/components/Editor/E2HtmlSanitizer.js`
- **Tests:** `react/utils/linkParser.test.js`

---

## Perl Reference

The JavaScript implementation is based on the Perl `parseLinks()` function in:
- `ecore/Everything/Application.pm` (lines 3642-3676)

The Perl implementation uses these regex patterns:
1. External pipelinks: `\[(https?://[^\]\|\[<>"]+)\|\s*([^\]\|\[]+)?\]`
2. External simple: `\[(https?://[^\]\|\[<>"]+)\]`
3. Internal links: `\[([^[\]]*(?:\[[^\]|]*[\]|][^[\]]*)?)]`

---

## Last Updated

2025-12-26
