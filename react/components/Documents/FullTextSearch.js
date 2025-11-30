import React, { useEffect } from 'react'

/**
 * FullTextSearch - Google Custom Search Engine integration
 *
 * Migrated from templates/pages/e2_full_text_search.mc
 *
 * Provides full-text search of Everything2 writeups using Google CSE.
 * All search processing happens on Google's servers - no database impact.
 *
 * Props:
 * - data.cseId: Google Custom Search Engine ID
 * - data.nodeId: Current node ID (for form submission)
 */
const FullTextSearch = ({ data }) => {
  useEffect(() => {
    // Load Google CSE branding stylesheet
    const link = document.createElement('link')
    link.rel = 'stylesheet'
    link.type = 'text/css'
    link.href = 'https://www.google.com/cse/api/branding.css'
    document.head.appendChild(link)

    // Set up global variables for Google CSE
    window.googleSearchIframeName = 'cse-search-results'
    window.googleSearchFormName = 'cse-search-box'
    window.googleSearchFrameWidth = 600
    window.googleSearchDomain = 'www.google.com'
    window.googleSearchPath = '/cse'

    // Load Google CSE script
    const script = document.createElement('script')
    script.type = 'text/javascript'
    script.src = 'https://www.google.com/afsonline/show_afs_search.js'
    script.async = true
    document.body.appendChild(script)

    // Cleanup on unmount
    return () => {
      document.head.removeChild(link)
      if (script.parentNode) {
        document.body.removeChild(script)
      }
      // Clean up global variables
      delete window.googleSearchIframeName
      delete window.googleSearchFormName
      delete window.googleSearchFrameWidth
      delete window.googleSearchDomain
      delete window.googleSearchPath
    }
  }, [])

  return (
    <div className="full-text-search">
      <div
        className="cse-branding-right"
        style={{
          backgroundColor: '#FFFFFF',
          color: '#000000'
        }}
      >
        <div className="cse-branding-form">
          <form action="" id="cse-search-box">
            <div>
              <input type="hidden" name="node_id" value={data.nodeId} />
              <input type="hidden" name="cx" value={data.cseId} />
              <input type="hidden" name="cof" value="FORID:9" />
              <input type="hidden" name="ie" value="UTF-8" />
              <input type="text" name="q" size="31" />
              <input type="submit" name="sa" value="Search" />
            </div>
          </form>
        </div>
        <div className="cse-branding-logo">
          <img
            src="https://www.google.com/images/poweredby_transparent/poweredby_FFFFFF.gif"
            alt="Google"
          />
        </div>
        <div className="cse-branding-text">Custom Search</div>
      </div>

      {/* Google Search Result Snippet */}
      <div id="cse-search-results"></div>
    </div>
  )
}

export default FullTextSearch
