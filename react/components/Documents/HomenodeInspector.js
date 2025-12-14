import React from 'react'

/**
 * HomenodeInspector - Inspect user homenodes for spam
 *
 * Admin tool for finding potentially spammy homenodes.
 */
const HomenodeInspector = ({ data }) => {
  const {
    error,
    node_id,
    filters = {},
    pole_id,
    page = 1,
    items = [],
    total = 0,
    per_page = 10,
    total_pages = 0
  } = data

  const {
    gonetime = 0,
    goneunit = 'MONTH',
    showlength = 1000,
    maxwus = 0,
    extlinks = 0,
    dotstoo = 0
  } = filters

  if (error) {
    return <div className="error-message">{error}</div>
  }

  return (
    <div className="homenode-inspector">
      {/* Options form */}
      <form method="GET" action={`/?node_id=${node_id}`}>
        <input type="hidden" name="node_id" value={node_id} />

        <fieldset style={{ marginBottom: '20px', padding: '15px' }}>
          <legend>Options</legend>

          <label>
            Max writeups:{' '}
            <input type="text" name="maxwus" defaultValue={maxwus} size={2} />
          </label>
          <br />

          <label>
            Not logged in for:{' '}
            <input type="text" name="gonetime" defaultValue={gonetime} size={2} />
            <select name="goneunit" defaultValue={goneunit.toLowerCase()}>
              <option value="year">year</option>
              <option value="month">month</option>
              <option value="week">week</option>
              <option value="day">day</option>
            </select>
          </label>
          <br />

          <label>
            <input
              type="checkbox"
              name="extlinks"
              value="1"
              defaultChecked={Boolean(extlinks)}
            />
            {' '}Only homenodes with external links
          </label>
          <br />

          <label>
            <input
              type="checkbox"
              name="dotstoo"
              value="1"
              defaultChecked={Boolean(dotstoo)}
            />
            {' '}Include "..." homenodes
          </label>
          <br />

          <label>
            Only show{' '}
            <input type="text" name="showlength" defaultValue={showlength} size={3} />
            {' '}characters
          </label>
          <br /><br />

          <input type="submit" value="Go" />
        </fieldset>
      </form>

      {/* Results */}
      <p><strong>Found {total} matching homenodes</strong></p>

      {items.map((item, idx) => (
        <div
          key={item.node_id}
          style={{
            marginBottom: '20px',
            padding: '10px',
            border: '1px solid #ccc',
            borderRadius: '5px'
          }}
        >
          <p>
            <strong>
              <a href={`/?node_id=${item.node_id}`}>{item.title}</a>
            </strong>
            {' '}({item.full_length} chars)
          </p>

          <div
            style={{
              backgroundColor: '#f9f9f9',
              padding: '10px',
              fontFamily: 'monospace',
              fontSize: '12px',
              whiteSpace: 'pre-wrap',
              wordBreak: 'break-word',
              maxHeight: '200px',
              overflow: 'auto'
            }}
          >
            {item.doctext}
          </div>

          {pole_id && (
            <p style={{ marginTop: '10px' }}>
              <a
                href={`/?node_id=${pole_id}&prefill=${encodeURIComponent(item.title)}`}
                className="action"
                title="Open The Old Hooked Pole with this username pre-filled"
                style={{ color: '#c00' }}
              >
                Smite Spammer
              </a>
            </p>
          )}

          <hr />
        </div>
      ))}

      {/* Pagination */}
      {total_pages > 1 && (
        <div style={{ textAlign: 'center', marginTop: '20px' }}>
          {page > 1 && (
            <a
              href={`/?node_id=${node_id}&gonetime=${gonetime}&goneunit=${goneunit}&showlength=${showlength}&maxwus=${maxwus}${extlinks ? '&extlinks=1' : ''}${dotstoo ? '&dotstoo=1' : ''}&page=${page - 1}`}
              style={{ marginRight: '20px' }}
            >
              &laquo; Previous
            </a>
          )}

          <span>Page {page} of {total_pages}</span>

          {page < total_pages && (
            <a
              href={`/?node_id=${node_id}&gonetime=${gonetime}&goneunit=${goneunit}&showlength=${showlength}&maxwus=${maxwus}${extlinks ? '&extlinks=1' : ''}${dotstoo ? '&dotstoo=1' : ''}&page=${page + 1}`}
              style={{ marginLeft: '20px' }}
            >
              Next &raquo;
            </a>
          )}
        </div>
      )}
    </div>
  )
}

export default HomenodeInspector
