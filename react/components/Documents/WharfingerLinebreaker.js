import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * WharfingerLinebreaker - Text processing utility for adding HTML line breaks
 *
 * Originally created by wharfinger (9/11/00), ported to React
 * Helps users add <br> tags to poetry/lyrics for proper E2 formatting
 *
 * Features:
 * - Adds <br /> tags at line breaks
 * - Optional: Replace indents with <dd> tags
 * - XHTML-compliant output
 * - Client-side JavaScript processing (no server round-trip)
 */

const WharfingerLinebreaker = () => {
  const [text, setText] = useState('')
  const [fixTabs, setFixTabs] = useState(false)

  const addBreakTags = (str, fixTabsOption) => {
    let result = str

    // If fixTabs enabled, replace indenting with <dd> tags
    if (fixTabsOption) {
      result = result.replace(/(\r\n|\r|\n)(\t| )+/g, '$1<dd>')
    }

    // Remove old break tags and trailing whitespace, add new break tags
    // Handles Windows/DOS/UNIX/Mac newline madness
    result = result.replace(/(<br>|<br\/>|<br \/>|\t| )*(\r\n|\r|\n)/g, ' <br />$2')

    return result
  }

  const handleProcess = () => {
    const processed = addBreakTags(text, fixTabs)
    setText(processed)
  }

  return (
    <div className="linebreaker">
      <h1>What's a "linebreaker?"</h1>

      <p>
        This is intended for use with <LinkNode title="lyric" type="e2node" />s and poetry, where you may have dozens of lines and you need a{' '}
        <code>&lt;br&gt;</code> tag at the end of each line.
      </p>

      <p>
        If you're doing ordinary prose, don't use this thing. For that, you should <i>enclose</i> each paragraph in{' '}
        <code>&lt;p&gt; &lt;/p&gt;</code> tags, like so:
      </p>

      <pre style={{ backgroundColor: '#f5f5f5', padding: '10px', border: '1px solid #ddd' }}>
        {`<p>Call me Ishmael. Some years ago -- never mind how long
precisely -- having little or no money in my purse, and
nothing particular to interest me on shore, I thought I
would sail about a little and see the watery part of the
world.</p>

<p>-- Herman Melville</p>`}
      </pre>

      <p>
        The <LinkNode title="E2 Paragraph Tagger" type="superdoc" /> does exactly that, with a few options thrown in.
      </p>

      <p>
        It's permissible to use just the "open paragraph" tag (<code>&lt;p&gt;</code>) at the <i>beginning</i> of <i>each</i>{' '}
        paragraph, but don't leave that out and put a "close paragraph" tag (<code>&lt;/p&gt;</code>) at the end of each paragraph;
        that's broken HTML and it causes formatting problems in some browsers. Note that putting a '/' at the end of the tag is not the
        same thing as putting it at the beginning: At the beginning (as in <code>&lt;/p&gt;</code> or <code>&lt;/i&gt;</code>), it means
        that the tag is a "close" tag; at the end (as in <code>&lt;br /&gt;</code>), it signifies that the tag is an "open" tag which{' '}
        <i>has no</i> matching "close" tag. Most tags, like <code>&lt;p&gt;</code> "contain" things; <code>&lt;br /&gt;</code> is a rare
        exception.
      </p>

      <h1>Here's how it works:</h1>

      <p>
        First paste your writeup into the box, then click the <b>"Add Break Tags"</b> button down below the box. The Linebreaker will
        insert a <code>&lt;br&gt;</code> tag wherever you hit the "return" key in the text. Where the lines wrap around without hitting
        "return", that will be ignored.
      </p>

      <p>
        If you select the <b>"Replace indenting with <code>&lt;dd&gt;</code> tag"</b> option, the Linebreaker will insert a{' '}
        <code>&lt;dd&gt;</code> tag at the beginning of every line which has been indented with one or more spaces or tabs. The{' '}
        <code>&lt;dd&gt;</code> tag will indent the line when you display your writeup.
      </p>

      <dl>
        <dt>Along similar lines:</dt>
        <dd>
          You can E2-proof source code (and reverse the process) with the{' '}
          <LinkNode title="E2 Source Code Formatter" type="superdoc" />.
        </dd>
        <dd>
          <LinkNode title="E2 Paragraph Tagger" type="superdoc" />
        </dd>
        <dd>
          You can also format lists as HTML with the <LinkNode title="E2 List Formatter" type="superdoc" />.
        </dd>
      </dl>

      <div style={{ marginTop: '30px', marginBottom: '30px' }}>
        <textarea
          value={text}
          onChange={(e) => setText(e.target.value)}
          rows={20}
          cols={70}
          style={{
            width: '100%',
            maxWidth: '700px',
            fontFamily: 'monospace',
            padding: '10px',
            border: '1px solid #ccc'
          }}
        />

        <div style={{ marginTop: '10px' }}>
          <button
            onClick={handleProcess}
            style={{
              padding: '8px 16px',
              fontSize: '1em',
              marginRight: '10px',
              cursor: 'pointer'
            }}
          >
            Add Break Tags
          </button>

          <label>
            <input
              type="checkbox"
              checked={fixTabs}
              onChange={(e) => setFixTabs(e.target.checked)}
              style={{ marginRight: '5px' }}
            />
            Replace indenting with <code>&lt;dd&gt;</code> tag
          </label>
        </div>
      </div>
    </div>
  )
}

export default WharfingerLinebreaker
