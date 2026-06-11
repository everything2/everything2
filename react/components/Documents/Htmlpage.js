import React from 'react'
import LinkNode from '../LinkNode'
import SourceMapDisplay from '../Developer/SourceMapDisplay'
import { FaList, FaCode, FaCogs, FaInfoCircle, FaFolder, FaFileCode } from 'react-icons/fa'

/**
 * Htmlpage - Display page for htmlpage nodes
 *
 * Htmlpages are legacy page templates that define display/edit behaviors
 * for different node types. Most functionality has been migrated to
 * Everything::Page classes and React components.
 */
const Htmlpage = ({ data, user }) => {
  if (!data || !data.htmlpage) return null

  const { htmlpage, sourceMap } = data
  const isDeveloper = user?.developer || user?.editor
  const {
    node_id,
    title,
    pagetype_nodetype,
    pagetype_title,
    displaytype,
    mimetype,
    parent_container,
    page_preview,
    is_delegated
  } = htmlpage

  return (
    <div className="htmlpage-display">
      {/* Quick Actions */}
      <div className="dev-display__actions">
        <a
          href={`/title/List%20Nodes%20of%20Type?setvars_ListNodesOfType_Type=${htmlpage.type_nodetype || 5}`}
          className="dev-display__action-btn"
        >
          <FaList size={12} /> List All Htmlpages
        </a>
      </div>

      {/* About Section */}
      <div className="dev-display__section">
        <h4 className="dev-display__header dev-display__header--section">
          <FaInfoCircle size={16} /> About Htmlpages
        </h4>
        <p className="dev-display__text dev-display__text--description">
          Htmlpages are legacy page templates that define how nodes of specific types
          are displayed or edited. Most htmlpage functionality has been migrated to
          Everything::Page classes and React document components.
          {!!is_delegated && (
            <span className="dev-display__delegated-warning">
              <strong>This htmlpage is delegated</strong> - its implementation has been moved
              to the codebase. To modify it, submit a pull request on GitHub.
            </span>
          )}
        </p>
      </div>

      {/* Configuration Section */}
      <div className="dev-display__section">
        <h4 className="dev-display__header dev-display__header--section">
          <FaCogs size={16} /> Configuration
        </h4>

        <div className="dev-display__grid">
          <div>
            <div className="dev-display__header">
              <FaFileCode size={12} /> Page Type
            </div>
            <div className="dev-display__text">
              {pagetype_nodetype ? (
                <LinkNode nodeId={pagetype_nodetype} title={pagetype_title || `Nodetype ${pagetype_nodetype}`} />
              ) : (
                <span className="dev-display__text--empty">None</span>
              )}
            </div>
          </div>

          <div>
            <div className="dev-display__header">
              <FaCode size={12} /> Display Type
            </div>
            <div className="dev-display__text">
              {displaytype || <span className="dev-display__text--empty">default</span>}
            </div>
          </div>

          <div>
            <div className="dev-display__header">
              <FaFolder size={12} /> Parent Container
            </div>
            <div className="dev-display__text">
              {parent_container && parent_container !== 0 ? (
                <LinkNode nodeId={parent_container} title={`Container ${parent_container}`} />
              ) : (
                <span className="dev-display__text--empty">None</span>
              )}
            </div>
          </div>

          <div>
            <div className="dev-display__header">
              <FaFileCode size={12} /> MIME Type
            </div>
            <div className="dev-display__text">
              {mimetype || <span className="dev-display__text--empty">text/html</span>}
            </div>
          </div>
        </div>
      </div>

      {/* Page Code Preview Section (Developer only) */}
      {!!isDeveloper && page_preview && (
        <div className="dev-display__section">
          <h4 className="dev-display__header dev-display__header--section">
            <FaCode size={16} /> Page Code Preview
          </h4>
          <div className="dev-display__code-preview">
            {page_preview}
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

export default Htmlpage
