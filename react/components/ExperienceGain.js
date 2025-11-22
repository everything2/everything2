import React from 'react'
import LinkNode from './LinkNode'

const ExperienceGain = ({ amount }) => {
  if (!amount || amount <= 0) return null

  return (
    <>
      You <LinkNode type="superdoc" title="node tracker" display="gained" />{' '}
      <strong>{amount}</strong> experience {amount === 1 ? 'point' : 'points'}!
    </>
  )
}

export default ExperienceGain
