import React from 'react'
import LinkNode from '../LinkNode'
import { FaBook, FaFileAlt, FaEye, FaNewspaper, FaTrash, FaStickyNote, FaShieldAlt, FaCog, FaVoteYea, FaUsers, FaClipboardList, FaUserSecret } from 'react-icons/fa'

const CESectionLinks = ({ currentMonth, currentYear, isUserNode, nodeId, nodeTitle }) => {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ]

  const curLog = `Editor Log: ${months[currentMonth]} ${currentYear}`

  return (
    <ul style={{ listStyle: 'none', paddingLeft: '8px' }}>
      <li style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '4px' }}>
        <FaBook size={12} style={{ color: '#666', flexShrink: 0 }} />
        <LinkNode type="superdoc" title="E2 Editor Doc" />
      </li>
      <li style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '4px' }}>
        <FaFileAlt size={12} style={{ color: '#666', flexShrink: 0 }} />
        <LinkNode type="oppressor_superdoc" title="Content Reports" />
      </li>
      <li style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '4px' }}>
        <FaEye size={12} style={{ color: '#666', flexShrink: 0 }} />
        <LinkNode type="superdoc" title="Drafts for review" />
      </li>
      <li style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '4px' }}>
        <FaNewspaper size={12} style={{ color: '#666', flexShrink: 0 }} />
        <LinkNode type="superdoc" title="25" /> |{' '}
        <LinkNode type="superdoc" title="Everything New Nodes" />
      </li>
      <li style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '4px' }}>
        <FaTrash size={12} style={{ color: '#666', flexShrink: 0 }} />
        <LinkNode type="superdoc" title="Nodeshells Marked For Destruction" display="Nodeshells" />
      </li>
      <li style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '4px' }}>
        <FaStickyNote size={12} style={{ color: '#666', flexShrink: 0 }} />
        <LinkNode type="superdoc" title="Recent Node Notes" display="Recent Notes" />
      </li>
      <li style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '4px' }}>
        <FaShieldAlt size={12} style={{ color: '#666', flexShrink: 0 }} />
        <LinkNode type="superdoc" title="Your insured writeups" />
      </li>
      <li style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '4px' }}>
        <FaCog size={12} style={{ color: '#666', flexShrink: 0 }} />
        <LinkNode
          type="oppressor_superdoc"
          title="Node Parameter Editor"
          display="Parameter Editor"
          params={{ for_node: nodeId }}
        />
      </li>
      <li style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '4px' }}>
        <FaVoteYea size={12} style={{ color: '#666', flexShrink: 0 }} />
        <LinkNode type="superdoc" title="Blind Voting Booth" />
      </li>
      <li style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '4px' }}>
        <FaUsers size={12} style={{ color: '#666', flexShrink: 0 }} />
        <LinkNode type="superdoc" title="usergroup discussions" display="Group discussions" />
      </li>
      <li style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '4px' }}>
        <FaClipboardList size={12} style={{ color: '#666', flexShrink: 0 }} />
        <LinkNode type="e2node" title={curLog} />
      </li>
      {isUserNode && (
        <li style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '4px' }}>
          <FaUserSecret size={12} style={{ color: '#666', flexShrink: 0 }} />
          <LinkNode
            type="oppressor_superdoc"
            title="The Oracle"
            params={{ the_oracle_subject: nodeTitle }}
          />
        </li>
      )}
    </ul>
  )
}

export default CESectionLinks
