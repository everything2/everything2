import React from 'react'
import { render, screen } from '@testing-library/react'

// TipTap v3's useEditor can hand a component an editor instance it has already destroyed (it
// re-creates the instance across remounts; the replacement arrives on the next render). Touching
// .commands on a destroyed editor throws, and an uncaught throw in an effect unmounts the whole
// page. Settings (profile tab) and UserEdit must render through it.
const destroyedEditor = {
  isDestroyed: true,
  get commands() { throw new TypeError("Cannot read properties of null (reading 'commands')") },
  getHTML() { throw new TypeError('destroyed') },
  on() {}, off() {},
}

jest.mock('@tiptap/react', () => ({
  ...jest.requireActual('@tiptap/react'),
  useEditor: () => destroyedEditor,
  EditorContent: () => null,
}))
jest.mock('../UserInteractions/FavoriteUsersManager', () => () => null)
jest.mock('../UserInteractions/UserInteractionsManager', () => () => null)

import Settings from './Settings'
import UserEdit from './UserEdit'

const profile = { realname: 'Real Name', email: 'a@b.c', doctext: '<p>my bio</p>', mission: '', specialties: '', employment: '', motto: '' }

describe('profile editors with a destroyed TipTap instance', () => {
  it('Settings profile tab still renders', () => {
    render(<Settings data={{
      defaultTab: 'profile', settingsPreferences: {}, advancedPreferences: {}, nodelets: [], availableNodelets: [],
      notificationPreferences: [], nodeletSettings: {}, editorPreferences: {}, macros: [], blockedUsers: [],
      favoriteUsers: [], availableStylesheets: [], profileData: profile,
    }} user={{ node_id: 1, title: 'tester' }} />)
    expect(screen.getByDisplayValue('a@b.c')).toBeInTheDocument()
  })

  it('UserEdit still renders', () => {
    render(<UserEdit data={{
      user: { node_id: 100, ...profile, bookmarks: [], imgsrc: '' },
      viewer: { node_id: 100, is_admin: false },
      can_have_image: true,
    }} />)
    expect(screen.getByDisplayValue('a@b.c')).toBeInTheDocument()
  })
})
