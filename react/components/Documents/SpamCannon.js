import React, { useState } from 'react';

/**
 * SpamCannon - Editor tool for bulk messaging
 * Styles in CSS: .spam-cannon__*
 */
const SpamCannon = ({ data, e2 }) => {
  const {
    is_editor = false,
    max_recipients = 20,
    username = ''
  } = data;

  const [recipients, setRecipients] = useState('');
  const [message, setMessage] = useState('');
  const [sending, setSending] = useState(false);
  const [result, setResult] = useState(null);

  const handleSubmit = async (e) => {
    e.preventDefault();

    if (!recipients.trim() || !message.trim()) {
      setResult({
        success: false,
        error: 'Please enter both recipients and a message'
      });
      return;
    }

    // Parse recipients (one per line)
    const recipientList = recipients
      .split('\n')
      .map(r => r.trim())
      .filter(r => r.length > 0);

    if (recipientList.length === 0) {
      setResult({
        success: false,
        error: 'Please enter at least one recipient'
      });
      return;
    }

    if (recipientList.length > max_recipients) {
      setResult({
        success: false,
        error: `Too many recipients. Maximum is ${max_recipients}.`
      });
      return;
    }

    setSending(true);
    setResult(null);

    try {
      const response = await fetch('/api/spamcannon', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          recipients: recipientList,
          message: message.trim()
        })
      });

      const json = await response.json();
      setResult(json);

      // Clear form on success
      if (json.success && json.sent_to && json.sent_to.length > 0) {
        setRecipients('');
        setMessage('');
      }
    } catch (err) {
      setResult({
        success: false,
        error: 'Failed to send message: ' + err.message
      });
    } finally {
      setSending(false);
    }
  };

  // Permission denied
  if (!is_editor) {
    return (
      <div className="spam-cannon">
        <div className="spam-cannon__error">
          <strong>Permission Denied.</strong>
          <p>The Spam Cannon is only available to Content Editors.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="spam-cannon">
      <div className="spam-cannon__description">
        <p>
          The Spam Cannon sends a single /msg to multiple recipients, without having
          to create a usergroup. You can enter usernames or usergroups you're a member of.
        </p>
        <p className="spam-cannon__warning">
          The privilege of using this tool will be revoked if abused.
        </p>
      </div>

      <form onSubmit={handleSubmit} className="spam-cannon__form">
        <div className="spam-cannon__form-row">
          <div className="spam-cannon__label-column">
            <label className="spam-cannon__label">Recipients:</label>
            <p className="spam-cannon__hint">
              Put each username on its own line, and don't hardlink them.
              Don't bother with underscores.
            </p>
            <p className="spam-cannon__hint">
              Maximum: {max_recipients} recipients
            </p>
          </div>
          <div className="spam-cannon__input-column">
            <textarea
              className="spam-cannon__textarea"
              value={recipients}
              onChange={(e) => setRecipients(e.target.value)}
              rows={12}
              placeholder="username1&#10;username2&#10;username3"
              disabled={sending}
            />
          </div>
        </div>

        <div className="spam-cannon__form-row">
          <div className="spam-cannon__label-column">
            <label className="spam-cannon__label">Message:</label>
            <p className="spam-cannon__hint">
              Max 243 characters
            </p>
          </div>
          <div className="spam-cannon__input-column">
            <input
              type="text"
              className="spam-cannon__text-input"
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              maxLength={243}
              placeholder="Your message here..."
              disabled={sending}
            />
            <div className="spam-cannon__char-count">
              {message.length}/243
            </div>
          </div>
        </div>

        <div className="spam-cannon__form-row">
          <div className="spam-cannon__label-column"></div>
          <div className="spam-cannon__input-column">
            <button
              type="submit"
              className={`spam-cannon__button${sending ? ' spam-cannon__button--disabled' : ''}`}
              disabled={sending}
            >
              {sending ? 'Sending...' : 'Send'}
            </button>
          </div>
        </div>
      </form>

      {result && (
        <div className="spam-cannon__result">
          {result.success ? (
            <>
              {result.sent_to && result.sent_to.length > 0 && (
                <div className="spam-cannon__success-box">
                  <h4 className="spam-cannon__result-heading">Sent message:</h4>
                  <p className="spam-cannon__message-preview">{result.message}</p>

                  <h4 className="spam-cannon__result-heading">To users:</h4>
                  <ul className="spam-cannon__user-list">
                    {result.sent_to.map((username, index) => (
                      <li key={index}>
                        <a href={`/title/${encodeURIComponent(username)}`} className="spam-cannon__user-link">
                          {username}
                        </a>
                      </li>
                    ))}
                  </ul>
                </div>
              )}

              {result.errors && result.errors.length > 0 && (
                <div className="spam-cannon__warning-box">
                  <h4 className="spam-cannon__result-heading">Issues:</h4>
                  <ul className="spam-cannon__error-list">
                    {result.errors.map((err, i) => (
                      <li key={i}>{err}</li>
                    ))}
                  </ul>
                </div>
              )}

              {(!result.sent_to || result.sent_to.length === 0) && (
                <div className="spam-cannon__warning-box">
                  <p>No messages were sent.</p>
                  {result.errors && result.errors.length > 0 && (
                    <ul className="spam-cannon__error-list">
                      {result.errors.map((err, i) => (
                        <li key={i}>{err}</li>
                      ))}
                    </ul>
                  )}
                </div>
              )}
            </>
          ) : (
            <div className="spam-cannon__error-box">
              <strong>Error:</strong> {result.error}
            </div>
          )}
        </div>
      )}
    </div>
  );
};

export default SpamCannon;
