import { Editor } from '@tiptap/core'
import { getE2EditorExtensions } from './useE2Editor'
import { convertToE2Syntax } from './E2LinkExtension'
import { convertRawBracketsToEntities, convertEntitiesToRawBrackets } from './RawBracketExtension'
import { normalizeEditorHtml } from './E2HtmlSanitizer'

// Round-trip fidelity for the real E2 editor schema (#4598).
//
// Each case runs stored writeup HTML through the same load path the editors use
// (normalizeEditorHtml -> convertEntitiesToRawBrackets -> TipTap) and the same save path
// (getHTML -> convertToE2Syntax -> convertRawBracketsToEntities), then pins the result.
// The expected values were captured on TipTap v2 before the v3 upgrade, so any change here
// is a behaviour change in what the editor saves, not just a refactor. Some pinned outputs
// are known quirks (e.g. the leading empty <p> for a <div>) — change them deliberately.
//
// Intended differences from v2, accepted in the v3 upgrade:
// - default colspan="1" / rowspan="1" on cells and type="1" on <ol> are no longer written;
// - table cell alignment is kept (as align=) instead of being dropped.

const load = (html) => convertEntitiesToRawBrackets(normalizeEditorHtml(html))
const save = (editor) => convertRawBracketsToEntities(convertToE2Syntax(editor.getHTML()))

