import React from 'react'

const LinkNode = ({type,title,id,display,className,author,anchor,url,params}) => {

  let rel=""
  if(url == undefined)
  {
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
        }else if(type == "user"){
          // User profile: /user/$username
          prefix = "/user/"+title
        }else{
          prefix = "/node/"+type+"/"+title
      }
      } else {
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

    url= prefix+paramstring
  }else{
    if(display==undefined)
    {
      display = url
    }

    if(className==undefined)
    {
      className="externalLink"
    }

    rel="nofollow"
  }

  return React.createElement('a', {className: className, href: url, rel: rel, style: {fontSize: 'inherit'}}, display);
}

export default LinkNode
