import React, { useState } from 'react';
import AdminCreateNodeLink from '../AdminCreateNodeLink';
import { decodeHtmlEntities } from '../../utils/textUtils';

const Findings = ({ data, user }) => {
  const { no_search_term, message, search_term, findings = [], lastnode_id, is_guest, has_excerpts } = data;

  const [searchValue, setSearchValue] = useState(search_term || '');
  const [soundex, setSoundex] = useState(false);
  const [matchAll, setMatchAll] = useState(false);

  if (no_search_term) {
    return (
      <div className="findings-container">
        <p className="findings-message">{message}</p>
        <p>
          <a href="/?node=Random%20Nodes">Visit Random Nodes</a>
        </p>
      </div>
    );
  }

  return (
    <div className="findings-container">
      <p className="findings-header">
        Here's the stuff we found when you searched for "{search_term}"
      </p>

      <ul className="findings-list">
        {findings.map((finding) => (
          <li
            key={finding.node_id}
            className={finding.is_nodeshell ? 'findings-item findings-item--nodeshell' : 'findings-item'}
          >
            <a href={`/?node_id=${finding.node_id}${is_guest ? '&lastnode_id=0' : `&lastnode_id=${lastnode_id}`}`}>
              {finding.title}
            </a>
            {finding.type !== 'e2node' && <span> ({finding.type})</span>}
            {finding.writeup_count > 1 && <span> ({finding.writeup_count} entries)</span>}
            {finding.excerpt && (
              <a
                href={`/?node_id=${finding.node_id}${is_guest ? '&lastnode_id=0' : `&lastnode_id=${lastnode_id}`}`}
                className="findings-excerpt-link"
              >
                <p className="findings-excerpt">{decodeHtmlEntities(finding.excerpt)}</p>
              </a>
            )}
          </li>
        ))}
      </ul>

      {findings.length === 0 && (
        <p className="findings-no-results">No results found.</p>
      )}

      {/* Create new node form */}
      <div className="findings-create-section">
        <p>
          {is_guest
            ? "Since we didn't find what you were looking for, you can search again:"
            : "Since we didn't find what you were looking for, you can search again, or create a new draft or e2node (page):"}
        </p>

        {/* Search again form */}
        <form method="get" action="/" className="findings-form">
          <fieldset className="findings-fieldset">
            <legend>Search again</legend>
            <div className="findings-input-row">
              <input
                type="text"
                name="node"
                value={searchValue}
                onChange={(e) => setSearchValue(e.target.value)}
                maxLength="100"
                className="findings-text-input"
              />
              <input type="hidden" name="lastnode_id" value={lastnode_id} />
              <button type="submit" name="searchy" value="search" className="findings-button">
                search
              </button>
            </div>
            <div className="findings-checkbox-row">
              <label className="findings-checkbox">
                <input
                  type="checkbox"
                  name="soundex"
                  value="1"
                  checked={soundex}
                  onChange={(e) => setSoundex(e.target.checked)}
                />
                {' '}Near Matches{' '}
              </label>
              <label className="findings-checkbox">
                <input
                  type="checkbox"
                  name="match_all"
                  value="1"
                  checked={matchAll}
                  onChange={(e) => setMatchAll(e.target.checked)}
                />
                {' '}Ignore Exact
              </label>
            </div>
          </fieldset>
        </form>

        {/* Create new form - only for logged-in users */}
        {!is_guest && (
          <form method="get" action="/" className="findings-form">
            <fieldset className="findings-fieldset">
              <legend>Create new...</legend>
              <small>You can correct the spelling or capitalization here.</small>
              <div className="findings-input-row">
                <input
                  type="text"
                  name="node"
                  defaultValue={search_term}
                  maxLength="100"
                  className="findings-text-input"
                />
                <input type="hidden" name="lastnode_id" value={lastnode_id} />
                <input type="hidden" name="op" value="new" />
              </div>
              <div className="findings-button-row">
                <button type="submit" name="type" value="draft" className="findings-button">
                  New draft
                </button>
                <button type="submit" name="type" value="e2node" className="findings-button">
                  New node
                </button>
              </div>
            </fieldset>
          </form>
        )}

        <AdminCreateNodeLink user={user} searchTerm={search_term} />

        {/* Full text search link */}
        <p className="findings-fulltext-search">
          <a href={`/node/superdoc/E2+Full+Text+Search?q=${encodeURIComponent(search_term)}`}>
            Do a full text search for "{search_term}"
          </a>
        </p>
      </div>
    </div>
  );
};

export default Findings;
