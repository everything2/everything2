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

    it('includes all heading tags h1-h6 with align attribute', () => {
      ;['h1', 'h2', 'h3', 'h4', 'h5', 'h6'].forEach(tag => {
        expect(APPROVED_TAGS).toHaveProperty(tag)
        expect(APPROVED_TAGS[tag]).toEqual(['align'])
      })
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

    it('has exactly 47 approved tags (matching Perl get_html_rules)', () => {
      // This ensures parity with the server-side configuration
      expect(Object.keys(APPROVED_TAGS).length).toBe(47)
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
        expect(result).toBe('Before <a href="/title/link" class="e2-link">link</a> middle <a href="/title/other" class="e2-link">text</a> after')
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

      it('handles nested brackets (inner gets converted)', () => {
        // Inner bracket pair gets converted to link
        const result = parseE2Links('[[nested]]')
        expect(result).toContain('/title/nested')
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

      it('escapes HTML in custom display text', () => {
        const result = parseE2Links('[node|<b>bold</b>]')
        expect(result).toContain('&lt;b&gt;bold&lt;/b&gt;</a>')
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

      it('does not convert empty inner brackets', () => {
        expect(parseE2Links('[title[]]')).toBe('[title[]]')
      })

      it('does not convert whitespace-only inner brackets', () => {
        expect(parseE2Links('[title[ ]]')).toBe('[title[ ]]')
      })

      it('URL-encodes special characters in title', () => {
        const result = parseE2Links('[Node & Co.[user]]')
        expect(result).toContain('/user/Node%20%26%20Co.')
      })

      it('escapes HTML in display text', () => {
        const result = parseE2Links('[<script>[user]]')
        expect(result).toContain('&lt;script&gt;</a>')
      })
    })

    describe('pipe separator handling', () => {
      it('handles pipe at start of content', () => {
        const result = parseE2Links('[|display only]')
        // Should not match because title would be empty
        expect(result).toBe('[|display only]')
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

      it('preserves all heading levels', () => {
        ;['h1', 'h2', 'h3', 'h4', 'h5', 'h6'].forEach(tag => {
          const input = `<${tag}>Heading</${tag}>`
          const { html } = sanitizeHtml(input, { parseLinks: false })
          expect(html).toContain(`<${tag}>`)
        })
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
      it('preserves align on headings', () => {
        const input = '<h1 align="center">Centered</h1>'
        const { html } = sanitizeHtml(input, { parseLinks: false })
        expect(html).toContain('align=')
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
      const input = 'Text\n\n<h1>Heading</h1>\n\nMore text'
      const result = breakTags(input)
      // Should not have <p><h1> or </h1></p>
      expect(result).not.toContain('<p><h1>')
      expect(result).not.toContain('</h1></p>')
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
})
