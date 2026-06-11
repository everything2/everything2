import React from 'react'
import SourceMapDisplay from '../Developer/SourceMapDisplay'
import { FaList, FaCode, FaInfoCircle } from 'react-icons/fa'

/**
 * Htmlcode - Display page for htmlcode nodes
 *
 * Htmlcodes are reusable Perl code snippets that can be called
 * from templates and other code throughout the system.
 */
const Htmlcode = ({ data, user }) => {
  if (!data || !data.htmlcode) return null

  const { htmlcode, sourceMap } = data
  const isDeveloper = user?.developer || user?.editor
  const {
    node_id,
    title,
    code_preview,
    is_delegated
  } = htmlcode

  return (
    <div className="htmlcode-display">
      {/* Quick Actions */}
      <div className="dev-display__actions">
        <a
          href={`/title/List%20Nodes%20of%20Type?setvars_ListNodesOfType_Type=${htmlcode.type_nodetype || 4}`}
          className="dev-display__action-btn"
        >
          <FaList size={12} /> List All Htmlcodes
        </a>
      </div>

      {/* About Section */}
      <div className="dev-display__section">
        <h4 className="dev-display__header dev-display__header--section">
          <FaInfoCircle size={16} /> About Htmlcodes
        </h4>
        <p className="dev-display__text dev-display__text--description">
          Htmlcodes are reusable Perl code snippets that can be called from templates
          and other code throughout the Everything2 system. They provide a way to
          share common functionality across different parts of the site.
          {!!is_delegated && (
            <span className="dev-display__delegated-warning">
              <strong>This htmlcode is delegated</strong> - its implementation has been moved
              to the codebase. To modify it, submit a pull request on GitHub.
            </span>
          )}
        </p>
      </div>

      {/* Code Preview Section (Developer only) */}
      {!!isDeveloper && code_preview && (
        <div className="dev-display__section">
          <h4 className="dev-display__header dev-display__header--section">
            <FaCode size={16} /> Code Preview
          </h4>
          <div className="dev-display__code-preview">
            {code_preview}
          </div>
        </div>
      )}

      {/* Developer Source Map */}
      {!!isDeveloper && sourceMap && (
        <SourceMapDisplay
          sourceMap={sourceMap}
          title={`Source Map: ${title}`}
          showContributeBox={true}
          showDescription={true}
        />
      )}
    </div>
  )
}

export default Htmlcode
