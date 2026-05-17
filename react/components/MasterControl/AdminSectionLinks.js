import React from 'react'
import LinkNode from '../LinkNode'
import { FaSkullCrossbones, FaEdit, FaBook, FaUserShield } from 'react-icons/fa'

const AdminSectionLinks = ({ isBorged }) => {
  return (
    <>
      {isBorged && (
        <div className="admin-section-links__unborg">
          <FaUserShield size={12} className="admin-section-links__icon" />
          <LinkNode
            type="restricted_superdoc"
            title="nate's secret unborg doc"
            display="Unborg Yourself"
          />
        </div>
      )}
      <ul className="admin-section-links__list">
        <li className="admin-section-links__item">
          <FaSkullCrossbones size={12} className="admin-section-links__icon" />
          <LinkNode type="restricted_superdoc" title="The Node Crypt" />
        </li>
        <li className="admin-section-links__item">
          <FaEdit size={12} className="admin-section-links__icon" />
          <LinkNode type="restricted_superdoc" title="Edit These E2 Titles" />
        </li>
        <li className="admin-section-links__item">
          <FaBook size={12} className="admin-section-links__icon" />
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
