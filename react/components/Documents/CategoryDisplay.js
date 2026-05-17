import React from 'react'
import LinkNode from '../LinkNode'
import TimeDistance from '../TimeDistance'
import { FaEdit, FaFolder, FaUser, FaGlobe, FaUsers, FaClock } from 'react-icons/fa'

/**
 * CategoryDisplay - Display component for category nodes
 * Styles in CSS: .category-display__*
 *
 * Shows category metadata, parsed description, and list of member nodes.
 * Provides edit button for users with permission.
 */
const CategoryDisplay = ({ data }) => {
  const { category, members = [], can_edit, viewer } = data

  if (!category) {
    return (
      <div className="category-display">
        <div className="category-display__error-box">Category not found.</div>
      </div>
    )
  }

  const {
    node_id,
    title,
    description,
    author,
    author_id,
    is_public,
    createtime,
    member_count
  } = category

  // Group members by type for nicer display
  const membersByType = members.reduce((acc, member) => {
    const type = member.type || 'unknown'
    if (!acc[type]) acc[type] = []
    acc[type].push(member)
    return acc
  }, {})

  return (
    <div className="category-display">
      {/* Header section */}
      <div className="category-display__header">
        <div className="category-display__title-row">
          <FaFolder size={24} className="category-display__folder-icon" />
          <h1 className="category-display__title">{title}</h1>
        </div>

        <div className="category-display__meta">
          <div className="category-display__meta-item">
            {is_public ? (
              <>
                <FaGlobe size={12} className="category-display__meta-icon--public" />
                <span>Public category (anyone can add)</span>
              </>
            ) : (
              <>
                <FaUser size={12} className="category-display__meta-icon" />
                <span>
                  Maintained by{' '}
                  <LinkNode nodeId={author_id} title={author} type={category.author_type || 'user'} display={author} />
                </span>
              </>
            )}
          </div>
          <div className="category-display__meta-item">
            <FaClock size={12} className="category-display__meta-icon" />
            <span>
              Created <TimeDistance then={createtime} />
            </span>
          </div>
          <div className="category-display__meta-item">
            <FaUsers size={12} className="category-display__meta-icon" />
            <span>{member_count} {member_count === 1 ? 'member' : 'members'}</span>
          </div>
        </div>

        {can_edit === 1 && (
          <div className="category-display__edit-button-container">
            <a
              href={`/node/${node_id}?displaytype=edit`}
              className="category-display__edit-button"
            >
              <FaEdit size={14} className="category-display__edit-icon" />
              Edit Category
            </a>
          </div>
        )}
      </div>

      {/* Description section */}
      {description && (
        <div className="category-display__description-section">
          <h2 className="category-display__section-title">Description</h2>
          <div className="category-display__description-box" dangerouslySetInnerHTML={{ __html: description }} />
        </div>
      )}

      {/* Members section */}
      <div className="category-display__members-section">
        <h2 className="category-display__section-title">
          Members ({member_count})
        </h2>

        {members.length === 0 ? (
          <div className="category-display__empty-members">
            <p>This category has no members yet.</p>
            <p className="category-display__empty-hint">
              Add nodes to this category using the "Add to category" form on any node page.
            </p>
          </div>
        ) : (
          <div className="category-display__members-list">
            {Object.entries(membersByType).map(([type, typeMembers]) => (
              <div key={type} className="category-display__type-group">
                <h3 className="category-display__type-header">
                  {type === 'e2node' ? 'E2Nodes' :
                   type === 'category' ? 'Categories' :
                   type.charAt(0).toUpperCase() + type.slice(1) + 's'}
                  <span className="category-display__type-count">({typeMembers.length})</span>
                </h3>
                <ul className="category-display__member-list">
                  {typeMembers.map((member) => (
                    <li key={member.node_id} className="category-display__member-item">
                      <LinkNode
                        nodeId={member.node_id}
                        title={member.title}
                        type={member.type}
                      />
                      {member.type !== 'e2node' && (
                        <span className="category-display__member-author">
                          {' '}by{' '}
                          <LinkNode
                            nodeId={member.author_id}
                            title={member.author}
                            type="user"
                            display={member.author}
                          />
                        </span>
                      )}
                    </li>
                  ))}
                </ul>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}

export default CategoryDisplay
