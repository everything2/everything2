import React from 'react'
import LinkNode from '../LinkNode'

/**
 * Everything's Richest Noders - Display GP wealth distribution
 * Styles in CSS: .richest-noders__*
 *
 * Shows top 1500 richest, 10 poorest, and top 10 with statistics
 */
const EverythingSRichestNoders = ({ data }) => {
  const {
    total_gp = 0,
    richest_all = [],
    poorest = [],
    richest_top = [],
    richest_top_gp = 0,
    top_percentage = 0,
    limit_all = 1500,
    limit_top = 10
  } = data

  return (
    <div className="richest-noders">
      {/* Top 1500 Richest Users */}
      <h3 className="richest-noders__heading">{limit_all} Richest Noders</h3>
      <ol className="richest-noders__list">
        {richest_all.map((user, index) => (
          <li key={user.user_id} className="richest-noders__list-item">
            <LinkNode id={user.user_id} display={user.title} /> ({user.gp}GP)
          </li>
        ))}
      </ol>

      <hr className="richest-noders__divider" />

      {/* 10 Poorest Users (excluding 0 GP) */}
      <h3 className="richest-noders__heading">{limit_top} Poorest Noders (ignore 0GP)</h3>
      <ol className="richest-noders__list">
        {poorest.map((user, index) => (
          <li key={user.user_id} className="richest-noders__list-item">
            <LinkNode id={user.user_id} display={user.title} /> ({user.gp}GP)
          </li>
        ))}
      </ol>

      <hr className="richest-noders__divider" />

      {/* Top 10 Richest Users */}
      <h3 className="richest-noders__heading">{limit_top} Richest Noders</h3>
      <ol className="richest-noders__list">
        {richest_top.map((user, index) => (
          <li key={user.user_id} className="richest-noders__list-item">
            <LinkNode id={user.user_id} display={user.title} /> ({user.gp}GP)
          </li>
        ))}
      </ol>

      {/* GP Statistics */}
      <p className="richest-noders__stats">
        <strong>Total GP in circulation:</strong> {total_gp.toLocaleString()}
      </p>
      <p className="richest-noders__stats">
        The top {limit_top} users hold {top_percentage.toFixed(2)}% of all the GP
      </p>
    </div>
  )
}

export default EverythingSRichestNoders
