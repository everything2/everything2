import React from 'react'
import RegistryFooter from '../shared/RegistryFooter'

/**
 * PopularRegistries - Show most popular registries by submission count
 * Styles in CSS: .popular-registries__*
 * Displays a table of registries sorted by number of entries
 */
const PopularRegistries = ({ data }) => {
  const { registries = [], limit = 25 } = data

  return (
    <div className="popular-registries">
      <p className="popular-registries__intro">
        These are the most popular registries on Everything2, ranked by the number of
        user submissions they have received.
      </p>

      <table className="popular-registries__table">
        <thead>
          <tr>
            <th className="popular-registries__th popular-registries__th--center">#</th>
            <th className="popular-registries__th">Registry</th>
            <th className="popular-registries__th popular-registries__th--right">Submissions</th>
          </tr>
        </thead>
        <tbody>
          {registries.length === 0 ? (
            <tr>
              <td colSpan="3" className="popular-registries__empty-cell">
                <em>No registries found</em>
              </td>
            </tr>
          ) : (
            registries.map((registry, idx) => (
              <tr key={registry.node_id} className={idx % 2 === 1 ? 'popular-registries__row--even' : 'popular-registries__row--odd'}>
                <td className="popular-registries__td popular-registries__td--center">{idx + 1}</td>
                <td className="popular-registries__td">
                  <a href={`/?node_id=${registry.node_id}`} className="popular-registries__link">
                    {registry.title}
                  </a>
                </td>
                <td className="popular-registries__td popular-registries__td--right">{registry.submission_count}</td>
              </tr>
            ))
          )}
        </tbody>
      </table>

      <div className="popular-registries__summary">
        Showing top {limit} registries by submission count.
      </div>

      <RegistryFooter currentPage="popular" />
    </div>
  )
}

export default PopularRegistries
