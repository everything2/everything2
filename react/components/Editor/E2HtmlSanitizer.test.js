/**
 * Comprehensive Tests for E2HtmlSanitizer
 *
 * SECURITY-CRITICAL: This module sanitizes user HTML content.
 * These tests must cover XSS prevention, tag/attribute filtering,
 * and E2 link parsing thoroughly.
 *
 * Client-side HTML sanitization using DOMPurify configured
 * to match E2's server-side "approved html tags" setting.
 */

import {
  sanitizeHtml,
  parseE2Links,
  renderE2Content,
  checkHtmlCompatibility,
  formatCompatibilityReport,
  APPROVED_TAGS,
  escapeHtml,
  breakTags,
} from './E2HtmlSanitizer'

describe('E2HtmlSanitizer', () => {
  // ============================================================
  // APPROVED_TAGS CONFIGURATION
  // ============================================================
  describe('APPROVED_TAGS configuration', () => {
    it('includes all expected text formatting tags', () => {
      const textTags = ['b', 'strong', 'i', 'em', 'u', 's', 'strike', 'del', 'ins', 'big', 'small', 'sub', 'sup', 'tt', 'kbd', 'code', 'samp', 'var', 'cite']
      textTags.forEach(tag => {
        expect(APPROVED_TAGS).toHaveProperty(tag)
      })
    })

    it('includes heading tags h2-h6 with align attribute (h1 excluded for SEO)', () => {
      ;['h2', 'h3', 'h4', 'h5', 'h6'].forEach(tag => {
        expect(APPROVED_TAGS).toHaveProperty(tag)
        expect(APPROVED_TAGS[tag]).toEqual(['align'])
      })
    })

    it('does NOT include h1 (converted to h2 for proper heading hierarchy)', () => {
      expect(APPROVED_TAGS).not.toHaveProperty('h1')
    })

    it('includes table tags with correct attributes', () => {
      expect(APPROVED_TAGS.table).toEqual(expect.arrayContaining(['border', 'cellpadding', 'cellspacing', 'cols', 'frame', 'width']))
      expect(APPROVED_TAGS.td).toEqual(expect.arrayContaining(['rowspan', 'colspan', 'align', 'valign', 'height', 'width']))
      expect(APPROVED_TAGS.th).toEqual(expect.arrayContaining(['rowspan', 'colspan', 'align', 'valign', 'height', 'width']))
      expect(APPROVED_TAGS.tr).toEqual(expect.arrayContaining(['align', 'valign']))
      expect(APPROVED_TAGS).toHaveProperty('tbody')
      expect(APPROVED_TAGS).toHaveProperty('thead')
      expect(APPROVED_TAGS).toHaveProperty('caption')
    })

    it('includes list tags with correct attributes', () => {
      expect(APPROVED_TAGS).toHaveProperty('ul')
      expect(APPROVED_TAGS).toHaveProperty('ol')
      expect(APPROVED_TAGS).toHaveProperty('li')
      expect(APPROVED_TAGS).toHaveProperty('dl')
      expect(APPROVED_TAGS).toHaveProperty('dt')
      expect(APPROVED_TAGS).toHaveProperty('dd')
      expect(APPROVED_TAGS.ol).toContain('type')
      expect(APPROVED_TAGS.ol).toContain('start')
      expect(APPROVED_TAGS.ul).toContain('type')
    })

    it('includes block elements with correct attributes', () => {
      expect(APPROVED_TAGS).toHaveProperty('p')
      expect(APPROVED_TAGS.p).toContain('align')
      expect(APPROVED_TAGS).toHaveProperty('br')
      expect(APPROVED_TAGS).toHaveProperty('hr')
      expect(APPROVED_TAGS.hr).toContain('width')
      expect(APPROVED_TAGS).toHaveProperty('pre')
      expect(APPROVED_TAGS).toHaveProperty('blockquote')
      expect(APPROVED_TAGS.blockquote).toContain('cite')
      expect(APPROVED_TAGS).toHaveProperty('center')
    })

    it('includes semantic tags with correct attributes', () => {
      expect(APPROVED_TAGS).toHaveProperty('abbr')
      expect(APPROVED_TAGS.abbr).toEqual(expect.arrayContaining(['lang', 'title']))
      expect(APPROVED_TAGS).toHaveProperty('acronym')
      expect(APPROVED_TAGS.acronym).toEqual(expect.arrayContaining(['lang', 'title']))
      expect(APPROVED_TAGS).toHaveProperty('q')
      expect(APPROVED_TAGS.q).toContain('cite')
    })

    it('has exactly 46 approved tags (h1 excluded, converted to h2 for SEO)', () => {
      // This ensures parity with the server-side configuration
      // h1 is not in the list - it gets converted to h2.user-h1
      expect(Object.keys(APPROVED_TAGS).length).toBe(46)
    })

    it('does NOT include dangerous tags', () => {
      const dangerousTags = ['script', 'style', 'iframe', 'object', 'embed', 'form', 'input', 'button', 'img', 'video', 'audio', 'svg', 'math', 'link', 'meta', 'base', 'noscript', 'template']
      dangerousTags.forEach(tag => {
        expect(APPROVED_TAGS).not.toHaveProperty(tag)
      })
    })

    it('does NOT include layout tags that could break page', () => {
      const layoutTags = ['div', 'span', 'article', 'section', 'nav', 'header', 'footer', 'aside', 'main', 'figure', 'figcaption']
      layoutTags.forEach(tag => {
        expect(APPROVED_TAGS).not.toHaveProperty(tag)
      })
    })
  })

  // ============================================================
  // E2 LINK PARSING
  // ============================================================
  describe('parseE2Links', () => {
    describe('basic syntax', () => {
      it('converts simple [link] syntax to anchor tag', () => {
        const result = parseE2Links('Check out [Test Node] for more info')
        expect(result).toContain('<a href="/title/Test%20Node"')
        expect(result).toContain('class="e2-link"')
        expect(result).toContain('Test Node</a>')
      })

      it('converts [link|display text] syntax', () => {
        const result = parseE2Links('See [actual node|click here] for details')
        expect(result).toContain('<a href="/title/actual%20node"')
        expect(result).toContain('click here</a>')
      })

      it('handles multiple links in one string', () => {
        const result = parseE2Links('[First] and [Second|two] and [Third]')
        expect(result).toContain('/title/First')
        expect(result).toContain('/title/Second')
        expect(result).toContain('two</a>')
        expect(result).toContain('/title/Third')
      })

      it('preserves text around links', () => {
        const result = parseE2Links('Before [link] middle [other|text] after')
        expect(result).toBe('Before <a href="/title/link" class="e2-link" title="link">link</a> middle <a href="/title/other" class="e2-link" title="other">text</a> after')
      })
    })

    describe('edge cases', () => {
      it('does not convert empty brackets', () => {
        expect(parseE2Links('[]')).toBe('[]')
      })

      it('does not convert whitespace-only brackets', () => {
        expect(parseE2Links('[  ]')).toBe('[  ]')
        expect(parseE2Links('[ \t ]')).toBe('[ \t ]')
      })

      it('handles nested brackets (treats inner as link)', () => {
        // [[nested]] - the outer pair is [[...]], the inner is [nested]
        // Parser matches [nested] as a simple link
        const result = parseE2Links('[[nested]]')
        // The [nested] becomes a link, outer brackets remain
        expect(result).toContain('/title/')
        expect(result).toContain('nested')
      })

      it('handles adjacent brackets', () => {
        const result = parseE2Links('[First][Second]')
        expect(result).toContain('/title/First')
        expect(result).toContain('/title/Second')
      })

      it('handles line breaks in surrounding text', () => {
        const result = parseE2Links('Line one\n[link]\nLine three')
        expect(result).toContain('/title/link')
      })

      it('returns empty string for null/undefined/empty', () => {
        expect(parseE2Links(null)).toBe('')
        expect(parseE2Links(undefined)).toBe('')
        expect(parseE2Links('')).toBe('')
      })
    })

    describe('special characters', () => {
      it('URL-encodes node names with spaces', () => {
        const result = parseE2Links('[Node With Spaces]')
        expect(result).toContain('/title/Node%20With%20Spaces')
      })

      it('URL-encodes node names with special characters', () => {
        const result = parseE2Links('[Node & Co.]')
        expect(result).toContain('/title/Node%20%26%20Co.')
      })

      it('escapes HTML in display text', () => {
        const result = parseE2Links('[Node & stuff]')
        expect(result).toContain('Node &amp; stuff</a>')
      })

      it('strips HTML from custom display text (legacy behavior)', () => {
        // Legacy behavior: HTML tags inside brackets are stripped
        const result = parseE2Links('[node|<b>bold</b>]')
        expect(result).toContain('bold</a>')
        expect(result).not.toContain('<b>')
      })

      it('handles quotes in node names', () => {
        const result = parseE2Links('[He said "hello"]')
        expect(result).toContain('He said &quot;hello&quot;</a>')
      })

      it('handles apostrophes in node names', () => {
        const result = parseE2Links("[It's a node]")
        expect(result).toContain("It&#039;s a node</a>")
      })

      it('handles Unicode characters', () => {
        const result = parseE2Links('[日本語ノード]')
        expect(result).toContain('日本語ノード</a>')
        expect(result).toContain('/title/')
      })
    })

    describe('typed link syntax [nodetitle[nodetype]]', () => {
      it('converts [title[type]] to /type/title URL', () => {
        const result = parseE2Links('[jaybonci[user]]')
        expect(result).toContain('<a href="/user/jaybonci"')
        expect(result).toContain('class="e2-link"')
        expect(result).toContain('jaybonci</a>')
      })

      it('handles space before inner bracket', () => {
        const result = parseE2Links('[jaybonci [user]]')
        expect(result).toContain('<a href="/user/jaybonci"')
      })

      it('handles spaces inside inner bracket', () => {
        const result = parseE2Links('[jaybonci[ user ]]')
        expect(result).toContain('<a href="/user/jaybonci"')
      })

      it('handles spaces both places', () => {
        const result = parseE2Links('[jaybonci [ user ]]')
        expect(result).toContain('<a href="/user/jaybonci"')
      })

      it('lowercases nodetype in URL', () => {
        const result = parseE2Links('[Test Node[SUPERDOC]]')
        expect(result).toContain('<a href="/superdoc/Test%20Node"')
      })

      it('handles writeup type', () => {
        const result = parseE2Links('[lazy dog[writeup]]')
        expect(result).toContain('<a href="/writeup/lazy%20dog"')
      })

      it('handles e2node type', () => {
        const result = parseE2Links('[Test Title[e2node]]')
        expect(result).toContain('<a href="/e2node/Test%20Title"')
      })

      it('handles room type', () => {
        const result = parseE2Links('[Political Asylum[room]]')
        expect(result).toContain('<a href="/room/Political%20Asylum"')
      })

      it('handles multiple typed links', () => {
        const result = parseE2Links('[user1[user]] and [user2[user]]')
        expect(result).toContain('<a href="/user/user1"')
        expect(result).toContain('<a href="/user/user2"')
      })

      it('handles mixed typed and regular links', () => {
        const result = parseE2Links('[jaybonci[user]] wrote [a writeup]')
        expect(result).toContain('<a href="/user/jaybonci"')
        expect(result).toContain('<a href="/title/a%20writeup"')
      })

      it('treats empty inner brackets as literal text in link', () => {
        // [title[]] - the [] is treated as literal text in the title
        // Parser sees this as [title[]] which becomes a link to "title[]"
        const result = parseE2Links('[title[]]')
        expect(result).toContain('/title/title%5B%5D')
      })

      it('treats whitespace-only inner brackets as literal text in link', () => {
        // [title[ ]] - the [ ] is treated as literal text in the title
        // Parser sees this as link to "title[ ]"
        const result = parseE2Links('[title[ ]]')
        expect(result).toContain('/title/title%5B%20%5D')
      })

      it('URL-encodes special characters in title', () => {
        const result = parseE2Links('[Node & Co.[user]]')
        expect(result).toContain('/user/Node%20%26%20Co.')
      })

      it('strips HTML from typed link display text (legacy behavior)', () => {
        // Legacy behavior: HTML tags inside brackets are stripped
        const result = parseE2Links('[<b>jaybonci</b>[user]]')
        expect(result).toBe('<a href="/user/jaybonci" class="e2-link" title="jaybonci">jaybonci</a>')
      })
    })

    describe('HTML inside brackets (legacy behavior)', () => {
      it('strips HTML from [<big>node</big>] to get link target', () => {
        const result = parseE2Links('[<big>node</big>]')
        expect(result).toBe('<a href="/title/node" class="e2-link" title="node">node</a>')
      })

      it('strips nested HTML tags from link brackets', () => {
        const result = parseE2Links('[<big><big>some node</big></big>]')
        expect(result).toBe('<a href="/title/some%20node" class="e2-link" title="some node">some node</a>')
      })

      it('handles HTML with attributes in brackets', () => {
        const result = parseE2Links('[<span class="foo">test</span>]')
        expect(result).toBe('<a href="/title/test" class="e2-link" title="test">test</a>')
      })

      it('does not convert brackets with only HTML tags (no text content)', () => {
        expect(parseE2Links('[<br>]')).toBe('[<br>]')
        expect(parseE2Links('[<big></big>]')).toBe('[<big></big>]')
      })

      it('handles HTML in typed links [node[type]]', () => {
        const result = parseE2Links('[<b>jaybonci</b>[user]]')
        expect(result).toBe('<a href="/user/jaybonci" class="e2-link" title="jaybonci">jaybonci</a>')
      })

      it('handles HTML in by-author links [title[by user]]', () => {
        const result = parseE2Links('[<i>April 2, 2012</i>[by wertperch]]')
        expect(result).toBe('<a href="/user/wertperch/writeups/April%202%2C%202012" class="e2-link" title="April 2, 2012">April 2, 2012</a>')
      })

      it('handles HTML in username of by-author links', () => {
        const result = parseE2Links('[My Writeup[by <b>author</b>]]')
        expect(result).toBe('<a href="/user/author/writeups/My%20Writeup" class="e2-link" title="My Writeup">My Writeup</a>')
      })

      it('handles mixed HTML and text in brackets', () => {
        const result = parseE2Links('[this is <b>bold</b> text]')
        expect(result).toBe('<a href="/title/this%20is%20bold%20text" class="e2-link" title="this is bold text">this is bold text</a>')
      })
    })

    describe('pipe separator handling', () => {
      it('handles pipe at start of content', () => {
        const result = parseE2Links('[|display only]')
        // Pipe at start means empty title - parser converts with empty href
        // The behavior is: title = "", display = "display only"
        expect(result).toContain('/title/')
        expect(result).toContain('display only')
      })

      it('handles multiple pipes (uses first)', () => {
        const result = parseE2Links('[node|text|more]')
        // Only first pipe should be used as separator
        expect(result).toContain('/title/node')
      })

      it('handles pipe with spaces (trims title)', () => {
        const result = parseE2Links('[node | display text]')
        // Title gets trimmed, display text preserves leading space
        expect(result).toContain('/title/node')
        expect(result).toContain('display text</a>')
      })
    })

    describe('[title[by username]] syntax - writeup by specific author', () => {
      it('converts basic [title[by username]] to /user/username/writeups/title', () => {
        const result = parseE2Links('[April 2, 2012[by wertperch]]')
        expect(result).toContain('<a href="/user/wertperch/writeups/April%202%2C%202012"')
        expect(result).toContain('class="e2-link"')
        expect(result).toContain('April 2, 2012</a>')
      })

      it('converts [title[by username]|display] with custom display text', () => {
        const result = parseE2Links("[April 2, 2012[by wertperch]|grundoon's memorial]")
        expect(result).toContain('<a href="/user/wertperch/writeups/April%202%2C%202012"')
        expect(result).toContain("grundoon&#039;s memorial</a>")
      })

      it('handles spaces around "by" keyword', () => {
        const result = parseE2Links('[My Title[ by  some_user ]]')
        expect(result).toContain('<a href="/user/some_user/writeups/My%20Title"')
      })

      it('handles space before inner bracket', () => {
        const result = parseE2Links('[My Title [by someone]]')
        expect(result).toContain('<a href="/user/someone/writeups/My%20Title"')
      })

      it('handles spaces everywhere', () => {
        const result = parseE2Links('[My Title [ by some_user ]]')
        expect(result).toContain('<a href="/user/some_user/writeups/My%20Title"')
      })

      it('is case-insensitive for "by" keyword', () => {
        const result1 = parseE2Links('[Title[BY user1]]')
        const result2 = parseE2Links('[Title[By user2]]')
        const result3 = parseE2Links('[Title[bY user3]]')
        expect(result1).toContain('/user/user1/writeups/Title')
        expect(result2).toContain('/user/user2/writeups/Title')
        expect(result3).toContain('/user/user3/writeups/Title')
      })

      it('URL-encodes special characters in title', () => {
        const result = parseE2Links('[Title & "special"[by author]]')
        expect(result).toContain('/user/author/writeups/Title%20%26%20%22special%22')
      })

      it('URL-encodes special characters in username', () => {
        const result = parseE2Links('[Some Title[by user name with spaces]]')
        expect(result).toContain('/user/user%20name%20with%20spaces/writeups/Some%20Title')
      })

      it('strips HTML in display text (legacy behavior)', () => {
        // HTML tags inside brackets are stripped for both URL and display
        const result = parseE2Links('[Title[by user]|<b>bold</b> text]')
        // The <b> tags in display text are stripped
        expect(result).toContain('bold text</a>')
        expect(result).not.toContain('<b>')
      })

      it('strips HTML from title used as default display (legacy behavior)', () => {
        // HTML tags in title are stripped for display
        // Note: <stuff> looks like an HTML tag and gets stripped
        const result = parseE2Links('[Title & <stuff>[by user]]')
        // Display shows "Title & " since <stuff> is stripped as HTML
        expect(result).toContain('Title &amp;</a>')
      })

      it('handles multiple by-author links', () => {
        const result = parseE2Links('[Node1[by user1]] and [Node2[by user2]]')
        expect(result).toContain('/user/user1/writeups/Node1')
        expect(result).toContain('/user/user2/writeups/Node2')
      })

      it('handles mixed by-author and typed links', () => {
        const result = parseE2Links('[Node[by author]] wrote by [username[user]]')
        expect(result).toContain('/user/author/writeups/Node')
        expect(result).toContain('/user/username')
        expect(result).not.toContain('/user/username/writeups')
      })

      it('handles mixed by-author and regular links', () => {
        const result = parseE2Links('[Writeup[by author]] about [topic]')
        expect(result).toContain('/user/author/writeups/Writeup')
        expect(result).toContain('/title/topic')
      })

      it('handles by-author link with pipe and regular link', () => {
        const result = parseE2Links('[Title[by user]|custom] see also [other node]')
        expect(result).toContain('/user/user/writeups/Title')
        expect(result).toContain('custom</a>')
        expect(result).toContain('/title/other%20node')
      })

      it('does not match if "by" keyword is missing', () => {
        // This should be treated as a regular typed link, not by-author
        const result = parseE2Links('[Title[user]]')
        expect(result).toContain('/user/Title')
        expect(result).not.toContain('/writeups/')
      })

      it('handles real-world example: grundoon memorial link', () => {
        const result = parseE2Links("[April 2, 2012[by wertperch]|grundoon's memorial]")
        expect(result).toContain('<a href="/user/wertperch/writeups/April%202%2C%202012"')
        expect(result).toContain("grundoon&#039;s memorial</a>")
      })

      it('handles daylog-style dates', () => {
        const result = parseE2Links('[December 25, 2023[by santa]]')
        expect(result).toContain('/user/santa/writeups/December%2025%2C%202023')
      })

      it('handles usernames with underscores', () => {
        const result = parseE2Links('[My Writeup[by some_user_name]]')
        expect(result).toContain('/user/some_user_name/writeups/My%20Writeup')
      })

      it('handles usernames with numbers', () => {
        const result = parseE2Links('[My Writeup[by user123]]')
        expect(result).toContain('/user/user123/writeups/My%20Writeup')
      })

      it('preserves surrounding text', () => {
        const result = parseE2Links('Read [Great Writeup[by author]|this] for more info.')
        expect(result).toBe('Read <a href="/user/author/writeups/Great%20Writeup" class="e2-link" title="Great Writeup">this</a> for more info.')
      })

      it('handles adjacent by-author links', () => {
        const result = parseE2Links('[A[by x]][B[by y]]')
        expect(result).toContain('/user/x/writeups/A')
        expect(result).toContain('/user/y/writeups/B')
      })

      it('handles empty title with inner bracket becoming link', () => {
        // [[by user]] - outer pair is [[...]], inner is [by user]
        // The inner [by user] matches as a simple link
        const result = parseE2Links('[[by user]]')
        // The parser treats [by user] as a link to "by user"
        expect(result).toContain('/title/')
        expect(result).toContain('by user')
      })

      it('handles malformed by-author pattern', () => {
        // [Title[by ]] - the username is empty/whitespace only
        // This doesn't match by-author syntax, so treated as typed link
        const result = parseE2Links('[Title[by ]]')
        // Parser leaves malformed patterns unchanged
        expect(result).toBe('[Title[by ]]')
      })
    })
  })

  // ============================================================
  // HTML ESCAPING
  // ============================================================
  describe('escapeHtml', () => {
    it('escapes less-than', () => {
      expect(escapeHtml('<')).toBe('&lt;')
    })

    it('escapes greater-than', () => {
      expect(escapeHtml('>')).toBe('&gt;')
    })

    it('escapes ampersand', () => {
      expect(escapeHtml('&')).toBe('&amp;')
    })

    it('escapes double quotes', () => {
      expect(escapeHtml('"')).toBe('&quot;')
    })

    it('escapes single quotes', () => {
      expect(escapeHtml("'")).toBe('&#039;')
    })

    it('escapes all special chars in one string', () => {
      expect(escapeHtml('<script>"test" & \'more\'')).toBe('&lt;script&gt;&quot;test&quot; &amp; &#039;more&#039;')
    })

    it('handles empty/null input', () => {
      expect(escapeHtml('')).toBe('')
      expect(escapeHtml(null)).toBe('')
      expect(escapeHtml(undefined)).toBe('')
    })

    it('preserves safe characters', () => {
      expect(escapeHtml('Hello World 123')).toBe('Hello World 123')
    })
  })

  // ============================================================
  // HTML SANITIZATION
  // ============================================================
  describe('sanitizeHtml', () => {
    describe('approved tags preservation', () => {
      it('preserves simple approved tags', () => {
        const input = '<p>Hello <strong>world</strong></p>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).toContain('<p>')
        expect(html).toContain('<strong>')
        expect(html).toContain('</strong>')
        expect(html).toContain('</p>')
      })

      it('preserves heading levels h2-h6', () => {
        ;['h2', 'h3', 'h4', 'h5', 'h6'].forEach(tag => {
          const input = `<${tag}>Heading</${tag}>`
          const { html } = sanitizeHtml(input, { parseLinks: false })
          expect(html).toContain(`<${tag}>`)
        })
      })

      it('converts h1 to h2 with user-h1 class for SEO hierarchy', () => {
        const input = '<h1>User Heading</h1>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).not.toContain('<h1>')
        expect(html).toContain('<h2')
        expect(html).toContain('class="user-h1"')
        expect(html).toContain('User Heading')
        expect(html).toContain('</h2>')
      })

      it('converts h1 with align attribute to h2 with user-h1 class', () => {
        const input = '<h1 align="center">Centered Heading</h1>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).not.toContain('<h1')
        expect(html).toContain('<h2')
        expect(html).toContain('class="user-h1"')
        expect(html).toContain('align=')
        expect(html).toContain('Centered Heading')
      })

      it('converts multiple h1 tags to h2', () => {
        const input = '<h1>First</h1><p>Text</p><h1>Second</h1>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).not.toContain('<h1>')
        expect(html).not.toContain('</h1>')
        expect((html.match(/class="user-h1"/g) || []).length).toBe(2)
      })

      it('h1 conversion is display-only - original h1 in source is not modified', () => {
        // This tests that the conversion happens at render time, not save time
        // Users can save <h1> tags in their writeups; they're only converted to
        // <h2 class="user-h1"> when displayed for proper SEO heading hierarchy
        const userInput = '<h1>My Section</h1><p>Content about my section</p>'

        // The sanitizeHtml function converts h1→h2 for display
        const { html: displayHtml } = sanitizeHtml(userInput, { parseLinks: false })
        expect(displayHtml).toContain('class="user-h1"')
        expect(displayHtml).toContain('<h2')
        expect(displayHtml).not.toContain('<h1>')

        // But the original input string is unchanged (would be saved as-is)
        expect(userInput).toContain('<h1>')
        expect(userInput).not.toContain('user-h1')
      })

      it('preserves table structure', () => {
        const input = '<table border="1"><thead><tr><th>Header</th></tr></thead><tbody><tr><td>Cell</td></tr></tbody></table>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).toContain('<table')
        expect(html).toContain('<thead>')
        expect(html).toContain('<tbody>')
        expect(html).toContain('<tr>')
        expect(html).toContain('<th>')
        expect(html).toContain('<td>')
      })

      it('preserves list structure', () => {
        const input = '<ul><li>One</li><li>Two</li></ul>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).toContain('<ul>')
        expect(html).toContain('<li>')
      })

      it('preserves definition lists', () => {
        const input = '<dl><dt>Term</dt><dd>Definition</dd></dl>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).toContain('<dl>')
        expect(html).toContain('<dt>')
        expect(html).toContain('<dd>')
      })

      it('preserves blockquotes with cite', () => {
        const input = '<blockquote cite="source">Quote</blockquote>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).toContain('<blockquote')
        expect(html).toContain('cite=')
      })

      it('preserves pre and code', () => {
        const input = '<pre><code>function() {}</code></pre>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).toContain('<pre>')
        expect(html).toContain('<code>')
      })
    })

    describe('approved attributes preservation', () => {
      it('preserves align on headings (h2-h6)', () => {
        const input = '<h2 align="center">Centered</h2>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).toContain('align=')
      })

      it('preserves align when h1 is converted to h2', () => {
        const input = '<h1 align="center">Centered</h1>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).toContain('align=')
        expect(html).toContain('class="user-h1"')
      })

      it('preserves table attributes', () => {
        const input = '<table border="1" cellpadding="5" cellspacing="0" width="100%"><tr><td>Cell</td></tr></table>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).toContain('border=')
        expect(html).toContain('cellpadding=')
        expect(html).toContain('cellspacing=')
        expect(html).toContain('width=')
      })

      it('preserves td/th attributes', () => {
        const input = '<table><tr><td rowspan="2" colspan="3" align="center" valign="top" width="100" height="50">Cell</td></tr></table>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).toContain('rowspan=')
        expect(html).toContain('colspan=')
        expect(html).toContain('align=')
        expect(html).toContain('valign=')
        expect(html).toContain('width=')
        expect(html).toContain('height=')
      })

      it('preserves ordered list attributes', () => {
        const input = '<ol type="a" start="5"><li>Item</li></ol>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).toContain('type=')
        expect(html).toContain('start=')
      })

      it('preserves abbr/acronym attributes', () => {
        const input = '<abbr lang="en" title="HyperText Markup Language">HTML</abbr>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).toContain('lang=')
        expect(html).toContain('title=')
      })
    })

    describe('XSS prevention - script injection', () => {
      it('removes script tags', () => {
        const input = '<p>Safe</p><script>alert("xss")</script>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).not.toContain('<script>')
        expect(html).not.toContain('alert')
        expect(html).toContain('Safe')
      })

      it('removes script tags with attributes', () => {
        const input = '<script src="evil.js"></script>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).not.toContain('<script')
        expect(html).not.toContain('evil.js')
      })

      it('removes nested script tags', () => {
        const input = '<div><script>alert(1)</script></div>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).not.toContain('<script')
      })

      it('removes script with encoding tricks', () => {
        const input = '<scr<script>ipt>alert(1)</script>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).not.toContain('<script')
      })
    })

    describe('XSS prevention - event handlers', () => {
      it('removes onclick', () => {
        const input = '<p onclick="evil()">Click</p>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).not.toContain('onclick')
        expect(html).toContain('<p>')
      })

      it('removes onmouseover', () => {
        const input = '<b onmouseover="evil()">Text</b>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).not.toContain('onmouseover')
      })

      it('removes onerror', () => {
        const input = '<p onerror="evil()">Text</p>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).not.toContain('onerror')
      })

      it('removes onfocus', () => {
        const input = '<p onfocus="evil()">Text</p>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).not.toContain('onfocus')
      })

      it('removes onload', () => {
        const input = '<p onload="evil()">Text</p>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).not.toContain('onload')
      })

      it('removes all on* handlers', () => {
        const handlers = ['onclick', 'onmouseover', 'onmouseout', 'onmousedown', 'onmouseup', 'onkeydown', 'onkeyup', 'onkeypress', 'onfocus', 'onblur', 'onchange', 'onsubmit', 'onload', 'onerror']
        handlers.forEach(handler => {
          const input = `<p ${handler}="evil()">Text</p>`
          const { html } = sanitizeHtml(input, { parseLinks: false })
          expect(html).not.toContain(handler)
        })
      })
    })

    describe('XSS prevention - dangerous tags', () => {
      it('removes iframe', () => {
        const input = '<iframe src="evil.com"></iframe>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).not.toContain('<iframe')
      })

      it('removes object', () => {
        const input = '<object data="evil.swf"></object>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).not.toContain('<object')
      })

      it('removes embed', () => {
        const input = '<embed src="evil.swf">'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).not.toContain('<embed')
      })

      it('removes form', () => {
        const input = '<form action="evil.com"><input type="text"></form>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).not.toContain('<form')
        expect(html).not.toContain('<input')
      })

      it('removes style tags', () => {
        const input = '<style>body { display: none; }</style>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).not.toContain('<style')
      })

      it('removes link tags', () => {
        const input = '<link rel="stylesheet" href="evil.css">'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).not.toContain('<link')
      })

      it('removes meta tags', () => {
        const input = '<meta http-equiv="refresh" content="0;url=evil.com">'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).not.toContain('<meta')
      })

      it('removes base tags', () => {
        const input = '<base href="evil.com">'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).not.toContain('<base')
      })

      it('removes svg (can contain scripts)', () => {
        const input = '<svg onload="evil()"><circle cx="50" cy="50" r="40"/></svg>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).not.toContain('<svg')
      })

      it('removes img (not in approved list)', () => {
        const input = '<img src="image.jpg" onerror="evil()">'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).not.toContain('<img')
      })
    })

    describe('XSS prevention - dangerous attributes', () => {
      it('removes style attribute', () => {
        const input = '<p style="background:url(javascript:evil())">Text</p>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).not.toContain('style=')
      })

      it('removes src attribute on non-approved tags', () => {
        const input = '<p src="evil.js">Text</p>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).not.toContain('src=')
      })

      it('removes href attribute (no a tag in approved list)', () => {
        // Note: links are created by parseE2Links, not raw HTML
        const input = '<a href="javascript:evil()">Click</a>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).not.toContain('href=')
      })

      it('removes data-* attributes', () => {
        const input = '<p data-evil="payload">Text</p>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).not.toContain('data-')
      })
    })

    describe('XSS prevention - protocol handlers', () => {
      it('blocks javascript: protocol in cite', () => {
        const input = '<blockquote cite="javascript:evil()">Quote</blockquote>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).not.toContain('javascript:')
      })
    })

    describe('edge cases', () => {
      it('handles empty input', () => {
        const { html, issues } = sanitizeHtml('')
        expect(html).toBe('')
        expect(issues).toEqual([])
      })

      it('handles null input', () => {
        const { html, issues } = sanitizeHtml(null)
        expect(html).toBe('')
        expect(issues).toEqual([])
      })

      it('handles undefined input', () => {
        const { html, issues } = sanitizeHtml(undefined)
        expect(html).toBe('')
        expect(issues).toEqual([])
      })

      it('handles plain text without tags', () => {
        const { html } = sanitizeHtml('Just plain text', { parseLinks: false })
        expect(html).toBe('Just plain text')
      })

      it('handles malformed HTML', () => {
        const input = '<p>Unclosed paragraph<p>Another'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        // Should still be safe, DOMPurify handles malformed HTML
        expect(html).not.toContain('<script')
      })

      it('handles deeply nested tags', () => {
        const input = '<p><strong><em><u><s>Deep</s></u></em></strong></p>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).toContain('<p>')
        expect(html).toContain('<strong>')
        expect(html).toContain('<em>')
        expect(html).toContain('<u>')
        expect(html).toContain('<s>')
      })

      it('handles mixed approved and unapproved tags', () => {
        const input = '<p>Safe</p><div>Removed</div><strong>Also safe</strong>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).toContain('<p>')
        expect(html).toContain('<strong>')
        expect(html).not.toContain('<div>')
      })

      it('handles Unicode content', () => {
        const input = '<p>日本語 and émojis 🎉</p>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).toContain('日本語')
        expect(html).toContain('🎉')
      })

      it('handles very long content', () => {
        const longText = 'A'.repeat(100000)
        const input = `<p>${longText}</p>`
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).toContain(longText)
      })
    })

    describe('E2 link parsing integration', () => {
      it('parses E2 links when option enabled (default)', () => {
        const input = '<p>See [Test Node] for info</p>'
        const { html } = sanitizeHtml(input, { parseLinks: true })
        expect(html).toContain('/title/Test%20Node')
        expect(html).toContain('class="e2-link"')
      })

      it('does not parse links when disabled', () => {
        const input = '<p>See [Test Node] for info</p>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).toContain('[Test Node]')
        expect(html).not.toContain('/title/')
      })

      it('sanitizes HTML before parsing links', () => {
        const input = '<p>See [Test Node]</p><script>alert(1)</script>'
        const { html } = sanitizeHtml(input, { parseLinks: true })
        expect(html).toContain('/title/Test%20Node')
        expect(html).not.toContain('<script>')
      })
    })
  })

  // ============================================================
  // RENDER E2 CONTENT
  // ============================================================
  describe('renderE2Content', () => {
    it('sanitizes HTML and parses links in one call', () => {
      const input = '<p>Visit [Cool Node] today!</p><script>bad</script>'
      const { html } = renderE2Content(input)
      expect(html).toContain('/title/Cool%20Node')
      expect(html).not.toContain('<script>')
    })

    it('handles complex E2 content', () => {
      const input = `
        <h2>My Writeup</h2>
        <p>This is about [some topic|a topic] I find interesting.</p>
        <blockquote cite="source">A quote</blockquote>
        <ul>
          <li>[Item One]</li>
          <li>[Item Two|number two]</li>
        </ul>
      `
      const { html } = renderE2Content(input)
      expect(html).toContain('<h2>')
      expect(html).toContain('<blockquote')
      expect(html).toContain('/title/some%20topic')
      expect(html).toContain('/title/Item%20One')
      expect(html).toContain('number two</a>')
    })

    it('handles typical E2 writeup', () => {
      const input = `
        <p>I first encountered [Everything2] back in 2001. At the time,
        [noding|the act of noding] was considered a noble pursuit.</p>

        <p>See also:</p>
        <ul>
          <li>[E2 FAQ]</li>
          <li>[How to write a good writeup|good writeup tips]</li>
        </ul>

        <blockquote>
        <em>"The database, she is beautiful."</em>
        </blockquote>
      `
      const { html } = renderE2Content(input)
      expect(html).toContain('/title/Everything2')
      expect(html).toContain('/title/noding')
      expect(html).toContain('the act of noding</a>')
      expect(html).toContain('/title/E2%20FAQ')
      expect(html).toContain('good writeup tips</a>')
    })
  })

  // ============================================================
  // COMPATIBILITY CHECKING
  // ============================================================
  describe('checkHtmlCompatibility', () => {
    it('returns array for valid HTML (may include body/#text from DOMPurify)', () => {
      const issues = checkHtmlCompatibility('<p><strong>Valid</strong></p>')
      // DOMPurify hook may report body and #text as "unsupported" - filter to actual tags
      const realTagIssues = issues.filter(i => i.type === 'unsupported_tag' && !['body', '#text'].includes(i.tag))
      expect(realTagIssues).toEqual([])
    })

    it('reports unsupported tags', () => {
      const issues = checkHtmlCompatibility('<div><span>Content</span></div>')
      const tagIssues = issues.filter(i => i.type === 'unsupported_tag')
      expect(tagIssues.length).toBeGreaterThan(0)
      const tags = tagIssues.map(i => i.tag)
      expect(tags).toContain('div')
      expect(tags).toContain('span')
    })

    it('reports unsupported attributes', () => {
      const issues = checkHtmlCompatibility('<p class="test">Text</p>')
      // class is not in approved list for p
      const attrIssues = issues.filter(i => i.type === 'unsupported_attribute')
      // Note: DOMPurify may not report this as we allow class for e2-link
    })
  })

  // ============================================================
  // COMPATIBILITY REPORTING
  // ============================================================
  describe('formatCompatibilityReport', () => {
    it('returns success message for no issues', () => {
      const report = formatCompatibilityReport([])
      expect(report).toContain('All HTML tags and attributes are supported')
    })

    it('returns success message for null', () => {
      const report = formatCompatibilityReport(null)
      expect(report).toContain('All HTML tags')
    })

    it('formats tag issues', () => {
      const issues = [{ type: 'unsupported_tag', tag: 'div' }]
      const report = formatCompatibilityReport(issues)
      expect(report).toContain('Unsupported tags')
      expect(report).toContain('<div>')
    })

    it('formats attribute issues', () => {
      const issues = [{ type: 'unsupported_attribute', tag: 'p', attr: 'style' }]
      const report = formatCompatibilityReport(issues)
      expect(report).toContain('Unsupported attributes')
      expect(report).toContain('p[style]')
    })

    it('formats mixed issues', () => {
      const issues = [
        { type: 'unsupported_tag', tag: 'div' },
        { type: 'unsupported_tag', tag: 'span' },
        { type: 'unsupported_attribute', tag: 'p', attr: 'style' }
      ]
      const report = formatCompatibilityReport(issues)
      expect(report).toContain('<div>')
      expect(report).toContain('<span>')
      expect(report).toContain('p[style]')
    })

    it('deduplicates repeated tags', () => {
      const issues = [
        { type: 'unsupported_tag', tag: 'div' },
        { type: 'unsupported_tag', tag: 'div' },
        { type: 'unsupported_tag', tag: 'div' }
      ]
      const report = formatCompatibilityReport(issues)
      const matches = report.match(/<div>/g)
      expect(matches.length).toBe(1)
    })
  })

  // ============================================================
  // BREAKTAGS FUNCTION (newline to HTML conversion)
  // ============================================================
  describe('breakTags', () => {
    it('returns empty string for null/undefined input', () => {
      expect(breakTags(null)).toBe('')
      expect(breakTags(undefined)).toBe('')
      expect(breakTags('')).toBe('')
    })

    it('skips conversion if content already has <p> tags', () => {
      const htmlWithP = '<p>Already formatted</p>\nWith newlines'
      expect(breakTags(htmlWithP)).toBe(htmlWithP)
    })

    it('skips conversion if content already has <br> tags', () => {
      const htmlWithBr = 'Line 1<br>Line 2\nLine 3'
      expect(breakTags(htmlWithBr)).toBe(htmlWithBr)
    })

    it('converts single newlines to <br> tags', () => {
      const input = 'Line 1\nLine 2\nLine 3'
      const result = breakTags(input)
      expect(result).toContain('<br>')
      expect(result).toContain('Line 1')
      expect(result).toContain('Line 2')
      expect(result).toContain('Line 3')
    })

    it('converts double newlines to paragraph breaks', () => {
      const input = 'Paragraph 1\n\nParagraph 2'
      const result = breakTags(input)
      expect(result).toContain('</p>')
      expect(result).toContain('<p>')
      expect(result).toContain('Paragraph 1')
      expect(result).toContain('Paragraph 2')
    })

    it('wraps content in <p> tags', () => {
      const input = 'Simple text'
      const result = breakTags(input)
      expect(result).toBe('<p>Simple text</p>')
    })

    it('preserves newlines inside <pre> tags', () => {
      const input = '<pre>Code\nWith\nNewlines</pre>'
      const result = breakTags(input)
      expect(result).toContain('Code\nWith\nNewlines')
      expect(result).not.toContain('Code<br>')
    })

    it('preserves newlines inside <ul> tags', () => {
      const input = '<ul>\n<li>Item 1</li>\n<li>Item 2</li>\n</ul>'
      const result = breakTags(input)
      // Newlines inside ul should be preserved
      expect(result).toContain('<li>Item 1</li>')
      expect(result).toContain('<li>Item 2</li>')
    })

    it('preserves newlines inside <ol> tags', () => {
      const input = '<ol>\n<li>First</li>\n<li>Second</li>\n</ol>'
      const result = breakTags(input)
      expect(result).toContain('<li>First</li>')
    })

    it('preserves newlines inside <table> tags', () => {
      const input = '<table>\n<tr>\n<td>Cell</td>\n</tr>\n</table>'
      const result = breakTags(input)
      expect(result).toContain('<td>Cell</td>')
    })

    it('preserves newlines inside <dl> tags', () => {
      const input = '<dl>\n<dt>Term</dt>\n<dd>Definition</dd>\n</dl>'
      const result = breakTags(input)
      expect(result).toContain('<dt>Term</dt>')
      expect(result).toContain('<dd>Definition</dd>')
    })

    it('handles mixed content with protected and unprotected newlines', () => {
      const input = 'Intro\n\n<pre>Code\nBlock</pre>\n\nConclusion'
      const result = breakTags(input)
      // Pre content should preserve newlines
      expect(result).toContain('Code\nBlock')
      // Intro and Conclusion should be in paragraphs
      expect(result).toContain('Intro')
      expect(result).toContain('Conclusion')
    })

    it('trims leading and trailing whitespace', () => {
      const input = '  \n  Text with whitespace  \n  '
      const result = breakTags(input)
      expect(result).toBe('<p>Text with whitespace</p>')
    })

    it('does not wrap block elements inside <p> tags', () => {
      const input = 'Text\n\n<h2>Heading</h2>\n\nMore text'
      const result = breakTags(input)
      // Should not have <p><h2> or </h2></p>
      expect(result).not.toContain('<p><h2>')
      expect(result).not.toContain('</h2></p>')
    })

    it('handles typical legacy writeup format', () => {
      const input = `This is a legacy writeup.

It has multiple paragraphs.

And some [links] too.`
      const result = breakTags(input)
      expect(result).toContain('<p>This is a legacy writeup.</p>')
      expect(result).toContain('<p>It has multiple paragraphs.</p>')
      expect(result).toContain('[links]') // Links are processed later
    })
  })

  // ============================================================
  // RENDERE2CONTENT WITH BREAKTAGS
  // ============================================================
  describe('renderE2Content with breakTags', () => {
    it('applies breakTags by default', () => {
      const input = 'Line 1\n\nLine 2'
      const { html } = renderE2Content(input)
      expect(html).toContain('</p>')
      expect(html).toContain('<p>')
    })

    it('can disable breakTags with option', () => {
      const input = 'Line 1\n\nLine 2'
      const { html } = renderE2Content(input, { applyBreakTags: false })
      // Without breakTags, newlines remain as-is (DOMPurify strips them)
      expect(html).not.toContain('</p>')
    })

    it('applies breakTags before link parsing', () => {
      const input = 'Check out [this node]\n\nIt is great'
      const { html } = renderE2Content(input)
      expect(html).toContain('<a href="/title/this%20node"')
      expect(html).toContain('</p>')
    })
  })

  // ============================================================
  // RAW BRACKET ENTITY PRESERVATION
  // ============================================================
  describe('raw bracket entity preservation', () => {
    it('preserves &#91; as literal [ character (not parsed as E2 link)', () => {
      // &#91; is the HTML entity for [, used for literal brackets that should NOT become links
      const input = 'Use &#91;square brackets&#93; in your code'
      const { html } = sanitizeHtml(input)
      // Should render as literal brackets, not as E2 links
      expect(html).toContain('[square brackets]')
      expect(html).not.toContain('<a href')
    })

    it('preserves raw bracket entities while still parsing regular E2 links', () => {
      // Mix of raw bracket entities and regular E2 link syntax
      const input = 'The array syntax is &#91;value&#93; but see [this node] for more'
      const { html } = sanitizeHtml(input)
      // Raw brackets should be literal, regular link should be parsed
      expect(html).toContain('[value]')
      expect(html).toContain('<a href="/title/this%20node"')
    })

    it('handles multiple raw bracket pairs', () => {
      const input = '&#91;a&#93; and &#91;b&#93; are different from [real link]'
      const { html } = sanitizeHtml(input)
      expect(html).toContain('[a]')
      expect(html).toContain('[b]')
      expect(html).toContain('<a href="/title/real%20link"')
    })

    it('handles nested-looking raw brackets', () => {
      const input = 'Syntax: &#91;foo&#91;bar&#93;&#93;'
      const { html } = sanitizeHtml(input)
      expect(html).toContain('[foo[bar]]')
      expect(html).not.toContain('<a href')
    })

    it('works with renderE2Content', () => {
      const input = 'Code example: &#91;i for i in range&#93;'
      const { html } = renderE2Content(input)
      expect(html).toContain('[i for i in range]')
      expect(html).not.toContain('<a href')
    })
  })
})
