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
    <div className="rot13-encoder">
      <p className="rot13-encoder__intro">
        Paste text below and click the button to encode or decode using ROT13.
      </p>

      <form onSubmit={(e) => e.preventDefault()}>
        <textarea
          name="rotter"
          rows="15"
          value={text}
          onChange={(e) => setText(e.target.value)}
          className="rot13-encoder__textarea"
        />
        <br />
        <button
          type="button"
          onClick={handleEncode}
          className="rot13-encoder__button"
        >
          ROT13 Encode/Decode
        </button>
      </form>
    </div>
  )
}

export default E2Rot13Encoder
