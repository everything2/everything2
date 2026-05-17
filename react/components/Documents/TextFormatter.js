import React, { useState, useRef } from 'react'

/**
 * TextFormatter - JavaScript-based text formatting tool for converting plain text to HTML
 *
 * Migrated from document.pm text_formatter() delegation function
 *
 * Provides paragraph formatting, list creation, style markup, and HTML character escaping.
 * This is the "E2 Text Formatter to end all Text Formatters" created by mblase in 2002.
 *
 * Features:
 * - Paragraph and line break insertion
 * - Style markup (*bold*, _italics_, /slashed/)
 * - List formatting (bulleted, numbered)
 * - HTML character escaping
 * - Horizontal rules
 * - Undo/Preview functionality
 */
const TextFormatter = ({ data, user }) => {
  const [text, setText] = useState(
    `Text can be *formatted* in a _variety_ of */styles/*.
Characters like <, >, and & are automatically escaped.

   You can also create indented text
   and lists of items:

1) alpha
2) bravo
3) charlie

* one
* two
* three

-----------
Just above this text is a horizontal line.`
  )
  const [undoText, setUndoText] = useState('')

  // Form options state
  const [breaks, setBreaks] = useState('p')
  const [starred, setStarred] = useState('b')
  const [underlined, setUnderlined] = useState('i')
  const [slashed, setSlashed] = useState('i')
  const [starlist, setStarlist] = useState('ul')
  const [dashlist, setDashlist] = useState('ul')
  const [numberlist, setNumberlist] = useState('ol')
  const [indent, setIndent] = useState('blockquote')
  const [horizrule, setHorizrule] = useState(true)
  const [logicalstyles, setLogicalstyles] = useState(false)
  const [curlyquotes, setCurlyquotes] = useState(true)
  const [brackets, setBrackets] = useState(false)
  const [asciichars, setAsciichars] = useState(true)
  const [striptags, setStriptags] = useState(false)

  const textareaRef = useRef(null)

  // Utility functions
  const stripTagsFunc = (str) => {
    return str.replace(/<[^ ][^>]*>/g, '')
  }

  const fixEndOfLine = (str) => {
    str = str.replace(/\r\n/g, '\n') // windows to unix
    str = str.replace(/\r/g, '\n') // mac to unix
    str = str.replace(/^\n+/, '') // trim extra leading linebreaks
    str = str.replace(/\n+$/, '') // trim extra trailing linebreaks
    return str
  }

  const fixCurlyQuotes = (str) => {
    str = str.replace(/[\u2018\u2019]/g, '"') // single quotes
    str = str.replace(/[\u201C\u201D]/g, "'") // double quotes
    return str
  }

  const encodeAscii = (str) => {
    str = str.replace(/&/g, '&amp;')
    str = str.replace(/</g, '&lt;')
    str = str.replace(/>/g, '&gt;')
    // get other odd ASCII characters
    for (let i = 160; i < 256; i++) {
      const reg = new RegExp(String.fromCharCode(i), 'g')
      str = str.replace(reg, `&#${i};`)
    }
    return str
  }

  const encodeBrackets = (str) => {
    str = str.replace(/\[/g, '&#91;')
    str = str.replace(/\]/g, '&#93;')
    return str
  }

  const addHorizRule = (str) => {
    const reg1 = /(<p>|\n<br \/>)?\n[ \t]*[-_=]{5,}[ \t]*(\n<\/p>|<br \/>\n|\n)?/g
    return str.replace(reg1, '\n<hr />\n')
  }

  const optimizeWhitespace = (str) => {
    str = str.replace(/  +/g, ' ')
    str = str.replace(/\t+/g, ' ')
    str = str.replace(/\n /g, '\n')
    str = str.replace(/\n\n+/g, '\n')
    return str
  }

  const addBr = (str) => {
    str = str.replace(/\n/g, '<br />\n')
    str += '<br />\n'
    return str
  }

  const addPara = (str) => {
    const reg1 = /\n[ \t]*\n+/g
    str = str.replace(reg1, '\n</p>\n<p>\n')
    str = '\n<p>\n' + str + '\n</p>\n'
    return str
  }

  const addGenericList = (match, tag, ltype, str) => {
    if (ltype === 'ignore') return str

    const startitem = '\n  <' + tag + '>'
    const enditem = '</' + tag + '>'
    const listtag = enditem + startitem
    const reg1 = new RegExp('\\n\\s*' + match + '\\s*', 'g')
    str = str.replace(reg1, listtag)
    const reg2 = new RegExp('^\\s*' + match + '\\s*', 'g')
    str = str.replace(reg2, '\n' + listtag)
    str = addListOpenClose(startitem, enditem, ltype, str)
    return str
  }

  const addListOpenClose = (startitem, enditem, ltype, str) => {
    const starttag = '\n<' + ltype + '>'
    const endtag = '\n</' + ltype + '>'
    const listtag = enditem + startitem
    let idx = 0
    while (idx >= 0) {
      // add opening list tag
      let mstr = '\n<p>' + listtag
      idx = str.indexOf(mstr, idx)
      if (idx < 0) {
        mstr = '\n<br />' + listtag
        idx = str.indexOf(mstr, idx)
      }
      if (idx < 0) {
        mstr = '\n' + listtag
        idx = str.indexOf(mstr, idx)
      }
      if (idx >= 0) {
        str = str.substring(0, idx) + starttag + startitem + str.substring(idx + mstr.length)
        idx += starttag.length + listtag.length
      }
      // add closing list tag
      if (idx >= 0) {
        mstr = '\n</p>'
        let temp = str.indexOf(mstr, idx)
        if (temp < 0) {
          mstr = '<br />\n<'
          temp = str.indexOf(mstr, idx) + 6
          if (temp < idx) temp = str.length
          mstr = '' // keep the break tag after the insertion
        }
        if (temp >= 0) {
          str = str.substring(0, temp) + enditem + endtag + str.substring(temp + mstr.length)
          temp += endtag.length
        }
        idx = temp
      }
    }
    return str
  }

  const addStyles = (mark, tag, str) => {
    if (tag === 'ignore') return str

    // Use logical styles if requested
    let actualTag = tag
    if (logicalstyles) {
      if (tag === 'b') actualTag = 'strong'
      else if (tag === 'i') actualTag = 'em'
    }

    // check the first character in the string
    const reg1 = new RegExp('^' + mark + '([^ >' + mark + '][^' + mark + ']*)' + mark, 'g')
    // ignore marks inside HTML tags
    const reg2 = new RegExp('([^<])' + mark + '([^ >' + mark + '][^' + mark + ']*[^ <' + mark + '])' + mark, 'g')

    if (actualTag) {
      str = str.replace(reg1, '<' + actualTag + '>$1</' + actualTag + '>')
      str = str.replace(reg2, '$1<' + actualTag + '>$2</' + actualTag + '>')
    } else {
      str = str.replace(reg1, '$1')
      str = str.replace(reg2, '$1$2')
    }
    return str
  }

  const clearBox = () => {
    setUndoText(text)
    setText('')
  }

  const doFormat = () => {
    let formattedText = text
    setUndoText(text)
    formattedText = fixEndOfLine(formattedText)

    // prepare the text
    if (striptags) formattedText = stripTagsFunc(formattedText)
    if (curlyquotes) formattedText = fixCurlyQuotes(formattedText)
    if (asciichars) formattedText = encodeAscii(formattedText)
    if (brackets) formattedText = encodeBrackets(formattedText)

    // add text styles
    formattedText = addStyles('\\/', slashed, formattedText)
    formattedText = addStyles('\\*', starred, formattedText)
    formattedText = addStyles('_', underlined, formattedText)

    // format linebreaks and horiz. rules
    if (breaks === 'p') formattedText = addPara(formattedText)
    else if (breaks === 'br') formattedText = addBr(formattedText)
    if (horizrule) formattedText = addHorizRule(formattedText)

    // format ordered and unordered lists and indenting
    formattedText = addGenericList('[\\*\\.] ', 'li', starlist, formattedText)
    formattedText = addGenericList('\\-\\-?', 'li', dashlist, formattedText)
    formattedText = addGenericList('\\d+[\\.\\) ]', 'li', numberlist, formattedText)
    formattedText = addGenericList('(\\t+|  +) *', '', indent, formattedText)

    // optimize HTML
    formattedText = formattedText.replace(/<\/?>/g, '') // delete "empty tags"
    formattedText = optimizeWhitespace(formattedText)
    formattedText = formattedText.replace(/^\n+/, '') // trim leading linebreaks
    formattedText = formattedText.replace(/\n+$/, '\n') // trim trailing linebreaks

    setText(formattedText)
    if (textareaRef.current) {
      textareaRef.current.select()
    }
  }

  const undoFormat = () => {
    const temp = text
    setText(undoText)
    setUndoText(temp)
  }

  const isDeveloper = user?.developerAccess || user?.is_admin

  // Radio option helper for style conversion
  const StyleOptions = ({ name, value, onChange }) => (
    <div className="text-formatter__option-choices">
      {[
        { value: 'b', label: 'bold' },
        { value: 'i', label: 'italics' },
        { value: 'u', label: 'underline' },
        { value: '', label: 'plain text' },
        { value: 'ignore', label: "don't convert to HTML" }
      ].map((option) => (
        <label key={option.value} className="text-formatter__radio-inline">
          <input
            type="radio"
            name={name}
            value={option.value}
            checked={value === option.value}
            onChange={() => onChange(option.value)}
          />{' '}
          {option.label}
        </label>
      ))}
    </div>
  )

  // Radio option helper for list conversion
  const ListOptions = ({ name, value, onChange }) => (
    <div className="text-formatter__option-choices">
      <label className="text-formatter__radio-inline">
        <input
          type="radio"
          name={name}
          value="ul"
          checked={value === 'ul'}
          onChange={() => onChange('ul')}
        />{' '}
        bulleted lists
      </label>
      <label className="text-formatter__radio-inline">
        <input
          type="radio"
          name={name}
          value="ol"
          checked={value === 'ol'}
          onChange={() => onChange('ol')}
        />{' '}
        numbered lists
      </label>
      <label>
        <input
          type="radio"
          name={name}
          value="ignore"
          checked={value === 'ignore'}
          onChange={() => onChange('ignore')}
        />{' '}
        don't convert to lists
      </label>
    </div>
  )

  return (
    <div className="text-formatter">
      {isDeveloper && (
        <p className="text-formatter__dev-note">
          Note: this is from [Magical Text Formatter]
        </p>
      )}

      <p className="text-formatter__date">
        Last updated Thursday March 21, 2002
      </p>

      <p>
        This is intended to be the E2 Text Formatter to end all Text Formatters. It will insert
        paragraphs. It will insert line breaks. It will escape special characters. It will format
        lists of items. And it will add styles, interpret horizontal rules, and indent using the
        markup tags of your choice, all thanks to the power of regular expressions.
      </p>

      <p>
        The "undo" feature is there because I always wanted it. I hope it's useful. Several
        configurable options are below the form buttons; their default settings are all what seem to
        be used most often.
      </p>

      <p className="text-formatter__hint">
        If you have any problems, comments, or whatnot, send a /msg to mblase.
      </p>

      <hr />

      <div className="text-formatter__main">
        <p>
          Enter the text to format below.{' '}
          <a
            href="#"
            onClick={(e) => {
              e.preventDefault()
              clearBox()
            }}
            className="text-formatter__clear-link"
          >
            Clear the box
          </a>
        </p>

        <textarea
          ref={textareaRef}
          value={text}
          onChange={(e) => setText(e.target.value)}
          cols="60"
          rows="16"
          className="text-formatter__textarea"
        />

        <div className="text-formatter__buttons">
          <button onClick={doFormat} className="text-formatter__btn text-formatter__btn--primary">
            Format Text
          </button>
          <button onClick={undoFormat} className="text-formatter__btn text-formatter__btn--secondary">
            Undo
          </button>
        </div>

        <hr className="text-formatter__divider" />

        <div className="text-formatter__options">
          <div className="text-formatter__option-group">
            <span className="text-formatter__option-label">Format new lines using:</span>
            <div className="text-formatter__option-choices">
              <label className="text-formatter__radio-block">
                <input
                  type="radio"
                  name="breaks"
                  value="p"
                  checked={breaks === 'p'}
                  onChange={() => setBreaks('p')}
                />{' '}
                <tt>&lt;p&gt;...&lt;/p&gt;</tt> paragraph tags at empty lines
              </label>
              <label className="text-formatter__radio-block">
                <input
                  type="radio"
                  name="breaks"
                  value="br"
                  checked={breaks === 'br'}
                  onChange={() => setBreaks('br')}
                />{' '}
                <tt>&lt;br /&gt;</tt> line break after each new line
              </label>
            </div>
          </div>

          <div className="text-formatter__option-group">
            <span className="text-formatter__option-label">Convert *starred text* to:</span>
            <StyleOptions name="starred" value={starred} onChange={setStarred} />
          </div>

          <div className="text-formatter__option-group">
            <span className="text-formatter__option-label">Convert _underscored text_ to:</span>
            <StyleOptions name="underlined" value={underlined} onChange={setUnderlined} />
          </div>

          <div className="text-formatter__option-group">
            <span className="text-formatter__option-label">Convert /slashed text/ to:</span>
            <StyleOptions name="slashed" value={slashed} onChange={setSlashed} />
          </div>

          <div className="text-formatter__option-group">
            <span className="text-formatter__option-label">Convert lines beginning with * or . to:</span>
            <ListOptions name="starlist" value={starlist} onChange={setStarlist} />
          </div>

          <div className="text-formatter__option-group">
            <span className="text-formatter__option-label">Convert lines beginning with - or -- to:</span>
            <ListOptions name="dashlist" value={dashlist} onChange={setDashlist} />
          </div>

          <div className="text-formatter__option-group">
            <span className="text-formatter__option-label">Convert lines beginning with 1.2.3. or 1)2)3) to:</span>
            <ListOptions name="numberlist" value={numberlist} onChange={setNumberlist} />
          </div>

          <div className="text-formatter__option-group">
            <span className="text-formatter__option-label">Convert other indented text to:</span>
            <div className="text-formatter__option-choices">
              <label className="text-formatter__radio-inline">
                <input
                  type="radio"
                  name="indent"
                  value="blockquote"
                  checked={indent === 'blockquote'}
                  onChange={() => setIndent('blockquote')}
                />{' '}
                blockquotes
              </label>
              <label className="text-formatter__radio-inline">
                <input
                  type="radio"
                  name="indent"
                  value="pre"
                  checked={indent === 'pre'}
                  onChange={() => setIndent('pre')}
                />{' '}
                <tt>preformatted text</tt>
              </label>
              <label>
                <input
                  type="radio"
                  name="indent"
                  value="ignore"
                  checked={indent === 'ignore'}
                  onChange={() => setIndent('ignore')}
                />{' '}
                don't indent
              </label>
            </div>
          </div>

          <div className="text-formatter__checkboxes">
            <label className="text-formatter__checkbox">
              <input
                type="checkbox"
                checked={horizrule}
                onChange={(e) => setHorizrule(e.target.checked)}
              />{' '}
              Convert rows of hyphens, equals or underscores into <tt>&lt;hr /&gt;</tt> tags
            </label>
            <label className="text-formatter__checkbox">
              <input
                type="checkbox"
                checked={logicalstyles}
                onChange={(e) => setLogicalstyles(e.target.checked)}
              />{' '}
              Use <strong>&lt;strong&gt;</strong> and <em>&lt;em&gt;</em> instead of{' '}
              <b>&lt;b&gt;</b> and <i>&lt;i&gt;</i>
            </label>
            <label className="text-formatter__checkbox">
              <input
                type="checkbox"
                checked={curlyquotes}
                onChange={(e) => setCurlyquotes(e.target.checked)}
              />{' '}
              Convert all "curly quotes" to standard quotes
            </label>
            <label className="text-formatter__checkbox">
              <input
                type="checkbox"
                checked={brackets}
                onChange={(e) => setBrackets(e.target.checked)}
              />{' '}
              Convert &#91;brackets&#93; to HTML symbols
            </label>
            <label className="text-formatter__checkbox">
              <input
                type="checkbox"
                checked={asciichars}
                onChange={(e) => setAsciichars(e.target.checked)}
              />{' '}
              Convert other ASCII characters to HTML symbols
            </label>
            <label className="text-formatter__checkbox">
              <input
                type="checkbox"
                checked={striptags}
                onChange={(e) => setStriptags(e.target.checked)}
              />{' '}
              Strip existing HTML tags before formatting
            </label>
          </div>
        </div>
      </div>
    </div>
  )
}

export default TextFormatter
