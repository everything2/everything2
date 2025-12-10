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

  // Text generators
  fezisms_generator: lazy(() => import('./Documents/RandomText')),
  piercisms_generator: lazy(() => import('./Documents/RandomText')),
  teddisms_generator: lazy(() => import('./Documents/TeddismsGenerator')),
  ask_everything_do_i_have_the_swine_flu: lazy(() => import('./Documents/DoIHaveSwineFlu')),

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
  my_recent_writeups: lazy(() => import('./Documents/MyRecentWriteups')),

  // Help & information pages
  ipfrom: lazy(() => import('./Documents/Ipfrom')),
  everything2_elsewhere: lazy(() => import('./Documents/Everything2Elsewhere')),
  online_only_msg: lazy(() => import('./Documents/OnlineOnlyMsg')),
  chatterbox_help_topics: lazy(() => import('./Documents/ChatterboxHelpTopics')),
  permission_denied: lazy(() => import('./Documents/PermissionDenied')),
  super_mailbox: lazy(() => import('./Documents/SuperMailbox')),
  available_rooms: lazy(() => import('./Documents/AvailableRooms')),
  random_nodeshells: lazy(() => import('./Documents/RandomNodeshells')),
  database_lag_o_meter: lazy(() => import('./Documents/DatabaseLagOMeter')),
  nothing_found: lazy(() => import('./Documents/NothingFound')),
  duplicates_found: lazy(() => import('./Documents/DuplicatesFound')),
  findings: lazy(() => import('./Documents/Findings')),

  // Fullscreen chat interface (all variants use same component)
  chatterlight: lazy(() => import('./Documents/Chatterlight')),
  chatterlight_classic: lazy(() => import('./Documents/Chatterlight')),
  chatterlighter: lazy(() => import('./Documents/Chatterlight')),

  // Fun & games
  everything_quote_server: lazy(() => import('./Documents/EverythingQuoteServer')),
  e2_rot13_encoder: lazy(() => import('./Documents/E2Rot13Encoder')),
  e2_color_toy: lazy(() => import('./Documents/E2ColorToy')),
  buffalo_generator: lazy(() => import('./Documents/BuffaloGenerator')),
  buffalo_haiku_generator: lazy(() => import('./Documents/BuffaloGenerator')),

  // Utility tools
  text_formatter: lazy(() => import('./Documents/TextFormatter')),

  // Admin tools - unified AdminBestowTool component
  admin_bestow_tool: lazy(() => import('./Documents/AdminBestowTool')),
  superbless: lazy(() => import('./Documents/AdminBestowTool')),
  xp_superbless: lazy(() => import('./Documents/AdminBestowTool')),
  giant_teddy_bear_suit: lazy(() => import('./Documents/AdminBestowTool')),
  fiery_teddy_bear_suit: lazy(() => import('./Documents/AdminBestowTool')),
  bestow_easter_eggs: lazy(() => import('./Documents/AdminBestowTool')),
  bestow_cools: lazy(() => import('./Documents/AdminBestowTool')),

  // Admin info pages
  suspension_info: lazy(() => import('./Documents/SuspensionInfo')),

  // Authentication
  login: lazy(() => import('./Documents/Login')),
  sign_up: lazy(() => import('./Documents/SignUp')),

  // Search
  full_text_search: lazy(() => import('./Documents/FullTextSearch')),

  // System nodes (maintenance, etc.)
  system_node: lazy(() => import('./Documents/SystemNode')),

  // Messaging
  message_inbox: lazy(() => import('./Documents/MessageInbox')),

  // User visibility
  decloaker: lazy(() => import('./Documents/Decloaker')),

  // Policy pages
  e2_acceptable_use_policy: lazy(() => import('./Documents/AcceptableUsePolicy')),

  // Content discovery
  everything_user_search: lazy(() => import('./Documents/UserSearch')),

  // Editor beta (Tiptap testing)
  e2_editor_beta: lazy(() => import('./Documents/EditorBeta')),

  // Settings (unified interface for all settings pages)
  settings: lazy(() => import('./Documents/Settings')),

  // User blocking interface
  pit_of_abomination: lazy(() => import('./Documents/PitOfAbomination')),

  // Statistics & analytics
  site_trajectory: lazy(() => import('./Documents/SiteTrajectory')),

  // Help & documentation
  voting_experience_system: lazy(() => import('./Documents/VotingExperienceSystem')),
  user_relations: lazy(() => import('./Documents/UserRelations')),

  // Content discovery & editorial
  cool_archive: lazy(() => import('./Documents/CoolArchive')),
  page_of_cool: lazy(() => import('./Documents/PageOfCool')),

  // Community features - Polls
  everything_poll_creator: lazy(() => import('./Documents/EverythingPollCreator')),
  everything_poll_directory: lazy(() => import('./Documents/EverythingPollDirectory')),
  everything_poll_archive: lazy(() => import('./Documents/EverythingPollArchive')),
  everything_user_poll: lazy(() => import('./Documents/EverythingUserPoll')),

  // Admin tools - SQL interface
  sql_prompt: lazy(() => import('./Documents/SQLPrompt')),

  // User statistics & rankings
  everything_s_best_users: lazy(() => import('./Documents/EverythingsBestUsers')),
  everything_s_best_writeups: lazy(() => import('./Documents/EverythingsBestWriteups')),
  everything_s_biggest_stars: lazy(() => import('./Documents/EverythingsBiggestStars')),
  level_distribution: lazy(() => import('./Documents/LevelDistribution')),

  // Tools & utilities
  e2_sperm_counter: lazy(() => import('./Documents/E2SpermCounter')),
  e2_source_code_formatter: lazy(() => import('./Documents/E2SourceCodeFormatter')),
  e2_marble_shop: lazy(() => import('./Documents/E2MarbleShop')),
  e2_penny_jar: lazy(() => import('./Documents/E2PennyJar')),

  // Developer resources
  edev_faq: lazy(() => import('./Documents/EdevFAQ')),
  edev_documentation_index: lazy(() => import('./Documents/EdevDocumentationIndex')),
  everything_data_pages: lazy(() => import('./Documents/EverythingDataPages')),

  // Editorial tools
  editor_endorsements: lazy(() => import('./Documents/EditorEndorsements')),
  content_reports: lazy(() => import('./Documents/ContentReports')),
  everything_document_directory: lazy(() => import('./Documents/EverythingDocumentDirectory')),
  drafts_for_review: lazy(() => import('./Documents/DraftsForReview')),
  bad_spellings_listing: lazy(() => import('./Documents/BadSpellingsListing')),
  alphabetizer: lazy(() => import('./Documents/Alphabetizer')),
  do_you_c_what_i_c: lazy(() => import('./Documents/DoYouCWhatIC')),
  the_recommender: lazy(() => import('./Documents/TheRecommender')),
  voting_oracle: lazy(() => import('./Documents/VotingOracle')),
  who_is_doing_what: lazy(() => import('./Documents/WhoIsDoingWhat')),
  recent_users: lazy(() => import('./Documents/RecentUsers')),
  e2_word_counter: lazy(() => import('./Documents/E2WordCounter')),
  spam_cannon: lazy(() => import('./Documents/SpamCannon')),
  e2_bouncer: lazy(() => import('./Documents/E2Bouncer')),

  // Chat room management
  create_room: lazy(() => import('./Documents/CreateRoom')),

  // News & announcements
  news_for_noders: lazy(() => import('./Documents/NewsForNoders')),

  // Community features - Who's online
  everything_finger: lazy(() => import('./Documents/EverythingFinger')),

  // Admin tools
  list_nodes_of_type: lazy(() => import('./Documents/ListNodesOfType')),
  gnl: lazy(() => import('./Documents/ListNodesOfType')),

  // Help & documentation
  macro_faq: lazy(() => import('./Documents/MacroFaq')),

  // Admin settings (uses unified Settings component with defaultTab='admin')
  admin_settings: lazy(() => import('./Documents/Settings')),

  // Voting
  blind_voting_booth: lazy(() => import('./Documents/BlindVotingBooth')),

  // Reputation visualization (both layouts use same component)
  reputation_graph: lazy(() => import('./Documents/ReputationGraph')),

  // Content discovery
  between_the_cracks: lazy(() => import('./Documents/BetweenTheCracks')),

  // Registries
  popular_registries: lazy(() => import('./Documents/PopularRegistries')),
  recent_registry_entries: lazy(() => import('./Documents/RecentRegistryEntries')),
  registry_information: lazy(() => import('./Documents/RegistryInformation')),
  the_registries: lazy(() => import('./Documents/TheRegistries')),
  create_a_registry: lazy(() => import('./Documents/CreateARegistry')),

  // Iron Noder (both use same component, differentiated by is_historical flag)
  iron_noder_progress: lazy(() => import('./Documents/IronNoderProgress'))

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
