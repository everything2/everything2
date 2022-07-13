import React from 'react'

const LinkNodeTitle = ({title,href}) => {
  if(href == undefined)
  {
    href = title
  }

  if(title != undefined)
  {
    if(href.includes("/"))
    {
      // Double-encode to work around E2 routing bugs
      href = encodeURIComponent(href)
    }
    return <a href={"/title/"+encodeURIComponent(href)}>{title}</a>
  }

  return <></>
}

export default LinkNodeTitle
