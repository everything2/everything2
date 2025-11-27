import React from 'react'
import LinkNode from '../LinkNode'

const EverythingObscureWriteups = ({ data }) => {
  const { writeups } = data

  return (
    <div className="everything-obscure-writeups">
      <h2>Everything's Obscure Writeups</h2>
      <p>
        These are writeups with zero reputation - the most obscure content on Everything2.
        Give them a read and consider voting on them!
      </p>

      {writeups.length === 0 ? (
        <p style={{ fontStyle: 'italic', color: '#666' }}>
          No obscure writeups found at this time.
        </p>
      ) : (
        <ul style={{ listStyle: 'none', padding: 0 }}>
          {writeups.map(({ node_id, title, parent_title, author, author_id }) => (
            <li key={node_id} style={{ marginBottom: '15px', padding: '10px', backgroundColor: '#f9f9f9', borderLeft: '3px solid #ddd' }}>
              <div style={{ marginBottom: '5px' }}>
                <a href={`/title/${encodeURIComponent(parent_title)}#${encodeURIComponent(author)}`} className="title">
                  "{title}"
                </a>
              </div>
              <div style={{ fontSize: '0.9em', color: '#888' }}>
                by <LinkNode node_id={author_id} title={author} type="user" />
              </div>
            </li>
          ))}
        </ul>
      )}

      <div style={{ marginTop: '20px', padding: '15px', backgroundColor: '#f0f8ff', borderRadius: '4px' }}>
        <p style={{ margin: 0, fontSize: '0.9em' }}>
          <strong>Tip:</strong> These writeups are randomly selected from those with reputation of 0.
          Reload the page to see different writeups.
        </p>
      </div>
    </div>
  )
}

export default EverythingObscureWriteups
