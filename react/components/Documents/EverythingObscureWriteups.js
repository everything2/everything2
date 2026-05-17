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
        <p className="obscure-writeups__empty">
          No obscure writeups found at this time.
        </p>
      ) : (
        <ul className="obscure-writeups__list">
          {writeups.map(({ node_id, title, parent_title, author, author_id }) => (
            <li key={node_id} className="obscure-writeups__item">
              <div className="obscure-writeups__title">
                <a href={`/title/${encodeURIComponent(parent_title)}#${encodeURIComponent(author)}`} className="title">
                  "{title}"
                </a>
              </div>
              <div className="obscure-writeups__author">
                by <LinkNode node_id={author_id} title={author} type="user" />
              </div>
            </li>
          ))}
        </ul>
      )}

      <div className="obscure-writeups__tip">
        <p className="obscure-writeups__tip-text">
          <strong>Tip:</strong> These writeups are randomly selected from those with reputation of 0.
          Reload the page to see different writeups.
        </p>
      </div>
    </div>
  )
}

export default EverythingObscureWriteups
