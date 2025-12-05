import React, { useState } from 'react';

export default function E2PennyJar({ data }) {
  const { user_gp, pennies_in_jar, can_interact, error, message: initialMessage } = data;
  const [message, setMessage] = useState(initialMessage || '');

  if (error) {
    return (
      <div style={{ padding: '20px', fontFamily: 'Arial, sans-serif' }}>
        <p>{error}</p>
      </div>
    );
  }

  const handleAction = (action) => {
    // Create a form and submit it
    const form = document.createElement('form');
    form.method = 'POST';
    form.action = window.location.href;

    // Add node_id hidden field (required for routing)
    const nodeIdInput = document.createElement('input');
    nodeIdInput.type = 'hidden';
    nodeIdInput.name = 'node_id';
    nodeIdInput.value = window.e2.node.node_id;
    form.appendChild(nodeIdInput);

    // Add action parameter
    const actionInput = document.createElement('input');
    actionInput.type = 'hidden';
    actionInput.name = action;
    actionInput.value = '1';
    form.appendChild(actionInput);

    document.body.appendChild(form);
    form.submit();
  };

  const getPennyMessage = () => {
    if (pennies_in_jar === 0) {
      return 'There are no more pennies in the penny jar!';
    } else if (pennies_in_jar === 1) {
      return 'There is currently 1 penny in the penny jar.';
    } else {
      return `There are currently ${pennies_in_jar} pennies in the penny jar.`;
    }
  };

  return (
    <div style={{ padding: '20px', fontFamily: 'Arial, sans-serif' }}>
      {message && (
        <p style={{
          padding: '10px',
          backgroundColor: '#e8f4f8',
          border: '1px solid #4060b0',
          borderRadius: '4px',
          marginBottom: '20px'
        }}>
          {message}
        </p>
      )}

      {pennies_in_jar < 1 ? (
        <div>
          <p>
            Sorry, there are no more pennies in the jar! Would you like to{' '}
            <a href="/title/Give+a+penny,+take+a+penny">donate one</a>?
          </p>
        </div>
      ) : (
        <div>
          <p>Oh look! It's a jar of pennies!</p>
          <p>Would you like to give a penny or take a penny?</p>

          {can_interact && (
            <div style={{ marginTop: '20px' }}>
              <button
                onClick={() => handleAction('give')}
                disabled={user_gp < 1}
                style={{
                  padding: '10px 20px',
                  marginRight: '10px',
                  backgroundColor: user_gp < 1 ? '#ccc' : '#4060b0',
                  color: 'white',
                  border: 'none',
                  borderRadius: '4px',
                  cursor: user_gp < 1 ? 'not-allowed' : 'pointer',
                  fontSize: '14px'
                }}
                title={user_gp < 1 ? 'You need at least 1 GP to give' : ''}
              >
                The more you give the more you get. Give!
              </button>

              <button
                onClick={() => handleAction('take')}
                disabled={pennies_in_jar < 1}
                style={{
                  padding: '10px 20px',
                  backgroundColor: pennies_in_jar < 1 ? '#ccc' : '#507898',
                  color: 'white',
                  border: 'none',
                  borderRadius: '4px',
                  cursor: pennies_in_jar < 1 ? 'not-allowed' : 'pointer',
                  fontSize: '14px'
                }}
              >
                No! Giving is for the weak. Take!
              </button>
            </div>
          )}
        </div>
      )}

      <p style={{ marginTop: '20px', fontWeight: 'bold' }}>
        {getPennyMessage()}
      </p>

      <p style={{ marginTop: '10px', color: '#666', fontSize: '14px' }}>
        You currently have <strong>{user_gp} GP</strong>.
      </p>
    </div>
  );
}
