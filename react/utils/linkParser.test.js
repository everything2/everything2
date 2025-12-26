import {
  escapeHtml,
  stripHtml,
  parseLinkContent,
  parseLinks,
  parseLinksToHtml,
  LINK_TYPE
} from './linkParser'

describe('linkParser', () => {
  describe('escapeHtml', () => {
    it('escapes ampersands', () => {
      expect(escapeHtml('Tom & Jerry')).toBe('Tom &amp; Jerry')
    })

    it('escapes angle brackets', () => {
      expect(escapeHtml('<script>')).toBe('&lt;script&gt;')
    })

    it('escapes quotes', () => {
      expect(escapeHtml('He said "hello"')).toBe('He said &quot;hello&quot;')
    })

    it('escapes single quotes', () => {
      expect(escapeHtml("It's fine")).toBe("It&#039;s fine")
    })

    it('handles empty string', () => {
      expect(escapeHtml('')).toBe('')
    })

    it('handles null/undefined', () => {
      expect(escapeHtml(null)).toBe('')
      expect(escapeHtml(undefined)).toBe('')
    })
  })

  describe('stripHtml', () => {
    it('removes simple tags', () => {
      expect(stripHtml('<b>bold</b>')).toBe('bold')
    })

    it('removes tags with attributes', () => {
      expect(stripHtml('<a href="test">link</a>')).toBe('link')
    })

    it('removes nested tags', () => {
      expect(stripHtml('<div><span>text</span></div>')).toBe('text')
    })

    it('handles empty string', () => {
      expect(stripHtml('')).toBe('')
    })
  })

  describe('parseLinkContent - External links', () => {
    it('parses simple https URL', () => {
      const result = parseLinkContent('https://reddit.com', '[https://reddit.com]')
      expect(result).toEqual({
        type: LINK_TYPE.EXTERNAL,
        url: 'https://reddit.com',
        display: 'https://reddit.com',
        href: 'https://reddit.com'
      })
    })

    it('parses simple http URL', () => {
      const result = parseLinkContent('http://example.com', '[http://example.com]')
      expect(result).toEqual({
        type: LINK_TYPE.EXTERNAL,
        url: 'http://example.com',
        display: 'http://example.com',
        href: 'http://example.com'
      })
    })

    it('parses URL with custom display text', () => {
      const result = parseLinkContent('https://reddit.com|Reddit', '[https://reddit.com|Reddit]')
      expect(result).toEqual({
        type: LINK_TYPE.EXTERNAL,
        url: 'https://reddit.com',
        display: 'Reddit',
        href: 'https://reddit.com'
      })
    })

    it('parses URL with empty pipe (uses [link])', () => {
      const result = parseLinkContent('https://reddit.com|', '[https://reddit.com|]')
      expect(result).toEqual({
        type: LINK_TYPE.EXTERNAL,
        url: 'https://reddit.com',
        display: '[link]',
        href: 'https://reddit.com'
      })
    })

    it('parses URL with query string', () => {
      const result = parseLinkContent('https://example.com/path?query=1&foo=bar', '[https://example.com/path?query=1&foo=bar]')
      expect(result.type).toBe(LINK_TYPE.EXTERNAL)
      expect(result.url).toBe('https://example.com/path?query=1&foo=bar')
    })

    it('parses URL with fragment', () => {
      const result = parseLinkContent('https://example.com/page#section', '[https://example.com/page#section]')
      expect(result.type).toBe(LINK_TYPE.EXTERNAL)
      expect(result.url).toBe('https://example.com/page#section')
    })

    it('handles whitespace around URL', () => {
      const result = parseLinkContent('  https://reddit.com  ', '[  https://reddit.com  ]')
      expect(result.url).toBe('https://reddit.com')
    })
  })

  describe('parseLinkContent - Internal links', () => {
    it('parses simple node title', () => {
      const result = parseLinkContent('node title', '[node title]')
      expect(result).toEqual({
        type: LINK_TYPE.INTERNAL,
        title: 'node title',
        display: 'node title',
        href: '/title/node%20title'
      })
    })

    it('parses pipelink with display text', () => {
      const result = parseLinkContent('actual title|shown text', '[actual title|shown text]')
      expect(result).toEqual({
        type: LINK_TYPE.INTERNAL,
        title: 'actual title',
        display: 'shown text',
        href: '/title/actual%20title'
      })
    })

    it('strips HTML from title for URL', () => {
      const result = parseLinkContent('<b>formatted</b> title', '[<b>formatted</b> title]')
      expect(result.title).toBe('formatted title')
      expect(result.href).toBe('/title/formatted%20title')
    })

    it('handles special characters in title', () => {
      const result = parseLinkContent('Tom & Jerry', '[Tom & Jerry]')
      expect(result.href).toBe('/title/Tom%20%26%20Jerry')
    })
  })

  describe('parseLinkContent - Typed links', () => {
    it('parses user type link', () => {
      const result = parseLinkContent('jaybonci[user]', '[jaybonci[user]]')
      expect(result).toEqual({
        type: LINK_TYPE.TYPED,
        title: 'jaybonci',
        nodetype: 'user',
        display: 'jaybonci',
        href: '/user/jaybonci'
      })
    })

    it('parses usergroup type link', () => {
      const result = parseLinkContent('gods[usergroup]', '[gods[usergroup]]')
      expect(result).toEqual({
        type: LINK_TYPE.TYPED,
        title: 'gods',
        nodetype: 'usergroup',
        display: 'gods',
        href: '/usergroup/gods'
      })
    })

    it('handles spaces before inner bracket', () => {
      const result = parseLinkContent('username [user]', '[username [user]]')
      expect(result.nodetype).toBe('user')
      expect(result.title).toBe('username')
    })

    it('lowercases nodetype', () => {
      const result = parseLinkContent('test[User]', '[test[User]]')
      expect(result.nodetype).toBe('user')
    })
  })

  describe('parseLinkContent - Writeup by author', () => {
    it('parses [title[by author]] format', () => {
      const result = parseLinkContent('My Writeup[by someuser]', '[My Writeup[by someuser]]')
      expect(result).toEqual({
        type: LINK_TYPE.USER_WRITEUP,
        title: 'My Writeup',
        author: 'someuser',
        display: 'My Writeup',
        href: '/user/someuser/writeups/My%20Writeup'
      })
    })

    it('handles "by" with different casing', () => {
      const result = parseLinkContent('Title[BY Author]', '[Title[BY Author]]')
      expect(result.type).toBe(LINK_TYPE.USER_WRITEUP)
      expect(result.author).toBe('Author')
    })

    it('parses [title[by author]|display] format', () => {
      const result = parseLinkContent('Long Title[by writer]|short', '[Long Title[by writer]|short]')
      expect(result.display).toBe('short')
      expect(result.title).toBe('Long Title')
    })
  })

  describe('parseLinkContent - Comment links', () => {
    it('parses [title[123]] format (comment ID)', () => {
      const result = parseLinkContent('Discussion[42]', '[Discussion[42]]')
      expect(result).toEqual({
        type: LINK_TYPE.COMMENT,
        title: 'Discussion',
        commentId: '42',
        display: 'Discussion',
        href: '/title/Discussion',
        anchor: 'debatecomment_42'
      })
    })
  })

  describe('parseLinkContent - Edge cases', () => {
    it('returns null for empty content', () => {
      expect(parseLinkContent('', '[]')).toBeNull()
    })

    it('returns null for whitespace-only content', () => {
      expect(parseLinkContent('   ', '[   ]')).toBeNull()
    })

    it('handles content with only HTML tags', () => {
      const result = parseLinkContent('<br><hr>', '[<br><hr>]')
      expect(result).toBeNull()
    })
  })

  describe('parseLinks', () => {
    it('returns empty array for empty string', () => {
      expect(parseLinks('')).toEqual([])
    })

    it('parses plain text without links', () => {
      const result = parseLinks('Just plain text')
      expect(result).toEqual([{ type: 'text', content: 'Just plain text' }])
    })

    it('parses single link', () => {
      const result = parseLinks('[node]')
      expect(result.length).toBe(1)
      expect(result[0].type).toBe(LINK_TYPE.INTERNAL)
      expect(result[0].title).toBe('node')
    })

    it('parses text with link in middle', () => {
      const result = parseLinks('Before [link] after')
      expect(result.length).toBe(3)
      expect(result[0]).toEqual({ type: 'text', content: 'Before ' })
      expect(result[1].type).toBe(LINK_TYPE.INTERNAL)
      expect(result[2]).toEqual({ type: 'text', content: ' after' })
    })

    it('parses multiple links', () => {
      const result = parseLinks('[one] and [two]')
      expect(result.length).toBe(3)
      expect(result[0].title).toBe('one')
      expect(result[1]).toEqual({ type: 'text', content: ' and ' })
      expect(result[2].title).toBe('two')
    })

    it('parses mixed external and internal links', () => {
      const result = parseLinks('Visit [https://reddit.com] or [home page]')
      expect(result.length).toBe(4)
      expect(result[1].type).toBe(LINK_TYPE.EXTERNAL)
      expect(result[3].type).toBe(LINK_TYPE.INTERNAL)
    })
  })

  describe('parseLinksToHtml', () => {
    it('converts simple internal link to HTML', () => {
      const result = parseLinksToHtml('[node title]')
      expect(result).toBe('<a href="/title/node%20title" class="e2-link">node title</a>')
    })

    it('converts external link to HTML', () => {
      const result = parseLinksToHtml('[https://reddit.com]')
      expect(result).toBe('<a href="https://reddit.com" rel="nofollow" class="externalLink" target="_blank">https://reddit.com</a>')
    })

    it('converts external link with display text', () => {
      const result = parseLinksToHtml('[https://reddit.com|Reddit]')
      expect(result).toBe('<a href="https://reddit.com" rel="nofollow" class="externalLink" target="_blank">Reddit</a>')
    })

    it('converts external link with empty pipe to [link]', () => {
      const result = parseLinksToHtml('[https://reddit.com|]')
      expect(result).toBe('<a href="https://reddit.com" rel="nofollow" class="externalLink" target="_blank">[link]</a>')
    })

    it('converts typed link to HTML', () => {
      const result = parseLinksToHtml('[username[user]]')
      expect(result).toBe('<a href="/user/username" class="e2-link">username</a>')
    })

    it('converts pipelink to HTML', () => {
      const result = parseLinksToHtml('[target|display text]')
      expect(result).toBe('<a href="/title/target" class="e2-link">display text</a>')
    })

    it('converts user writeup link to HTML', () => {
      const result = parseLinksToHtml('[My Post[by author]]')
      expect(result).toBe('<a href="/user/author/writeups/My%20Post" class="e2-link">My Post</a>')
    })

    it('includes anchor for comment links', () => {
      const result = parseLinksToHtml('[Discussion[42]]')
      expect(result).toBe('<a href="/title/Discussion#debatecomment_42" class="e2-link">Discussion</a>')
    })

    it('escapes HTML in display text', () => {
      // HTML tags are stripped from the title and display
      // This matches Perl behavior where tags inside links are removed
      const result = parseLinksToHtml('[<script>alert]')
      expect(result).toBe('<a href="/title/alert" class="e2-link">alert</a>')
    })

    it('escapes ampersands in display text', () => {
      const result = parseLinksToHtml('[Tom & Jerry]')
      expect(result).toBe('<a href="/title/Tom%20%26%20Jerry" class="e2-link">Tom &amp; Jerry</a>')
    })

    it('preserves text around links', () => {
      const result = parseLinksToHtml('Check out [site] for more')
      expect(result).toBe('Check out <a href="/title/site" class="e2-link">site</a> for more')
    })

    it('handles multiple links in text', () => {
      const result = parseLinksToHtml('[one], [two], and [three]')
      expect(result).toContain('one</a>')
      expect(result).toContain('two</a>')
      expect(result).toContain('three</a>')
    })
  })

  describe('parseLinksToHtml - Regression tests', () => {
    it('does not convert [link] text inside external link display', () => {
      // When external link uses [link] as display, that shouldn't get parsed again
      const result = parseLinksToHtml('[https://reddit.com|]')
      expect(result).toBe('<a href="https://reddit.com" rel="nofollow" class="externalLink" target="_blank">[link]</a>')
      // Should NOT contain nested links
      expect(result).not.toContain('"/title/')
    })

    it('handles consecutive links without text between', () => {
      const result = parseLinksToHtml('[one][two]')
      expect(result).toContain('/title/one')
      expect(result).toContain('/title/two')
    })

    it('does not parse URLs without brackets', () => {
      const result = parseLinksToHtml('Visit https://reddit.com for more')
      expect(result).toBe('Visit https://reddit.com for more')
    })

    it('handles complex URL with special characters', () => {
      const result = parseLinksToHtml('[https://example.com/search?q=hello+world&lang=en]')
      expect(result).toContain('href="https://example.com/search?q=hello+world&lang=en"')
    })

    it('preserves unmatched brackets', () => {
      const result = parseLinksToHtml('Array[0] = value')
      // This should be treated as text since [0] alone isn't a valid link pattern
      expect(result).toBe('Array<a href="/title/0" class="e2-link">0</a> = value')
    })
  })
})
