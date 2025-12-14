import React from 'react'

/**
 * CajaDeArena - Sandbox spam detection tool
 *
 * Admin tool for finding potentially spammy homenodes from users
 * who have never published any writeups.
 */
const CajaDeArena = ({ data }) => {
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
    gonesince = '1 YEAR',
    showlength = 1000,
    published = 0,
    extlinks = 0
  } = filters

  if (error) {
    return <div className="error-message">{error}</div>
  }

  // Parse gonesince into number and unit
  const [goneNum, goneUnit] = gonesince.split(' ')

  return (
    <div className="caja-de-arena">
      {/* Options form */}
      <form method="GET" action={`/?node_id=${node_id}`}>
        <input type="hidden" name="node_id" value={node_id} />

        <fieldset style={{ marginBottom: '20px', padding: '15px' }}>
          <legend>Sandbox Options</legend>

          <label>
            Not logged in for:{' '}
            <input type="text" name="gonenum" defaultValue={goneNum} size={2} />
            <select name="goneunit" defaultValue={goneUnit}>
              <option value="YEAR">YEAR</option>
              <option value="MONTH">MONTH</option>
              <option value="WEEK">WEEK</option>
              <option value="DAY">DAY</option>
            </select>
          </label>
          <br />

          <label>
            <input
              type="checkbox"
              name="published"
              value="1"
              defaultChecked={Boolean(published)}
            />
            {' '}Include users with writeups (default: only zero-writeup users)
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
            Only show{' '}
            <input type="text" name="showlength" defaultValue={showlength} size={3} />
            {' '}characters
          </label>
          <br /><br />

          <input type="submit" value="Search" />
        </fieldset>

        {/* Handle combining gonenum and goneunit */}
        <input type="hidden" name="gonesince" value="" />
      </form>

      {/* Results header */}
      <p><strong>Spam entries: {total} found</strong></p>

      {/* Results */}
      {items.map((item) => (
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
              <hr />
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
        </div>
      ))}

      {items.length === 0 && (
        <p style={{ fontStyle: 'italic', color: '#666' }}>
          No matching homenodes found with current filters.
        </p>
      )}

      {/* Pagination */}
      {total_pages > 1 && (
        <div style={{ textAlign: 'center', marginTop: '20px' }}>
          {page > 1 && (
            <a
              href={`/?node_id=${node_id}&gonesince=${encodeURIComponent(gonesince)}&showlength=${showlength}${published ? '&published=1' : ''}${extlinks ? '&extlinks=1' : ''}&page=${page - 1}`}
              style={{ marginRight: '20px' }}
            >
              &laquo; Previous
            </a>
          )}

          <span>Page {page} of {total_pages}</span>

          {page < total_pages && (
            <a
              href={`/?node_id=${node_id}&gonesince=${encodeURIComponent(gonesince)}&showlength=${showlength}${published ? '&published=1' : ''}${extlinks ? '&extlinks=1' : ''}&page=${page + 1}`}
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

export default CajaDeArena
