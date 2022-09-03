import React from 'react'

const LinkNode = ({type,title,id,display,className,author,anchor,params}) => {

  let prefix = ""

  if(title != undefined)
  {
    if(display == undefined)
    {
      display = title
    }

    if(title.includes("/"))
    {
      // Double-encode to work around E2 routing bugs
      title = encodeURIComponent(title)
    }
  }

  if(author != undefined)
  {
    /* Used in the form /user/$username/writeups/$writeupname */
    prefix = "/user/"+encodeURIComponent(author)+"/"+encodeURIComponent(type)+"s/"+title
  }else{
    if(id == undefined)
    {
      if(type == undefined)
      {
        prefix = "/title/"+encodeURIComponent(title)
      }else{
        prefix = "/node/"+type+"/"+encodeURIComponent(title)
      }
    }else {
      prefix = "/node/"+encodeURIComponent(id)

      if(display == undefined)
      {
        display = "node_id: "+id
      }
    }
  }

  if(params == undefined)
  {
    params = {}
  }

  let param_list = []

  Object.keys(params).forEach((key) => {
    param_list.push(encodeURIComponent(key)+"="+encodeURIComponent(params[key]))
  })

  let paramstring = param_list.join('&')

  if(paramstring !== "")
  {
    paramstring = '?'+paramstring
  }

  if(anchor !== undefined)
  {
    paramstring = paramstring+"#"+encodeURIComponent(anchor)
  }

  return <a href={prefix+paramstring} className={className}>{display}</a>
}

export default LinkNode
