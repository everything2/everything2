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
    <ul className="ce-section-links">
      <li className="ce-section-links__item">
        <FaBook size={12} className="ce-section-links__icon" />
        <LinkNode type="superdoc" title="E2 Editor Doc" />
      </li>
      <li className="ce-section-links__item">
        <FaFileAlt size={12} className="ce-section-links__icon" />
        <LinkNode type="oppressor_superdoc" title="Content Reports" />
      </li>
      <li className="ce-section-links__item">
        <FaEye size={12} className="ce-section-links__icon" />
        <LinkNode type="superdoc" title="Drafts for review" />
      </li>
      <li className="ce-section-links__item">
        <FaNewspaper size={12} className="ce-section-links__icon" />
        <LinkNode type="superdoc" title="25" /> |{' '}
        <LinkNode type="superdoc" title="Everything New Nodes" />
      </li>
      <li className="ce-section-links__item">
        <FaTrash size={12} className="ce-section-links__icon" />
        <LinkNode type="superdoc" title="Nodeshells Marked For Destruction" display="Nodeshells" />
      </li>
      <li className="ce-section-links__item">
        <FaStickyNote size={12} className="ce-section-links__icon" />
        <LinkNode type="superdoc" title="Recent Node Notes" display="Recent Notes" />
      </li>
      <li className="ce-section-links__item">
        <FaShieldAlt size={12} className="ce-section-links__icon" />
        <LinkNode type="superdoc" title="Your insured writeups" />
      </li>
      <li className="ce-section-links__item">
        <FaCog size={12} className="ce-section-links__icon" />
        <LinkNode
          type="oppressor_superdoc"
          title="Node Parameter Editor"
          display="Parameter Editor"
          params={{ for_node: nodeId }}
        />
      </li>
      <li className="ce-section-links__item">
        <FaVoteYea size={12} className="ce-section-links__icon" />
        <LinkNode type="superdoc" title="Blind Voting Booth" />
      </li>
      <li className="ce-section-links__item">
        <FaUsers size={12} className="ce-section-links__icon" />
        <LinkNode type="superdoc" title="usergroup discussions" display="Group discussions" />
      </li>
      <li className="ce-section-links__item">
        <FaClipboardList size={12} className="ce-section-links__icon" />
        <LinkNode type="e2node" title={curLog} />
      </li>
      {isUserNode && (
        <li className="ce-section-links__item">
          <FaUserSecret size={12} className="ce-section-links__icon" />
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
