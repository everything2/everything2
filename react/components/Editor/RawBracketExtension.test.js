import { convertRawBracketsToEntities, convertEntitiesToRawBrackets } from './RawBracketExtension'

describe('convertRawBracketsToEntities', () => {
  it('converts span-wrapped left/right brackets to &#91;/&#93;', () => {
    const html = '<p>before <span data-raw-bracket="true" data-bracket-type="left">[</span>x<span data-raw-bracket="true" data-bracket-type="right">]</span> after</p>'
    expect(convertRawBracketsToEntities(html)).toBe('<p>before &#91;x&#93; after</p>')
  })

  it('converts span-wrapped lt/gt to &#60;/&#62;', () => {
    const html = '<p>vector<span data-raw-bracket="true" data-bracket-type="lt">&lt;</span>int<span data-raw-bracket="true" data-bracket-type="gt">&gt;</span> v</p>'
    expect(convertRawBracketsToEntities(html)).toBe('<p>vector&#60;int&#62; v</p>')
  })

  it('handles attribute order variations', () => {
    const html = '<span data-bracket-type="lt" data-raw-bracket="true">&lt;</span>'
    expect(convertRawBracketsToEntities(html)).toBe('&#60;')
  })

  it('handles legacy spans without data-raw-bracket', () => {
    const html = '<span data-bracket-type="gt">&gt;</span>'
    expect(convertRawBracketsToEntities(html)).toBe('&#62;')
  })

  it('folds naturally-typed &lt; / &gt; to &#60; / &#62;', () => {
    expect(convertRawBracketsToEntities('a &lt; b &amp;&amp; c &gt; d'))
      .toBe('a &#60; b &amp;&amp; c &#62; d')
  })

  it('passes null/empty through unchanged', () => {
    expect(convertRawBracketsToEntities('')).toBe('')
    expect(convertRawBracketsToEntities(null)).toBe(null)
  })
})

describe('convertEntitiesToRawBrackets', () => {
  it('wraps &#91; and &#93; in atom-node spans for the editor', () => {
    expect(convertEntitiesToRawBrackets('&#91;x&#93;'))
      .toBe('<span data-raw-bracket="true" data-bracket-type="left">[</span>x<span data-raw-bracket="true" data-bracket-type="right">]</span>')
  })

  it('wraps &#60; and &#62; in atom-node spans using &lt;/&gt; inner', () => {
    // Inner content is the entity form so the browser's HTML parser sees text,
    // not an attempted tag — restoring to a literal `<` would re-trigger the
    // strip bug at TipTap's parseHTML step.
    expect(convertEntitiesToRawBrackets('vector&#60;int&#62;'))
      .toBe('vector<span data-raw-bracket="true" data-bracket-type="lt">&lt;</span>int<span data-raw-bracket="true" data-bracket-type="gt">&gt;</span>')
  })

  it('round-trips with convertRawBracketsToEntities', () => {
    const stored = 'C&#43;&#43; vector&#60;int&#62; with brackets &#91;x&#93;'
    // Note: we don't escape `+`, only the four characters this extension owns
    const expectedRoundTrip = 'C&#43;&#43; vector&#60;int&#62; with brackets &#91;x&#93;'
    const inEditor = convertEntitiesToRawBrackets(stored)
    const out = convertRawBracketsToEntities(inEditor)
    expect(out).toBe(expectedRoundTrip)
  })
})
