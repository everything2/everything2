import React, { useState } from 'react'
import MessageModal from './MessageModal'

/**
 * MessageBox - Inline message input that triggers MessageModal
 *
 * Used on user homenodes to send a quick message to that user.
 * Can show as a button or as an envelope icon (showAsIcon prop).
 */
const MessageBox = ({ recipientId, recipientTitle, showAsIcon = false }) => {
  const [isModalOpen, setIsModalOpen] = useState(false)

  const handleSend = async (recipient, message) => {
    try {
      const response = await fetch('/api/messages/create', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'same-origin',
        body: JSON.stringify({
          for_id: recipientId,
          message: message
        })
      })

      if (!response.ok) {
        throw new Error('Failed to send message')
      }

      const result = await response.json()
      // API returns successes/errors counts, not success boolean
      if (result.successes || result.ignores === undefined) {
        return true
      } else if (result.ignores) {
        throw new Error('User is blocking messages from you')
      } else {
        throw new Error(result.error || 'Failed to send message')
      }
    } catch (error) {
      throw error
    }
  }

  return (
    <>
      {showAsIcon ? (
        <button
          type="button"
          onClick={() => setIsModalOpen(true)}
          title={`Send message to ${recipientTitle}`}
          className="message-box__icon-btn"
        >
          ✉
        </button>
      ) : (
        <button
          type="button"
          onClick={() => setIsModalOpen(true)}
          className="message-box__text-btn"
        >
          Send Message
        </button>
      )}

      <MessageModal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        replyTo={{
          author_user: {
            node_id: recipientId,
            title: recipientTitle,
            type: 'user'
          }
        }}
        onSend={handleSend}
      />
    </>
  )
}

export default MessageBox
