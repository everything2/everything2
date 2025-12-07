import React, { useState, useMemo } from 'react';

const E2WordCounter = ({ data, e2 }) => {
  const [text, setText] = useState('');

  // Calculate statistics
  const stats = useMemo(() => {
    // Strip HTML tags (replace with space to preserve word boundaries)
    const textWithoutHtml = text.replace(/<[^>]*>/g, ' ');

    // Normalize whitespace and trim
    const normalizedText = textWithoutHtml.replace(/\s+/g, ' ').trim();

    // Count words - split on whitespace, filter empty strings
    // Also handle common punctuation that should separate words (em-dashes, etc.)
    const wordsText = normalizedText
      .replace(/--+/g, ' ')  // em-dashes
      .replace(/—/g, ' ')    // unicode em-dash
      .replace(/–/g, ' ')    // unicode en-dash
      .replace(/\.\.\./g, ' ') // ellipsis
      .replace(/…/g, ' ');   // unicode ellipsis

    const words = wordsText.split(/\s+/).filter(word => word.length > 0);
    const wordCount = words.length;

    // Character counts
    const charCount = text.length;
    const charCountNoSpaces = text.replace(/\s/g, '').length;
    const charCountNoHtml = textWithoutHtml.replace(/\s/g, '').length;

    // Line and paragraph counts
    const lines = text.split('\n');
    const lineCount = lines.length;
    const paragraphCount = text.split(/\n\s*\n/).filter(p => p.trim().length > 0).length || (text.trim() ? 1 : 0);

    // Sentence count (rough estimate)
    const sentenceCount = (normalizedText.match(/[.!?]+(?:\s|$)/g) || []).length || (normalizedText.length > 0 ? 1 : 0);

    // Average word length
    const avgWordLength = wordCount > 0
      ? (words.join('').replace(/[^a-zA-Z0-9]/g, '').length / wordCount).toFixed(1)
      : 0;

    // Reading time (average 200 words per minute)
    const readingTimeMinutes = Math.ceil(wordCount / 200);

    return {
      wordCount,
      charCount,
      charCountNoSpaces,
      charCountNoHtml,
      lineCount,
      paragraphCount,
      sentenceCount,
      avgWordLength,
      readingTimeMinutes
    };
  }, [text]);

  const handleClear = () => {
    setText('');
  };

  return (
    <div style={styles.container}>
      <div style={styles.description}>
        <h4 style={styles.heading}>About This Tool</h4>
        <p>
          Paste or type your text below to get a live word count and other statistics.
          HTML tags are stripped for counting purposes. Em-dashes (--) and other
          punctuation are treated as word separators.
        </p>
      </div>

      <div style={styles.textareaContainer}>
        <textarea
          style={styles.textarea}
          value={text}
          onChange={(e) => setText(e.target.value)}
          placeholder="Paste or type your text here..."
          rows={15}
        />

        <div style={styles.statsBar}>
          <span style={styles.mainStat}>
            <strong>{stats.wordCount.toLocaleString()}</strong> word{stats.wordCount !== 1 ? 's' : ''}
          </span>
          <span style={styles.secondaryStat}>
            {stats.charCount.toLocaleString()} characters
          </span>
          {text.length > 0 && (
            <button onClick={handleClear} style={styles.clearButton}>
              Clear
            </button>
          )}
        </div>
      </div>

      {text.length > 0 && (
        <div style={styles.detailedStats}>
          <h4 style={styles.statsHeading}>Detailed Statistics</h4>
          <div style={styles.statsGrid}>
            <div style={styles.statBox}>
              <div style={styles.statValue}>{stats.wordCount.toLocaleString()}</div>
              <div style={styles.statLabel}>Words</div>
            </div>
            <div style={styles.statBox}>
              <div style={styles.statValue}>{stats.charCount.toLocaleString()}</div>
              <div style={styles.statLabel}>Characters</div>
            </div>
            <div style={styles.statBox}>
              <div style={styles.statValue}>{stats.charCountNoSpaces.toLocaleString()}</div>
              <div style={styles.statLabel}>Chars (no spaces)</div>
            </div>
            <div style={styles.statBox}>
              <div style={styles.statValue}>{stats.sentenceCount.toLocaleString()}</div>
              <div style={styles.statLabel}>Sentences</div>
            </div>
            <div style={styles.statBox}>
              <div style={styles.statValue}>{stats.paragraphCount.toLocaleString()}</div>
              <div style={styles.statLabel}>Paragraphs</div>
            </div>
            <div style={styles.statBox}>
              <div style={styles.statValue}>{stats.lineCount.toLocaleString()}</div>
              <div style={styles.statLabel}>Lines</div>
            </div>
            <div style={styles.statBox}>
              <div style={styles.statValue}>{stats.avgWordLength}</div>
              <div style={styles.statLabel}>Avg Word Length</div>
            </div>
            <div style={styles.statBox}>
              <div style={styles.statValue}>{stats.readingTimeMinutes} min</div>
              <div style={styles.statLabel}>Reading Time</div>
            </div>
          </div>
        </div>
      )}

      <div style={styles.notes}>
        <h4 style={styles.notesHeading}>Notes</h4>
        <ul style={styles.notesList}>
          <li>HTML tags are stripped and don't count toward word totals</li>
          <li>Em-dashes (--) separate words: "foo--bar" counts as 2 words</li>
          <li>Reading time assumes 200 words per minute</li>
          <li>Sentence count is approximate (based on . ! ? punctuation)</li>
        </ul>
      </div>
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
  description: {
    marginBottom: '20px',
    padding: '15px',
    background: '#f8f9f9',
    border: '1px solid #dee2e6',
    borderRadius: '4px'
  },
  heading: {
    margin: '0 0 10px 0',
    fontSize: '18px',
    color: '#38495e'
  },
  textareaContainer: {
    marginBottom: '20px'
  },
  textarea: {
    width: '100%',
    padding: '15px',
    fontSize: '16px',
    fontFamily: 'inherit',
    border: '2px solid #dee2e6',
    borderRadius: '4px 4px 0 0',
    resize: 'vertical',
    minHeight: '200px',
    boxSizing: 'border-box',
    lineHeight: '1.6'
  },
  statsBar: {
    display: 'flex',
    alignItems: 'center',
    gap: '20px',
    padding: '12px 15px',
    background: '#38495e',
    borderRadius: '0 0 4px 4px',
    color: 'white'
  },
  mainStat: {
    fontSize: '18px'
  },
  secondaryStat: {
    fontSize: '14px',
    opacity: 0.8
  },
  clearButton: {
    marginLeft: 'auto',
    padding: '6px 12px',
    background: 'transparent',
    color: 'white',
    border: '1px solid rgba(255,255,255,0.5)',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '14px'
  },
  detailedStats: {
    marginBottom: '20px',
    padding: '20px',
    background: '#ffffff',
    border: '1px solid #dee2e6',
    borderRadius: '4px'
  },
  statsHeading: {
    margin: '0 0 15px 0',
    fontSize: '16px',
    color: '#38495e'
  },
  statsGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(4, 1fr)',
    gap: '15px'
  },
  statBox: {
    padding: '15px',
    background: '#f8f9f9',
    borderRadius: '4px',
    textAlign: 'center'
  },
  statValue: {
    fontSize: '24px',
    fontWeight: 'bold',
    color: '#4060b0',
    marginBottom: '5px'
  },
  statLabel: {
    fontSize: '12px',
    color: '#507898',
    textTransform: 'uppercase'
  },
  notes: {
    padding: '15px',
    background: '#f8f9f9',
    border: '1px solid #dee2e6',
    borderRadius: '4px'
  },
  notesHeading: {
    margin: '0 0 10px 0',
    fontSize: '14px',
    color: '#507898'
  },
  notesList: {
    margin: 0,
    paddingLeft: '20px',
    fontSize: '14px',
    color: '#507898'
  }
};

export default E2WordCounter;
