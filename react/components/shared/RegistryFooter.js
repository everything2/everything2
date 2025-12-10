import React from 'react'

/**
 * RegistryFooter - Unified navigation footer for all registry pages
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
    <nav style={styles.footer}>
      {pages.map((page, index) => (
        <React.Fragment key={page.key}>
          {index > 0 && <span>{' | '}</span>}
          {page.key === currentPage ? (
            <strong style={styles.currentPage}>{page.label}</strong>
          ) : (
            <a href={page.href} style={styles.link}>{page.label}</a>
          )}
        </React.Fragment>
      ))}
    </nav>
  )
}

const styles = {
  footer: {
    fontSize: '12px',
    color: '#6c757d',
    textAlign: 'center',
    marginTop: '20px',
    paddingTop: '15px',
    borderTop: '1px solid #dee2e6'
  },
  link: {
    color: '#4060b0',
    textDecoration: 'none'
  },
  currentPage: {
    color: '#38495e'
  }
}

export default RegistryFooter
