import React, { useState } from 'react'
import LinkNode from '../LinkNode'

/**
 * NodeHeavenTitleSearch - Admin tool for searching deleted writeups by title
 * Styles in CSS: .node-heaven-search__*
 *
 * Searches the Node Heaven database for writeups matching a title pattern.
 * Shows createtime, title, reputation, author, and killa user.
 */
const NodeHeavenTitleSearch = ({ data }) => {
  const {
    error,
    search_title: initialSearchTitle = '',
    results = [],
    total_count,
    self_kill_count,
    visit_node_id
  } = data

  const [searchTitle, setSearchTitle] = useState(initialSearchTitle)

  if (error) {
    return (
      <div className="node-heaven-search">
        <div className="node-heaven-search__error-box">{error}</div>
      </div>
    )
  }

  const handleSubmit = (e) => {
    // Let form submit naturally with GET parameters
  }

  return (
    <div className="node-heaven-search">
      <p>
        Welcome to Node Heaven, where you may sit and reconcile with your dear departed writeups.
      </p>

      <p>
        <strong>Note:</strong> It takes <em>up to</em> 48 hours for a writeup that was deleted to
        turn up in Node Heaven. Remember: first they must be <em>judged</em>. For that 48 hours
        they are in purgatory...
        <strong>
          <em>
            <LinkNode nodeId={203136} title="sleeping" />
          </em>
        </strong>
        .
      </p>

      <div className="node-heaven-search__search-box">
        <p>Since you are a god, you can also see other nuked nodes.</p>
        <form method="get" onSubmit={handleSubmit} className="node-heaven-search__form">
          <input type="hidden" name="node_id" value={window.e2?.node_id || ''} />
          <label className="node-heaven-search__label">
            Title:
            <input
              type="text"
              name="heaventitle"
              value={searchTitle}
              onChange={(e) => setSearchTitle(e.target.value)}
              className="node-heaven-search__input"
              placeholder="Search deleted writeups by title"
            />
          </label>
          <button type="submit" className="node-heaven-search__button">
            Search
          </button>
        </form>
      </div>

      {initialSearchTitle && (
        <>
          <p className="node-heaven-search__center-text">Here are the little Angels:</p>

          {results.length === 0 ? (
            <p className="node-heaven-search__center-text">
              <em>No nodes by this title have been nuked</em>
            </p>
          ) : (
            <>
              <table className="node-heaven-search__table">
                <thead>
                  <tr>
                    <th className="node-heaven-search__th">Create Time</th>
                    <th className="node-heaven-search__th">Writeup Title</th>
                    <th className="node-heaven-search__th">Rep</th>
                    <th className="node-heaven-search__th">Killa</th>
                  </tr>
                </thead>
                <tbody>
                  {results.map((result) => (
                    <tr key={result.node_id}>
                      <td className="node-heaven-search__td">
                        <small>{result.createtime}</small>
                      </td>
                      <td className="node-heaven-search__td">
                        <a href={`?node_id=${visit_node_id}&visit_id=${result.node_id}`}>
                          {result.title}
                        </a>{' '}
                        by <LinkNode nodeId={result.author_user} title={result.author_title} />
                      </td>
                      <td className="node-heaven-search__td">{result.reputation}</td>
                      <td className="node-heaven-search__td">
                        {result.killa_title ? (
                          <LinkNode nodeId={result.killa_user} title={result.killa_title} />
                        ) : (
                          ''
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>

              <p>
                {total_count} writeups, of which you killed {self_kill_count}.
              </p>
            </>
          )}
        </>
      )}
    </div>
  )
}

export default NodeHeavenTitleSearch
