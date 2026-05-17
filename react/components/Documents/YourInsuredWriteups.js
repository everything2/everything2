import React from 'react'
import LinkNode from '../LinkNode'

/**
 * Your Insured Writeups - Shows writeups you've insured
 *
 * Staff only - shows writeups in the "publish" table
 */
const YourInsuredWriteups = ({ data }) => {
  const { writeups = [] } = data

  return (
    <div className="document">
      {writeups.length === 0 ? (
        <p><em>You have no insured writeups</em></p>
      ) : (
        <ol>
          {writeups.map((wu) => (
            <li key={wu.node_id}>
              <LinkNode nodeId={wu.node_id} title={wu.title} />
            </li>
          ))}
        </ol>
      )}

      <p className="your-insured-writeups__total">
        Total: {writeups.length} insured writeup{writeups.length !== 1 ? 's' : ''}
      </p>
    </div>
  )
}

export default YourInsuredWriteups
