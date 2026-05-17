import React, { useState } from 'react';

/**
 * Alphabetizer - Text alphabetizing tool
 * Styles in CSS: .alphabetizer__*
 */
const Alphabetizer = ({ data }) => {
  const {
    separator = '0',
    sort_order = false,
    ignore_case = true,
    format_links = false
  } = data;

  const [inputText, setInputText] = useState('');
  const [separatorOption, setSeparatorOption] = useState(separator);
  const [reverseSort, setReverseSort] = useState(sort_order);
  const [ignoreCase, setIgnoreCase] = useState(ignore_case);
  const [makeLinks, setMakeLinks] = useState(format_links);
  const [output, setOutput] = useState('');

  const alphabetize = () => {
    if (!inputText.trim()) {
      setOutput('');
      return;
    }

    // Split into lines and trim whitespace
    let entries = inputText.split('\n').map(line => line.trim()).filter(line => line.length > 0);

    // Move articles (A, An, The) to end for sorting
    entries = entries.map(entry => {
      let sortKey = entry;
      sortKey = sortKey.replace(/^(An?) (.*)$/i, '$2, $1');
      sortKey = sortKey.replace(/^(The) (.*)$/i, '$2, $1');
      return { original: entry, sortKey };
    });

    // Sort entries
    if (ignoreCase) {
      entries.sort((a, b) => a.sortKey.toLowerCase().localeCompare(b.sortKey.toLowerCase()));
    } else {
      entries.sort((a, b) => a.sortKey.localeCompare(b.sortKey));
    }

    // Reverse if requested
    if (reverseSort) {
      entries.reverse();
    }

    // Restore articles to beginning
    entries = entries.map(({ sortKey }) => {
      let restored = sortKey;
      restored = restored.replace(/^(.*), (An?)$/i, '$2 $1');
      restored = restored.replace(/^(.*), (The)$/i, '$2 $1');
      return restored;
    });

    // Format as links if requested
    if (makeLinks) {
      entries = entries.map(entry => `[${entry}]`);
    }

    // Apply separator formatting
    let formatted;
    if (separatorOption === '1') {
      // <br> separator
      formatted = entries.map(entry => `${entry}<br>`).join('\n');
    } else if (separatorOption === '2') {
      // <li> separator
      formatted = entries.map(entry => `<li>${entry}</li>`).join('\n');
    } else {
      // No separator
      formatted = entries.join('\n');
    }

    setOutput(formatted);
  };

  const handleProcess = (e) => {
    e.preventDefault();
    alphabetize();
  };

  return (
    <div className="alphabetizer">
      <p>Go ahead -- one entry per line:</p>

      <form onSubmit={handleProcess} className="alphabetizer__form">
        <div className="alphabetizer__options-group">
          <div className="alphabetizer__option">
            <label className="alphabetizer__label">
              separator:{' '}
              <select
                value={separatorOption}
                onChange={(e) => setSeparatorOption(e.target.value)}
                className="alphabetizer__select"
              >
                <option value="0">none (default)</option>
                <option value="1">&lt;br&gt;</option>
                <option value="2">&lt;li&gt; (use in UL or OL)</option>
              </select>
            </label>
          </div>

          <div className="alphabetizer__option">
            <label className="alphabetizer__checkbox-label">
              <input
                type="checkbox"
                checked={reverseSort}
                onChange={(e) => setReverseSort(e.target.checked)}
                className="alphabetizer__checkbox"
              />
              reverse
            </label>

            <label className="alphabetizer__checkbox-label">
              <input
                type="checkbox"
                checked={ignoreCase}
                onChange={(e) => setIgnoreCase(e.target.checked)}
                className="alphabetizer__checkbox"
              />
              ignore case (default yes)
            </label>
          </div>

          <div className="alphabetizer__option">
            <label className="alphabetizer__checkbox-label">
              <input
                type="checkbox"
                checked={makeLinks}
                onChange={(e) => setMakeLinks(e.target.checked)}
                className="alphabetizer__checkbox"
              />
              make everything an E2 link
            </label>
          </div>
        </div>

        <div className="alphabetizer__textarea-group">
          <textarea
            value={inputText}
            onChange={(e) => setInputText(e.target.value)}
            rows={20}
            cols={60}
            className="alphabetizer__textarea"
            placeholder="Enter text here, one entry per line..."
          />
        </div>

        <button type="submit" className="alphabetizer__button">
          Alphabetize
        </button>
      </form>

      {output && (
        <div className="alphabetizer__output-section">
          <h3 className="alphabetizer__output-header">Output:</h3>
          <pre className="alphabetizer__output">{output}</pre>
        </div>
      )}
    </div>
  );
};

export default Alphabetizer;
