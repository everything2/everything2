import React from 'react'

/**
 * RegistryFooter - Unified navigation footer for all registry pages
 * Styles in CSS: .registry-footer__*
 * @param {string} currentPage - One of: 'popular', 'the_registries', 'recent', 'your_entries', 'create'
 */
const RegistryFooter = ({ currentPage }) => {
  const pages = [
    { key: 'popular', label: 'Popular Registries', href: '/title/Popular+Registries' },
    { key: 'the_registries', label: 'The Registries', href: '/title/The+Registries' },
    { key: 'recent', label: 'Recent Registry Entries', href: '/title/Recent+Registry+Entries' },
    { key: 'your_entries', label: 'Your Registry Entries', href: '/title/Registry+Information' },
    { key: 'create', label: 'Create a Registry', href: '/title/Create+a+Registry' }
  ]

  return (
    <nav className="registry-footer">
      {pages.map((page, index) => (
        <React.Fragment key={page.key}>
          {index > 0 && <span>{' | '}</span>}
          {page.key === currentPage ? (
            <strong className="registry-footer__current">{page.label}</strong>
          ) : (
            <a href={page.href} className="registry-footer__link">{page.label}</a>
          )}
        </React.Fragment>
      ))}
    </nav>
  )
}

export default RegistryFooter
