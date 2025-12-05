import React, { useState } from 'react';

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
    <div style={{ padding: '20px', fontFamily: 'Arial, sans-serif' }}>
      <h2 style={{
        color: '#38495e',
        borderBottom: '2px solid #4060b0',
        paddingBottom: '10px',
        marginBottom: '20px'
      }}>
        Edev Documentation Index
      </h2>

      {docs.length === 0 ? (
        <p style={{
          fontStyle: 'italic',
          color: '#666',
          padding: '20px',
          backgroundColor: '#f8f9f9',
          borderRadius: '4px',
          textAlign: 'center'
        }}>
          Looks pretty lonely...
        </p>
      ) : (
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))',
          gap: '12px',
          marginBottom: '30px'
        }}>
          {docs.map((doc) => (
            <a
              key={doc.node_id}
              href={`/title/${encodeURIComponent(doc.title)}?node_id=${doc.node_id}`}
              style={{
                padding: '12px 16px',
                backgroundColor: '#f8f9f9',
                border: '1px solid #ddd',
                borderRadius: '4px',
                textDecoration: 'none',
                color: '#4060b0',
                transition: 'all 0.2s',
                display: 'flex',
                alignItems: 'center',
                gap: '8px'
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.backgroundColor = '#e8f4f8';
                e.currentTarget.style.borderColor = '#4060b0';
                e.currentTarget.style.transform = 'translateX(4px)';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.backgroundColor = '#f8f9f9';
                e.currentTarget.style.borderColor = '#ddd';
                e.currentTarget.style.transform = 'translateX(0)';
              }}
            >
              <svg
                stroke="currentColor"
                fill="currentColor"
                strokeWidth="0"
                viewBox="0 0 384 512"
                height="16"
                width="16"
                xmlns="http://www.w3.org/2000/svg"
                style={{ flexShrink: 0, color: '#507898' }}
              >
                <path d="M224 136V0H24C10.7 0 0 10.7 0 24v464c0 13.3 10.7 24 24 24h336c13.3 0 24-10.7 24-24V160H248c-13.2 0-24-10.8-24-24zm64 236c0 6.6-5.4 12-12 12H108c-6.6 0-12-5.4-12-12v-8c0-6.6 5.4-12 12-12h168c6.6 0 12 5.4 12 12v8zm0-64c0 6.6-5.4 12-12 12H108c-6.6 0-12-5.4-12-12v-8c0-6.6 5.4-12 12-12h168c6.6 0 12 5.4 12 12v8zm0-72v8c0 6.6-5.4 12-12 12H108c-6.6 0-12-5.4-12-12v-8c0-6.6 5.4-12 12-12h168c6.6 0 12 5.4 12 12zm96-114.1v6.1H256V0h6.1c6.4 0 12.5 2.5 17 7l97.9 98c4.5 4.5 7 10.6 7 16.9z"></path>
              </svg>
              <span style={{ fontWeight: '500' }}>{doc.title}</span>
            </a>
          ))}
        </div>
      )}

      {is_developer && (
        <div style={{
          marginTop: '30px',
          padding: '20px',
          backgroundColor: '#f8f9f9',
          border: '2px solid #4060b0',
          borderRadius: '8px'
        }}>
          <h3 style={{
            color: '#38495e',
            marginTop: 0,
            marginBottom: '15px',
            display: 'flex',
            alignItems: 'center',
            gap: '8px'
          }}>
            <svg
              stroke="currentColor"
              fill="currentColor"
              strokeWidth="0"
              viewBox="0 0 448 512"
              height="20"
              width="20"
              xmlns="http://www.w3.org/2000/svg"
              style={{ color: '#4060b0' }}
            >
              <path d="M416 208H272V64c0-17.67-14.33-32-32-32h-32c-17.67 0-32 14.33-32 32v144H32c-17.67 0-32 14.33-32 32v32c0 17.67 14.33 32 32 32h144v144c0 17.67 14.33 32 32 32h32c17.67 0 32-14.33 32-32V304h144c17.67 0 32-14.33 32-32v-32c0-17.67-14.33-32-32-32z"></path>
            </svg>
            Create New Edev Documentation
          </h3>

          <form onSubmit={handleCreateDoc}>
            <div style={{ display: 'flex', gap: '10px', alignItems: 'flex-start' }}>
              <div style={{ flex: 1 }}>
                <input
                  type="text"
                  value={newDocTitle}
                  onChange={(e) => setNewDocTitle(e.target.value)}
                  placeholder="Enter document title..."
                  style={{
                    width: '100%',
                    padding: '10px 12px',
                    border: '1px solid #ddd',
                    borderRadius: '4px',
                    fontSize: '14px',
                    boxSizing: 'border-box'
                  }}
                  onFocus={(e) => {
                    e.target.style.borderColor = '#4060b0';
                    e.target.style.outline = 'none';
                  }}
                  onBlur={(e) => {
                    e.target.style.borderColor = '#ddd';
                  }}
                />
                <p style={{
                  fontSize: '12px',
                  color: '#666',
                  marginTop: '8px',
                  marginBottom: 0
                }}>
                  Edevdocs are only visible to members of the edev group
                </p>
              </div>

              <button
                type="submit"
                disabled={!newDocTitle.trim()}
                style={{
                  padding: '10px 20px',
                  backgroundColor: newDocTitle.trim() ? '#4060b0' : '#ccc',
                  color: 'white',
                  border: 'none',
                  borderRadius: '4px',
                  cursor: newDocTitle.trim() ? 'pointer' : 'not-allowed',
                  fontSize: '14px',
                  fontWeight: '500',
                  whiteSpace: 'nowrap',
                  transition: 'background-color 0.2s'
                }}
                onMouseEnter={(e) => {
                  if (newDocTitle.trim()) {
                    e.currentTarget.style.backgroundColor = '#365a9c';
                  }
                }}
                onMouseLeave={(e) => {
                  if (newDocTitle.trim()) {
                    e.currentTarget.style.backgroundColor = '#4060b0';
                  }
                }}
              >
                Create Doc
              </button>
            </div>
          </form>
        </div>
      )}

      <div style={{
        marginTop: '30px',
        padding: '15px',
        backgroundColor: '#e8f4f8',
        borderLeft: '4px solid #4060b0',
        borderRadius: '4px'
      }}>
        <p style={{ margin: 0, fontSize: '14px', color: '#38495e' }}>
          <strong>What are Edevdocs?</strong> These are developer documentation pages that can only be viewed and edited by members of the{' '}
          <a href="/user/edev" style={{ color: '#4060b0' }}>edev</a> usergroup. They're useful for testing APIs, documenting internal features, or writing experimental JavaScript.
        </p>
      </div>
    </div>
  );
}
