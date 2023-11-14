import React from 'react'

const LinkNode = ({type,title,id,display,className,author,anchor,params}) => {

  let prefix = ""

  if(title != undefined)
  {
    if(display == undefined)
    {
      display = title
    }

    // Double-encode to work around E2 routing bugs
    title = title.replace(/[\&@\+\/\;\?]/g, (match) => {return encodeURIComponent(encodeURIComponent(match))});
  }

  if(author != undefined)
  {
    /* Used in the form /user/$username/writeups/$writeupname */
    prefix = "/user/"+author+"/"+type+"s/"+title
  }else{
    if(id == undefined)
    {
      if(type == undefined)
      {
        prefix = "/title/"+title
      }else{
        prefix = "/node/"+type+"/"+title
      }
    }else {
      prefix = "/node/"+id

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
    param_list.push(key+"="+params[key])
  })

  let paramstring = param_list.join('&')

  if(paramstring !== "")
  {
    paramstring = '?'+paramstring
  }

  if(anchor !== undefined)
  {
    paramstring = paramstring+"#"+anchor
  }

  return React.createElement('a', {className: className, href: prefix+paramstring}, display);
}

export default LinkNode
