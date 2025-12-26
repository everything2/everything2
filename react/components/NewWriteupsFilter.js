import React from 'react'

const newWriteupsCount = [1, 5, 10, 15, 20, 25, 30, 40]

const NewWriteupsFilter = ({ limit, newWriteupsChange, noJunk, noJunkChange, user }) => {
  if (user.guest) {
    return null
  }

  return (
    <div style={{
      display: 'flex',
      alignItems: 'center',
      gap: '12px',
      padding: '8px',
      backgroundColor: '#f8f9fa',
      borderRadius: '4px',
      fontSize: '12px'
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
        <label htmlFor="newwriteups-limit" style={{ color: '#495057' }}>Show:</label>
        <select
          id="newwriteups-limit"
          name="newwriteups-limit"
          value={limit}
          onChange={(event) => newWriteupsChange(event.target.value)}
          style={{
            padding: '4px 8px',
            borderRadius: '3px',
            border: '1px solid #dee2e6',
            fontSize: '12px',
            backgroundColor: '#fff',
            cursor: 'pointer'
          }}
        >
          {newWriteupsCount.map((count) => (
            <option value={count} key={`newwupref_${count}`}>
              {count}
            </option>
          ))}
        </select>
      </div>

      {user.editor && (
        <label htmlFor="newwriteups-nojunk" style={{
          display: 'flex',
          alignItems: 'center',
          gap: '6px',
          cursor: 'pointer',
          color: '#495057'
        }}>
          <input
            type="checkbox"
            id="newwriteups-nojunk"
            name="newwriteups-nojunk"
            onChange={(event) => noJunkChange(event.target.checked)}
            defaultChecked={noJunk}
            style={{ cursor: 'pointer' }}
          />
          <span>No junk</span>
        </label>
      )}
    </div>
  )
}

export default NewWriteupsFilter
