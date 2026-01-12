import React, { useState, useEffect } from 'react'

/**
 * E2 Rot13 Encoder/Decoder
 *
 * A simple ROT13 cipher tool that rotates letters by 13 positions.
 * ROT13 is its own inverse (encoding and decoding are the same operation).
 */
const E2Rot13Encoder = ({ data }) => {
  const { lastNodeText = '' } = data || {}
  const [text, setText] = useState(lastNodeText)

  // Update text if lastNodeText changes (when visiting from a writeup)
  useEffect(() => {
    if (lastNodeText) {
      setText(lastNodeText)
    }
  }, [lastNodeText])

  // ROT13 transformation function
  const rot13 = (str) => {
    const am = 'abcdefghijklmABCDEFGHIJKLM'
    const nz = 'nopqrstuvwxyzNOPQRSTUVWXYZ'
    let result = ''

    for (let i = 0; i < str.length; i++) {
      const ch = str.charAt(i)
      const ca = am.indexOf(ch)

      if (ca >= 0) {
        result += nz.charAt(ca)
      } else {
        const cz = nz.indexOf(ch)
        if (cz >= 0) {
          result += am.charAt(cz)
        } else {
          result += ch
        }
      }
    }

    return result
  }

  const handleEncode = () => {
    setText(rot13(text))
  }

  return (
    <div>
      <p style={{ marginBottom: '16px', fontSize: '14px' }}>
        Paste text below and click the button to encode or decode using ROT13.
      </p>

      <form onSubmit={(e) => e.preventDefault()}>
        <textarea
          name="rotter"
          rows="15"
          value={text}
          onChange={(e) => setText(e.target.value)}
          style={{
            width: '100%',
            maxWidth: '800px',
            padding: '8px',
            fontFamily: 'monospace',
            fontSize: '13px',
            border: '1px solid #d3d3d3',
            borderRadius: '4px',
            boxSizing: 'border-box'
          }}
        />
        <br />
        <button
          type="button"
          onClick={handleEncode}
          style={{
            marginTop: '12px',
            padding: '8px 16px',
            backgroundColor: '#4060b0',
            color: 'white',
            border: '1px solid #38495e',
            borderRadius: '4px',
            cursor: 'pointer',
            fontSize: '14px'
          }}
        >
          ROT13 Encode/Decode
        </button>
      </form>
    </div>
  )
}

export default E2Rot13Encoder
