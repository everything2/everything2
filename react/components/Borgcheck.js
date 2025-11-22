import React from 'react'
import LinkNode from './LinkNode'

const Borgcheck = ({ borged, numborged, currentTime }) => {
  if (!borged) return null

  const timeElapsed = currentTime - borged
  const adjustedNum = (numborged || 1) * 2
  const cooldownPeriod = 300 + 60 * adjustedNum

  if (timeElapsed < cooldownPeriod) {
    return (
      <>
        <LinkNode title="You've Been Borged!" />
        <br />
        <br />
      </>
    )
  }

  return (
    <>
      <em>
        <LinkNode title="EDB" /> has spit you out...
      </em>
      <br />
      <br />
    </>
  )
}

export default Borgcheck
