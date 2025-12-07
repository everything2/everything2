import React, { useState } from 'react';

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
    <div style={styles.container}>
      <p>Go ahead -- one entry per line:</p>

      <form onSubmit={handleProcess} style={styles.form}>
        <div style={styles.optionsGroup}>
          <div style={styles.option}>
            <label style={styles.label}>
              separator:{' '}
              <select
                value={separatorOption}
                onChange={(e) => setSeparatorOption(e.target.value)}
                style={styles.select}
              >
                <option value="0">none (default)</option>
                <option value="1">&lt;br&gt;</option>
                <option value="2">&lt;li&gt; (use in UL or OL)</option>
              </select>
            </label>
          </div>

          <div style={styles.option}>
            <label style={styles.checkboxLabel}>
              <input
                type="checkbox"
                checked={reverseSort}
                onChange={(e) => setReverseSort(e.target.checked)}
                style={styles.checkbox}
              />
              reverse
            </label>

            <label style={styles.checkboxLabel}>
              <input
                type="checkbox"
                checked={ignoreCase}
                onChange={(e) => setIgnoreCase(e.target.checked)}
                style={styles.checkbox}
              />
              ignore case (default yes)
            </label>
          </div>

          <div style={styles.option}>
            <label style={styles.checkboxLabel}>
              <input
                type="checkbox"
                checked={makeLinks}
                onChange={(e) => setMakeLinks(e.target.checked)}
                style={styles.checkbox}
              />
              make everything an E2 link
            </label>
          </div>
        </div>

        <div style={styles.textareaGroup}>
          <textarea
            value={inputText}
            onChange={(e) => setInputText(e.target.value)}
            rows={20}
            cols={60}
            style={styles.textarea}
            placeholder="Enter text here, one entry per line..."
          />
        </div>

        <button type="submit" style={styles.button}>
          Alphabetize
        </button>
      </form>

      {output && (
        <div style={styles.outputSection}>
          <h3 style={styles.outputHeader}>Output:</h3>
          <pre style={styles.output}>{output}</pre>
        </div>
      )}
    </div>
  );
};

const styles = {
  container: {
    maxWidth: '900px',
    margin: '0 auto',
    padding: '20px',
    fontSize: '16px',
    lineHeight: '1.6',
    color: '#111111'
  },
  form: {
    marginBottom: '20px'
  },
  optionsGroup: {
    marginBottom: '15px',
    padding: '15px',
    background: '#f8f9f9',
    border: '1px solid #dee2e6',
    borderRadius: '4px'
  },
  option: {
    marginBottom: '10px'
  },
  label: {
    fontSize: '14px',
    color: '#111111'
  },
  select: {
    padding: '4px 8px',
    fontSize: '14px',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    background: 'white',
    marginLeft: '5px'
  },
  checkboxLabel: {
    fontSize: '14px',
    color: '#111111',
    marginRight: '15px',
    display: 'inline-block'
  },
  checkbox: {
    marginRight: '5px',
    cursor: 'pointer'
  },
  textareaGroup: {
    marginBottom: '15px'
  },
  textarea: {
    width: '100%',
    maxWidth: '100%',
    padding: '10px',
    fontSize: '14px',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    fontFamily: 'monospace',
    lineHeight: '1.4'
  },
  button: {
    padding: '8px 16px',
    background: '#4060b0',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '14px',
    fontWeight: 'bold'
  },
  outputSection: {
    marginTop: '30px',
    padding: '15px',
    background: '#f8f9f9',
    border: '1px solid #dee2e6',
    borderRadius: '4px'
  },
  outputHeader: {
    margin: '0 0 10px 0',
    fontSize: '18px',
    color: '#38495e'
  },
  output: {
    background: 'white',
    padding: '15px',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    fontSize: '14px',
    lineHeight: '1.6',
    overflowX: 'auto',
    whiteSpace: 'pre-wrap',
    wordWrap: 'break-word'
  }
};

export default Alphabetizer;
