/**
 * Tests for text utility functions
 */

import { decodeHtmlEntities } from './textUtils'

describe('textUtils', () => {
  describe('decodeHtmlEntities', () => {
    it('decodes common HTML entities', () => {
      expect(decodeHtmlEntities('&amp;')).toBe('&')
      expect(decodeHtmlEntities('&lt;')).toBe('<')
      expect(decodeHtmlEntities('&gt;')).toBe('>')
      expect(decodeHtmlEntities('&quot;')).toBe('"')
      expect(decodeHtmlEntities('&#39;')).toBe("'")
    })

    it('decodes multiple entities in one string', () => {
      const input = 'Tom &amp; Jerry &lt;love&gt; cheese &quot;very much&quot;'
      const expected = 'Tom & Jerry <love> cheese "very much"'
      expect(decodeHtmlEntities(input)).toBe(expected)
    })

    it('decodes numeric entities', () => {
      expect(decodeHtmlEntities('&#64;')).toBe('@')
      expect(decodeHtmlEntities('&#123;')).toBe('{')
      expect(decodeHtmlEntities('&#125;')).toBe('}')
    })

    it('decodes hexadecimal entities', () => {
      expect(decodeHtmlEntities('&#x40;')).toBe('@')
      expect(decodeHtmlEntities('&#x7B;')).toBe('{')
      expect(decodeHtmlEntities('&#x7D;')).toBe('}')
    })

    it('decodes special characters', () => {
      expect(decodeHtmlEntities('&nbsp;')).toBe('\u00A0')
      expect(decodeHtmlEntities('&copy;')).toBe('©')
      expect(decodeHtmlEntities('&reg;')).toBe('®')
      expect(decodeHtmlEntities('&trade;')).toBe('™')
    })

    it('decodes Unicode entities', () => {
      expect(decodeHtmlEntities('&#8364;')).toBe('€')
      expect(decodeHtmlEntities('&#8592;')).toBe('←')
      expect(decodeHtmlEntities('&#8594;')).toBe('→')
      expect(decodeHtmlEntities('&#9829;')).toBe('♥')
    })

    it('returns string unchanged if no entities', () => {
      const input = 'Hello World'
      expect(decodeHtmlEntities(input)).toBe(input)
    })

    it('handles empty string', () => {
      expect(decodeHtmlEntities('')).toBe('')
    })

    it('handles null input', () => {
      expect(decodeHtmlEntities(null)).toBeNull()
    })

    it('handles undefined input', () => {
      expect(decodeHtmlEntities(undefined)).toBeUndefined()
    })

    it('handles non-string input', () => {
      expect(decodeHtmlEntities(123)).toBe(123)
      expect(decodeHtmlEntities(true)).toBe(true)
      expect(decodeHtmlEntities({})).toEqual({})
    })

    it('handles complex HTML with nested entities', () => {
      const input = '&lt;div class=&quot;test&quot;&gt;Hello &amp; Goodbye&lt;/div&gt;'
      const expected = '<div class="test">Hello & Goodbye</div>'
      expect(decodeHtmlEntities(input)).toBe(expected)
    })

    it('handles malformed entities gracefully', () => {
      // Browser's native parser handles these gracefully
      const input = '&invalid; &amp'
      const result = decodeHtmlEntities(input)
      expect(result).toBeTruthy()
      expect(typeof result).toBe('string')
    })

    it('handles entities at start of string', () => {
      expect(decodeHtmlEntities('&amp;test')).toBe('&test')
    })

    it('handles entities at end of string', () => {
      expect(decodeHtmlEntities('test&amp;')).toBe('test&')
    })

    it('handles consecutive entities', () => {
      expect(decodeHtmlEntities('&amp;&amp;&amp;')).toBe('&&&')
      expect(decodeHtmlEntities('&lt;&gt;&lt;&gt;')).toBe('<><>')
    })

    it('preserves whitespace', () => {
      const input = '  &amp;  &lt;  &gt;  '
      const expected = '  &  <  >  '
      expect(decodeHtmlEntities(input)).toBe(expected)
    })

    it('handles newlines and tabs', () => {
      const input = 'Line 1\n&amp;\nLine 2\t&lt;tab&gt;'
      const expected = 'Line 1\n&\nLine 2\t<tab>'
      expect(decodeHtmlEntities(input)).toBe(expected)
    })

    it('handles very long strings', () => {
      const longString = 'test&amp;'.repeat(1000)
      const expected = 'test&'.repeat(1000)
      expect(decodeHtmlEntities(longString)).toBe(expected)
    })

    it('handles E2-specific content', () => {
      // Test with typical E2 node titles that might have entities
      expect(decodeHtmlEntities('C &amp; C++')).toBe('C & C++')
      expect(decodeHtmlEntities('&lt;HTML&gt; tags')).toBe('<HTML> tags')
      expect(decodeHtmlEntities('Quotes &quot;test&quot;')).toBe('Quotes "test"')
    })

    it('does not execute scripts in entities', () => {
      // Security test - ensure no script execution
      const input = '&lt;script&gt;alert("XSS")&lt;/script&gt;'
      const result = decodeHtmlEntities(input)
      expect(result).toBe('<script>alert("XSS")</script>')
      // Verify it's just a string, not executed code
      expect(typeof result).toBe('string')
    })

    it('handles mixed entity types', () => {
      const input = '&amp; &#64; &#x40; &copy;'
      const expected = '& @ @ ©'
      expect(decodeHtmlEntities(input)).toBe(expected)
    })

    it('handles uppercase and lowercase entity names', () => {
      // Browsers actually decode both uppercase and lowercase
      expect(decodeHtmlEntities('&AMP;')).toBe('&')     // Browser decodes uppercase too
      expect(decodeHtmlEntities('&amp;')).toBe('&')     // And lowercase
    })

    it('handles partial entities', () => {
      // Test strings that look like entities but aren't complete
      const input = '&am test &'
      const result = decodeHtmlEntities(input)
      expect(typeof result).toBe('string')
    })

    it('handles emoji and special Unicode', () => {
      // These should pass through unchanged if already decoded
      const input = 'Hello 👋 World 🌍'
      expect(decodeHtmlEntities(input)).toBe(input)
    })

    it('handles entities in URLs', () => {
      const input = 'http://example.com?foo=bar&amp;baz=qux'
      const expected = 'http://example.com?foo=bar&baz=qux'
      expect(decodeHtmlEntities(input)).toBe(expected)
    })
  })
})
