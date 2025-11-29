import React from 'react'

/**
 * Node Tracker - Track writing statistics and changes
 *
 * Displays user's writing stats, reputation changes, and node activity.
 * Shows XP, node count, cools, reputation metrics, and tracks changes over time.
 */
const NodeTracker = ({ data }) => {
  const { html } = data || {}

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

          /* Stats grid layout */
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

          /* Type percentages */
          .node-tracker-container tt {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            background-color: #f8f9f9;
            padding: 0.5em;
            border-radius: 3px;
            display: block;
            margin: 1em 0;
            color: #333333;
          }

          /* Links in tracker */
          .node-tracker-container a {
            color: #4060b0;
            text-decoration: none;
          }

          .node-tracker-container a:hover {
            text-decoration: underline;
          }

          /* Section headers */
          .node-tracker-container strong {
            color: #38495e;
            font-weight: 600;
          }

          /* Update button styling */
          .node-tracker-container input[type="submit"],
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

          .node-tracker-container input[type="submit"]:hover,
          .node-tracker-container button:hover {
            background-color: #38495e;
          }
        `
      }} />
      <div className="node-tracker-container" dangerouslySetInnerHTML={{ __html: html }} />
    </div>
  )
}

export default NodeTracker
