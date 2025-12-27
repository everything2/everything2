import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import EditorBeta from './EditorBeta'

// Mock Tiptap editor - the real editor requires a DOM environment
jest.mock('@tiptap/react', () => ({
  useEditor: jest.fn(() => ({
    commands: {
      setContent: jest.fn(),
    },
    getHTML: jest.fn(() => '<p>Test content</p>'),
  })),
  EditorContent: ({ editor }) => (
    <div className="e2-editor-content" data-testid="editor-content">
      Mock Editor Content
    </div>
  ),
}))

// Mock the MenuBar component
jest.mock('../Editor/MenuBar', () => {
  return function MockMenuBar({ editor }) {
    return <div data-testid="menu-bar">Mock Menu Bar</div>
  }
})

// Mock the E2LinkExtension
jest.mock('../Editor/E2LinkExtension', () => ({
  E2Link: {},
  convertToE2Syntax: jest.fn((html) => html),
}))

// Mock the RawBracketExtension
jest.mock('../Editor/RawBracketExtension', () => ({
  RawBracket: {},
  convertRawBracketsToEntities: jest.fn((html) => html),
  convertEntitiesToRawBrackets: jest.fn((html) => html),
}))

// Mock shared editor utilities
jest.mock('../Editor/useE2Editor', () => ({
  getE2EditorExtensions: jest.fn(() => []),
}))

// Mock StarterKit and other Tiptap extensions
jest.mock('@tiptap/starter-kit', () => ({
  __esModule: true,
  default: {
    configure: jest.fn(() => ({})),
  },
}))

jest.mock('@tiptap/extension-underline', () => ({
  __esModule: true,
  default: {},
}))

jest.mock('@tiptap/extension-subscript', () => ({
  __esModule: true,
  default: {},
}))

jest.mock('@tiptap/extension-superscript', () => ({
  __esModule: true,
  default: {},
}))

jest.mock('@tiptap/extension-table', () => ({
  __esModule: true,
  default: {
    configure: jest.fn(() => ({})),
  },
}))

jest.mock('@tiptap/extension-table-row', () => ({
  __esModule: true,
  default: {},
}))

jest.mock('@tiptap/extension-table-cell', () => ({
  __esModule: true,
  default: {},
}))

jest.mock('@tiptap/extension-table-header', () => ({
  __esModule: true,
  default: {},
}))

jest.mock('@tiptap/extension-text-align', () => ({
  __esModule: true,
  default: {
    configure: jest.fn(() => ({})),
  },
}))

// Mock fetch for API calls
global.fetch = jest.fn(() =>
  Promise.resolve({
    ok: true,
    json: () => Promise.resolve({ success: true }),
  })
)

