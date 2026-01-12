import React from 'react'

const newWriteupsCount = [1, 5, 10, 15, 20, 25, 30, 40]

const NewWriteupsFilter = ({ limit, newWriteupsChange, noJunk, noJunkChange, user }) => {
  if (user.guest) {
    return null
  }

  return (
    <div className="newwriteups-filter">
      <div className="newwriteups-filter-group">
        <label htmlFor="newwriteups-limit" className="newwriteups-filter-label">Show:</label>
        <select
          id="newwriteups-limit"
          name="newwriteups-limit"
          value={limit}
          onChange={(event) => newWriteupsChange(event.target.value)}
          className="newwriteups-filter-select"
        >
          {newWriteupsCount.map((count) => (
            <option value={count} key={`newwupref_${count}`}>
              {count}
            </option>
          ))}
        </select>
      </div>

      {user.editor && (
        <label htmlFor="newwriteups-nojunk" className="newwriteups-filter-checkbox">
          <input
            type="checkbox"
            id="newwriteups-nojunk"
            name="newwriteups-nojunk"
            onChange={(event) => noJunkChange(event.target.checked)}
            defaultChecked={noJunk}
          />
          <span>No junk</span>
        </label>
      )}
    </div>
  )
}

export default NewWriteupsFilter
