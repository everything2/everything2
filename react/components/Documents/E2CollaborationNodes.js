import React, { useState, useCallback } from 'react'

const styles = {
  container: {
    maxWidth: '800px',
    margin: '0 auto',
    padding: '20px',
  },
  header: {
    marginBottom: '20px',
    borderBottom: '1px solid #ccc',
    paddingBottom: '10px',
  },
  title: {
    margin: 0,
    fontSize: '1.5rem',
  },
  section: {
    marginBottom: '30px',
  },
  instructions: {
    padding: '15px',
    backgroundColor: '#f8f9fa',
    borderRadius: '8px',
    marginBottom: '20px',
    lineHeight: '1.6',
  },
  dl: {
    marginBottom: '20px',
  },
  dt: {
    fontWeight: 'bold',
    marginBottom: '5px',
  },
  dd: {
    marginLeft: '20px',
    marginBottom: '15px',
  },
  form: {
    padding: '15px',
    backgroundColor: '#fff',
    border: '1px solid #ddd',
    borderRadius: '8px',
    marginBottom: '20px',
  },
  formTitle: {
    fontWeight: 'bold',
    marginBottom: '10px',
  },
  input: {
    padding: '8px',
    fontSize: '14px',
    border: '1px solid #ccc',
    borderRadius: '4px',
    marginRight: '10px',
    width: '300px',
    maxWidth: '100%',
  },
  button: {
    padding: '8px 16px',
    backgroundColor: '#007bff',
    color: 'white',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '14px',
  },
  checkboxGroup: {
    marginTop: '10px',
  },
  checkboxLabel: {
    marginRight: '20px',
    cursor: 'pointer',
  },
}

const E2CollaborationNodes = ({ data }) => {
  const [searchNode, setSearchNode] = useState('')
  const [createNode, setCreateNode] = useState('')
  const [soundex, setSoundex] = useState(false)
  const [matchAll, setMatchAll] = useState(false)

  return (
    <div style={styles.container}>
      <div style={styles.header}>
        <h1 style={styles.title}>E2 Collaboration Nodes</h1>
      </div>

      <div style={styles.instructions}>
        <p><strong>Here's how these puppies operate:</strong></p>

        <dl style={styles.dl}>
          <dt style={styles.dt}>Access</dt>
          <dd style={styles.dd}>
            <p>Any CE or god can view or edit any collaboration node. A regular
            user can't, unless one of us explicitly grants access. You grant
            access by editing the node and adding the user's name to the
            "Allowed Users" list for that node (just type it into the box; it
            should be clear). You can also add a user<em>group</em> to the
            list: In that case, every user who belongs to that group will have
            access (<em>full</em> access) to the node.</p>
          </dd>

          <dt style={styles.dt}>Locking</dt>
          <dd style={styles.dd}>
            <p>The only difficulty with this is the fact that two different
            users will, inevitably, end up trying to edit the same node at the
            same time. They'll step on each other's changes. We handle this
            problem the way everybody does: When somebody begins editing a
            collaboration node, it is automatically "locked". CEs and gods can
            forcibly unlock a collaboration node, but don't do it too casually
            because, once again, you may step on the user's changes. Any user
            can voluntarily release his or her <em>own</em> lock on a
            collaboration node (but they'll forget which is why you can do it
            yourself). Finally, all "locks" on these nodes expire after fifteen
            idle minutes, or maybe it's twenty. I can't remember.{' '}
            <strong>Use it or lose it.</strong></p>

            <p>The "locking" feature may be a bit perplexing at first, but
            it's necessary if the feature is to be useful in practice.</p>
          </dd>
        </dl>

        <p>The HTML "rules" here are the same as for writeups, except
        that you can also use the mysterious and powerful &lt;highlight&gt; tag.</p>
      </div>

      <hr />

      {/* Search Form */}
      <div style={styles.form}>
        <div style={styles.formTitle}>Search for a collaboration node:</div>
        <form method="post" encType="application/x-www-form-urlencoded">
          <div>
            <input
              type="text"
              name="node"
              value={searchNode}
              onChange={(e) => setSearchNode(e.target.value)}
              style={styles.input}
              placeholder="Node title"
              maxLength={64}
            />
            <input type="hidden" name="type" value="collaboration" />
            <button type="submit" name="searchy" style={styles.button}>
              search
            </button>
          </div>
          <div style={styles.checkboxGroup}>
            <label style={styles.checkboxLabel}>
              <input
                type="checkbox"
                name="soundex"
                value="1"
                checked={soundex}
                onChange={(e) => setSoundex(e.target.checked)}
              />
              {' '}Near Matches
            </label>
            <label style={styles.checkboxLabel}>
              <input
                type="checkbox"
                name="match_all"
                value="1"
                checked={matchAll}
                onChange={(e) => setMatchAll(e.target.checked)}
              />
              {' '}Ignore Exact
            </label>
          </div>
        </form>
      </div>

      <hr />

      {/* Create Form */}
      <div style={styles.form}>
        <div style={styles.formTitle}>Create a new collaboration node:</div>
        <form method="post">
          <input type="hidden" name="op" value="new" />
          <input type="hidden" name="type" value="collaboration" />
          <input type="hidden" name="displaytype" value="useredit" />
          <input
            type="text"
            name="node"
            value={createNode}
            onChange={(e) => setCreateNode(e.target.value)}
            style={styles.input}
            placeholder="New node title"
            maxLength={64}
          />
          <button type="submit" style={styles.button}>
            create
          </button>
        </form>
      </div>
    </div>
  )
}

export default E2CollaborationNodes
