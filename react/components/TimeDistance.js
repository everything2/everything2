import React from 'react'

const roundGently = (value,precision) => {
    var multiplier = Math.pow(10, precision || 0);
    return Math.round(value * multiplier) / multiplier;
}

const TimeDistance = ({then,now}) => {
  if(now == undefined)
  {
    now = Math.floor(Date.now()/1000)
  }
  let suffix = "ago"
  if(then > now)
  {
    suffix = "in the future"
    let tmp = then
    then = now
    now = tmp 
  }

  if(then == 0)
  {
    return "forever ago"
  }

  let timeDiff = now - then;
  let timeStr = 0

  if(timeDiff < 300)
  {
    return "just now"
  }else if(timeDiff < 60*60)
  {
    timeStr = roundGently(timeDiff/60,1)+"m"
  }else if(timeDiff < 60*60*24)
  {
    timeStr = roundGently(timeDiff/(60*60),1)+"h"
  }else if(timeDiff < 60*60*24*30)
  {
    timeStr = roundGently(timeDiff/(60*60*24),1)+"d"
  }else if(timeDiff < 60*60*24*365)
  {
    timeStr = roundGently(timeDiff/(60*60*24*30),1)+"m"
  }else
  {
    timeStr = roundGently(timeDiff/(60*60*24*365),1)+"y"
  }

  return <>{timeStr + " "+suffix}</>
}

export default TimeDistance
