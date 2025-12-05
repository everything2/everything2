import React, { useState } from 'react';

export default function E2SourceCodeFormatter() {
  const [code, setCode] = useState('');

  const fixBrackets = (str) => {
    let result = str;
    result = result.replace(/&/g, '&amp;');
    result = result.replace(/</g, '&lt;');
    result = result.replace(/>/g, '&gt;');
    result = result.replace(/\[/g, '&#91;');
    result = result.replace(/\]/g, '&#93;');
    return result;
  };

  const restoreBrackets = (str) => {
    let result = str;
    result = result.replace(/&lt;/g, '<');
    result = result.replace(/&gt;/g, '>');
    result = result.replace(/&amp;/g, '&');
    result = result.replace(/&#91;/g, '[');
    result = result.replace(/&#93;/g, ']');
    return result;
  };

  const handleReformat = () => {
    setCode(fixBrackets(code));
  };

  const handleDeformat = () => {
    setCode(restoreBrackets(code));
  };

  const handleClear = () => {
    setCode('');
  };

  return (
    <div style={{ padding: '20px', fontFamily: 'Arial, sans-serif' }}>
      <p style={{ textAlign: 'justify' }}>
        You have fallen into the loving arms of the E2 Source Code Formatter.
        Just paste your source code into the box and click the <strong>"Reformat"</strong> button,
        and all your dreams will come true. If you don't know (or don't care) what source code is,
        you won't find this thing useful at all.
      </p>

      <p style={{ textAlign: 'justify' }}>
        The <strong>"Reformat"</strong> button replaces angle brackets, square brackets, and
        ampersands with appropriate HTML character entities. <strong>"DEformat"</strong> changes
        them back again.
      </p>

      <p style={{ textAlign: 'justify' }}>
        Because users' screen resolutions vary, we strongly urge you to keep your code &lt;= 80
        columns in width so that it doesn't mess with E2's page formatting. If the lines are far
        too wide, a god may feel compelled to fix the thing -- and most of our gods are not
        programmers. To that end, we also strongly encourage you to use spaces instead of tabs:
        Most browsers display tabs as eight spaces, which increases the line width for no good
        reason since you probably only want four-space tabs anyway. Even if you don't, you should.
        Don't start me on about where the braces go.
      </p>

      <p style={{ textAlign: 'justify' }}>
        These operations are performed on the entire string, so you'll want to paste in only the
        actual source code part of your writeup. You'll need to supply your own{' '}
        <code>&lt;pre&gt;</code> tags as well. I fussed around with making it{' '}
        <code>&lt;pre&gt;</code>-aware, but that got painful.
      </p>

      <dl style={{ marginBottom: '20px' }}>
        <dt><strong>Other E2 Formatting Utilities:</strong></dt>
        <dd>
          <strong>
            <a href="/title/Wharfinger%27s+Linebreaker">Wharfinger's Linebreaker</a>:
          </strong>{' '}
          For formatting poetry and lyrics.
        </dd>
      </dl>

      <form
        name="codefixer"
        onSubmit={(e) => e.preventDefault()}
        style={{ marginTop: '20px' }}
      >
        <textarea
          name="edit"
          value={code}
          onChange={(e) => setCode(e.target.value)}
          style={{
            width: '100%',
            maxWidth: '800px',
            height: '400px',
            fontFamily: 'monospace',
            fontSize: '14px',
            padding: '10px',
            border: '1px solid #ccc',
            borderRadius: '4px'
          }}
        />

        <div style={{ marginTop: '10px' }}>
          <button
            type="button"
            onClick={handleReformat}
            style={{
              padding: '8px 16px',
              marginRight: '10px',
              backgroundColor: '#4060b0',
              color: 'white',
              border: 'none',
              borderRadius: '4px',
              cursor: 'pointer'
            }}
          >
            Reformat
          </button>
          <button
            type="button"
            onClick={handleDeformat}
            style={{
              padding: '8px 16px',
              marginRight: '10px',
              backgroundColor: '#507898',
              color: 'white',
              border: 'none',
              borderRadius: '4px',
              cursor: 'pointer'
            }}
          >
            DEformat
          </button>
          <button
            type="button"
            onClick={handleClear}
            style={{
              padding: '8px 16px',
              backgroundColor: '#666',
              color: 'white',
              border: 'none',
              borderRadius: '4px',
              cursor: 'pointer'
            }}
          >
            Clear
          </button>
        </div>
      </form>

      <hr style={{ marginTop: '30px' }} />
    </div>
  );
}
