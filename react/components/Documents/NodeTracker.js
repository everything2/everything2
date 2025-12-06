import React from 'react'

/**
 * Node Tracker - Track writing statistics and changes
 *
 * Displays user's writing stats, reputation changes, and node activity.
 * Shows XP, node count, cools, reputation metrics, and tracks changes over time.
 */
const NodeTracker = ({ data }) => {
  const {
    intro_text,
    last_update,
    stats = {},
    type_breakdown = [],
    merit_range = {},
    published_nodes = [],
    removed_nodes = [],
    renamed_nodes = [],
    changed_nodes = [],
    has_changes
  } = data || {}

  const formatStat = (stat) => {
    if (!stat) return '0'
    let str = String(stat.current || 0)
    if (stat.diff && stat.diff !== 0) {
      str += ` (${stat.diff > 0 ? '+' : ''}${stat.diff})`
    }
    return str
  }

  const formatStatFP = (stat, isPercent = false) => {
    if (!stat) return '0.00' + (isPercent ? '%' : '')
    const current = (stat.current || 0).toFixed(2)
    let str = current + (isPercent ? '%' : '')
    if (stat.diff && Math.abs(stat.diff) > 0.001) {
      str += ` (${stat.diff > 0 ? '+' : ''}${stat.diff.toFixed(3)}${isPercent ? '%' : ''})`
    }
    return str
  }

  return (
    <div className="document">
      <style dangerouslySetInnerHTML={{
        __html: `
          .node-tracker-container {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            line-height: 1.6;
          }

          .node-tracker-container p {
            margin: 1em 0;
            color: #333333;
          }

          .node-tracker-container em {
            font-style: italic;
            color: #507898;
          }

          .node-tracker-container pre {
            font-family: 'SF Mono', 'Monaco', 'Menlo', 'Consolas', monospace;
            font-size: 0.9em;
            background-color: #f8f9f9;
            border: 1px solid #d3d3d3;
            border-radius: 4px;
            padding: 1em;
            margin: 1.5em 0;
            overflow-x: auto;
            line-height: 1.8;
            color: #111111;
          }

          .node-tracker-container strong {
            color: #38495e;
            font-weight: 600;
          }

          .node-tracker-container button {
            background-color: #4060b0;
            color: white;
            border: none;
            padding: 0.5em 1.5em;
            border-radius: 4px;
            cursor: pointer;
            font-size: 0.95em;
            font-weight: 500;
            margin: 1em 0;
          }

          .node-tracker-container button:hover {
            background-color: #38495e;
          }

          .node-tracker-container table {
            width: 100%;
            border-collapse: collapse;
            margin: 1em 0;
            font-family: 'SF Mono', 'Monaco', 'Menlo', 'Consolas', monospace;
            font-size: 0.9em;
          }

          .node-tracker-container th {
            text-align: left;
            padding: 0.5em;
            background: #f8f9f9;
            border-bottom: 2px solid #dee2e6;
          }

          .node-tracker-container td {
            padding: 0.3em 0.5em;
            border-bottom: 1px solid #eee;
          }

          .node-tracker-container a {
            color: #4060b0;
            text-decoration: none;
          }

          .node-tracker-container a:hover {
            text-decoration: underline;
          }
        `
      }} />
      <div className="node-tracker-container">
        <div dangerouslySetInnerHTML={{ __html: intro_text }} />

        <pre>
{`        E2 USER INFO: last update ${last_update}

Nodes:      ${formatStat(stats.nodes).padEnd(20)}   XP:          ${formatStat(stats.xp).padEnd(20)}   Cools:       ${formatStat(stats.cools)}
Max Rep:    ${formatStat(stats.maxrep).padEnd(20)}   Min Rep:     ${formatStat(stats.minrep).padEnd(20)}   Total Rep:   ${formatStat(stats.totalrep)}
Node-Fu:    ${formatStatFP(stats.nodefu).padEnd(20)}   WNF:         ${formatStatFP(stats.wnf).padEnd(20)}   Cool Ratio:  ${formatStatFP(stats.coolratio, true)}
Merit:      ${formatStatFP(stats.merit).padEnd(20)}   Average Rep: ${formatStatFP(stats.average).padEnd(20)}   Median rep:  ${formatStat(stats.median)}
Up votes:   ${formatStat(stats.upvotes).padEnd(20)}   Devotion:    ${formatStat(stats.devotion).padEnd(20)}   Merit Range: ${merit_range.min || 0} to ${merit_range.max || 0}
Max Cools:  ${formatStat(stats.maxcools).padEnd(20)}   Down votes:  ${formatStat(stats.downvotes).padEnd(20)}   Votes:       ${formatStat(stats.votes)}
Max Votes:  ${formatStat(stats.maxvotes)}`}
        </pre>

        {type_breakdown.length > 0 && (
          <div style={{ background: '#f8f9f9', padding: '0.5em', borderRadius: '3px', margin: '1em 0' }}>
            {type_breakdown.map(t => `${t.type}: ${t.percentage}%`).join('  ')}
          </div>
        )}

        {(published_nodes.length > 0 || removed_nodes.length > 0 || renamed_nodes.length > 0) && (
          <pre>
{`        Published/Removed/Renamed:
Change      Title
─────────────────────────────────────────────────────────────────`}
{published_nodes.map(n => `\nPublished | ${n.title}`).join('')}
{removed_nodes.map(n => `\nRemoved   | ${n.title}`).join('')}
{renamed_nodes.map(n => `\nRenamed   | ${n.old_title}->${n.new_title}`).join('')}
{'\n─────────────────────────────────────────────────────────────────'}
          </pre>
        )}

        {changed_nodes.length > 0 && (
          <>
            <h3 style={{ margin: '1.5em 0 0.5em 0' }}>Reputation Changes / Cools:</h3>
            <table>
              <thead>
                <tr>
                  <th>Rep</th>
                  <th>+/-</th>
                  <th>C!</th>
                  <th>+/-</th>
                  <th>Title</th>
                </tr>
              </thead>
              <tbody>
                {changed_nodes.map(node => (
                  <tr key={node.node_id}>
                    <td>
                      {node.upvotes && node.downvotes
                        ? `${node.reputation >= 0 ? '+' : ''}${node.reputation} (+${node.upvotes}/-${node.downvotes})`
                        : `${node.reputation >= 0 ? '+' : ''}${node.reputation}`}
                    </td>
                    <td>
                      {node.upvotes_change && node.downvotes_change
                        ? `${node.rep_change >= 0 ? '+' : ''}${node.rep_change} (+${node.upvotes_change}/-${node.downvotes_change})`
                        : `${node.rep_change >= 0 ? '+' : ''}${node.rep_change}`}
                    </td>
                    <td>{node.cools}</td>
                    <td>{node.cool_change !== 0 ? `${node.cool_change >= 0 ? '+' : ''}${node.cool_change}` : ''}</td>
                    <td><a href={`/?node_id=${node.node_id}`}>{node.title}</a></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </>
        )}

        {!has_changes && (
          <pre>No nodes changed.</pre>
        )}

        <form method="get" action="/">
          <input type="hidden" name="node" value="Node Tracker" />
          <button type="submit" name="update" value="1">Update</button>
        </form>
      </div>
    </div>
  )
}

export default NodeTracker
