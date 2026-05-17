import React, { useState, useCallback } from 'react';

/**
 * AdminSettings - Editor settings and macro management
 * Styles in CSS: .admin-settings__*
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
      <div className="admin-settings">
        <div className="admin-settings__error">
          <p>{message || 'You must be logged in to view settings.'}</p>
          <p>
            <a href="/title/Sign%20up" className="admin-settings__link">Register</a> or{' '}
            <a href="/title/Login" className="admin-settings__link">Log in</a> to continue.
          </p>
        </div>
      </div>
    );
  }

  if (error === 'permission') {
    return (
      <div className="admin-settings">
        <div className="admin-settings__error">
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
    <div className="admin-settings">
      {/* Settings Navigation */}
      <div className="admin-settings__nav">
        <a href="/title/Settings" className="admin-settings__nav-link">Settings</a>
        <span className="admin-settings__nav-separator">|</span>
        <a href="/title/Advanced%20Settings" className="admin-settings__nav-link">Advanced Settings</a>
        <span className="admin-settings__nav-separator">|</span>
        <strong className="admin-settings__nav-current">Admin Settings</strong>
        <span className="admin-settings__nav-separator">|</span>
        <a href="/title/Nodelet%20Settings" className="admin-settings__nav-link">Nodelet Settings</a>
        <span className="admin-settings__nav-separator">|</span>
        <a href={`/node/${data.currentUser?.node_id}?displaytype=edit`} className="admin-settings__nav-link">Profile</a>
      </div>

      <h2 className="admin-settings__title">Admin Settings</h2>

      {/* Save status */}
      {saveError && (
        <div className="admin-settings__error-banner">
          {saveError}
        </div>
      )}
      {saveSuccess && (
        <div className="admin-settings__success-banner">
          Settings saved successfully!
        </div>
      )}

      {/* Editor Options */}
      <section className="admin-settings__section">
        <h3 className="admin-settings__section-title">Editor Stuff</h3>

        <div className="admin-settings__checkbox-group">
          <label className="admin-settings__checkbox-label">
            <input
              type="checkbox"
              checked={Boolean(editorPrefs.hidenodenotes)}
              onChange={() => handleTogglePref('hidenodenotes')}
              className="admin-settings__checkbox"
            />
            Hide Node Notes
          </label>
        </div>
      </section>

      {/* Macros Section */}
      <section className="admin-settings__section">
        <h3 className="admin-settings__section-title">Macros</h3>

        <table className="admin-settings__table">
          <thead>
            <tr>
              <th className="admin-settings__th">Use?</th>
              <th className="admin-settings__th">Name</th>
              <th className="admin-settings__th">Text</th>
            </tr>
          </thead>
          <tbody>
            {macros.map((macro) => (
              <tr key={macro.name}>
                <td className="admin-settings__td-use">
                  <input
                    type="checkbox"
                    checked={Boolean(macro.enabled)}
                    onChange={() => handleToggleMacro(macro.name)}
                    className="admin-settings__checkbox"
                  />
                </td>
                <td className="admin-settings__td-name">
                  <code>{macro.name}</code>
                </td>
                <td className="admin-settings__td-text">
                  <textarea
                    value={macro.text}
                    onChange={(e) => handleMacroTextChange(macro.name, e.target.value)}
                    rows={6}
                    className="admin-settings__textarea"
                    maxLength={maxMacroLength}
                  />
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        <div className="admin-settings__macro-help">
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
            <a href="/title/macro%20FAQ" className="admin-settings__link">macro FAQ</a>.
          </p>
        </div>
      </section>

      {/* Save Button */}
      <div className="admin-settings__save-section">
        <button
          onClick={handleSave}
          disabled={!isDirty || isSaving}
          className={`admin-settings__save-button${(!isDirty || isSaving) ? ' admin-settings__save-button--disabled' : ''}`}
        >
          {isSaving ? 'Saving...' : 'Save Settings'}
        </button>
        {isDirty && (
          <span className="admin-settings__unsaved-notice">You have unsaved changes</span>
        )}
      </div>
    </div>
  );
};

export default AdminSettings;
