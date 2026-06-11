import React, { useState } from 'react';

/**
 * EdevDocumentationIndex - Developer documentation index page
 *
 * Shows list of edev documentation and allows developers to create new docs.
 * Styles are in CSS classes (edev-docs__*)
 */
export default function EdevDocumentationIndex({ data }) {
  const { docs = [], is_developer } = data;
  const [newDocTitle, setNewDocTitle] = useState('');

  const handleCreateDoc = (e) => {
    e.preventDefault();
    if (!newDocTitle.trim()) return;

    // Create a form and submit it
    const form = document.createElement('form');
    form.method = 'POST';
    form.action = '/index.pl';

    // Add hidden fields for node creation
    const fields = {
      op: 'new',
      type: 'edevdoc',
      displaytype: 'edit',
      node: newDocTitle.trim()
    };

    Object.entries(fields).forEach(([name, value]) => {
      const input = document.createElement('input');
      input.type = 'hidden';
      input.name = name;
      input.value = value;
      form.appendChild(input);
    });

    document.body.appendChild(form);
    form.submit();
  };

  return (
    <div className="edev-docs">
      <h2 className="edev-docs__heading">
        Edev Documentation Index
      </h2>

      {docs.length === 0 ? (
        <p className="edev-docs__empty">
          Looks pretty lonely...
        </p>
      ) : (
        <div className="edev-docs__grid">
          {docs.map((doc) => (
            <a
              key={doc.node_id}
              href={`/title/${encodeURIComponent(doc.title)}?node_id=${doc.node_id}`}
              className="edev-docs__doc-link"
            >
              <svg
                stroke="currentColor"
                fill="currentColor"
                strokeWidth="0"
                viewBox="0 0 384 512"
                height="16"
                width="16"
                xmlns="http://www.w3.org/2000/svg"
                className="edev-docs__doc-icon"
              >
                <path d="M224 136V0H24C10.7 0 0 10.7 0 24v464c0 13.3 10.7 24 24 24h336c13.3 0 24-10.7 24-24V160H248c-13.2 0-24-10.8-24-24zm64 236c0 6.6-5.4 12-12 12H108c-6.6 0-12-5.4-12-12v-8c0-6.6 5.4-12 12-12h168c6.6 0 12 5.4 12 12v8zm0-64c0 6.6-5.4 12-12 12H108c-6.6 0-12-5.4-12-12v-8c0-6.6 5.4-12 12-12h168c6.6 0 12 5.4 12 12v8zm0-72v8c0 6.6-5.4 12-12 12H108c-6.6 0-12-5.4-12-12v-8c0-6.6 5.4-12 12-12h168c6.6 0 12 5.4 12 12zm96-114.1v6.1H256V0h6.1c6.4 0 12.5 2.5 17 7l97.9 98c4.5 4.5 7 10.6 7 16.9z"></path>
              </svg>
              <span className="edev-docs__doc-title">{doc.title}</span>
            </a>
          ))}
        </div>
      )}

      {!!is_developer && (
        <div className="edev-docs__create-box">
          <h3 className="edev-docs__create-heading">
            <svg
              stroke="currentColor"
              fill="currentColor"
              strokeWidth="0"
              viewBox="0 0 448 512"
              height="20"
              width="20"
              xmlns="http://www.w3.org/2000/svg"
              className="edev-docs__create-icon"
            >
              <path d="M416 208H272V64c0-17.67-14.33-32-32-32h-32c-17.67 0-32 14.33-32 32v144H32c-17.67 0-32 14.33-32 32v32c0 17.67 14.33 32 32 32h144v144c0 17.67 14.33 32 32 32h32c17.67 0 32-14.33 32-32V304h144c17.67 0 32-14.33 32-32v-32c0-17.67-14.33-32-32-32z"></path>
            </svg>
            Create New Edev Documentation
          </h3>

          <form onSubmit={handleCreateDoc}>
            <div className="edev-docs__form-row">
              <div className="edev-docs__input-wrapper">
                <input
                  type="text"
                  value={newDocTitle}
                  onChange={(e) => setNewDocTitle(e.target.value)}
                  placeholder="Enter document title..."
                  className="edev-docs__input"
                />
                <p className="edev-docs__help-text">
                  Edevdocs are only visible to members of the edev group
                </p>
              </div>

              <button
                type="submit"
                disabled={!newDocTitle.trim()}
                className="edev-docs__submit"
              >
                Create Doc
              </button>
            </div>
          </form>
        </div>
      )}

      <div className="edev-docs__info-box">
        <p className="edev-docs__info-text">
          <strong>What are Edevdocs?</strong> These are developer documentation pages that can only be viewed and edited by members of the{' '}
          <a href="/user/edev" className="edev-docs__info-link">edev</a> usergroup. They're useful for testing APIs, documenting internal features, or writing experimental JavaScript.
        </p>
      </div>
    </div>
  );
}
