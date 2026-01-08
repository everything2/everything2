import React from 'react'

// Helper to decode HTML entities (numeric and named) to actual characters
// This is needed because node titles may contain entities like &#9608; (█)
// which must be decoded before URL encoding
const decodeHtmlEntities = (str) => {
  if (!str || typeof str !== 'string') return str

  // First decode numeric entities (&#NNN; or &#xHH;)
  let decoded = str.replace(/&#(\d+);/g, (match, dec) => {
    return String.fromCodePoint(parseInt(dec, 10))
  }).replace(/&#x([0-9A-Fa-f]+);/g, (match, hex) => {
    return String.fromCodePoint(parseInt(hex, 16))
  })

  // Decode common named entities
  const namedEntities = {
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&apos;': "'",
    '&nbsp;': '\u00A0'
  }
  for (const [entity, char] of Object.entries(namedEntities)) {
    decoded = decoded.split(entity).join(char)
  }

  return decoded
}

// Note: nodeId, nodeType, and titleAttr are destructured but intentionally handled specially -
// this prevents React warnings when parent components pass these as props
// titleAttr is used to override the hover title (since 'title' is used for URL generation)
// nodeType is sometimes passed from parent data but not used in link generation
const LinkNode = ({type,title,id,display,className,author,anchor,url,params,style,onMouseEnter,onMouseLeave,nodeId,nodeType,titleAttr,...restProps}) => {

  let rel=""
  let originalDecodedTitle = null  // Store decoded title for hover text
  if(url == undefined)
  {
    let prefix = ""

    if(title != undefined)
    {
      if(display == undefined)
      {
        display = title
      }

      // Decode HTML entities first, then double-encode special URL characters
      // This ensures &#9608; becomes █ before encoding, not %2526%25239608%253B
      originalDecodedTitle = decodeHtmlEntities(title)
      title = originalDecodedTitle.replace(/[\&@\+\/\;\?]/g, (match) => {return encodeURIComponent(encodeURIComponent(match))});
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
  // titleAttr prop overrides automatic title generation
  // For internal links: show the node title being linked to
  // For external links: show the URL
  let hoverTitle = null
  if (titleAttr) {
    // Explicit title override provided
    hoverTitle = titleAttr
  } else if (rel === "nofollow") {
    // External link - show URL in hover
    hoverTitle = url
  } else if (originalDecodedTitle != null) {
    // Internal link - use the decoded title we saved earlier
    hoverTitle = originalDecodedTitle
  }

  return React.createElement('a', {
    className: className,
    href: url,
    rel: rel || undefined,
    title: hoverTitle || undefined,
    style: style || {fontSize: 'inherit'},
    onMouseEnter: onMouseEnter,
    onMouseLeave: onMouseLeave,
    ...restProps
  }, display);
}

export default LinkNode
