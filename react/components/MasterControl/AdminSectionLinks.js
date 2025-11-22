import React from 'react'
import LinkNode from '../LinkNode'
import { FaSkullCrossbones, FaEdit, FaBook, FaUserShield } from 'react-icons/fa'

const AdminSectionLinks = ({ isBorged }) => {
  return (
    <>
      {isBorged && (
        <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '8px', paddingLeft: '8px' }}>
          <FaUserShield size={12} style={{ color: '#666', flexShrink: 0 }} />
          <LinkNode
            type="restricted_superdoc"
            title="nate's secret unborg doc"
            display="Unborg Yourself"
          />
        </div>
      )}
      <ul style={{ listStyle: 'none', paddingLeft: '8px' }}>
        <li style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '4px' }}>
          <FaSkullCrossbones size={12} style={{ color: '#666', flexShrink: 0 }} />
          <LinkNode type="restricted_superdoc" title="The Node Crypt" />
        </li>
        <li style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '4px' }}>
          <FaEdit size={12} style={{ color: '#666', flexShrink: 0 }} />
          <LinkNode type="restricted_superdoc" title="Edit These E2 Titles" />
        </li>
        <li style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '4px' }}>
          <FaBook size={12} style={{ color: '#666', flexShrink: 0 }} />
          <LinkNode
            type="oppressor_document"
            title="God Powers and How to Use Them"
            display="Admin HOWTO"
          />
        </li>
      </ul>
    </>
  )
}

export default AdminSectionLinks
