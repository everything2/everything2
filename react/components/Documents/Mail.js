import React from 'react'
import LinkNode from '../LinkNode'
import { renderE2Content } from '../Editor/E2HtmlSanitizer'

/**
 * Mail Component - Display mail nodes
 *
 * Renders mail messages with:
 * - To: recipient (author_user)
 * - From: sender address
 * - Body: doctext content with E2 link parsing
 *
 * Edit uses the standard basicedit form (gods only)
 *
 * Data comes from Everything::Controller::mail
 */
const Mail = ({ data }) => {
  const { mail, can_edit } = data

  if (!mail) {
    return <div className="error">Mail not found</div>
  }

  // Get sanitized HTML for display
  const getSanitizedHtml = (text) => {
    if (!text) return ''
    const { html } = renderE2Content(text)
    return html
  }

  return (
    <div className="mail-page">
      {/* Mail header table */}
      <table className="mail__table">
        <tbody>
          <tr className="mail__header-row">
            <th className="mail__header-cell">To:</th>
            <td className="mail__data-cell">
              {mail.recipient ? (
                <LinkNode
                  nodeId={mail.recipient.node_id}
                  title={mail.recipient.title}
                  type="user"
                />
              ) : (
                <em>nobody</em>
              )}
            </td>
          </tr>
          <tr className="mail__header-row">
            <th className="mail__header-cell">From:</th>
            <td className="mail__data-cell">
              {mail.from_address || <em>nobody</em>}
            </td>
          </tr>
        </tbody>
      </table>

      {/* Mail body */}
      <div
        className="content mail__body"
        dangerouslySetInnerHTML={{ __html: getSanitizedHtml(mail.doctext) }}
      />

      {/* Edit link for admins */}
      {Boolean(can_edit) && (
        <div className="mail__edit-link">
          <a href={`?displaytype=basicedit`}>Edit this mail</a>
        </div>
      )}
    </div>
  )
}

export default Mail
