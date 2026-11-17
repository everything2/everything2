# E2 Link Syntax Specification

This document describes all supported link syntax in Everything2.

**Source of Truth:** `react/utils/linkParser.js`
**Last verified:** 2026-11-16 — every example below was re-run through `parseLinksToHtml()`; outputs are verbatim.

> **Two render paths.** The HTML strings below are what `parseLinksToHtml()` emits (used by `E2HtmlSanitizer.js` for previews/HTML strings). The React path (`ParseLinks.js`) uses the same `parseLinks()` segments but renders internal links through `LinkNode.js`, which builds its own URL (it percent-encodes `& @ + / ; ? #` in titles exactly once — see the LinkNode/route-helper note in `CLAUDE.md`) and does not add `title` attributes to external links.

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
<a href="https://example.com" rel="nofollow" class="externalLink" target="_blank" title="https://example.com">https://example.com</a>
```

#### External Link with Display Text
```
[https://example.com|Example Site]
```
**Output:**
```html
<a href="https://example.com" rel="nofollow" class="externalLink" target="_blank" title="https://example.com">Example Site</a>
```

#### External Link with Empty Pipe (Uses "[link]" as Display)
```
[https://example.com|]
```
**Output:**
```html
<a href="https://example.com" rel="nofollow" class="externalLink" target="_blank" title="https://example.com">[link]</a>
```

#### External Link with Query String
```
[https://example.com/search?q=hello&lang=en]
```
**Output:**
```html
<a href="https://example.com/search?q=hello&amp;lang=en" rel="nofollow" class="externalLink" target="_blank" title="https://example.com/search?q=hello&amp;lang=en">https://example.com/search?q=hello&amp;lang=en</a>
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
<a href="/user/username/writeups/My%20Writeup" class="e2-link" title="My Writeup">My Writeup</a>
```

#### With Custom Display Text
```
[My Writeup[by username]|click here]
```
**Output:**
```html
<a href="/user/username/writeups/My%20Writeup" class="e2-link" title="My Writeup">click here</a>
```

The `by` keyword is case-insensitive. A bare `[x[by ]]` (no author) is not a link and is left as text.

#### Display-First Form
```
[shown|My WU[by root]]
```
**Output:**
```html
<a href="/user/root/writeups/My%20WU" class="e2-link" title="My WU">shown</a>
```

#### With Spaces in Username
```
[My Writeup[by user with spaces]]
```
**Output:**
```html
<a href="/user/user%20with%20spaces/writeups/My%20Writeup" class="e2-link" title="My Writeup">My Writeup</a>
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
<a href="/user/username" class="e2-link" title="username">username</a>
```

#### Usergroup Link
```
[gods[usergroup]]
```
**Output:**
```html
<a href="/usergroup/gods" class="e2-link" title="gods">gods</a>
```

#### Superdoc Link
```
[User Settings[superdoc]]
```
**Output:**
```html
<a href="/superdoc/User%20Settings" class="e2-link" title="User Settings">User Settings</a>
```

#### Room Link
```
[Everything Noder Picks[room]]
```
**Output:**
```html
<a href="/room/Everything%20Noder%20Picks" class="e2-link" title="Everything Noder Picks">Everything Noder Picks</a>
```

#### Typed Link with Display Text (either order, #4532)
```
[gate[user]|gate's]
[gate's|gate[user]]
```
**Output:**
```html
<a href="/user/gate" class="e2-link" title="gate">gate&#039;s</a>
```

#### Nodetype Rules
- The type is lowercased: `[Root[USER]]` → `href="/user/Root"`.
- After lowercasing it must match `^[a-z0-9_]+$`; otherwise the whole bracket is left as plain text (e.g. `[x[Not A Type!]]` is not a link).
- The parser does not check that the nodetype exists.

---

### 4. Comment Links

Links to discussion comments using numeric IDs.

#### Basic Syntax
```
[Discussion Title[42]]
```
**Output:**
```html
<a href="/title/Discussion%20Title#debatecomment_42" class="e2-link" title="Discussion Title">Discussion Title</a>
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
<a href="/title/node%20title" class="e2-link" title="node title">node title</a>
```

#### Pipelink with Custom Display
```
[actual node title|shown text]
```
**Output:**
```html
<a href="/title/actual%20node%20title" class="e2-link" title="actual node title">shown text</a>
```

- Empty display falls back to the title: `[title|]` → display `title`.
- Only the first two `|`-separated parts are used: `[a|b|c]` → link to `a`, display `b`.
- **Inline HTML in display text** (#4534): in `parseLinksToHtml()` only, a pipelink display keeps a small inline-tag allowlist (`INLINE_DISPLAY_TAGS`: `b`, `i`, `em`, `strong`, `abbr`, `code`, `sub`, `sup`, …; attributes limited to `title`/`lang`/`cite`). Other tags are unwrapped to their text. Example: `[a title|<b>bold</b> text]` → `<a href="/title/a%20title" class="e2-link" title="a title"><b>bold</b> text</a>`. This runs only on content that has already passed E2HtmlSanitizer's DOMPurify step. The React path shows plain text.

#### Link with Special Characters
```
[Tom & Jerry]
[Tom &amp; Jerry]
```
**Output (both):**
```html
<a href="/title/Tom%20%26%20Jerry" class="e2-link" title="Tom &amp; Jerry">Tom &amp; Jerry</a>
```
Bracket content is entity-decoded first (`&amp; &lt; &gt; &quot; &#39; &#039;`, single pass) because DOMPurify has usually already encoded it (#4060).

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
<a href="/title/formatted%20title" class="e2-link" title="formatted title">formatted title</a>
```
Note: HTML tags are stripped from the title (and from plain display text).

### Nested Brackets
```
[[nested]]
```
**Output:**
```html
<a href="/title/%5Bnested%5D" class="e2-link" title="[nested]">[nested]</a>
```
Note: Treated as a link to "[nested]" (literal brackets in title).

### URLs Without Brackets
```
Visit https://example.com for more
```
**Output:** `Visit https://example.com for more` (not converted - must be in brackets)

---

## Processing Order

`parseLinks()` finds bracket groups with `/\[([^\[\]]*(?:\[[^\]]*\][^\[\]]*)?)\]/g` (one level of nesting), then `parseLinkContent()` tries these in order (first match wins):

0. **Entity-decode + trim** the content; empty → not a link
1. **External Links** - `[http(s)://...]`, optional `|display`
2. **Writeup by Author** - `[title[by author]]`, optional `|display`
3. **Typed / Comment Links** - `[title[type]]` or `[title[123]]`, optional `|display`
4. **Display-first Typed** - `[display|title[type]]`, `[display|title[by author]]`, `[display|title[123]]`
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
- **Link component (React path):** `react/components/LinkNode.js`
- **Tests:** `react/utils/linkParser.test.js` (87 cases)
- **Perl ↔ JS comparison tool:** `tools/compare-link-parsing.js`

---

## Perl Reference

The JavaScript implementation is based on the Perl `parseLinks()` function in:
- `ecore/Everything/Application.pm` (`sub parseLinks`, ~line 3965; `Everything::HTML::parseLinks` is a thin wrapper). Internal links are resolved by `linkNodeTitle()`.

The Perl implementation uses these regex patterns:
1. External pipelinks: `\[(https?://[^\]\|\[<>"]+)\|\s*([^\]\|\[]+)?\]`
2. External simple: `\[(https?://[^\]\|\[<>"]+)\]`
3. Internal links: `\[([^[\]]*(?:\[[^\]|]*[\]|][^[\]]*)?)]`

---

## Last Updated

2025-12-26; verified against `linkParser.js` 2026-11-16