describe('EditorBeta', () => {
  const mockData = {
    canAccess: true,
    username: 'testuser',
    approvedTags: ['p', 'strong', 'em', 'a', 'h1', 'h2', 'ul', 'li'],
    drafts: [],
    statuses: [
      { id: '1', name: 'private' },
      { id: '2', name: 'shared' },
      { id: '3', name: 'findable' },
      { id: '4', name: 'review' },
    ],
  }

  beforeEach(() => {
    jest.clearAllMocks()
    // Reset fetch mock with default successful response
    global.fetch.mockReset()
    global.fetch.mockImplementation(() =>
      Promise.resolve({
        ok: true,
        json: () => Promise.resolve({ success: true }),
      })
    )
  })

  describe('access control', () => {
    it('shows login message when canAccess is false', () => {
      render(<EditorBeta data={{ ...mockData, canAccess: false }} />)

      expect(screen.getByText('Please log in to use the drafts editor.')).toBeInTheDocument()
    })

    it('shows editor when canAccess is true', () => {
      render(<EditorBeta data={mockData} />)

      expect(screen.getByText('Drafts')).toBeInTheDocument()
      expect(screen.getByText(/Hello, testuser/)).toBeInTheDocument()
    })
  })

  describe('UI elements', () => {
    it('renders title input', () => {
      render(<EditorBeta data={mockData} />)

      expect(screen.getByPlaceholderText('Enter draft title...')).toBeInTheDocument()
    })

    it('renders the editor menu bar', () => {
      render(<EditorBeta data={mockData} />)

      expect(screen.getByTestId('menu-bar')).toBeInTheDocument()
    })

    it('renders the editor content area', () => {
      render(<EditorBeta data={mockData} />)

      expect(screen.getByTestId('editor-content')).toBeInTheDocument()
    })

    it('renders status dropdown with all statuses', () => {
      render(<EditorBeta data={mockData} />)

      const select = screen.getByRole('combobox')
      expect(select).toBeInTheDocument()

      // Check all status options are present
      expect(screen.getByRole('option', { name: 'private' })).toBeInTheDocument()
      expect(screen.getByRole('option', { name: 'shared' })).toBeInTheDocument()
      expect(screen.getByRole('option', { name: 'findable' })).toBeInTheDocument()
      expect(screen.getByRole('option', { name: 'review' })).toBeInTheDocument()
    })

    it('renders Hide Preview button (preview shown by default)', () => {
      render(<EditorBeta data={mockData} />)

      expect(screen.getByRole('button', { name: 'Hide Preview' })).toBeInTheDocument()
    })

    it('renders Create Draft button when no draft selected', () => {
      render(<EditorBeta data={mockData} />)

      expect(screen.getByRole('button', { name: 'Create Draft' })).toBeInTheDocument()
    })

  })

  describe('drafts sidebar', () => {
    it('shows empty state when no drafts', () => {
      render(<EditorBeta data={mockData} />)

      expect(screen.getByText('No drafts yet. Your drafts will appear here.')).toBeInTheDocument()
    })

    it('shows drafts when provided', () => {
      const dataWithDrafts = {
        ...mockData,
        drafts: [
          {
            node_id: 123,
            title: 'My First Draft',
            status: 'private',
            doctext: '<p>Draft content</p>',
            createtime: '2025-01-15',
          },
          {
            node_id: 456,
            title: 'Second Draft',
            status: 'review',
            doctext: '<p>More content</p>',
            createtime: '2025-01-14',
          },
        ],
      }

      render(<EditorBeta data={dataWithDrafts} />)

      expect(screen.getByText('My First Draft')).toBeInTheDocument()
      expect(screen.getByText('Second Draft')).toBeInTheDocument()
    })

    it('renders + New Draft button', () => {
      render(<EditorBeta data={mockData} />)

      expect(screen.getByRole('button', { name: '+ New Draft' })).toBeInTheDocument()
    })

    it('can collapse sidebar', () => {
      render(<EditorBeta data={mockData} />)

      const collapseButton = screen.getByRole('button', { name: '<' })
      expect(collapseButton).toBeInTheDocument()

      fireEvent.click(collapseButton)

      // After collapse, button text should change to '>'
      expect(screen.getByRole('button', { name: '>' })).toBeInTheDocument()
    })
  })

  describe('draft selection', () => {
    it('loads draft content when clicking on a draft', () => {
      const dataWithDrafts = {
        ...mockData,
        drafts: [
          {
            node_id: 123,
            title: 'My First Draft',
            status: 'private',
            doctext: '<p>Draft content</p>',
            createtime: '2025-01-15',
          },
        ],
      }

      render(<EditorBeta data={dataWithDrafts} />)

      const draftItem = screen.getByText('My First Draft')
      fireEvent.click(draftItem)

      // Title input should be populated
      expect(screen.getByDisplayValue('My First Draft')).toBeInTheDocument()

      // Button should change to "Save" when draft is selected
      expect(screen.getByRole('button', { name: 'Save' })).toBeInTheDocument()
    })

    it('shows Version History button when draft is selected', () => {
      const dataWithDrafts = {
        ...mockData,
        drafts: [
          {
            node_id: 123,
            title: 'My Draft',
            status: 'private',
            doctext: '<p>Content</p>',
            createtime: '2025-01-15',
          },
        ],
      }

      render(<EditorBeta data={dataWithDrafts} />)

      // Click on draft to select it
      fireEvent.click(screen.getByText('My Draft'))

      // Version History button should appear
      expect(screen.getByRole('button', { name: 'Version History' })).toBeInTheDocument()
    })

    it('hides Version History button when no draft selected', () => {
      render(<EditorBeta data={mockData} />)

      expect(screen.queryByRole('button', { name: 'Version History' })).not.toBeInTheDocument()
    })
  })

  describe('creating drafts', () => {
    it('calls API when Create Draft is clicked', async () => {
      global.fetch.mockResolvedValueOnce({
        json: () =>
          Promise.resolve({
            success: true,
            draft: {
              node_id: 999,
              title: 'New Draft',
              status: 'private',
            },
          }),
      })

      render(<EditorBeta data={mockData} />)

      // Enter a title
      const titleInput = screen.getByPlaceholderText('Enter draft title...')
      fireEvent.change(titleInput, { target: { value: 'New Draft' } })

      // Click Create Draft
      const createButton = screen.getByRole('button', { name: 'Create Draft' })
      fireEvent.click(createButton)

      await waitFor(() => {
        expect(global.fetch).toHaveBeenCalledWith('/api/drafts', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: expect.stringContaining('New Draft'),
        })
      })
    })
  })

  describe('saving drafts', () => {
    it('calls update API when Save is clicked on existing draft', async () => {
      const dataWithDrafts = {
        ...mockData,
        drafts: [
          {
            node_id: 123,
            title: 'Existing Draft',
            status: 'private',
            doctext: '<p>Original content</p>',
            createtime: '2025-01-15',
          },
        ],
      }

      global.fetch.mockResolvedValueOnce({
        json: () =>
          Promise.resolve({
            success: true,
            updated: { doctext: 1 },
            draft_id: 123,
          }),
      })

      render(<EditorBeta data={dataWithDrafts} />)

      // Select the draft
      fireEvent.click(screen.getByText('Existing Draft'))

      // Click Save
      const saveButton = screen.getByRole('button', { name: 'Save' })
      fireEvent.click(saveButton)

      await waitFor(() => {
        expect(global.fetch).toHaveBeenCalledWith('/api/drafts/123', {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: expect.any(String),
        })
      })
    })
  })

  describe('preview functionality', () => {
    it('shows preview by default without API call', async () => {
      render(<EditorBeta data={mockData} />)

      // Preview should be visible by default
      expect(screen.getByRole('button', { name: /Hide Preview/i })).toBeInTheDocument()
      expect(screen.getByText('Preview', { selector: 'h3' })).toBeInTheDocument()

      // Should NOT have called the preview API (client-side rendering)
      expect(global.fetch).not.toHaveBeenCalledWith(
        '/api/drafts/preview',
        expect.anything()
      )
    })

    it('toggles preview pane visibility', async () => {
      render(<EditorBeta data={mockData} />)

      // Preview should be visible initially
      expect(screen.getByText('Preview', { selector: 'h3' })).toBeInTheDocument()

      // Click Hide Preview button
      const hidePreviewButton = screen.getByRole('button', { name: 'Hide Preview' })
      fireEvent.click(hidePreviewButton)

      // Preview should be hidden
      expect(screen.queryByText('Preview', { selector: 'h3' })).not.toBeInTheDocument()
      expect(screen.getByRole('button', { name: 'Preview' })).toBeInTheDocument()
    })
  })


  describe('edit mode toggle', () => {
    it('renders Rich/HTML slider toggle', () => {
      render(<EditorBeta data={mockData} />)

      // Should show both Rich and HTML options in the toggle
      expect(screen.getByText('Rich')).toBeInTheDocument()
      expect(screen.getByText('HTML')).toBeInTheDocument()
    })

    it('switches to HTML editing mode when toggle is clicked', () => {
      render(<EditorBeta data={mockData} />)

      // Click the toggle (it's the container div with class e2-mode-toggle)
      const toggle = screen.getByText('Rich').parentElement
      fireEvent.click(toggle)

      // Should show HTML editing hint
      expect(screen.getByText(/Editing raw HTML/)).toBeInTheDocument()
    })

    it('switches back to rich text mode', () => {
      render(<EditorBeta data={mockData} />)

      // Switch to HTML mode
      const toggle = screen.getByText('Rich').parentElement
      fireEvent.click(toggle)

      // Should show HTML mode indicator
      expect(screen.getByText(/Editing raw HTML/)).toBeInTheDocument()

      // Switch back to rich mode
      fireEvent.click(toggle)

      // HTML mode indicator should be gone
      expect(screen.queryByText(/Editing raw HTML/)).not.toBeInTheDocument()
    })

    it('respects preferRawHtml prop to start in HTML mode', () => {
      render(<EditorBeta data={{ ...mockData, preferRawHtml: true }} />)

      // Should start in HTML mode
      expect(screen.getByText(/Editing raw HTML/)).toBeInTheDocument()
    })

    it('saves preference when mode is toggled', () => {
      render(<EditorBeta data={mockData} />)

      const toggle = screen.getByText('Rich').parentElement
      fireEvent.click(toggle)

      // Should have called fetch to save preference
      expect(global.fetch).toHaveBeenCalledWith(
        '/api/preferences/set',
        expect.objectContaining({
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ tiptap_editor_raw: 1 })
        })
      )
    })
  })

  describe('status management', () => {
    it('allows changing publication status', () => {
      render(<EditorBeta data={mockData} />)

      const statusSelect = screen.getByRole('combobox')
      fireEvent.change(statusSelect, { target: { value: 'review' } })

      expect(statusSelect.value).toBe('review')
    })
  })

  describe('title editing', () => {
    it('updates title when input changes', () => {
      render(<EditorBeta data={mockData} />)

      const titleInput = screen.getByPlaceholderText('Enter draft title...')
      fireEvent.change(titleInput, { target: { value: 'My New Title' } })

      expect(screen.getByDisplayValue('My New Title')).toBeInTheDocument()
    })
  })

  describe('new draft functionality', () => {
    it('clears editor when New Draft is clicked', () => {
      const dataWithDrafts = {
        ...mockData,
        drafts: [
          {
            node_id: 123,
            title: 'Existing Draft',
            status: 'private',
            doctext: '<p>Content</p>',
            createtime: '2025-01-15',
          },
        ],
      }

      render(<EditorBeta data={dataWithDrafts} />)

      // First select a draft
      fireEvent.click(screen.getByText('Existing Draft'))
      expect(screen.getByDisplayValue('Existing Draft')).toBeInTheDocument()

      // Click New Draft
      fireEvent.click(screen.getByRole('button', { name: '+ New Draft' }))

      // Title should be cleared
      expect(screen.queryByDisplayValue('Existing Draft')).not.toBeInTheDocument()
      expect(screen.getByPlaceholderText('Enter draft title...')).toHaveValue('')

      // Button should change back to Create Draft
      expect(screen.getByRole('button', { name: 'Create Draft' })).toBeInTheDocument()
    })
  })

  describe('edge cases', () => {
    it('handles missing data gracefully', () => {
      render(<EditorBeta data={{}} />)

      // Should show login prompt when canAccess is falsy
      expect(screen.getByText('Please log in to use the drafts editor.')).toBeInTheDocument()
    })

    it('handles null drafts array gracefully', () => {
      const dataWithNullDrafts = {
        ...mockData,
        drafts: null,
      }

      // Should not throw and should show empty state
      render(<EditorBeta data={dataWithNullDrafts} />)
      expect(screen.getByText('No drafts yet. Your drafts will appear here.')).toBeInTheDocument()
    })

    it('handles empty statuses array', () => {
      const dataWithNoStatuses = {
        ...mockData,
        statuses: [],
      }

      render(<EditorBeta data={dataWithNoStatuses} />)

      const select = screen.getByRole('combobox')
      expect(select).toBeInTheDocument()
      expect(select.options.length).toBe(0)
    })
  })
})