const CASES = [
  ["plain paragraphs",
    "<p>One</p><p>Two</p>",
    "<p>One</p><p>Two</p>"],
  ["plain text with blank lines (breakTags)",
    "First para\n\nSecond para",
    "<p>First para</p><p>Second para</p>"],
  ["inline marks",
    "<p><strong>b</strong> <b>b2</b> <em>i</em> <i>i2</i> <u>u</u> <s>s</s> <strike>st</strike> <del>d</del> <code>c</code></p>",
    "<p><strong>b</strong> <strong>b2</strong> <em>i</em> <em>i2</em> <u>u</u> <s>s</s> <s>st</s> <s>d</s> <code>c</code></p>"],
  ["tt is not in the schema",
    "<p><tt>mono</tt></p>",
    "<p>mono</p>"],
  ["sub and sup",
    "<p>H<sub>2</sub>O and E=mc<sup>2</sup></p>",
    "<p>H<sub>2</sub>O and E=mc<sup>2</sup></p>"],
  ["headings",
    "<h1>h1</h1><h2>h2</h2><h3>h3</h3><h4>h4</h4><h5>h5</h5><h6>h6</h6>",
    "<h1>h1</h1><h2>h2</h2><h3>h3</h3><h4>h4</h4><h5>h5</h5><h6>h6</h6>"],
  ["align attribute",
    "<p align=\"center\">c</p><p align=\"right\">r</p><h2 align=\"center\">hc</h2><p align=\"left\">l</p>",
    "<p align=\"center\">c</p><p align=\"right\">r</p><h2 align=\"center\">hc</h2><p>l</p>"],
  ["style text-align is ignored",
    "<p style=\"text-align: center\">styled</p>",
    "<p>styled</p>"],
  ["lists",
    "<ul><li>a</li><li>b<ol><li>b1</li></ol></li></ul><ol><li>one</li></ol>",
    "<ul><li><p>a</p></li><li><p>b</p><ol><li><p>b1</p></li></ol></li></ul><ol><li><p>one</p></li></ol>"],
  ["blockquote",
    "<blockquote><p>quoted</p></blockquote><blockquote>bare</blockquote>",
    "<blockquote><p>quoted</p></blockquote><blockquote><p>bare</p></blockquote>"],
  ["pre",
    "<pre>line 1\n  indented\nline 3</pre>",
    "<pre><code>line 1\n  indented\nline 3</code></pre>"],
  ["hr and br",
    "<p>a<br>b</p><hr><p>c</p>",
    "<p>a<br>b</p><hr><p>c</p>"],
  ["table",
    "<table><tr><th>H1</th><th>H2</th></tr><tr><td>a</td><td>b</td></tr></table>",
    "<table style=\"min-width: 50px;\"><colgroup><col style=\"min-width: 25px;\"><col style=\"min-width: 25px;\"></colgroup><tbody><tr><th><p>H1</p></th><th><p>H2</p></th></tr><tr><td><p>a</p></td><td><p>b</p></td></tr></tbody></table>"],
  ["table with attributes",
    "<table border=\"1\" cellpadding=\"3\"><tr><td colspan=\"2\">wide</td></tr><tr><td>a</td><td>b</td></tr></table>",
    "<table style=\"min-width: 50px;\"><colgroup><col style=\"min-width: 25px;\"><col style=\"min-width: 25px;\"></colgroup><tbody><tr><td colspan=\"2\"><p>wide</p></td></tr><tr><td><p>a</p></td><td><p>b</p></td></tr></tbody></table>"],
  ["document ending in a table",
    "<p>before</p><table><tr><td>last</td></tr></table>",
    "<p>before</p><table style=\"min-width: 25px;\"><colgroup><col style=\"min-width: 25px;\"></colgroup><tbody><tr><td><p>last</p></td></tr></tbody></table>"],
  ["document ending in a heading",
    "<p>before</p><h2>last</h2>",
    "<p>before</p><h2>last</h2>"],
  ["document ending in a list",
    "<p>before</p><ul><li>last</li></ul>",
    "<p>before</p><ul><li><p>last</p></li></ul>"],
  ["table cell alignment is kept as align=",
    "<table><tr><th align=\"center\">H</th><td align=\"right\">r</td><td style=\"text-align: left\">l</td><td align=\"justify\">j</td></tr></table>",
    "<table style=\"min-width: 100px;\"><colgroup><col style=\"min-width: 25px;\"><col style=\"min-width: 25px;\"><col style=\"min-width: 25px;\"><col style=\"min-width: 25px;\"></colgroup><tbody><tr><th align=\"center\"><p>H</p></th><td align=\"right\"><p>r</p></td><td align=\"left\"><p>l</p></td><td><p>j</p></td></tr></tbody></table>"],
  ["ordered list numbering",
    "<ol type=\"1\"><li>one</li></ol><ol type=\"a\"><li>a</li></ol><ol start=\"3\"><li>three</li></ol>",
    "<ol><li><p>one</p></li></ol><ol type=\"a\"><li><p>a</p></li></ol><ol start=\"3\"><li><p>three</p></li></ol>"],
  ["E2 bracket links stay as text",
    "<p>See [Everything2] and [some node|this text].</p>",
    "<p>See [Everything2] and [some node|this text].</p>"],
  ["e2link element becomes bracket syntax",
    "<p><e2link title=\"Foo\">bar</e2link> and <e2link title=\"Same\">Same</e2link></p>",
    "<p>[Foo|bar] and [Same]</p>"],
  ["internal anchor becomes bracket syntax",
    "<p><a href=\"/title/Some%20Node\">display</a> <a href=\"/node/123\">num</a></p>",
    "<p>[Some Node|display] [123|num]</p>"],
  ["external anchor",
    "<p><a href=\"https://example.com/x\">ext</a></p>",
    "<p>[https://example.com/x|ext]</p>"],
  ["literal bracket entities",
    "<p>&#91;not a link&#93;</p>",
    "<p>&#91;not a link&#93;</p>"],
  ["literal angle entities",
    "<p>&#60;tag&#62; and &lt;typed&gt;</p>",
    "<p>&#60;tag&#62; and &#60;typed&#62;</p>"],
  ["ampersand",
    "<p>Tom &amp; Jerry &amp;amp;</p>",
    "<p>Tom &amp; Jerry &amp;amp;</p>"],
  ["non-ASCII",
    "<p>café \u2014 “quotes” ★ 日本語</p>",
    "<p>café \u2014 “quotes” ★ 日本語</p>"],
  ["unknown tags are dropped",
    "<p><span class=\"x\">span</span> <font color=\"red\">font</font> <big>big</big> <small>small</small></p>",
    "<p>span font big small</p>"],
  ["div content",
    "<div>in a div</div><center>centered</center>",
    "<p></p><p>in a div</p><p>centered</p>"],
  ["dl lists",
    "<dl><dt>term</dt><dd>definition</dd></dl>",
    "<p>term</p><p>definition</p>"],
  ["mixed block and text",
    "<p>Hello</p>\n\nHello",
    "<p>Hello</p><p>Hello</p>"],
  ["empty",
    "",
    "<p></p>"],
]

describe('E2 editor HTML round trip (real schema)', () => {
  it.each(CASES)('%s', (_name, input, expected) => {
    const editor = new Editor({ extensions: getE2EditorExtensions(), content: load(input) })
    try {
      expect(save(editor)).toBe(expected)
    } finally {
      editor.destroy()
    }
  })

  it.each(CASES)('%s (loaded via setContent)', (_name, input, expected) => {
    const editor = new Editor({ extensions: getE2EditorExtensions(), content: '' })
    try {
      editor.commands.setContent(load(input))
      expect(save(editor)).toBe(expected)
    } finally {
      editor.destroy()
    }
  })
})
