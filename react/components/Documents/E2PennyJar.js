import React, { useState } from 'react';

export default function E2PennyJar({ data }) {
  const { error, message: initialMessage } = data;
  const [message, setMessage] = useState(initialMessage || '');
  const [gp, setGp] = useState(data.user_gp || 0);
  const [pennies, setPennies] = useState(data.pennies_in_jar || 0);
  const [loading, setLoading] = useState(false);
  const canInteract = !!data.can_interact;

  if (error) {
    return (
      <div className="penny-jar">
        <p>{error}</p>
      </div>
    );
  }

  // The give/take WRITE moved to POST /api/e2_penny_jar/give|take (#4453, Refs #4298);
  // update the jar count / GP / message from the response in place -- no full-page
  // POST + reload the way the old throwaway-form submit did.
  const handleAction = async (action) => {
    setLoading(true);
    try {
      const res = await fetch(`/api/e2_penny_jar/${action}`, {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: '{}',
      });
      const json = res.ok ? await res.json() : null;
      if (json) {
        setMessage(json.message || json.error || '');
        if (typeof json.pennies_in_jar === 'number') setPennies(json.pennies_in_jar);
        if (typeof json.user_gp === 'number') setGp(json.user_gp);
      } else {
        setMessage('Something went wrong reaching the penny jar.');
      }
    } catch (err) {
      setMessage(err.message || 'Something went wrong reaching the penny jar.');
    } finally {
      setLoading(false);
    }
  };

  const getPennyMessage = () => {
    if (pennies === 0) {
      return 'There are no more pennies in the penny jar!';
    } else if (pennies === 1) {
      return 'There is currently 1 penny in the penny jar.';
    } else {
      return `There are currently ${pennies} pennies in the penny jar.`;
    }
  };

  return (
    <div className="penny-jar">
      {message && (
        <p className="penny-jar__message">
          {message}
        </p>
      )}

      {pennies < 1 ? (
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

          {canInteract && (
            <div className="penny-jar__buttons">
              <button
                onClick={() => handleAction('give')}
                disabled={gp < 1 || loading}
                className="penny-jar__btn penny-jar__btn--give"
                title={gp < 1 ? 'You need at least 1 GP to give' : ''}
              >
                The more you give the more you get. Give!
              </button>

              <button
                onClick={() => handleAction('take')}
                disabled={pennies < 1 || loading}
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
        You currently have <strong>{gp} GP</strong>.
      </p>
    </div>
  );
}
