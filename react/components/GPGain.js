import React from 'react'

const GPGain = ({ amount }) => {
  if (!amount || amount <= 0) return null

  return (
    <>
      Yay! You gained <strong>{amount}</strong> GP{amount === 1 ? '.' : '!'}
    </>
  )
}

export default GPGain
