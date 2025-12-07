import React, { useState } from 'react';

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
      <div style={styles.container}>
        <div style={styles.error}>
          <strong>Permission Denied.</strong>
          <p>The Spam Cannon is only available to Content Editors.</p>
        </div>
      </div>
    );
  }

  return (
    <div style={styles.container}>
      <div style={styles.description}>
        <p>
          The Spam Cannon sends a single /msg to multiple recipients, without having
          to create a usergroup. You can enter usernames or usergroups you're a member of.
        </p>
        <p style={styles.warning}>
          The privilege of using this tool will be revoked if abused.
        </p>
      </div>

      <form onSubmit={handleSubmit} style={styles.form}>
        <div style={styles.formRow}>
          <div style={styles.labelColumn}>
            <label style={styles.label}>Recipients:</label>
            <p style={styles.hint}>
              Put each username on its own line, and don't hardlink them.
              Don't bother with underscores.
            </p>
            <p style={styles.hint}>
              Maximum: {max_recipients} recipients
            </p>
          </div>
          <div style={styles.inputColumn}>
            <textarea
              style={styles.textarea}
              value={recipients}
              onChange={(e) => setRecipients(e.target.value)}
              rows={12}
              placeholder="username1&#10;username2&#10;username3"
              disabled={sending}
            />
          </div>
        </div>

        <div style={styles.formRow}>
          <div style={styles.labelColumn}>
            <label style={styles.label}>Message:</label>
            <p style={styles.hint}>
              Max 243 characters
            </p>
          </div>
          <div style={styles.inputColumn}>
            <input
              type="text"
              style={styles.textInput}
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              maxLength={243}
              placeholder="Your message here..."
              disabled={sending}
            />
            <div style={styles.charCount}>
              {message.length}/243
            </div>
          </div>
        </div>

        <div style={styles.formRow}>
          <div style={styles.labelColumn}></div>
          <div style={styles.inputColumn}>
            <button
              type="submit"
              style={{
                ...styles.button,
                ...(sending ? styles.buttonDisabled : {})
              }}
              disabled={sending}
            >
              {sending ? 'Sending...' : 'Send'}
            </button>
          </div>
        </div>
      </form>

      {result && (
        <div style={styles.result}>
          {result.success ? (
            <>
              {result.sent_to && result.sent_to.length > 0 && (
                <div style={styles.successBox}>
                  <h4 style={styles.resultHeading}>Sent message:</h4>
                  <p style={styles.messagePreview}>{result.message}</p>

                  <h4 style={styles.resultHeading}>To users:</h4>
                  <ul style={styles.userList}>
                    {result.sent_to.map((username, index) => (
                      <li key={index}>
                        <a href={`/title/${encodeURIComponent(username)}`} style={styles.userLink}>
                          {username}
                        </a>
                      </li>
                    ))}
                  </ul>
                </div>
              )}

              {result.errors && result.errors.length > 0 && (
                <div style={styles.warningBox}>
                  <h4 style={styles.resultHeading}>Issues:</h4>
                  <ul style={styles.errorList}>
                    {result.errors.map((err, i) => (
                      <li key={i}>{err}</li>
                    ))}
                  </ul>
                </div>
              )}

              {(!result.sent_to || result.sent_to.length === 0) && (
                <div style={styles.warningBox}>
                  <p>No messages were sent.</p>
                  {result.errors && result.errors.length > 0 && (
                    <ul style={styles.errorList}>
                      {result.errors.map((err, i) => (
                        <li key={i}>{err}</li>
                      ))}
                    </ul>
                  )}
                </div>
              )}
            </>
          ) : (
            <div style={styles.errorBox}>
              <strong>Error:</strong> {result.error}
            </div>
          )}
        </div>
      )}
    </div>
  );
};

const styles = {
  container: {
    maxWidth: '800px',
    margin: '0 auto',
    padding: '20px',
    fontSize: '16px',
    lineHeight: '1.6',
    color: '#111111'
  },
  description: {
    marginBottom: '20px',
    padding: '15px',
    background: '#f8f9f9',
    border: '1px solid #dee2e6',
    borderRadius: '4px'
  },
  warning: {
    color: '#c00000',
    fontWeight: 'bold',
    marginBottom: 0
  },
  form: {
    marginBottom: '20px'
  },
  formRow: {
    display: 'flex',
    marginBottom: '15px'
  },
  labelColumn: {
    width: '150px',
    paddingRight: '15px',
    textAlign: 'right'
  },
  inputColumn: {
    flex: 1
  },
  label: {
    fontWeight: 'bold',
    display: 'block',
    marginBottom: '5px'
  },
  hint: {
    fontSize: '13px',
    color: '#507898',
    fontStyle: 'italic',
    margin: '5px 0'
  },
  textarea: {
    width: '100%',
    padding: '10px',
    fontSize: '14px',
    fontFamily: 'inherit',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    resize: 'vertical',
    boxSizing: 'border-box'
  },
  textInput: {
    width: '100%',
    padding: '10px',
    fontSize: '14px',
    fontFamily: 'inherit',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    boxSizing: 'border-box'
  },
  charCount: {
    fontSize: '12px',
    color: '#507898',
    textAlign: 'right',
    marginTop: '5px'
  },
  button: {
    padding: '10px 20px',
    fontSize: '16px',
    fontWeight: 'bold',
    background: '#4060b0',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer'
  },
  buttonDisabled: {
    background: '#999',
    cursor: 'not-allowed'
  },
  result: {
    marginTop: '20px'
  },
  successBox: {
    padding: '15px',
    background: '#e8f5e9',
    border: '1px solid #4caf50',
    borderRadius: '4px',
    marginBottom: '15px'
  },
  warningBox: {
    padding: '15px',
    background: '#fff3e0',
    border: '1px solid #ff9800',
    borderRadius: '4px',
    marginBottom: '15px'
  },
  errorBox: {
    padding: '15px',
    background: '#ffebee',
    border: '1px solid #f44336',
    borderRadius: '4px'
  },
  error: {
    padding: '20px',
    background: '#ffebee',
    border: '1px solid #f44336',
    borderRadius: '4px',
    textAlign: 'center'
  },
  resultHeading: {
    margin: '0 0 10px 0',
    fontSize: '14px',
    color: '#38495e'
  },
  messagePreview: {
    padding: '10px',
    background: 'rgba(255,255,255,0.5)',
    borderRadius: '4px',
    marginBottom: '15px',
    fontStyle: 'italic'
  },
  userList: {
    margin: 0,
    paddingLeft: '20px'
  },
  errorList: {
    margin: 0,
    paddingLeft: '20px',
    color: '#c00000'
  },
  userLink: {
    color: '#4060b0',
    textDecoration: 'none'
  }
};

export default SpamCannon;
