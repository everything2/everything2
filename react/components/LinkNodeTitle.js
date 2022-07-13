import React from 'react'

const LinkNodeTitle = ({title,href}) => {
  if(href == undefined)
  {
    href = title
  }

  if(title != undefined)
  {
    return <a href={"/title/"+encodeURIComponent(href)}>{title}</a>
  }

  return <></>
}

export default LinkNodeTitle
