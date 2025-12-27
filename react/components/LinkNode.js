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

  // Build title attribute for hover text (shows link target, useful for pipelinks)
  // For internal links: show the node title being linked to
  // For external links: show the URL
  let hoverTitle = null
  if (rel === "nofollow") {
    // External link - show URL in hover
    hoverTitle = url
  } else if (title != null) {
    // Internal link - show the actual node title (decoded for readability)
    // Decode the double-encoding we did above for the URL
    hoverTitle = title.replace(/%25([0-9A-F]{2})/gi, (match, hex) => {
      return decodeURIComponent('%' + hex)
    })
  }

  return React.createElement('a', {
    className: className,
    href: url,
    rel: rel || undefined,
    title: hoverTitle || undefined,
    style: {fontSize: 'inherit'}
  }, display);
}

export default LinkNode
