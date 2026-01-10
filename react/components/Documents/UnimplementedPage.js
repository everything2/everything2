import React from 'react'

/**
 * UnimplementedPage - Displayed when a node's htmlpage has not been migrated to React
 *
 * This component provides a friendly error message directing users to report the issue
 * on GitHub so it can be fixed.
 */
const UnimplementedPage = ({ contentData }) => {
  const node = contentData?.node || {}
  const page = contentData?.page || {}

  const issueTitle = encodeURIComponent(`Unimplemented page: ${page.title}`)
  const issueBody = encodeURIComponent(
    `Node: ${node.title}\nType: ${node.type}\nPage: ${page.title}\nURL: ${window.location.href}`
  )
  const githubUrl = `https://github.com/everything2/everything2/issues/new?title=${issueTitle}&body=${issueBody}`

  return (
    <div className="unimplemented-page">
      <h1>Unimplemented Page</h1>

      <div className="error-box">
        <p>
          The page you're trying to view (<code>{page.title}</code>) has not yet
          been migrated to the new React-based system.
        </p>
        <dl>
          <dt>Node</dt>
          <dd>{node.title}</dd>
          <dt>Type</dt>
          <dd>{node.type}</dd>
          <dt>Page</dt>
          <dd>{page.title}</dd>
        </dl>
      </div>

      <p>This is likely a bug. Please help us fix it by reporting this issue:</p>

      <p>
        <a href={githubUrl} target="_blank" rel="noopener noreferrer">
          Report this issue on GitHub
        </a>
      </p>

      <p>
        <a href="/">Return to Everything2 homepage</a>
      </p>

      <style>{`
        .unimplemented-page {
          max-width: 800px;
          margin: 20px auto;
          padding: 20px;
        }
        .unimplemented-page h1 {
          color: #4060b0;
        }
        .unimplemented-page code {
          background: #e8f4f8;
          padding: 2px 6px;
          border-radius: 3px;
        }
        .unimplemented-page a {
          color: #4060b0;
        }
        .unimplemented-page .error-box {
          background: #fff3cd;
          border: 1px solid #ffc107;
          padding: 20px;
          border-radius: 8px;
          margin: 20px 0;
        }
        .unimplemented-page dl {
          margin: 15px 0 0 0;
        }
        .unimplemented-page dt {
          font-weight: bold;
          color: #38495e;
        }
        .unimplemented-page dd {
          margin: 0 0 10px 20px;
        }
      `}</style>
    </div>
  )
}

export default UnimplementedPage
