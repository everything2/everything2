import React, { useState } from 'react';
import AdminCreateNodeLink from '../AdminCreateNodeLink';
import { decodeHtmlEntities } from '../../utils/textUtils';
import { InContentAd } from '../Layout/GoogleAds';

// Show an ad every N items in the best entries list (for guests only)
const AD_INTERVAL = 4;

/**
 * NothingFound - Search results when nothing matches
 * Styles in CSS: .nothing-found__*
 */
const NothingFound = ({ data, user }) => {
  const {
    was_nuke,
    search_term,
    is_url,
    external_link,
    is_guest,
    show_tin_opener,
    tinopener_active,
    tin_opener_message,
    existing_e2node,
    lastnode_id,
    best_entries = []
  } = data;

  const [searchValue, setSearchValue] = useState(search_term || '');
  const [createValue, setCreateValue] = useState(search_term ? search_term.replace(/^\s*https?:\/\//, '') : '');
  const [soundex, setSoundex] = useState(false);
  const [matchAll, setMatchAll] = useState(false);

  // Handle successful nuke
  if (was_nuke) {
    return (
      <div className="nothing-found">
        <p>Oh good, there's nothing there!</p>
        <p>(It looks like you nuked it.)</p>
      </div>
    );
  }

  // Handle no search term
  if (!search_term) {
    return (
      <div className="nothing-found">
        <p>Hmm... that's odd. There's nothing there!</p>
      </div>
    );
  }

  return (
    <div className="nothing-found">
      <p>Sorry, but nothing matching "{search_term}" was found.</p>

      {is_url && external_link && (
        <p className="nothing-found__url-note">
          (this appears to be an external link:{' '}
          <a href={external_link} target="_blank" rel="noopener noreferrer">
            {external_link}
          </a>)
        </p>
      )}

      {show_tin_opener && !tinopener_active && (
        <p className="nothing-found__small-note">
          <small>
            You could{' '}
            <a href={`${window.location.pathname}${window.location.search}&tinopener=1`}>
              use the godly tin-opener
            </a>{' '}
            to show a censored version of any draft that may be here, but only do that if you really need to.
          </small>
        </p>
      )}

      {show_tin_opener && tinopener_active && tin_opener_message && (
        <p className="nothing-found__small-note">
          <small>({tin_opener_message})</small>
        </p>
      )}

      {/* Guest user message */}
      {is_guest ? (
        <>
          <p className="nothing-found__guest-message">
            If you <a href="/?node=login">Log in</a> you could create a "{createValue}" node.
            If you don't already have an account, you can{' '}
            <a href="/?node=Sign%20Up">register here</a>.
          </p>

          {/* Best entries for guests */}
          {best_entries.length > 0 && (
            <div className="nothing-found__best-entries-section">
              <h3 className="nothing-found__best-entries-title">
                We couldn't find what you're looking for, but here are some of our best entries from the past few months:
              </h3>
              <ul className="nothing-found__best-entries-list">
                {best_entries.map((entry, index) => (
                  <React.Fragment key={entry.writeup_id}>
                    <li className="nothing-found__best-entry-item">
                      <a href={`/node/${entry.node_id}?lastnode_id=0`} className="nothing-found__best-entry-link">
                        {entry.title}
                      </a>
                      {entry.author && (
                        <span className="nothing-found__best-entry-author">
                          {' '}by{' '}
                          <a href={`/user/${encodeURIComponent(entry.author.title)}`}>
                            {entry.author.title}
                          </a>
                        </span>
                      )}
                      {entry.excerpt && (
                        <p className="nothing-found__best-entry-excerpt">{decodeHtmlEntities(entry.excerpt)}</p>
                      )}
                    </li>
                    {/* Show ad every AD_INTERVAL items */}
                    {(index + 1) % AD_INTERVAL === 0 && index < best_entries.length - 1 && (
                      <li className="nothing-found__ad-item">
                        <InContentAd show={true} />
                      </li>
                    )}
                  </React.Fragment>
                ))}
              </ul>
            </div>
          )}
        </>
      ) : existing_e2node ? (
        <p>
          <a href={`/?node_id=${existing_e2node.node_id}`}>{existing_e2node.title}</a> already exists.
        </p>
      ) : (
        <>
          <p>Since we didn't find what you were looking for, you can search again, or create a new draft or e2node (page):</p>

          {/* Search again form */}
          <form method="get" action="/" className="nothing-found__form">
            <fieldset className="nothing-found__fieldset">
              <legend>Search again</legend>
              <input
                type="text"
                name="node"
                value={searchValue}
                onChange={(e) => setSearchValue(e.target.value)}
                size="50"
                maxLength="100"
                className="nothing-found__text-input"
              />
              {' '}
              <input type="hidden" name="lastnode_id" value={lastnode_id} />
              <button type="submit" name="searchy" value="search" className="nothing-found__button">
                search
              </button>
              <br />
              <label className="nothing-found__checkbox">
                <input
                  type="checkbox"
                  name="soundex"
                  value="1"
                  checked={soundex}
                  onChange={(e) => setSoundex(e.target.checked)}
                />
                {' '}Near Matches{' '}
              </label>
              <label className="nothing-found__checkbox">
                <input
                  type="checkbox"
                  name="match_all"
                  value="1"
                  checked={matchAll}
                  onChange={(e) => setMatchAll(e.target.checked)}
                />
                {' '}Ignore Exact
              </label>
            </fieldset>
          </form>

          {/* Create new form */}
          <form method="get" action="/" className="nothing-found__form">
            <fieldset className="nothing-found__fieldset">
              <legend>Create new...</legend>
              <small>You can correct the spelling or capitalization here.</small>
              <br />
              <input
                type="text"
                name="node"
                value={createValue}
                onChange={(e) => setCreateValue(e.target.value)}
                size="50"
                maxLength="100"
                className="nothing-found__text-input"
              />
              <input type="hidden" name="lastnode_id" value={lastnode_id} />
              <input type="hidden" name="op" value="new" />
              {' '}
              <button type="submit" name="type" value="draft" className="nothing-found__button">
                New draft
              </button>
              {' '}
              <button type="submit" name="type" value="e2node" className="nothing-found__button">
                New node
              </button>
            </fieldset>
          </form>

          <AdminCreateNodeLink user={user} searchTerm={createValue} />
        </>
      )}
    </div>
  );
};

export default NothingFound;
