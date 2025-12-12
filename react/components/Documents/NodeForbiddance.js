import React from 'react'
import LinkNode from '../LinkNode'

/**
 * NodeForbiddance - Admin tool to forbid/unforbid users from creating nodes.
 */
const NodeForbiddance = ({ data }) => {
  const { message, forbidden_users, node_id } = data

  return (
    <div style={styles.container}>
      {message && <p style={styles.message}>{message}</p>}

      <form method="post" style={styles.form}>
        <label>
          Forbid user:{' '}
          <input type="text" name="forbid" style={styles.input} />
        </label>
        {' '}
        <label>
          because:{' '}
          <input type="text" name="reason" style={styles.inputWide} />
        </label>
        <br />
        <button type="submit" style={styles.button}>do it</button>
      </form>

      <hr style={styles.hr} />

      <h3 style={styles.subtitle}>Currently Forbidden Users</h3>

      {forbidden_users.length === 0 ? (
        <p><em>No users are currently forbidden.</em></p>
      ) : (
        <ul style={styles.list}>
          {forbidden_users.map((user) => (
            <li key={user.user_id} style={styles.listItem}>
              <LinkNode nodeId={user.user_id} title={user.user_title} />
              {' '}is forbidden by{' '}
              <LinkNode nodeId={user.forbidder_id} title={user.forbidder_title} />
              {' '}
              <small>
                ({user.reason ? (
                  <span dangerouslySetInnerHTML={{ __html: user.reason }} />
                ) : (
                  <em>No reason given</em>
                )})
              </small>
              {' '}
              <a
                href={`?node_id=${node_id}&unforbid=${user.user_id}`}
                style={styles.link}
              >
                unforbid
              </a>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}

const styles = {
  container: {
    padding: '10px',
    fontSize: '13px',
    lineHeight: '1.5',
    color: '#111'
  },
  message: {
    color: '#2e7d32',
    fontWeight: 'bold',
    marginBottom: '15px'
  },
  form: {
    marginBottom: '20px'
  },
  input: {
    padding: '6px 10px',
    fontSize: '13px',
    border: '1px solid #d3d3d3',
    borderRadius: '3px',
    width: '150px'
  },
  inputWide: {
    padding: '6px 10px',
    fontSize: '13px',
    border: '1px solid #d3d3d3',
    borderRadius: '3px',
    width: '300px'
  },
  button: {
    padding: '6px 15px',
    backgroundColor: '#38495e',
    color: '#ffffff',
    border: 'none',
    borderRadius: '3px',
    cursor: 'pointer',
    fontSize: '13px',
    marginTop: '10px'
  },
  hr: {
    width: '300px',
    border: 'none',
    borderTop: '1px solid #d3d3d3',
    margin: '20px auto'
  },
  subtitle: {
    fontSize: '14px',
    fontWeight: 'bold',
    color: '#38495e',
    marginBottom: '10px'
  },
  list: {
    margin: '10px 0',
    paddingLeft: '20px'
  },
  listItem: {
    marginBottom: '8px'
  },
  link: {
    color: '#4060b0',
    textDecoration: 'none'
  }
}

export default NodeForbiddance
