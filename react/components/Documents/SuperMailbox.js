import React from 'react';

const SuperMailbox = ({ data }) => {
  const { access_denied, message, bots = [] } = data;

  if (access_denied) {
    return (
      <div style={styles.container}>
        <div style={styles.accessDenied}>
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
    <div style={styles.container}>
      <h3 style={styles.title}>The 'bot super mailbox</h3>
      <p style={styles.description}>
        One stop check for msgs to 'bot and support mailboxes. You can see messages for: {botList}
      </p>
      <ul style={styles.list}>
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

const styles = {
  container: {
    maxWidth: '800px',
    margin: '0 auto',
    padding: '20px'
  },
  title: {
    fontSize: '24px',
    fontWeight: '600',
    color: '#38495e',
    marginBottom: '15px'
  },
  description: {
    fontSize: '16px',
    lineHeight: '1.6',
    color: '#111111',
    marginBottom: '20px'
  },
  list: {
    fontSize: '16px',
    lineHeight: '1.8',
    color: '#111111',
    paddingLeft: '20px'
  },
  accessDenied: {
    padding: '40px',
    textAlign: 'center',
    background: '#fff3cd',
    border: '1px solid #ffc107',
    borderRadius: '4px',
    color: '#856404'
  }
};

export default SuperMailbox;
