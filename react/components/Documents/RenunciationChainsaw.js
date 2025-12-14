import React from 'react'
import LinkNode from '../LinkNode'

/**
 * RenunciationChainsaw - Bulk transfer writeup ownership
 *
 * Admin tool for transferring ownership of multiple writeups from one
 * user to another.
 */
const RenunciationChainsaw = ({ data }) => {
  const {
    error,
    node_id,
    prefill_user = '',
    prefill_node = '',
    processed,
    from_user,
    to_user,
    reparented = [],
    nonexistent = [],
    no_writeup = [],
    bad_owner = [],
    bad_type = [],
    generated_list,
    list_error
  } = data

  if (error) {
    return <div className="error-message">{error}</div>
  }

  return (
    <div className="renunciation-chainsaw">
      {/* Results from processing */}
      {processed && (
        <dl>
          {reparented.length > 0 && (
            <>
              <dt>
                <strong>
                  {reparented.length} writeups re-ownered from{' '}
                  <LinkNode id={from_user.id} display={from_user.title} /> to{' '}
                  <LinkNode id={to_user.id} display={to_user.title} />:
                </strong>
              </dt>
              {reparented.map((node, idx) => (
                <dd key={idx}>
                  <LinkNode id={node.node_id} display={node.title} />
                </dd>
              ))}
            </>
          )}

          {nonexistent.length > 0 && (
            <span style={{ color: '#c00000' }}>
              <dt>&nbsp;</dt>
              <dt>
                <strong>Nonexistent nodes:</strong> (if you provided writeup titles,
                they may differ from their parent node titles due to the parent nodes
                having been renamed)
              </dt>
              {nonexistent.map((node, idx) => (
                <dd key={idx}>{node.title}</dd>
              ))}
            </span>
          )}

          {bad_owner.length > 0 && (
            <span style={{ color: '#c00000' }}>
              <dt>&nbsp;</dt>
              <dt>
                <strong>Wrong <code>author_user</code> (SQL problem; talk to nate):</strong>
              </dt>
              {bad_owner.map((node, idx) => (
                <dd key={idx}>
                  <LinkNode id={node.node_id} display={node.title} />
                </dd>
              ))}
            </span>
          )}

          {bad_type.length > 0 && (
            <span style={{ color: '#c00000' }}>
              <dt>&nbsp;</dt>
              <dt>
                <strong>Wrong <code>type_nodetype</code> (SQL problem; talk to nate):</strong>
              </dt>
              {bad_type.map((node, idx) => (
                <dd key={idx}>
                  <LinkNode id={node.node_id} display={node.title} />
                </dd>
              ))}
            </span>
          )}

          {no_writeup.length > 0 && (
            <span style={{ color: '#c00000' }}>
              <dt>&nbsp;</dt>
              <dt>
                <strong>
                  <LinkNode id={from_user.id} display={from_user.title} /> has nothing here:
                </strong>
              </dt>
              {no_writeup.map((node, idx) => (
                <dd key={idx}>
                  <LinkNode id={node.node_id} display={node.title} />
                </dd>
              ))}
            </span>
          )}

          <p style={{ marginTop: '20px' }}>
            [ <LinkNode id={node_id} display="back" /> ]
          </p>
        </dl>
      )}

      {/* Main form */}
      {!processed && (
        <form method="POST" action={`/?node_id=${node_id}`}>
          <input type="hidden" name="node_id" value={node_id} />

          <p>
            Change ownership of writeups from user<br />
            <input
              type="text"
              name="user_name_from"
              id="user_name_from"
              defaultValue={prefill_user || (generated_list ? generated_list.user_title : '')}
              style={{ width: '200px' }}
            />
            {' '}
            <a
              href="#"
              onClick={(e) => {
                e.preventDefault()
                const username = document.getElementById('user_name_from')?.value?.trim()
                if (!username) {
                  alert('Please enter a username first')
                  return
                }
                window.location.href = `/?node_id=${node_id}&nodes_for=${encodeURIComponent(username)}`
              }}
              style={{
                padding: '2px 8px',
                backgroundColor: '#38495e',
                color: '#fff',
                textDecoration: 'none',
                borderRadius: '3px',
                fontSize: '12px',
                cursor: 'pointer'
              }}
            >
              Generate nodelist
            </a>
          </p>

          {list_error && (
            <p style={{ color: '#c00000', marginTop: '10px' }}>{list_error}</p>
          )}

          <p>
            to user<br />
            <input type="text" name="user_name_to" style={{ width: '200px' }} />
          </p>

          <p>The writeups in question:</p>
          <textarea
            name="namelist"
            rows={20}
            cols={50}
            defaultValue={
              prefill_node ||
              (generated_list && generated_list.nodes.length > 0
                ? generated_list.nodes.map(n => n.title).join('\n')
                : '')
            }
          />

          <p>
            <input type="submit" value="Do It" />
          </p>
        </form>
      )}
    </div>
  )
}

export default RenunciationChainsaw
