import React from 'react'
import LinkNode from '../LinkNode'
import NodeletContainer from '../NodeletContainer'

const QuickReference = (props) => {

  let wikilink = (term) => {return `https://en.wikipedia.org/wiki/${encodeURIComponent(term)}`}
  let wiktionarylink = (term) => {return `https://en.wiktionary.org/wiki/${encodeURIComponent(term)}`}
  let googlelink = (term) => {return `https://www.google.com/search?q=${encodeURIComponent(term)}`}

  return(<NodeletContainer id={props.id}
      title="Quick Reference" showNodelet={props.showNodelet} nodeletIsOpen={props.nodeletIsOpen}>
  <p>Look for more about this topic:</p>
  <ul>
    <li key="quickref_wiki">Try <LinkNode url={wikilink(props.quickRefSearchTerm)} display="Wikipedia" /> or <LinkNode url={wiktionarylink(props.quickRefSearchTerm)} display="Wiktionary" /></li>
    <li key="quickref_google">Try <LinkNode url={googlelink(props.quickRefSearchTerm)} display="Google" /></li>
  </ul>
  </NodeletContainer>)
}

export default QuickReference;