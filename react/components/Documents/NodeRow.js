import React from 'react'
import LinkNode from '../LinkNode'

/**
 * Node Row - Deprecated editorial tool
 * Styles in CSS: .node-row__*
 *
 * Shows writeups that have been removed from nodes and placed in the editorial queue.
 * This tool is part of the legacy editorial workflow and is scheduled for removal.
 */
const NodeRow = ({ data }) => {
  const {
    error,
    total_count,
    removed_by_user,
    entries = [],
    offset,
    interval,
    has_more,
    node_row_id
  } = data

  if (error) {
    return (
      <div className="node-row">
        <div className="node-row__error-box">{error}</div>
      </div>
    )
  }

  const hasPrev = offset > 0
  const prevOffset = Math.max(0, offset - interval)
  const nextOffset = offset + interval

  return (
    <div className="node-row">
      <div className="node-row__deprecation-notice">
        <strong>⚠️ DEPRECATED TOOL</strong>
        <p>
          This editorial tool is part of the legacy workflow and is scheduled for removal.
          Modern editorial processes should use alternative tools.
        </p>
      </div>

      <div className="node-row__stats">
        <p>
          There are <strong>{total_count}</strong> items waiting on Node Row.
          {' '}Of those, you removed <strong>{removed_by_user}</strong>.
        </p>
      </div>

      {entries.length === 0 ? (
        <p>No items currently on Node Row.</p>
      ) : (
        <>
          {entries.map((entry, idx) => (
            <div key={entry.weblog_id} className="node-row__entry">
              <div className="node-row__entry-header">
                <LinkNode nodeId={entry.to_node} title={entry.node_title} />
                {entry.parent_node && (
                  <span className="node-row__parent-info">
                    {' '}from <LinkNode nodeId={entry.parent_node.node_id} title={entry.parent_node.title} />
                  </span>
                )}
              </div>

              <div className="node-row__entry-meta">
                <span className="node-row__byline">
                  Linked by <LinkNode nodeId={entry.linkedby_user} title={entry.linkedby_title} />
                </span>
                <span className="node-row__date">{entry.linkedtime}</span>
              </div>

              {entry.content && (
                <div
                  className="node-row__content"
                  dangerouslySetInnerHTML={{ __html: entry.content }}
                />
              )}

              <div className="node-row__actions">
                <a
                  href={`?node_id=${node_row_id}&source=${node_row_id}&to_node=${entry.to_node}&op=removeweblog`}
                  className="node-row__remove-link"
                >
                  restore
                </a>
              </div>
            </div>
          ))}

          {(hasPrev || has_more) && (
            <div className="node-row__pagination">
              {hasPrev && (
                <a href={`?offset=${prevOffset}`} className="node-row__link">
                  ← newer
                </a>
              )}
              {hasPrev && has_more && <span className="node-row__separator">|</span>}
              {has_more && (
                <a href={`?offset=${nextOffset}`} className="node-row__link">
                  older →
                </a>
              )}
            </div>
          )}
        </>
      )}
    </div>
  )
}

export default NodeRow
