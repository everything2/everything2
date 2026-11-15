import { Editor } from '@tiptap/core'
import { getE2EditorExtensions } from './useE2Editor'

// Paste-path coverage for the real E2 editor schema (#4603). Other editor tests mock
// getE2EditorExtensions() away, so nothing exercised the schema the editor actually runs.
//
// prosemirror-view < 1.42.3 rebuilt the "slice context" nodes described by a clipboard
// `data-pm-slice` attribute with whatever attributes the pasted HTML claimed, without validating
// them, which allowed XSS when attacker-supplied HTML was pasted (GHSA-c8x8-7fp4-3x9w). These
// tests paste hostile clipboard HTML through ProseMirror's real paste pipeline (view.pasteHTML)
// and assert nothing executable reaches the editor DOM or the HTML the editor would save.

// jsdom has no ClipboardEvent, and EditorView.pasteHTML() constructs one when no event is passed.
if (typeof global.ClipboardEvent === 'undefined') {
  global.ClipboardEvent = class ClipboardEvent extends Event {
    constructor(type, init = {}) { super(type, init); this.clipboardData = init.clipboardData || null }
  }
}

const HOSTILE = [
  '" onmouseover="alert(1)',
  'javascript:alert(1)',
  '<img src=x onerror=alert(1)>',
  'x" autofocus onfocus="alert(1)',
]

const makeEditor = () => new Editor({ extensions: getE2EditorExtensions(), content: '<p>start</p>' })

const executableBits = (root) => {
  const found = []
  root.querySelectorAll('*').forEach((el) => {
    if (['SCRIPT', 'IFRAME', 'OBJECT', 'EMBED'].includes(el.tagName)) found.push(`<${el.tagName.toLowerCase()}>`)
    for (const { name, value } of [...el.attributes]) {
      if (/^on/i.test(name)) found.push(`${el.tagName.toLowerCase()}[${name}]`)
      if (/^\s*javascript:/i.test(value)) found.push(`${el.tagName.toLowerCase()}[${name}=javascript:]`)
    }
  })
  return found
}

const savedBits = (editor) => {
  const div = document.createElement('div')
  div.innerHTML = editor.getHTML()
  return executableBits(div)
}

describe('E2 editor paste handling (real schema)', () => {
  let editor
  afterEach(() => editor && editor.destroy())

  it('builds the real schema (guards against this test silently testing nothing)', () => {
    editor = makeEditor()
    const nodes = Object.keys(editor.schema.nodes)
    expect(nodes).toEqual(expect.arrayContaining(['doc', 'paragraph', 'text', 'table', 'tableCell']))
  })

  it('pastes ordinary HTML normally', () => {
    editor = makeEditor()
    editor.view.pasteHTML('<p>hello <strong>world</strong></p>')
    expect(editor.getHTML()).toMatch(/hello/)
    expect(editor.getHTML()).toMatch(/<strong>world<\/strong>/)
  })

  it('drops inline event handlers and script from pasted HTML', () => {
    editor = makeEditor()
    editor.view.pasteHTML('<p onclick="alert(1)">a<img src=x onerror="alert(1)"><script>alert(1)</script></p>')
    expect(executableBits(editor.view.dom)).toEqual([])
    expect(savedBits(editor)).toEqual([])
  })

  it('does not trust attributes injected through a hostile data-pm-slice context', () => {
    editor = makeEditor()
    const probed = []
    let landed = 0
    let rejected = 0
    for (const [name, type] of Object.entries(editor.schema.nodes)) {
      const attrNames = Object.keys(type.spec.attrs || {})
      if (!attrNames.length || type.hasRequiredAttrs() || name === 'doc' || name === 'text') continue
      for (const payload of HOSTILE) {
        const attrs = Object.fromEntries(attrNames.map((a) => [a, payload]))
        const context = JSON.stringify([name, attrs]).replace(/"/g, '&quot;')
        editor.commands.setContent('<p>start</p>')
        try {
          editor.view.pasteHTML(`<p data-pm-slice="1 1 ${context}">pasted</p>`)
        } catch (e) {
          // ProseMirror rejecting an invalid context by throwing is an acceptable outcome, but a
          // harness error (missing DOM API etc.) must not be mistaken for that.
          if (e instanceof ReferenceError) throw e
          rejected += 1
        }
        if (/pasted/.test(editor.getHTML())) landed += 1
        expect({ node: name, payload, dom: executableBits(editor.view.dom) }).toEqual({ node: name, payload, dom: [] })
        expect({ node: name, payload, saved: savedBits(editor) }).toEqual({ node: name, payload, saved: [] })
      }
      probed.push(name)
    }
    // Make sure the probe actually covered attribute-bearing nodes in our schema, and that hostile
    // pastes really went through the paste pipeline (a swallowed harness error once made this
    // test pass while testing nothing).
    expect(probed.length).toBeGreaterThan(0)
    expect(landed).toBeGreaterThan(0)
  })
})
