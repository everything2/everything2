import React from 'react';

/**
 * BadSpellingsListing - Common bad spellings reference
 * Styles in CSS: .bad-spellings-listing__*
 */
const BadSpellingsListing = ({ data, user }) => {
  const {
    spellings = [],
    shown_count,
    total_count,
    user_has_disabled = false,
    setting_node_id,
    error,
    message
  } = data;

  const isAdmin = !!user?.admin;
  const isEditor = !!user?.editor;

  // Handle errors
  if (error === 'config') {
    return (
      <div className="bad-spellings-listing">
        <p className="bad-spellings-listing__error">{message}</p>
      </div>
    );
  }

  return (
    <div className="bad-spellings-listing">
      <p>
        If you have the option enabled to show <strong>common bad spellings</strong> in your writeups,
        common bad spellings will be flagged and displayed you are looking at your writeup by itself
        (as opposed to the e2node, which may contain other noders' writeups).
      </p>

      <p>
        This option can be toggled at{' '}
        <a href="/?node=Settings">Settings</a> in the Writeup Hints section.
        You currently have it{' '}
        {user_has_disabled ? (
          <span className="bad-spellings-listing__warning">disabled, which is not recommended</span>
        ) : (
          <span>enabled, the recommended setting</span>
        )}.
      </p>

      {isAdmin && (
        <p className="bad-spellings-listing__admin-note">
          (Site administrators can edit this setting at{' '}
          <a href={`/?node_id=${setting_node_id}`}>bad spellings en-US</a>.)
        </p>
      )}

      <p>
        Spelling errors and corrections:
      </p>

      <table className="bad-spellings-listing__table">
        <thead>
          <tr className="bad-spellings-listing__header-row">
            <th className="bad-spellings-listing__th">invalid</th>
            <th className="bad-spellings-listing__th">correction</th>
          </tr>
        </thead>
        <tbody>
          {spellings.map((item, index) => (
            <tr key={index} className={index % 2 === 0 ? 'bad-spellings-listing__row--even' : 'bad-spellings-listing__row--odd'}>
              <td className="bad-spellings-listing__td">{item.invalid}</td>
              <td className="bad-spellings-listing__td" dangerouslySetInnerHTML={{ __html: item.correction }} />
            </tr>
          ))}
        </tbody>
      </table>

      <p className="bad-spellings-listing__summary">
        ({shown_count} entries
        {isEditor && ` shown, ${total_count} total`})
      </p>
    </div>
  );
};

export default BadSpellingsListing;
