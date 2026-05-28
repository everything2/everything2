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

// Note: nodeType and titleAttr are destructured but intentionally handled specially -
// this prevents React warnings when parent components pass these as props
// titleAttr is used to override the hover title (since 'title' is used for URL generation)
// nodeType is sometimes passed from parent data but not used in link generation
const LinkNode = ({type,title,id,display,className,author,anchor,url,params,style,onMouseEnter,onMouseLeave,nodeId,nodeType,titleAttr,...restProps}) => {

  // Accept `nodeId` as a synonym for `id`. Server-side data is keyed
  // `node_id`, so React callers usually pass `nodeId={...}` (120-odd
  // callers use this form vs ~46 using `id`). Without this fallback,
  // `nodeId` was being silently ignored and the URL fell back to a
  // /title/<title> form — which fails for nodes whose title isn't a
  // public e2node (drafts, deleted/private nodes, exotic titles like
  // CJK characters not present as e2nodes). User-visible symptom: a
  // bookmark to a draft titled "美国国家安全局" produced a Nothing Found
  // page even though the node existed under that node_id.
  if (id === undefined) id = nodeId

  let rel=""
  let originalDecodedTitle = null  // Store decoded title for hover text
  if(url == undefined)
  {
    let prefix = ""

    if(title != undefined)
    {
      // Decode HTML entities first, then single-encode special URL characters.
      // Decoding `&amp;` → `&` before encoding avoids `%2526...` garbage in the
      // href. The server-side path-recovery helper
      // Everything::HTML::_recover_route_params_from_request_uri (#4060) decodes
      // REQUEST_URI exactly once, so double-encoding here would now resolve to
      // literal "%26" in the looked-up node title and miss every node.
      //
      // '#' is in the set because an unencoded '#' makes the browser treat
      // everything after it as a URL fragment and never send it to the
      // server — so titles like "Star Trek #9: Triangle" silently truncate
      // to "/title/Star Trek " on the wire (#4132).
      originalDecodedTitle = decodeHtmlEntities(title)

      // Default the visible link text to the decoded title so CJK-titled nodes
      // (e.g. #2198233 "美国国家安全局", stored as "&#32654;&#22269;…") and
      // syntax-conflict titles (e.g. "&#91;?&#93;" → "[?]") render readably
      // instead of showing literal "&#NNNN;" runs. The hover tooltip already
      // used the decoded form via originalDecodedTitle, so prior to this the
      // tooltip showed proper Chinese while the visible text showed entity
      // refs — the asymmetry that surfaced the bug.
      if(display == undefined)
      {
        display = originalDecodedTitle
      }

      title = originalDecodedTitle.replace(/[\&@\+\/\;\?#]/g, (match) => {return encodeURIComponent(match)});
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

    // Skip null/empty anchors (not just undefined) — `<LinkNode anchor={author?.title} />`
    // passes null when author is missing, which would otherwise render as `#null`.
    if(anchor !== undefined && anchor !== null && anchor !== '')
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
