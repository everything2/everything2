import React, { useState, useMemo } from 'react';

/**
 * E2WordCounter - Text word counting tool
 * Styles in CSS: .word-counter__*
 */
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
    <div className="word-counter">
      <div className="word-counter__description">
        <h4 className="word-counter__heading">About This Tool</h4>
        <p>
          Paste or type your text below to get a live word count and other statistics.
          HTML tags are stripped for counting purposes. Em-dashes (--) and other
          punctuation are treated as word separators.
        </p>
      </div>

      <div className="word-counter__textarea-container">
        <textarea
          className="word-counter__textarea"
          value={text}
          onChange={(e) => setText(e.target.value)}
          placeholder="Paste or type your text here..."
          rows={15}
        />

        <div className="word-counter__stats-bar">
          <span className="word-counter__main-stat">
            <strong>{stats.wordCount.toLocaleString()}</strong> word{stats.wordCount !== 1 ? 's' : ''}
          </span>
          <span className="word-counter__secondary-stat">
            {stats.charCount.toLocaleString()} characters
          </span>
          {text.length > 0 && (
            <button onClick={handleClear} className="word-counter__clear-button">
              Clear
            </button>
          )}
        </div>
      </div>

      {text.length > 0 && (
        <div className="word-counter__detailed-stats">
          <h4 className="word-counter__stats-heading">Detailed Statistics</h4>
          <div className="word-counter__stats-grid">
            <div className="word-counter__stat-box">
              <div className="word-counter__stat-value">{stats.wordCount.toLocaleString()}</div>
              <div className="word-counter__stat-label">Words</div>
            </div>
            <div className="word-counter__stat-box">
              <div className="word-counter__stat-value">{stats.charCount.toLocaleString()}</div>
              <div className="word-counter__stat-label">Characters</div>
            </div>
            <div className="word-counter__stat-box">
              <div className="word-counter__stat-value">{stats.charCountNoSpaces.toLocaleString()}</div>
              <div className="word-counter__stat-label">Chars (no spaces)</div>
            </div>
            <div className="word-counter__stat-box">
              <div className="word-counter__stat-value">{stats.sentenceCount.toLocaleString()}</div>
              <div className="word-counter__stat-label">Sentences</div>
            </div>
            <div className="word-counter__stat-box">
              <div className="word-counter__stat-value">{stats.paragraphCount.toLocaleString()}</div>
              <div className="word-counter__stat-label">Paragraphs</div>
            </div>
            <div className="word-counter__stat-box">
              <div className="word-counter__stat-value">{stats.lineCount.toLocaleString()}</div>
              <div className="word-counter__stat-label">Lines</div>
            </div>
            <div className="word-counter__stat-box">
              <div className="word-counter__stat-value">{stats.avgWordLength}</div>
              <div className="word-counter__stat-label">Avg Word Length</div>
            </div>
            <div className="word-counter__stat-box">
              <div className="word-counter__stat-value">{stats.readingTimeMinutes} min</div>
              <div className="word-counter__stat-label">Reading Time</div>
            </div>
          </div>
        </div>
      )}

      <div className="word-counter__notes">
        <h4 className="word-counter__notes-heading">Notes</h4>
        <ul className="word-counter__notes-list">
          <li>HTML tags are stripped and don't count toward word totals</li>
          <li>Em-dashes (--) separate words: "foo--bar" counts as 2 words</li>
          <li>Reading time assumes 200 words per minute</li>
          <li>Sentence count is approximate (based on . ! ? punctuation)</li>
        </ul>
      </div>
    </div>
  );
};

export default E2WordCounter;
