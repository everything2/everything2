import React, { useState, useEffect } from 'react'

/**
 * E2 Rot13 Encoder/Decoder
 *
 * A simple ROT13 cipher tool that rotates letters by 13 positions.
 * ROT13 is its own inverse (encoding and decoding are the same operation).
 *
 * Features:
 * - Encode/decode text using ROT13 cipher
 * - Pre-loads lastnode writeup text if available
 * - Preserves non-alphabetic characters
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
        // Character is in first half of alphabet
        result += nz.charAt(ca)
      } else {
        const cz = nz.indexOf(ch)
        if (cz >= 0) {
          // Character is in second half of alphabet
          result += am.charAt(cz)
        } else {
          // Non-alphabetic character, keep as is
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
    <div style={{ padding: '20px' }}>
      <h1 style={{ color: '#333333', marginBottom: '12px' }}>E2 Rot13 Encoder</h1>

      <p style={{ marginBottom: '20px', fontSize: '14px', color: '#111111' }}>
        This is the E2 Rot13 Encoder. It also does decoding. You can just paste the stuff
        you want swapped around in the little box and click the buttons. It's really quite
        simple. Enjoy!
      </p>

      <form
        name="myform"
        style={{ marginBottom: '20px' }}
        onSubmit={(e) => e.preventDefault()}
      >
        <textarea
          name="rotter"
          rows="30"
          cols="80"
          value={text}
          onChange={(e) => setText(e.target.value)}
          style={{
            width: '100%',
            maxWidth: '800px',
            padding: '8px',
            fontFamily: 'monospace',
            fontSize: '13px',
            border: '1px solid #d3d3d3',
            borderRadius: '4px'
          }}
        />
        <br />
        <button
          type="button"
          onClick={handleEncode}
          style={{
            marginTop: '12px',
            marginRight: '8px',
            padding: '8px 16px',
            backgroundColor: '#4060b0',
            color: 'white',
            border: '1px solid #38495e',
            borderRadius: '4px',
            cursor: 'pointer',
            fontSize: '14px'
          }}
          onMouseEnter={(e) => e.target.style.backgroundColor = '#507898'}
          onMouseLeave={(e) => e.target.style.backgroundColor = '#4060b0'}
        >
          Rot13 Encode
        </button>
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
          onMouseEnter={(e) => e.target.style.backgroundColor = '#507898'}
          onMouseLeave={(e) => e.target.style.backgroundColor = '#4060b0'}
        >
          Rot13 Decode
        </button>
      </form>

      <div style={{
        marginTop: '80px',
        fontSize: '11px',
        color: '#666',
        textAlign: 'right'
      }}>
        <p>Thanks to mblase for the function update.</p>
      </div>
    </div>
  )
}

export default E2Rot13Encoder
