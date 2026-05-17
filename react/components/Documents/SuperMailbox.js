import React from 'react';

/**
 * SuperMailbox - Bot message inbox checker
 * Styles in CSS: .super-mailbox__*
 */
const SuperMailbox = ({ data }) => {
  const { access_denied, message, bots = [] } = data;

  if (access_denied) {
    return (
      <div className="super-mailbox">
        <div className="super-mailbox__access-denied">
          <p>{message}</p>
        </div>
      </div>
    );
  }

  // Build list of bot names
  const botLinks = bots.map(bot => bot.username);
  let botList = '';
  if (botLinks.length > 1) {
    const lastBot = botLinks.pop();
    botList = botLinks.join(', ') + ' and ' + lastBot;
  } else if (botLinks.length === 1) {
    botList = botLinks[0];
  }

  return (
    <div className="super-mailbox">
      <h3 className="super-mailbox__title">The 'bot super mailbox</h3>
      <p className="super-mailbox__description">
        One stop check for msgs to 'bot and support mailboxes. You can see messages for: {botList}
      </p>
      <ul className="super-mailbox__list">
        {bots.map((bot) => (
          bot.message_count > 0 ? (
            <li key={bot.user_id}>
              {bot.username} has{' '}
              <a href={`/?node=Message%20Inbox&spy_user=${encodeURIComponent(bot.username)}`}>
                {bot.message_count} message{bot.message_count !== 1 ? 's' : ''}
              </a>
            </li>
          ) : null
        ))}
        {bots.every(bot => bot.message_count === 0) && (
          <li>No messages</li>
        )}
      </ul>
    </div>
  );
};

export default SuperMailbox;
