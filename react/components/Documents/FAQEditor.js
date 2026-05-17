import React, { useState } from 'react'

/**
 * FAQ Editor - Create/edit FAQ entries
 * Styles in CSS: .faq-editor__*
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
      <div className="faq-editor">
        <div className="faq-editor__error">{error}</div>
      </div>
    )
  }

  return (
    <div className="faq-editor">
      {success_message && (
        <div className="faq-editor__success">{success_message}</div>
      )}

      <form method="post">
        <input type="hidden" name="node_id" value={e2?.node_id || ''} />
        {faq_id > 0 && (
          <input type="hidden" name="edit_faq" value={faq_id} />
        )}

        <div className="faq-editor__form-group">
          <label className="faq-editor__label">Question:</label>
          <textarea
            name="faq_question"
            rows="6"
            cols="40"
            value={question}
            onChange={(e) => setQuestion(e.target.value)}
            className="faq-editor__textarea"
          />
        </div>

        <div className="faq-editor__form-group">
          <label className="faq-editor__label">Answer:</label>
          <textarea
            name="faq_answer"
            rows="6"
            cols="40"
            value={answer}
            onChange={(e) => setAnswer(e.target.value)}
            className="faq-editor__textarea"
          />
        </div>

        <div className="faq-editor__form-group">
          <label className="faq-editor__label">Keywords (separated by commas):</label>
          <textarea
            name="faq_keywords"
            rows="1"
            cols="40"
            value={keywords}
            onChange={(e) => setKeywords(e.target.value)}
            className="faq-editor__textarea"
          />
        </div>

        <div className="faq-editor__button-group">
          <button
            type="submit"
            name="sexisgood"
            value="1"
            className="faq-editor__submit-button"
          >
            {faq_id > 0 ? 'Update FAQ' : 'Create FAQ'}
          </button>
        </div>
      </form>

      {faq_id > 0 && (
        <div className="faq-editor__info">
          <p>Editing FAQ entry #{faq_id}</p>
        </div>
      )}
    </div>
  )
}

export default FAQEditor
