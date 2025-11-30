import React, { Suspense, lazy } from 'react'

/**
 * DocumentComponent - Router for React-migrated documents
 *
 * Phase 4a: Routes structured content data to appropriate React components
 * - Accepts contentData prop with type field
 * - Dynamically loads and renders the correct React component
 * - Supports progressive migration from Mason to React
 * - Uses React.lazy() for code splitting - components only loaded when needed
 *
 * As documents are migrated from Mason/delegation to React, they are
 * registered in the COMPONENT_MAP below. Documents not yet migrated will
 * render as Mason HTML via MasonContent component instead.
 *
 * Code Splitting: Each lazy-loaded component creates a separate bundle chunk,
 * reducing the main bundle size and improving initial page load.
 *
 * Scalability: Component map pattern scales to hundreds of documents without
 * creating an unwieldy switch statement.
 */

// Component registry - maps document type to lazy-loaded React component
// Add new migrated documents here as they are converted from Mason to React
const COMPONENT_MAP = {
  // Phase 4a migrations
  wheel_of_surprise: lazy(() => import('./Documents/WheelOfSurprise')),
  silver_trinkets: lazy(() => import('./Documents/SilverTrinkets')),
  golden_trinkets: lazy(() => import('./Documents/GoldenTrinkets')),
  about_nobody: lazy(() => import('./Documents/AboutNobody')),
  e2_staff: lazy(() => import('./Documents/E2Staff')),
  what_to_do_if_e2_goes_down: lazy(() => import('./Documents/WhatToDoIfE2GoesDown')),
  list_html_tags: lazy(() => import('./Documents/ListHtmlTags')),
  your_gravatar: lazy(() => import('./Documents/YourGravatar')),
  oblique_strategies_garden: lazy(() => import('./Documents/ObliqueStrategiesGarden')),
  manna_from_heaven: lazy(() => import('./Documents/MannaFromHeaven')),
  everything_s_obscure_writeups: lazy(() => import('./Documents/EverythingObscureWriteups')),
  nodeshells: lazy(() => import('./Documents/Nodeshells')),

  // Numbered nodelist pages (reusable NodeList component)
  '25': lazy(() => import('./Documents/NodeList')),
  everything_new_nodes: lazy(() => import('./Documents/NodeList')),
  e2n: lazy(() => import('./Documents/NodeList')),
  enn: lazy(() => import('./Documents/NodeList')),
  ekn: lazy(() => import('./Documents/NodeList')),

  // Text generators (reusable RandomText component)
  fezisms_generator: lazy(() => import('./Documents/RandomText')),
  piercisms_generator: lazy(() => import('./Documents/RandomText')),

  // Utility tools
  wharfinger_s_linebreaker: lazy(() => import('./Documents/WharfingerLinebreaker')),

  // Holiday checkers (all use same IsItHoliday component)
  is_it_christmas_yet: lazy(() => import('./Documents/IsItHoliday')),
  is_it_halloween_yet: lazy(() => import('./Documents/IsItHoliday')),
  is_it_new_year_s_day_yet: lazy(() => import('./Documents/IsItHoliday')),
  is_it_new_year_s_eve_yet: lazy(() => import('./Documents/IsItHoliday')),
  is_it_april_fools_day_yet: lazy(() => import('./Documents/IsItHoliday')),

  // User-specific pages
  a_year_ago_today: lazy(() => import('./Documents/AYearAgoToday')),
  node_tracker: lazy(() => import('./Documents/NodeTracker')),
  node_tracker2: lazy(() => import('./Documents/NodeTracker')),
  your_ignore_list: lazy(() => import('./Documents/YourIgnoreList')),
  your_insured_writeups: lazy(() => import('./Documents/YourInsuredWriteups')),
  your_nodeshells: lazy(() => import('./Documents/YourNodeshells')),
  recent_node_notes: lazy(() => import('./Documents/RecentNodeNotes')),

  // Help & information pages
  ipfrom: lazy(() => import('./Documents/Ipfrom')),
  everything2_elsewhere: lazy(() => import('./Documents/Everything2Elsewhere')),
  online_only_msg: lazy(() => import('./Documents/OnlineOnlyMsg')),
  chatterbox_help_topics: lazy(() => import('./Documents/ChatterboxHelpTopics')),

  // Fullscreen chat interface (all variants use same component)
  chatterlight: lazy(() => import('./Documents/Chatterlight')),
  chatterlight_classic: lazy(() => import('./Documents/Chatterlight')),
  chatterlighter: lazy(() => import('./Documents/Chatterlight')),

  // Fun & games
  everything_quote_server: lazy(() => import('./Documents/EverythingQuoteServer')),
  e2_rot13_encoder: lazy(() => import('./Documents/E2Rot13Encoder')),
  e2_color_toy: lazy(() => import('./Documents/E2ColorToy')),

  // Utility tools
  text_formatter: lazy(() => import('./Documents/TextFormatter')),

  // Admin tools
  giant_teddy_bear_suit: lazy(() => import('./Documents/GiantTeddyBearSuit')),
  suspension_info: lazy(() => import('./Documents/SuspensionInfo')),

  // Authentication
  login: lazy(() => import('./Documents/Login')),
  sign_up: lazy(() => import('./Documents/SignUp')),

  // Search
  full_text_search: lazy(() => import('./Documents/FullTextSearch')),

  // System nodes (maintenance, etc.)
  system_node: lazy(() => import('./Documents/SystemNode')),

  // Messaging
  message_inbox: lazy(() => import('./Documents/MessageInbox'))

  // Add new documents here as they are migrated
  // Format: document_type: lazy(() => import('./Documents/ComponentName'))
}

const DocumentComponent = ({ data, user, e2 }) => {
  const { type } = data

  // Suspense fallback - shown while component is loading
  const LoadingFallback = () => (
    <div className="document-loading" style={{ padding: '20px', textAlign: 'center' }}>
      <p>Loading...</p>
    </div>
  )

  // Look up component in registry
  const Component = COMPONENT_MAP[type]

  // Render component if found, otherwise show error
  const renderDocument = () => {
    if (Component) {
      return <Component data={data} user={user} e2={e2} />
    }

    return (
      <div className="document-error">
        <h2>Unknown Document Type</h2>
        <p>
          Document type "{type}" is not registered in DocumentComponent router.
        </p>
        <p>
          This document may need to be migrated to React, or the type may be incorrect.
        </p>
      </div>
    )
  }

  return <Suspense fallback={<LoadingFallback />}>{renderDocument()}</Suspense>
}

export default DocumentComponent
