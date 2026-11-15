import React, { useState } from 'react';

const ESCAPES = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '[': '&#91;', ']': '&#93;' };
const UNESCAPES = { amp: '&', lt: '<', gt: '>', '#91': '[', '#93': ']' };

export default function E2SourceCodeFormatter() {
  const [code, setCode] = useState('');

  const fixBrackets = (str) => str.replace(/[&<>[\]]/g, (ch) => ESCAPES[ch]);

  // One pass, so &amp;lt; deformats to the literal text &lt; rather than to <.
  const restoreBrackets = (str) => str.replace(/&(amp|lt|gt|#91|#93);/g, (match, name) => UNESCAPES[name]);

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
    <div className="source-formatter">
      <p className="source-formatter__intro">
        You have fallen into the loving arms of the E2 Source Code Formatter.
        Just paste your source code into the box and click the <strong>"Reformat"</strong> button,
        and all your dreams will come true. If you don't know (or don't care) what source code is,
        you won't find this thing useful at all.
      </p>

      <p className="source-formatter__intro">
        The <strong>"Reformat"</strong> button replaces angle brackets, square brackets, and
        ampersands with appropriate HTML character entities. <strong>"DEformat"</strong> changes
        them back again.
      </p>

      <p className="source-formatter__intro">
        Because users' screen resolutions vary, we strongly urge you to keep your code &lt;= 80
        columns in width so that it doesn't mess with E2's page formatting. If the lines are far
        too wide, a god may feel compelled to fix the thing -- and most of our gods are not
        programmers. To that end, we also strongly encourage you to use spaces instead of tabs:
        Most browsers display tabs as eight spaces, which increases the line width for no good
        reason since you probably only want four-space tabs anyway. Even if you don't, you should.
        Don't start me on about where the braces go.
      </p>

      <p className="source-formatter__intro">
        These operations are performed on the entire string, so you'll want to paste in only the
        actual source code part of your writeup. You'll need to supply your own{' '}
        <code>&lt;pre&gt;</code> tags as well. I fussed around with making it{' '}
        <code>&lt;pre&gt;</code>-aware, but that got painful.
      </p>

      <dl className="source-formatter__links">
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
        className="source-formatter__form"
      >
        <textarea
          name="edit"
          value={code}
          onChange={(e) => setCode(e.target.value)}
          className="source-formatter__textarea"
        />

        <div className="source-formatter__buttons">
          <button
            type="button"
            onClick={handleReformat}
            className="source-formatter__btn source-formatter__btn--primary"
          >
            Reformat
          </button>
          <button
            type="button"
            onClick={handleDeformat}
            className="source-formatter__btn source-formatter__btn--secondary"
          >
            DEformat
          </button>
          <button
            type="button"
            onClick={handleClear}
            className="source-formatter__btn source-formatter__btn--muted"
          >
            Clear
          </button>
        </div>
      </form>

      <hr className="source-formatter__hr" />
    </div>
  );
}
