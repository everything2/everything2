import React from 'react'
import LinkNode from '../LinkNode'
import TimeDistance from '../TimeDistance'
import { FaEdit, FaFolder, FaUser, FaGlobe, FaUsers, FaClock } from 'react-icons/fa'

/**
 * CategoryDisplay - Display component for category nodes
 *
 * Shows category metadata, parsed description, and list of member nodes.
 * Provides edit button for users with permission.
 */
const CategoryDisplay = ({ data }) => {
  const { category, members = [], can_edit, viewer } = data

  if (!category) {
    return (
      <div style={styles.container}>
        <div style={styles.errorBox}>Category not found.</div>
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
    <div style={styles.container}>
      {/* Header section */}
      <div style={styles.header}>
        <div style={styles.titleRow}>
          <FaFolder size={24} style={{ color: '#4060b0', marginRight: '10px' }} />
          <h1 style={styles.title}>{title}</h1>
        </div>

        <div style={styles.meta}>
          <div style={styles.metaItem}>
            {is_public ? (
              <>
                <FaGlobe size={12} style={{ marginRight: '6px', color: '#4060b0' }} />
                <span>Public category (anyone can add)</span>
              </>
            ) : (
              <>
                <FaUser size={12} style={{ marginRight: '6px', color: '#666' }} />
                <span>
                  Maintained by{' '}
                  <LinkNode nodeId={author_id} title={author} type={category.author_type || 'user'} display={author} />
                </span>
              </>
            )}
          </div>
          <div style={styles.metaItem}>
            <FaClock size={12} style={{ marginRight: '6px', color: '#666' }} />
            <span>
              Created <TimeDistance then={createtime} />
            </span>
          </div>
          <div style={styles.metaItem}>
            <FaUsers size={12} style={{ marginRight: '6px', color: '#666' }} />
            <span>{member_count} {member_count === 1 ? 'member' : 'members'}</span>
          </div>
        </div>

        {can_edit === 1 && (
          <div style={styles.editButtonContainer}>
            <a
              href={`/node/${node_id}?displaytype=edit`}
              style={styles.editButton}
            >
              <FaEdit size={14} style={{ marginRight: '6px' }} />
              Edit Category
            </a>
          </div>
        )}
      </div>

      {/* Description section */}
      {description && (
        <div style={styles.descriptionSection}>
          <h2 style={styles.sectionTitle}>Description</h2>
          <div style={styles.descriptionBox} dangerouslySetInnerHTML={{ __html: description }} />
        </div>
      )}

      {/* Members section */}
      <div style={styles.membersSection}>
        <h2 style={styles.sectionTitle}>
          Members ({member_count})
        </h2>

        {members.length === 0 ? (
          <div style={styles.emptyMembers}>
            <p>This category has no members yet.</p>
            <p style={{ fontSize: '12px', color: '#666' }}>
              Add nodes to this category using the "Add to category" form on any node page.
            </p>
          </div>
        ) : (
          <div style={styles.membersList}>
            {Object.entries(membersByType).map(([type, typeMembers]) => (
              <div key={type} style={styles.typeGroup}>
                <h3 style={styles.typeHeader}>
                  {type === 'e2node' ? 'E2Nodes' :
                   type === 'category' ? 'Categories' :
                   type.charAt(0).toUpperCase() + type.slice(1) + 's'}
                  <span style={styles.typeCount}>({typeMembers.length})</span>
                </h3>
                <ul style={styles.memberList}>
                  {typeMembers.map((member) => (
                    <li key={member.node_id} style={styles.memberItem}>
                      <LinkNode
                        nodeId={member.node_id}
                        title={member.title}
                        type={member.type}
                      />
                      {member.type !== 'e2node' && (
                        <span style={styles.memberAuthor}>
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

const styles = {
  container: {
    fontSize: '13px',
    lineHeight: '1.6',
    color: '#111',
    padding: '20px',
    maxWidth: '900px'
  },
  errorBox: {
    padding: '15px',
    backgroundColor: '#ffebee',
    border: '1px solid #f44336',
    borderRadius: '4px',
    color: '#c62828'
  },
  header: {
    marginBottom: '25px',
    paddingBottom: '15px',
    borderBottom: '2px solid #e0e0e0'
  },
  titleRow: {
    display: 'flex',
    alignItems: 'center',
    marginBottom: '15px'
  },
  title: {
    fontSize: '24px',
    fontWeight: 'bold',
    color: '#38495e',
    margin: 0
  },
  meta: {
    display: 'flex',
    flexWrap: 'wrap',
    gap: '20px',
    marginBottom: '15px'
  },
  metaItem: {
    display: 'flex',
    alignItems: 'center',
    fontSize: '13px',
    color: '#555'
  },
  editButtonContainer: {
    marginTop: '10px'
  },
  editButton: {
    display: 'inline-flex',
    alignItems: 'center',
    padding: '8px 16px',
    backgroundColor: '#4060b0',
    color: 'white',
    textDecoration: 'none',
    borderRadius: '4px',
    fontSize: '13px',
    fontWeight: '500',
    transition: 'background-color 0.2s'
  },
  descriptionSection: {
    marginBottom: '25px'
  },
  sectionTitle: {
    fontSize: '16px',
    fontWeight: 'bold',
    color: '#38495e',
    marginBottom: '10px',
    paddingBottom: '5px',
    borderBottom: '1px solid #e0e0e0'
  },
  descriptionBox: {
    padding: '15px',
    backgroundColor: '#f8f9fa',
    borderRadius: '4px',
    border: '1px solid #e0e0e0'
  },
  membersSection: {
    marginBottom: '20px'
  },
  emptyMembers: {
    padding: '20px',
    backgroundColor: '#f5f5f5',
    borderRadius: '4px',
    textAlign: 'center',
    color: '#666'
  },
  membersList: {},
  typeGroup: {
    marginBottom: '20px'
  },
  typeHeader: {
    fontSize: '14px',
    fontWeight: 'bold',
    color: '#555',
    marginBottom: '8px'
  },
  typeCount: {
    fontWeight: 'normal',
    color: '#888',
    marginLeft: '8px'
  },
  memberList: {
    listStyle: 'none',
    padding: 0,
    margin: 0
  },
  memberItem: {
    padding: '6px 0',
    borderBottom: '1px solid #eee'
  },
  memberAuthor: {
    fontSize: '12px',
    color: '#666'
  }
}

export default CategoryDisplay
