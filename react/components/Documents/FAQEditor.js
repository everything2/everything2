import React, { useState } from 'react'

/**
 * FAQ Editor - Create/edit FAQ entries
 *
 * Admin tool for managing FAQ database entries.
 * Handles question, answer, and keywords fields.
 */
const FAQEditor = ({ data, e2 }) => {
  const {
    error,
    faq_id = 0,
    question: initialQuestion = '',
    answer: initialAnswer = '',
    keywords: initialKeywords = '',
    success_message = ''
  } = data

  const [question, setQuestion] = useState(initialQuestion)
  const [answer, setAnswer] = useState(initialAnswer)
  const [keywords, setKeywords] = useState(initialKeywords)

  if (error) {
    return (
      <div style={styles.container}>
        <div style={styles.error}>{error}</div>
      </div>
    )
  }

  return (
    <div style={styles.container}>
      <h2 style={styles.heading}>FAQ Editor</h2>

      {success_message && (
        <div style={styles.success}>{success_message}</div>
      )}

      <form method="post">
        <input type="hidden" name="node_id" value={e2?.node_id || ''} />
        {faq_id > 0 && (
          <input type="hidden" name="edit_faq" value={faq_id} />
        )}

        <div style={styles.formGroup}>
          <label style={styles.label}>Question:</label>
          <textarea
            name="faq_question"
            rows="6"
            cols="40"
            value={question}
            onChange={(e) => setQuestion(e.target.value)}
            style={styles.textarea}
          />
        </div>

        <div style={styles.formGroup}>
          <label style={styles.label}>Answer:</label>
          <textarea
            name="faq_answer"
            rows="6"
            cols="40"
            value={answer}
            onChange={(e) => setAnswer(e.target.value)}
            style={styles.textarea}
          />
        </div>

        <div style={styles.formGroup}>
          <label style={styles.label}>Keywords (separated by commas):</label>
          <textarea
            name="faq_keywords"
            rows="1"
            cols="40"
            value={keywords}
            onChange={(e) => setKeywords(e.target.value)}
            style={styles.textarea}
          />
        </div>

        <div style={styles.buttonGroup}>
          <button
            type="submit"
            name="sexisgood"
            value="1"
            style={styles.submitButton}
          >
            {faq_id > 0 ? 'Update FAQ' : 'Create FAQ'}
          </button>
        </div>
      </form>

      {faq_id > 0 && (
        <div style={styles.info}>
          <p>Editing FAQ entry #{faq_id}</p>
        </div>
      )}
    </div>
  )
}

const styles = {
  container: {
    fontSize: '13px',
    lineHeight: '1.6',
    color: '#111',
    maxWidth: '700px',
    margin: '0 auto',
    padding: '20px'
  },
  heading: {
    fontSize: '18px',
    fontWeight: 'bold',
    color: '#38495e',
    marginBottom: '20px',
    borderBottom: '2px solid #38495e',
    paddingBottom: '8px'
  },
  error: {
    padding: '15px',
    backgroundColor: '#ffebee',
    border: '1px solid #f44336',
    borderRadius: '4px',
    color: '#c62828',
    marginBottom: '20px'
  },
  success: {
    padding: '15px',
    backgroundColor: '#e8f5e9',
    border: '1px solid #4caf50',
    borderRadius: '4px',
    color: '#2e7d32',
    marginBottom: '20px'
  },
  formGroup: {
    marginBottom: '20px'
  },
  label: {
    display: 'block',
    fontWeight: '600',
    marginBottom: '8px',
    color: '#38495e'
  },
  textarea: {
    width: '100%',
    maxWidth: '600px',
    padding: '8px 12px',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    fontSize: '13px',
    fontFamily: 'inherit',
    lineHeight: '1.5',
    resize: 'vertical'
  },
  buttonGroup: {
    marginTop: '20px',
    paddingTop: '20px',
    borderTop: '1px solid #dee2e6'
  },
  submitButton: {
    padding: '10px 20px',
    border: '1px solid #4060b0',
    borderRadius: '4px',
    backgroundColor: '#4060b0',
    color: '#fff',
    fontSize: '14px',
    cursor: 'pointer',
    fontWeight: '600'
  },
  info: {
    marginTop: '20px',
    padding: '12px',
    backgroundColor: '#f8f9f9',
    borderRadius: '4px',
    fontSize: '12px',
    color: '#666'
  }
}

export default FAQEditor
