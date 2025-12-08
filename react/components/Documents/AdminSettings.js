import React, { useState, useCallback } from 'react';

/**
 * AdminSettings - Editor settings and macro management
 *
 * Features:
 * - Editor-specific display options
 * - Macro management for chatterbox commands
 * - Links to macro FAQ for help
 */
const AdminSettings = ({ data }) => {
  const {
    editorPreferences = {},
    macros: initialMacros = [],
    maxMacroLength = 768,
    error,
    message
  } = data;

  // Editor preferences state
  const [editorPrefs, setEditorPrefs] = useState(editorPreferences);

  // Macros state
  const [macros, setMacros] = useState(initialMacros);

  // Form state
  const [isDirty, setIsDirty] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [saveError, setSaveError] = useState(null);
  const [saveSuccess, setSaveSuccess] = useState(false);

  // Handle error states
  if (error === 'guest') {
    return (
      <div style={styles.container}>
        <div style={styles.error}>
          <p>{message || 'You must be logged in to view settings.'}</p>
          <p>
            <a href="/title/Sign%20up" style={styles.link}>Register</a> or{' '}
            <a href="/title/Login" style={styles.link}>Log in</a> to continue.
          </p>
        </div>
      </div>
    );
  }

  if (error === 'permission') {
    return (
      <div style={styles.container}>
        <div style={styles.error}>
          <p>{message || 'Admin Settings is only available to Content Editors and gods.'}</p>
        </div>
      </div>
    );
  }

  // Handle editor preference toggle
  const handleTogglePref = useCallback((prefKey) => {
    setEditorPrefs(prev => ({
      ...prev,
      [prefKey]: prev[prefKey] ? 0 : 1
    }));
    setIsDirty(true);
    setSaveSuccess(false);
  }, []);

  // Handle macro enabled toggle
  const handleToggleMacro = useCallback((macroName) => {
    setMacros(prev => prev.map(m =>
      m.name === macroName ? { ...m, enabled: m.enabled ? 0 : 1 } : m
    ));
    setIsDirty(true);
    setSaveSuccess(false);
  }, []);

  // Handle macro text change
  const handleMacroTextChange = useCallback((macroName, newText) => {
    setMacros(prev => prev.map(m =>
      m.name === macroName ? { ...m, text: newText } : m
    ));
    setIsDirty(true);
    setSaveSuccess(false);
  }, []);

  // Handle save
  const handleSave = async () => {
    setIsSaving(true);
    setSaveError(null);
    setSaveSuccess(false);

    try {
      // Build the settings payload
      const payload = {
        settings: { ...editorPrefs },
        macros: {}
      };

      // Add macros to payload
      macros.forEach(macro => {
        if (macro.enabled) {
          // Convert curly braces to square brackets for storage
          let text = macro.text;
          text = text.replace(/\{/g, '[');
          text = text.replace(/\}/g, ']');
          // Clean up line endings
          text = text.replace(/\r/g, '\n');
          text = text.replace(/\n+/g, '\n');
          // Limit length
          text = text.substring(0, maxMacroLength);
          payload.macros[macro.name] = text;
        } else {
          payload.macros[macro.name] = null; // Will delete the macro
        }
      });

      const response = await fetch('/api/preferences/admin', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(payload)
      });

      const result = await response.json();

      if (result.success) {
        setIsDirty(false);
        setSaveSuccess(true);
        // Clear success message after a few seconds
        setTimeout(() => setSaveSuccess(false), 3000);
      } else {
        setSaveError(result.error || 'Failed to save settings');
      }
    } catch (err) {
      setSaveError('Network error: ' + err.message);
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div style={styles.container}>
      {/* Settings Navigation */}
      <div style={styles.settingsNav}>
        <a href="/title/Settings" style={styles.navLink}>Settings</a>
        <span style={styles.navSeparator}>|</span>
        <a href="/title/Advanced%20Settings" style={styles.navLink}>Advanced Settings</a>
        <span style={styles.navSeparator}>|</span>
        <strong style={styles.navCurrent}>Admin Settings</strong>
        <span style={styles.navSeparator}>|</span>
        <a href="/title/Nodelet%20Settings" style={styles.navLink}>Nodelet Settings</a>
        <span style={styles.navSeparator}>|</span>
        <a href={`/node/${data.currentUser?.node_id}?displaytype=edit`} style={styles.navLink}>Profile</a>
      </div>

      <h2 style={styles.title}>Admin Settings</h2>

      {/* Save status */}
      {saveError && (
        <div style={styles.errorBanner}>
          {saveError}
        </div>
      )}
      {saveSuccess && (
        <div style={styles.successBanner}>
          Settings saved successfully!
        </div>
      )}

      {/* Editor Options */}
      <section style={styles.section}>
        <h3 style={styles.sectionTitle}>Editor Stuff</h3>

        <div style={styles.checkboxGroup}>
          <label style={styles.checkboxLabel}>
            <input
              type="checkbox"
              checked={Boolean(editorPrefs.hidenodenotes)}
              onChange={() => handleTogglePref('hidenodenotes')}
              style={styles.checkbox}
            />
            Hide Node Notes
          </label>
        </div>
      </section>

      {/* Macros Section */}
      <section style={styles.section}>
        <h3 style={styles.sectionTitle}>Macros</h3>

        <table style={styles.table}>
          <thead>
            <tr>
              <th style={styles.th}>Use?</th>
              <th style={styles.th}>Name</th>
              <th style={styles.th}>Text</th>
            </tr>
          </thead>
          <tbody>
            {macros.map((macro) => (
              <tr key={macro.name}>
                <td style={styles.tdUse}>
                  <input
                    type="checkbox"
                    checked={Boolean(macro.enabled)}
                    onChange={() => handleToggleMacro(macro.name)}
                    style={styles.checkbox}
                  />
                </td>
                <td style={styles.tdName}>
                  <code>{macro.name}</code>
                </td>
                <td style={styles.tdText}>
                  <textarea
                    value={macro.text}
                    onChange={(e) => handleMacroTextChange(macro.name, e.target.value)}
                    rows={6}
                    style={styles.textarea}
                    maxLength={maxMacroLength}
                  />
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        <div style={styles.macroHelp}>
          <p>
            If you will use a macro, make sure the "Use" column is checked.
            If you won't use it, uncheck it, and it will be deleted.
            The text in the "macro" area of a "non-use" macro is the default text,
            although you can change it (but be sure to check the "use" checkbox if you want to keep it).
          </p>
          <p>
            Each macro must currently begin with <code>/say</code> (which indicates that you're saying something).
            Note: each macro is limited to {maxMacroLength} characters.
          </p>
          <p>
            Note: instead of square brackets, [ and ],
            you'll have to use curly brackets, {'{'} and {'}'} instead.
          </p>
          <p>
            There is more information about macros at{' '}
            <a href="/title/macro%20FAQ" style={styles.link}>macro FAQ</a>.
          </p>
        </div>
      </section>

      {/* Save Button */}
      <div style={styles.saveSection}>
        <button
          onClick={handleSave}
          disabled={!isDirty || isSaving}
          style={{
            ...styles.saveButton,
            opacity: (!isDirty || isSaving) ? 0.6 : 1,
            cursor: (!isDirty || isSaving) ? 'not-allowed' : 'pointer'
          }}
        >
          {isSaving ? 'Saving...' : 'Save Settings'}
        </button>
        {isDirty && (
          <span style={styles.unsavedNotice}>You have unsaved changes</span>
        )}
      </div>
    </div>
  );
};

const styles = {
  container: {
    maxWidth: '900px',
    margin: '0 auto',
    padding: '20px'
  },
  settingsNav: {
    marginBottom: '20px',
    padding: '10px',
    backgroundColor: '#f8f9f9',
    borderRadius: '4px',
    textAlign: 'center'
  },
  navLink: {
    color: '#4060b0',
    textDecoration: 'none'
  },
  navSeparator: {
    margin: '0 8px',
    color: '#888888'
  },
  navCurrent: {
    color: '#111111'
  },
  title: {
    color: '#38495e',
    marginBottom: '20px'
  },
  section: {
    marginBottom: '32px'
  },
  sectionTitle: {
    color: '#38495e',
    marginBottom: '16px',
    borderBottom: '1px solid #dee2e6',
    paddingBottom: '8px'
  },
  checkboxGroup: {
    marginBottom: '12px'
  },
  checkboxLabel: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    cursor: 'pointer'
  },
  checkbox: {
    cursor: 'pointer'
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    marginBottom: '16px'
  },
  th: {
    backgroundColor: '#f8f9f9',
    border: '1px solid #dee2e6',
    padding: '8px',
    textAlign: 'left'
  },
  tdUse: {
    border: '1px solid #dee2e6',
    padding: '8px',
    textAlign: 'center',
    verticalAlign: 'top',
    width: '50px'
  },
  tdName: {
    border: '1px solid #dee2e6',
    padding: '8px',
    verticalAlign: 'top',
    whiteSpace: 'nowrap',
    width: '80px'
  },
  tdText: {
    border: '1px solid #dee2e6',
    padding: '8px',
    verticalAlign: 'top'
  },
  textarea: {
    width: '100%',
    minWidth: '400px',
    fontFamily: 'monospace',
    fontSize: '13px',
    padding: '8px',
    border: '1px solid #dee2e6',
    borderRadius: '4px',
    resize: 'vertical'
  },
  macroHelp: {
    color: '#507898',
    fontSize: '14px',
    lineHeight: '1.5'
  },
  link: {
    color: '#4060b0',
    textDecoration: 'none'
  },
  saveSection: {
    display: 'flex',
    alignItems: 'center',
    gap: '16px',
    marginTop: '24px',
    paddingTop: '16px',
    borderTop: '1px solid #dee2e6'
  },
  saveButton: {
    padding: '10px 24px',
    backgroundColor: '#4060b0',
    color: '#ffffff',
    border: 'none',
    borderRadius: '4px',
    fontSize: '14px',
    fontWeight: 'bold'
  },
  unsavedNotice: {
    color: '#dc3545',
    fontStyle: 'italic'
  },
  error: {
    padding: '20px',
    backgroundColor: '#ffebee',
    border: '1px solid #f44336',
    borderRadius: '4px',
    textAlign: 'center'
  },
  errorBanner: {
    padding: '12px',
    backgroundColor: '#ffebee',
    border: '1px solid #f44336',
    borderRadius: '4px',
    marginBottom: '16px',
    color: '#c62828'
  },
  successBanner: {
    padding: '12px',
    backgroundColor: '#e8f5e9',
    border: '1px solid #4caf50',
    borderRadius: '4px',
    marginBottom: '16px',
    color: '#2e7d32'
  }
};

export default AdminSettings;
