import React, { useState } from 'react';

export default function E2PennyJar({ data }) {
  const { user_gp, pennies_in_jar, can_interact, error, message: initialMessage } = data;
  const [message, setMessage] = useState(initialMessage || '');

  if (error) {
    return (
      <div className="penny-jar">
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
    <div className="penny-jar">
      {message && (
        <p className="penny-jar__message">
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
            <div className="penny-jar__buttons">
              <button
                onClick={() => handleAction('give')}
                disabled={user_gp < 1}
                className="penny-jar__btn penny-jar__btn--give"
                title={user_gp < 1 ? 'You need at least 1 GP to give' : ''}
              >
                The more you give the more you get. Give!
              </button>

              <button
                onClick={() => handleAction('take')}
                disabled={pennies_in_jar < 1}
                className="penny-jar__btn penny-jar__btn--take"
              >
                No! Giving is for the weak. Take!
              </button>
            </div>
          )}
        </div>
      )}

      <p className="penny-jar__count">
        {getPennyMessage()}
      </p>

      <p className="penny-jar__gp-status">
        You currently have <strong>{user_gp} GP</strong>.
      </p>
    </div>
  );
}
