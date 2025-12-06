import React from 'react';
import LinkNode from '../LinkNode';

/**
 * Everything Data Pages - Directory of XML/JSON API endpoints
 *
 * Displays available data feeds for client developers:
 * - Fullpage endpoints (interactive data interfaces)
 * - Ticker endpoints (XML/Atom/RSS feeds)
 */
const EverythingDataPages = ({ data }) => {
  const { fullpages = [], tickers = [] } = data;

  return (
    <div style={styles.container}>
      {/* Header */}
      <div style={styles.header}>
        <h1 style={styles.title}>Everything Data Pages</h1>
        <p style={styles.subtitle}>
          XML and JSON API endpoints for client developers
        </p>
      </div>

      {/* Developer Notice */}
      <div style={styles.notice}>
        <h3 style={styles.noticeTitle}>Note to Client Developers</h3>
        <p style={styles.noticeText}>
          The following are Everything Data Pages that provide server-side data in parseable formats.
          Please be respectful of server resources:
        </p>
        <ul style={styles.noticeList}>
          <li>
            <strong>New Nodes XML Ticker</strong> and <strong>User Search XML Ticker</strong>:
            Poll no more frequently than <strong>every 5 minutes</strong> (these are expensive operations)
          </li>
          <li>
            All other endpoints: Poll no more frequently than <strong>every 30 seconds</strong>
          </li>
          <li>
            You may offer a "refresh" button for manual updates, but avoid automated polling by inactive users
          </li>
        </ul>
        <p style={styles.noticeText}>
          <strong>RDF Feed:</strong>{' '}
          <a href="/headlines.rdf" style={styles.link}>
            https://everything2.com/headlines.rdf
          </a>{' '}
          provides Cool Nodes ("Cool User Picks!")
        </p>
      </div>

      {/* Fullpage Endpoints */}
      <div style={styles.section}>
        <h2 style={styles.sectionTitle}>
          Fullpage Endpoints
          <span style={styles.badge}>{fullpages.length}</span>
        </h2>
        <p style={styles.sectionDesc}>
          Interactive data interfaces (nodetype: <code style={styles.code}>fullpage</code>)
        </p>

        {fullpages.length > 0 ? (
          <div style={styles.tableWrapper}>
            <table style={styles.table}>
              <thead>
                <tr>
                  <th style={{ ...styles.th, textAlign: 'left' }}>Endpoint</th>
                  <th style={{ ...styles.th, textAlign: 'center' }}>Node ID</th>
                  <th style={{ ...styles.th, textAlign: 'left' }}>URL</th>
                </tr>
              </thead>
              <tbody>
                {fullpages.map((page, index) => (
                  <tr key={page.node_id} style={index % 2 === 0 ? styles.evenRow : styles.oddRow}>
                    <td style={styles.td}>
                      <LinkNode type="fullpage" title={page.title} />
                    </td>
                    <td style={{ ...styles.td, textAlign: 'center', fontFamily: 'monospace', color: '#507898' }}>
                      {page.node_id}
                    </td>
                    <td style={styles.td}>
                      <code style={styles.urlCode}>
                        /title/{encodeURIComponent(page.title.replace(/ /g, '+'))}
                      </code>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <p style={styles.empty}>No fullpage endpoints found.</p>
        )}
      </div>

      {/* Ticker Endpoints */}
      <div style={styles.section}>
        <h2 style={styles.sectionTitle}>
          Ticker Endpoints
          <span style={styles.badge}>{tickers.length}</span>
        </h2>
        <p style={styles.sectionDesc}>
          Second-generation XML/Atom/RSS feeds with unified structure (nodetype: <code style={styles.code}>ticker</code>)
        </p>

        {tickers.length > 0 ? (
          <div style={styles.tableWrapper}>
            <table style={styles.table}>
              <thead>
                <tr>
                  <th style={{ ...styles.th, textAlign: 'left' }}>Endpoint</th>
                  <th style={{ ...styles.th, textAlign: 'center' }}>Node ID</th>
                  <th style={{ ...styles.th, textAlign: 'left' }}>URL</th>
                </tr>
              </thead>
              <tbody>
                {tickers.map((ticker, index) => (
                  <tr key={ticker.node_id} style={index % 2 === 0 ? styles.evenRow : styles.oddRow}>
                    <td style={styles.td}>
                      <LinkNode type="ticker" title={ticker.title} />
                    </td>
                    <td style={{ ...styles.td, textAlign: 'center', fontFamily: 'monospace', color: '#507898' }}>
                      {ticker.node_id}
                    </td>
                    <td style={styles.td}>
                      <code style={styles.urlCode}>
                        /node/ticker/{encodeURIComponent(ticker.title.replace(/ /g, '+'))}
                      </code>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <p style={styles.empty}>No ticker endpoints found.</p>
        )}
      </div>

      {/* Footer Info */}
      <div style={styles.footer}>
        <p style={styles.footerText}>
          For more information about API usage, rate limiting, and data formats, please see{' '}
          <a
            href="https://github.com/everything2/everything2/blob/master/docs/API.md"
            target="_blank"
            rel="noopener noreferrer"
            style={styles.link}
          >
            API.md on GitHub
          </a>.
        </p>
      </div>
    </div>
  );
};

const styles = {
  container: {
    maxWidth: '1200px',
    margin: '0 auto',
    padding: '20px'
  },
  header: {
    textAlign: 'center',
    marginBottom: '32px',
    paddingBottom: '20px',
    borderBottom: '3px solid #38495e'
  },
  title: {
    fontSize: '32px',
    fontWeight: '600',
    color: '#38495e',
    marginBottom: '8px'
  },
  subtitle: {
    fontSize: '16px',
    color: '#507898',
    margin: 0
  },
  notice: {
    background: '#e8f4f8',
    border: '2px solid #3bb5c3',
    borderRadius: '8px',
    padding: '20px',
    marginBottom: '32px'
  },
  noticeTitle: {
    fontSize: '18px',
    fontWeight: '600',
    color: '#38495e',
    marginTop: 0,
    marginBottom: '12px'
  },
  noticeText: {
    fontSize: '14px',
    color: '#111',
    lineHeight: '1.6',
    margin: '8px 0'
  },
  noticeList: {
    fontSize: '14px',
    color: '#111',
    lineHeight: '1.8',
    marginLeft: '20px',
    marginTop: '12px',
    marginBottom: '12px'
  },
  link: {
    color: '#4060b0',
    textDecoration: 'none',
    fontFamily: 'monospace'
  },
  section: {
    marginBottom: '40px'
  },
  sectionTitle: {
    fontSize: '24px',
    fontWeight: '600',
    color: '#38495e',
    marginBottom: '8px',
    display: 'flex',
    alignItems: 'center',
    gap: '12px'
  },
  badge: {
    fontSize: '14px',
    fontWeight: '500',
    background: '#3bb5c3',
    color: 'white',
    padding: '4px 12px',
    borderRadius: '12px'
  },
  sectionDesc: {
    fontSize: '14px',
    color: '#507898',
    marginBottom: '16px'
  },
  code: {
    background: '#f5f5f5',
    padding: '2px 6px',
    borderRadius: '3px',
    fontFamily: 'monospace',
    fontSize: '13px',
    color: '#d73a49'
  },
  tableWrapper: {
    overflowX: 'auto',
    borderRadius: '8px',
    border: '1px solid #dee2e6'
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    fontSize: '14px',
    background: 'white'
  },
  th: {
    padding: '12px 16px',
    fontWeight: '600',
    color: '#38495e',
    background: '#f8f9f9',
    borderBottom: '2px solid #dee2e6',
    whiteSpace: 'nowrap'
  },
  td: {
    padding: '12px 16px',
    borderBottom: '1px solid #eee'
  },
  evenRow: {
    background: '#fff'
  },
  oddRow: {
    background: '#fafbfc'
  },
  urlCode: {
    fontSize: '12px',
    fontFamily: 'monospace',
    color: '#507898',
    background: '#f5f5f5',
    padding: '4px 8px',
    borderRadius: '3px',
    display: 'inline-block'
  },
  empty: {
    textAlign: 'center',
    padding: '40px 20px',
    color: '#6c757d',
    fontSize: '14px',
    background: '#f8f9f9',
    borderRadius: '8px'
  },
  footer: {
    marginTop: '40px',
    paddingTop: '20px',
    borderTop: '1px solid #dee2e6',
    textAlign: 'center'
  },
  footerText: {
    fontSize: '14px',
    color: '#507898'
  }
};

export default EverythingDataPages;
