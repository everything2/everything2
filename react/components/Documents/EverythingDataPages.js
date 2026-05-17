import React from 'react';
import LinkNode from '../LinkNode';

/**
 * Everything Data Pages - Directory of XML/JSON API endpoints
 * Styles in CSS: .e2-data-pages__*
 *
 * Displays available data feeds for client developers:
 * - Fullpage endpoints (interactive data interfaces)
 * - Ticker endpoints (XML/Atom/RSS feeds)
 */
const EverythingDataPages = ({ data }) => {
  const { fullpages = [], tickers = [] } = data;

  return (
    <div className="e2-data-pages">
      {/* Developer Notice */}
      <div className="e2-data-pages__notice">
        <h3 className="e2-data-pages__notice-title">Note to Client Developers</h3>
        <p className="e2-data-pages__notice-text">
          The following are Everything Data Pages that provide server-side data in parseable formats.
          Please be respectful of server resources:
        </p>
        <ul className="e2-data-pages__notice-list">
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
        <p className="e2-data-pages__notice-text">
          <strong>RDF Feed:</strong>{' '}
          <a href="/headlines.rdf" className="e2-data-pages__link">
            https://everything2.com/headlines.rdf
          </a>{' '}
          provides Cool Nodes ("Cool User Picks!")
        </p>
      </div>

      {/* Fullpage Endpoints */}
      <div className="e2-data-pages__section">
        <h2 className="e2-data-pages__section-title">
          Fullpage Endpoints
          <span className="e2-data-pages__badge">{fullpages.length}</span>
        </h2>
        <p className="e2-data-pages__section-desc">
          Interactive data interfaces (nodetype: <code className="e2-data-pages__code">fullpage</code>)
        </p>

        {fullpages.length > 0 ? (
          <div className="e2-data-pages__table-wrapper">
            <table className="e2-data-pages__table">
              <thead>
                <tr>
                  <th className="e2-data-pages__th">Endpoint</th>
                  <th className="e2-data-pages__th e2-data-pages__th--center">Node ID</th>
                  <th className="e2-data-pages__th">URL</th>
                </tr>
              </thead>
              <tbody>
                {fullpages.map((page, index) => (
                  <tr key={page.node_id} className={index % 2 === 0 ? 'e2-data-pages__even-row' : 'e2-data-pages__odd-row'}>
                    <td className="e2-data-pages__td">
                      <LinkNode type="fullpage" title={page.title} />
                    </td>
                    <td className="e2-data-pages__td e2-data-pages__td--center">
                      {page.node_id}
                    </td>
                    <td className="e2-data-pages__td">
                      <code className="e2-data-pages__url-code">
                        /title/{encodeURIComponent(page.title.replace(/ /g, '+'))}
                      </code>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <p className="e2-data-pages__empty">No fullpage endpoints found.</p>
        )}
      </div>

      {/* Ticker Endpoints */}
      <div className="e2-data-pages__section">
        <h2 className="e2-data-pages__section-title">
          Ticker Endpoints
          <span className="e2-data-pages__badge">{tickers.length}</span>
        </h2>
        <p className="e2-data-pages__section-desc">
          Second-generation XML/Atom/RSS feeds with unified structure (nodetype: <code className="e2-data-pages__code">ticker</code>)
        </p>

        {tickers.length > 0 ? (
          <div className="e2-data-pages__table-wrapper">
            <table className="e2-data-pages__table">
              <thead>
                <tr>
                  <th className="e2-data-pages__th">Endpoint</th>
                  <th className="e2-data-pages__th e2-data-pages__th--center">Node ID</th>
                  <th className="e2-data-pages__th">URL</th>
                </tr>
              </thead>
              <tbody>
                {tickers.map((ticker, index) => (
                  <tr key={ticker.node_id} className={index % 2 === 0 ? 'e2-data-pages__even-row' : 'e2-data-pages__odd-row'}>
                    <td className="e2-data-pages__td">
                      <LinkNode type="ticker" title={ticker.title} />
                    </td>
                    <td className="e2-data-pages__td e2-data-pages__td--center">
                      {ticker.node_id}
                    </td>
                    <td className="e2-data-pages__td">
                      <code className="e2-data-pages__url-code">
                        /node/ticker/{encodeURIComponent(ticker.title.replace(/ /g, '+'))}
                      </code>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <p className="e2-data-pages__empty">No ticker endpoints found.</p>
        )}
      </div>

      {/* Footer Info */}
      <div className="e2-data-pages__footer">
        <p className="e2-data-pages__footer-text">
          For more information about API usage, rate limiting, and data formats, please see{' '}
          <a
            href="https://github.com/everything2/everything2/blob/master/docs/API.md"
            target="_blank"
            rel="noopener noreferrer"
            className="e2-data-pages__link"
          >
            API.md on GitHub
          </a>.
        </p>
      </div>
    </div>
  );
};

export default EverythingDataPages;
