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
      <table style={{ width: '100%', cellPadding: 0, cellSpacing: 1, border: 0 }}>
        <tbody>
          <tr style={{ backgroundColor: '#CCCCCC' }}>
            <th style={{ textAlign: 'left', padding: '4px 8px' }}>To:</th>
            <td style={{ width: '100%', padding: '4px 8px' }}>
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
          <tr style={{ backgroundColor: '#CCCCCC' }}>
            <th style={{ textAlign: 'left', padding: '4px 8px' }}>From:</th>
            <td style={{ width: '100%', padding: '4px 8px' }}>
              {mail.from_address || <em>nobody</em>}
            </td>
          </tr>
        </tbody>
      </table>

      {/* Mail body */}
      <div
        className="content"
        style={{ marginTop: '10px' }}
        dangerouslySetInnerHTML={{ __html: getSanitizedHtml(mail.doctext) }}
      />

      {/* Edit link for admins */}
      {Boolean(can_edit) && (
        <div style={{ marginTop: '20px', fontSize: '0.9em' }}>
          <a href={`?displaytype=basicedit`}>Edit this mail</a>
        </div>
      )}
    </div>
  )
}

export default Mail
