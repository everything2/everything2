import React from 'react'
import {
  FaFileAlt,
  FaCode,
  FaCog,
  FaUser,
  FaUsers,
  FaFile,
  FaFolder,
  FaSitemap,
  FaWrench,
  FaBell,
  FaPalette,
  FaTrophy,
  FaEnvelope,
  FaPoll,
  FaBook,
  FaDatabase,
  FaList
} from 'react-icons/fa'

/**
 * Node Type Icon Mapping
 *
 * Maps nodetype titles to appropriate icons for display in
 * nodegroup editors and other contexts where we need to
 * visually distinguish different node types.
 */

const TYPE_ICONS = {
  // Document types
  document: FaFileAlt,
  superdoc: FaFileAlt,
  oppressor_superdoc: FaFileAlt,
  restricted_superdoc: FaFileAlt,
  superdocnolinks: FaFileAlt,
  fullpage: FaFileAlt,
  edevdoc: FaFileAlt,
  oppressor_document: FaFileAlt,

  // User types
  user: FaUser,
  usergroup: FaUsers,

  // E2 content types
  e2node: FaBook,
  writeup: FaFile,
  draft: FaFile,
  category: FaList,

  // System/code types
  nodetype: FaSitemap,
  htmlcode: FaCode,
  htmlpage: FaCode,
  opcode: FaCode,
  jsonexport: FaCode,

  // Container/structure types
  nodelet: FaFolder,
  container: FaFolder,
  nodegroup: FaFolder,

  // Settings/config types
  setting: FaCog,
  dbtable: FaDatabase,
  maintenance: FaWrench,

  // Communication types
  mail: FaEnvelope,
  notification: FaBell,

  // Special types
  e2poll: FaPoll,
  ticker: FaFileAlt,
  schema: FaFileAlt,
  achievement: FaTrophy,
  stylesheet: FaPalette,
  room: FaFolder,

  // Default fallback
  default: FaFile
}

/**
 * Get the appropriate icon component for a node type
 *
 * @param {string} typeName - The nodetype title (e.g., 'document', 'user', 'e2node')
 * @param {object} props - Optional props to pass to the icon component
 * @returns {JSX.Element} The icon component
 */
export const getNodeTypeIcon = (typeName, props = {}) => {
  const normalizedType = (typeName || '').toLowerCase()
  const IconComponent = TYPE_ICONS[normalizedType] || TYPE_ICONS.default

  return <IconComponent {...props} />
}

/**
 * Get just the icon component class (not rendered)
 * Useful when you need the component reference itself
 *
 * @param {string} typeName - The nodetype title
 * @returns {React.ComponentType} The icon component class
 */
export const getNodeTypeIconComponent = (typeName) => {
  const normalizedType = (typeName || '').toLowerCase()
  return TYPE_ICONS[normalizedType] || TYPE_ICONS.default
}

/**
 * Get icon style based on node type category
 * Returns color suggestions for different type categories
 *
 * @param {string} typeName - The nodetype title
 * @returns {object} Style object with color
 */
export const getNodeTypeIconStyle = (typeName) => {
  const normalizedType = (typeName || '').toLowerCase()

  // User types - blue
  if (['user', 'usergroup'].includes(normalizedType)) {
    return { color: '#4060b0' }
  }

  // Content types - teal
  if (['e2node', 'writeup', 'draft', 'category'].includes(normalizedType)) {
    return { color: '#3bb5c3' }
  }

  // Document types - muted blue
  if (['document', 'superdoc', 'oppressor_superdoc', 'restricted_superdoc',
    'superdocnolinks', 'fullpage', 'edevdoc', 'oppressor_document'].includes(normalizedType)) {
    return { color: '#507898' }
  }

  // System types - darker
  if (['nodetype', 'htmlcode', 'htmlpage', 'opcode', 'jsonexport',
    'dbtable', 'maintenance', 'setting'].includes(normalizedType)) {
    return { color: '#38495e' }
  }

  // Default - muted
  return { color: '#666' }
}

export default {
  getNodeTypeIcon,
  getNodeTypeIconComponent,
  getNodeTypeIconStyle
}
