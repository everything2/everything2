import React from 'react';

/**
 * News for Noders - Displays announcements from the News usergroup
 *
 * Shows weblog entries with title, author, date, and content.
 * Supports pagination for viewing older/newer entries.
 */
const NewsForNoders = ({ data, e2 }) => {
  const {
    entries = [],
    has_older = false,
    has_newer = false,
    next_older = 0,
    next_newer = 0,
    error = null
  } = data;

  const currentNodeId = e2?.node_id || data.node_id;

  if (error) {
    return (
      <div style={styles.container}>
        <div style={styles.error}>
          <strong>Error:</strong> {error}
        </div>
      </div>
    );
  }

  if (entries.length === 0) {
    return (
      <div style={styles.container}>
        <p style={styles.empty}>No news entries found.</p>
      </div>
    );
  }

  return (
    <div style={styles.container}>
      <div style={styles.weblog}>
        {entries.map((entry, index) => (
          <div key={entry.node_id || index} style={styles.item}>
            <div style={styles.header}>
              <a
                href={`/node/document/${encodeURIComponent(entry.title)}`}
                style={styles.title}
              >
                {entry.title}
              </a>
              <cite style={styles.byline}>
                by{' '}
                <a
                  href={`/user/${encodeURIComponent(entry.author)}`}
                  style={styles.authorLink}
                >
                  {entry.author}
                </a>
              </cite>
              <span style={styles.date}>
                {formatDate(entry.linkedtime)}
              </span>
            </div>
            <div
              style={styles.content}
              dangerouslySetInnerHTML={{ __html: entry.content }}
            />
          </div>
        ))}
      </div>

      <div style={styles.footer}>
        {Boolean(has_newer || has_older) && (
          <div style={styles.moreLink}>
            {Boolean(has_newer) && (
              <a
                href={`/node/${currentNodeId}?nextweblog=${next_newer}`}
                style={styles.navLink}
              >
                ← newer
              </a>
            )}
            {Boolean(has_newer && has_older) && <span style={styles.separator}> | </span>}
            {Boolean(has_older) && (
              <a
                href={`/node/${currentNodeId}?nextweblog=${next_older}`}
                style={styles.navLink}
              >
                older →
              </a>
            )}
          </div>
        )}
        <p style={styles.faqLink}>
          <a href="/title/Everything+FAQ" style={styles.link}>
            Everything FAQ
          </a>
        </p>
      </div>
    </div>
  );
};

/**
 * Format a MySQL datetime string for display
 */
function formatDate(dateStr) {
  if (!dateStr) return '';

  try {
    // MySQL datetime format: "2025-12-06 00:22:26"
    const date = new Date(dateStr.replace(' ', 'T') + 'Z');
    if (isNaN(date.getTime())) return dateStr;

    const options = {
      weekday: 'short',
      month: 'short',
      day: '2-digit',
      year: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
      second: '2-digit',
      hour12: false
    };

    return date.toLocaleString('en-US', options).replace(',', '');
  } catch (e) {
    return dateStr;
  }
}

const styles = {
  container: {
    maxWidth: '800px',
    margin: '0 auto',
    padding: '10px 20px',
    fontSize: '14px',
    lineHeight: '1.6',
    color: '#111111'
  },
  weblog: {
    marginBottom: '20px'
  },
  item: {
    marginBottom: '24px',
    paddingBottom: '16px'
  },
  header: {
    marginBottom: '10px',
    padding: '8px',
    backgroundColor: '#f8f9f9',
    borderRadius: '4px'
  },
  title: {
    display: 'block',
    fontSize: '16px',
    fontWeight: 'bold',
    color: '#4060b0',
    textDecoration: 'none',
    marginBottom: '4px'
  },
  byline: {
    display: 'block',
    fontSize: '13px',
    color: '#507898',
    fontStyle: 'normal'
  },
  authorLink: {
    color: '#4060b0',
    textDecoration: 'none'
  },
  date: {
    display: 'block',
    fontSize: '12px',
    color: '#888888',
    marginTop: '4px'
  },
  content: {
    padding: '0 8px',
    fontSize: '14px',
    lineHeight: '1.7'
  },
  moreLink: {
    textAlign: 'center',
    padding: '15px 0',
    borderTop: '1px solid #dee2e6',
    marginTop: '10px'
  },
  navLink: {
    color: '#4060b0',
    textDecoration: 'none',
    padding: '5px 10px'
  },
  separator: {
    color: '#888888'
  },
  footer: {
    textAlign: 'center',
    marginTop: '30px',
    paddingTop: '20px',
    borderTop: '1px solid #dee2e6'
  },
  faqLink: {
    margin: 0
  },
  link: {
    color: '#4060b0',
    textDecoration: 'none'
  },
  error: {
    padding: '15px',
    backgroundColor: '#ffebee',
    border: '1px solid #f44336',
    borderRadius: '4px'
  },
  empty: {
    textAlign: 'center',
    color: '#888888',
    fontStyle: 'italic',
    padding: '40px 0'
  }
};

export default NewsForNoders;
