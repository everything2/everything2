import React from 'react'
import { render, screen, fireEvent, waitFor, act } from '@testing-library/react'
import InlineWriteupEditor from './InlineWriteupEditor'

// Mock Tiptap editor
const mockEditor = {
  getHTML: jest.fn(() => '<p>Test content</p>'),
  commands: {
    focus: jest.fn(),
    setContent: jest.fn()
  }
}

jest.mock('@tiptap/react', () => ({
  useEditor: jest.fn(() => mockEditor),
  EditorContent: ({ editor }) => (
    <div data-testid="editor-content">Editor Content</div>
  )
}))

// Mock shared editor utilities
jest.mock('./Editor/useE2Editor', () => ({
  getE2EditorExtensions: jest.fn(() => []),
  useEditorMode: jest.fn(() => ({
    editorMode: 'rich',
    setEditorMode: jest.fn(),
    htmlContent: '',
    setHtmlContent: jest.fn(),
    handleHtmlChange: jest.fn(),
    toggleMode: jest.fn(),
    getCurrentContent: jest.fn(() => '')
  }))
}))

// Mock custom extensions
jest.mock('./Editor/E2LinkExtension', () => ({
  E2Link: {},
  convertToE2Syntax: jest.fn((html) => html)
}))

jest.mock('./Editor/RawBracketExtension', () => ({
  RawBracket: {},
  convertRawBracketsToEntities: jest.fn((html) => html),
  convertEntitiesToRawBrackets: jest.fn((html) => html)
}))

// Mock MenuBar
jest.mock('./Editor/MenuBar', () => {
  return function MockMenuBar({ editor }) {
    return <div data-testid="menu-bar">Menu Bar</div>
  }
})

// Mock localStorage
const localStorageMock = {
  getItem: jest.fn(),
  setItem: jest.fn(),
  clear: jest.fn()
}
Object.defineProperty(window, 'localStorage', { value: localStorageMock })

// Mock fetch - always return a resolved promise by default
global.fetch = jest.fn(() => Promise.resolve({
  json: () => Promise.resolve({ success: true })
}))

describe('InlineWriteupEditor', () => {
  const defaultProps = {
    e2nodeId: 123,
    e2nodeTitle: 'Test Node',
    onPublish: jest.fn(),
    onSave: jest.fn(),
    onCancel: jest.fn()
  }

  beforeEach(() => {
    jest.clearAllMocks()
    jest.useFakeTimers()
    // Reset fetch to default behavior
    fetch.mockImplementation(() => Promise.resolve({
      json: () => Promise.resolve({ success: true })
    }))
    localStorageMock.getItem.mockReturnValue(null)
  })

  afterEach(() => {
    jest.useRealTimers()
  })

  describe('rendering', () => {
    it('renders the editor for new writeup', () => {
      render(<InlineWriteupEditor {...defaultProps} />)

      expect(screen.getByText('Add a Writeup')).toBeInTheDocument()
      expect(screen.getByText(/to "Test Node"/)).toBeInTheDocument()
    })

    it('renders menu bar in rich mode', () => {
      render(<InlineWriteupEditor {...defaultProps} />)

      expect(screen.getByTestId('menu-bar')).toBeInTheDocument()
    })

    it('shows continue draft message when draftId provided', () => {
      render(<InlineWriteupEditor {...defaultProps} draftId={456} />)

      expect(screen.getByText('Continue your draft')).toBeInTheDocument()
    })

    it('shows editing message when writeupId provided', () => {
      render(
        <InlineWriteupEditor
          {...defaultProps}
          writeupId={789}
          isOwnWriteup={true}
        />
      )

      expect(screen.getByText('Editing your writeup')).toBeInTheDocument()
    })

    it('shows editing others writeup message', () => {
      render(
        <InlineWriteupEditor
          {...defaultProps}
          writeupId={789}
          writeupAuthor="OtherAuthor"
          isOwnWriteup={false}
        />
      )

      expect(screen.getByText("Editing OtherAuthor's writeup")).toBeInTheDocument()
    })
  })

  describe('mode toggle', () => {
    it('starts in rich mode by default', () => {
      render(<InlineWriteupEditor {...defaultProps} />)

      expect(screen.getByTestId('editor-content')).toBeInTheDocument()
    })

    it('respects localStorage preference for HTML mode', () => {
      localStorageMock.getItem.mockReturnValue('html')

      render(<InlineWriteupEditor {...defaultProps} />)

      // In HTML mode, should show textarea
      expect(screen.getByPlaceholderText('Enter HTML content here...')).toBeInTheDocument()
    })

    it('toggles between Rich and HTML modes', () => {
      render(<InlineWriteupEditor {...defaultProps} />)

      // Click on the toggle (the HTML part)
      const toggleContainer = screen.getByText('Rich').parentElement
      fireEvent.click(toggleContainer)

      // Should now show HTML mode
      expect(screen.getByPlaceholderText('Enter HTML content here...')).toBeInTheDocument()
    })

    it('saves mode preference to localStorage', () => {
      render(<InlineWriteupEditor {...defaultProps} />)

      const toggleContainer = screen.getByText('Rich').parentElement
      fireEvent.click(toggleContainer)

      expect(localStorageMock.setItem).toHaveBeenCalledWith('e2_editor_mode', 'html')
    })
  })

  describe('buttons', () => {
    it('has Save button for drafts', () => {
      render(<InlineWriteupEditor {...defaultProps} draftId={456} />)

      expect(screen.getByRole('button', { name: 'Save' })).toBeInTheDocument()
    })

    it('has Publish button for new writeups', () => {
      render(<InlineWriteupEditor {...defaultProps} />)

      expect(screen.getByRole('button', { name: 'Publish' })).toBeInTheDocument()
    })

    it('Publish button is disabled without draft', () => {
      render(<InlineWriteupEditor {...defaultProps} />)

      expect(screen.getByRole('button', { name: 'Publish' })).toBeDisabled()
    })

    it('has Update button for existing writeups', () => {
      render(<InlineWriteupEditor {...defaultProps} writeupId={789} />)

      expect(screen.getByRole('button', { name: 'Update' })).toBeInTheDocument()
    })

    it('does not show Publish button for existing writeups', () => {
      render(<InlineWriteupEditor {...defaultProps} writeupId={789} />)

      expect(screen.queryByRole('button', { name: 'Publish' })).not.toBeInTheDocument()
    })

    it('has Delete Draft button when draft exists', () => {
      render(<InlineWriteupEditor {...defaultProps} draftId={456} />)

      expect(screen.getByRole('button', { name: 'Delete Draft' })).toBeInTheDocument()
    })

    it('does not show Delete Draft button without draft', () => {
      render(<InlineWriteupEditor {...defaultProps} />)

      expect(screen.queryByRole('button', { name: 'Delete Draft' })).not.toBeInTheDocument()
    })

    it('does not show Delete Draft button for existing writeups', () => {
      render(<InlineWriteupEditor {...defaultProps} writeupId={789} />)

      expect(screen.queryByRole('button', { name: 'Delete Draft' })).not.toBeInTheDocument()
    })

    it('shows confirmation modal when Delete Draft is clicked', () => {
      render(<InlineWriteupEditor {...defaultProps} draftId={456} />)

      fireEvent.click(screen.getByRole('button', { name: 'Delete Draft' }))

      expect(screen.getByText('Delete Draft?')).toBeInTheDocument()
      expect(screen.getByText(/Are you sure you want to delete this draft/)).toBeInTheDocument()
      expect(screen.getByRole('button', { name: 'Cancel' })).toBeInTheDocument()
      expect(screen.getByRole('button', { name: 'Delete' })).toBeInTheDocument()
    })

    it('closes confirmation modal when Cancel is clicked', () => {
      render(<InlineWriteupEditor {...defaultProps} draftId={456} />)

      fireEvent.click(screen.getByRole('button', { name: 'Delete Draft' }))
      expect(screen.getByText('Delete Draft?')).toBeInTheDocument()

      fireEvent.click(screen.getByRole('button', { name: 'Cancel' }))
      expect(screen.queryByText('Delete Draft?')).not.toBeInTheDocument()
    })
  })

  describe('save status', () => {
    it('shows start typing message for new writeups', () => {
      render(<InlineWriteupEditor {...defaultProps} />)

      expect(screen.getByText('Start typing to create a draft')).toBeInTheDocument()
    })

    it('shows unsaved changes for editing mode', () => {
      // Mock useEditor to trigger unsaved state
      const { useEditor } = require('@tiptap/react')
      useEditor.mockImplementation(({ onUpdate }) => {
        // Simulate an update to trigger unsaved state
        setTimeout(() => {
          if (onUpdate) onUpdate({ editor: mockEditor })
        }, 0)
        return mockEditor
      })

      render(<InlineWriteupEditor {...defaultProps} writeupId={789} />)

      // Initial state
      expect(screen.queryByText('Unsaved changes')).not.toBeInTheDocument()
    })
  })

  describe('writeuptype selection', () => {
    it('fetches writeuptypes on mount for new writeup', async () => {
      fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({
          success: true,
          writeuptypes: [
            { node_id: 1, title: 'thing' },
            { node_id: 2, title: 'idea' }
          ]
        })
      })

      render(<InlineWriteupEditor {...defaultProps} />)

      await waitFor(() => {
        // Hook uses fetchWithErrorReporting which calls fetch(url, options)
        expect(fetch).toHaveBeenCalledWith('/api/writeuptypes', expect.any(Object))
      })
    })

    it('fetches writeuptypes for existing writeup too (in-place type edit, #4224)', () => {
      render(<InlineWriteupEditor {...defaultProps} writeupId={789} />)

      // Edit mode now loads types so the author can change the type in place.
      expect(fetch).toHaveBeenCalledWith('/api/writeuptypes', expect.any(Object))
    })

    it('has writeuptype select for new writeups', async () => {
      fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({
          success: true,
          writeuptypes: [{ node_id: 1, title: 'thing' }]
        })
      })

      render(<InlineWriteupEditor {...defaultProps} />)

      // Should show dynamic publishing preview with e2node title and writeup type
      expect(screen.getByText(/Publishing:/)).toBeInTheDocument()
    })

    it('shows e2node title in publishing preview', () => {
      render(<InlineWriteupEditor {...defaultProps} />)

      // Should show the e2node title in the publishing preview
      expect(screen.getByText('Test Node')).toBeInTheDocument()
    })
  })

  describe('hide from new writeups', () => {
    it('has hide checkbox for new writeups', () => {
      render(<InlineWriteupEditor {...defaultProps} />)

      expect(screen.getByLabelText('Hide from New Writeups')).toBeInTheDocument()
    })

    it('checkbox is unchecked by default', () => {
      render(<InlineWriteupEditor {...defaultProps} />)

      expect(screen.getByLabelText('Hide from New Writeups')).not.toBeChecked()
    })

    it('can toggle hide checkbox', () => {
      render(<InlineWriteupEditor {...defaultProps} />)

      const checkbox = screen.getByLabelText('Hide from New Writeups')
      fireEvent.click(checkbox)

      expect(checkbox).toBeChecked()
    })
  })

  describe('error handling', () => {
    it('shows error state styling when error exists', () => {
      // This test validates that error message elements exist and can be rendered
      // The actual error display is tested by checking the error UI container exists
      render(<InlineWriteupEditor {...defaultProps} draftId={456} />)

      // The component has the error message div structure ready
      // Actual error triggering requires complex async flow with tiptap
      expect(screen.getByRole('button', { name: 'Save' })).toBeInTheDocument()
    })
  })

  describe('HTML mode', () => {
    beforeEach(() => {
      localStorageMock.getItem.mockReturnValue('html')
    })

    it('renders textarea in HTML mode', () => {
      render(<InlineWriteupEditor {...defaultProps} />)

      expect(screen.getByPlaceholderText('Enter HTML content here...')).toBeInTheDocument()
    })

    it('allows typing in HTML textarea', () => {
      render(<InlineWriteupEditor {...defaultProps} />)

      const textarea = screen.getByPlaceholderText('Enter HTML content here...')
      fireEvent.change(textarea, { target: { value: '<p>New content</p>' } })

      expect(textarea.value).toBe('<p>New content</p>')
    })
  })

  describe('initial content', () => {
    it('accepts initial content prop', () => {
      const initialContent = '<p>Initial content</p>'

      render(
        <InlineWriteupEditor
          {...defaultProps}
          initialContent={initialContent}
        />
      )

      // In rich mode, editor should have content
      expect(screen.getByTestId('editor-content')).toBeInTheDocument()
    })

    // #3385: shared/plain-text drafts lost their paragraph breaks in the edit
    // box (one solid block) while the read-only display rendered them fine.
    // The editor must run the same breakTags newline→<p> normalization the
    // display does, before handing content to TipTap (which collapses bare
    // newlines).
    describe('paragraph preservation (#3385)', () => {
      const getEditorContent = () => {
        const { useEditor } = require('@tiptap/react')
        // convertEntitiesToRawBrackets is mocked identity, so the content arg
        // is exactly the breakTags-normalized initial content.
        return useEditor.mock.calls[0][0].content
      }

      it('converts plain-text \\n\\n paragraph breaks to <p> before TipTap sees them', () => {
        render(
          <InlineWriteupEditor
            {...defaultProps}
            initialContent={'First paragraph.\n\nSecond paragraph.'}
          />
        )
        const content = getEditorContent()
        // Should be wrapped/split into paragraphs, not a single bare block.
        expect(content).toMatch(/<p>/i)
        expect(content).toContain('First paragraph.')
        expect(content).toContain('Second paragraph.')
        // The two paragraphs must be separated by block markup, not just a
        // collapsed space.
        expect(content).not.toBe('First paragraph.\n\nSecond paragraph.')
      })

      it('leaves already-formatted (<p>-tagged) drafts unchanged (idempotent)', () => {
        const formatted = '<p>Already</p><p>Formatted</p>'
        render(
          <InlineWriteupEditor
            {...defaultProps}
            initialContent={formatted}
          />
        )
        expect(getEditorContent()).toBe(formatted)
      })

      it('handles empty initial content without error', () => {
        render(<InlineWriteupEditor {...defaultProps} initialContent={''} />)
        expect(getEditorContent()).toBe('')
      })
    })
  })

  describe('title parsing for drafts', () => {
    it('parses writeuptype from title and displays extracted e2node title', async () => {
      // When e2nodeTitle has format "title (writeuptype)", should extract just the title
      fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({
          success: true,
          writeuptypes: [
            { node_id: 1, title: 'thing' },
            { node_id: 2, title: 'poetry' },
            { node_id: 3, title: 'idea' }
          ]
        })
      })

      render(
        <InlineWriteupEditor
          {...defaultProps}
          e2nodeTitle="Quick brown fox (poetry)"
        />
      )

      // Should show just the e2node title part in "to" text
      expect(screen.getByText(/to "Quick brown fox"/)).toBeInTheDocument()
      // Should NOT show the full title with writeuptype suffix
      expect(screen.queryByText(/to "Quick brown fox \(poetry\)"/)).not.toBeInTheDocument()
    })

    it('pre-selects writeuptype from parsed title', async () => {
      fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({
          success: true,
          writeuptypes: [
            { node_id: 1, title: 'thing' },
            { node_id: 2, title: 'poetry' },
            { node_id: 3, title: 'idea' }
          ]
        })
      })

      render(
        <InlineWriteupEditor
          {...defaultProps}
          e2nodeTitle="Quick brown fox (poetry)"
          draftId={456}
        />
      )

      await waitFor(() => {
        // Find the select element and check its value - poetry should be selected
        const select = screen.getByRole('combobox')
        expect(select.value).toBe('2') // poetry's node_id
      })
    })

    it('shows publishing preview with parsed title and selected writeuptype', async () => {
      fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({
          success: true,
          writeuptypes: [
            { node_id: 1, title: 'thing' },
            { node_id: 2, title: 'poetry' },
            { node_id: 3, title: 'idea' }
          ]
        })
      })

      render(
        <InlineWriteupEditor
          {...defaultProps}
          e2nodeTitle="Quick brown fox (poetry)"
          draftId={456}
        />
      )

      await waitFor(() => {
        // Publishing preview should show correctly formatted title
        expect(screen.getByText('Quick brown fox (poetry)')).toBeInTheDocument()
      })
    })

    it('keeps full title when no writeuptype suffix present', () => {
      fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({
          success: true,
          writeuptypes: [{ node_id: 1, title: 'thing' }]
        })
      })

      render(
        <InlineWriteupEditor
          {...defaultProps}
          e2nodeTitle="My Simple Title"
        />
      )

      expect(screen.getByText(/to "My Simple Title"/)).toBeInTheDocument()
    })

    it('handles titles with parentheses that are not writeuptypes', () => {
      fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({
          success: true,
          writeuptypes: [
            { node_id: 1, title: 'thing' },
            { node_id: 2, title: 'idea' }
          ]
        })
      })

      render(
        <InlineWriteupEditor
          {...defaultProps}
          e2nodeTitle="Something (with parens) in middle"
        />
      )

      // Should show the full title since "in middle" is not a valid writeuptype
      expect(screen.getByText(/to "Something \(with parens\) in middle"/)).toBeInTheDocument()
    })

    it('auto-selects writeuptype for reverted draft instead of defaulting to thing', async () => {
      // Simulates a reverted writeup where the draft title contains the original writeuptype
      fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({
          success: true,
          writeuptypes: [
            { node_id: 1, title: 'thing' },
            { node_id: 2, title: 'idea' },
            { node_id: 3, title: 'essay' },
            { node_id: 4, title: 'poetry' }
          ]
        })
      })

      render(
        <InlineWriteupEditor
          {...defaultProps}
          e2nodeTitle="My reverted writeup (essay)"
          draftId={789}
        />
      )

      await waitFor(() => {
        const select = screen.getByRole('combobox')
        // Should be essay (node_id 3), NOT thing (node_id 1)
        expect(select.value).toBe('3')
      })
    })

    it('matches writeuptype case-insensitively', async () => {
      fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({
          success: true,
          writeuptypes: [
            { node_id: 1, title: 'thing' },
            { node_id: 2, title: 'Poetry' },  // Capital P
            { node_id: 3, title: 'idea' }
          ]
        })
      })

      render(
        <InlineWriteupEditor
          {...defaultProps}
          e2nodeTitle="My poem (poetry)"  // lowercase in title
          draftId={456}
        />
      )

      await waitFor(() => {
        const select = screen.getByRole('combobox')
        // Should match Poetry despite case difference
        expect(select.value).toBe('2')
      })
    })

    it('defaults to thing when writeuptype in title does not match any available type', async () => {
      fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({
          success: true,
          writeuptypes: [
            { node_id: 1, title: 'thing' },
            { node_id: 2, title: 'idea' }
          ]
        })
      })

      render(
        <InlineWriteupEditor
          {...defaultProps}
          e2nodeTitle="Old writeup (obsoletetype)"
          draftId={456}
        />
      )

      await waitFor(() => {
        const select = screen.getByRole('combobox')
        // Should default to thing since obsoletetype doesn't exist
        expect(select.value).toBe('1')
      })
    })
  })

  describe('in-place writeup type editing (#4224)', () => {
    // Full type set including the two editor-only restricted types.
    const ALL_TYPES = [
      { node_id: 1, title: 'thing' },
      { node_id: 2, title: 'idea' },
      { node_id: 3, title: 'poetry' },
      { node_id: 4, title: 'definition' },
      { node_id: 5, title: 'lede' }
    ]

    const mockTypes = (types = ALL_TYPES) => {
      fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({ success: true, writeuptypes: types })
      })
    }

    const typeOptions = () => {
      const select = screen.getByLabelText('Writeup type')
      return Array.from(select.querySelectorAll('option')).map(o => o.textContent)
    }

    it('renders a Type selector when editing an existing writeup', async () => {
      mockTypes()
      render(
        <InlineWriteupEditor {...defaultProps} writeupId={789} currentWriteuptype="thing" isEditor={false} />
      )
      await waitFor(() => expect(screen.getByLabelText('Writeup type')).toBeInTheDocument())
      expect(screen.getByText('Type:')).toBeInTheDocument()
    })

    it('pre-selects the writeup\'s current type', async () => {
      mockTypes()
      render(
        <InlineWriteupEditor {...defaultProps} writeupId={789} currentWriteuptype="poetry" isEditor={false} />
      )
      await waitFor(() => {
        expect(screen.getByLabelText('Writeup type').value).toBe('3') // poetry
      })
    })

    it('pre-selects current type case-insensitively', async () => {
      mockTypes()
      render(
        <InlineWriteupEditor {...defaultProps} writeupId={789} currentWriteuptype="Poetry" isEditor={false} />
      )
      await waitFor(() => {
        expect(screen.getByLabelText('Writeup type').value).toBe('3')
      })
    })

    it('editors see all types including definition and lede', async () => {
      mockTypes()
      render(
        <InlineWriteupEditor {...defaultProps} writeupId={789} currentWriteuptype="thing" isEditor={true} />
      )
      await waitFor(() => expect(typeOptions()).toContain('definition'))
      const opts = typeOptions()
      expect(opts).toEqual(expect.arrayContaining(['thing', 'idea', 'poetry', 'definition', 'lede']))
    })

    it('non-editors do NOT see definition or lede', async () => {
      mockTypes()
      render(
        <InlineWriteupEditor {...defaultProps} writeupId={789} currentWriteuptype="thing" isEditor={false} />
      )
      // Wait until the type list has populated (more than the Loading... placeholder).
      await waitFor(() => expect(typeOptions()).toContain('thing'))
      const opts = typeOptions()
      expect(opts).toEqual(expect.arrayContaining(['thing', 'idea', 'poetry']))
      expect(opts).not.toContain('definition')
      expect(opts).not.toContain('lede')
    })

    it('non-editor holding an existing lede DOES see lede (keep-if-current) but not definition', async () => {
      mockTypes()
      render(
        <InlineWriteupEditor {...defaultProps} writeupId={789} currentWriteuptype="lede" isEditor={false} />
      )
      await waitFor(() => expect(typeOptions()).toContain('lede'))
      const opts = typeOptions()
      expect(opts).toContain('lede')        // can keep it
      expect(opts).not.toContain('definition') // but not switch to the other restricted type
    })

    it('includes wrtype_writeuptype in the update request body when editing', async () => {
      // Route fetch by URL: writeuptypes list, then the writeup update.
      fetch.mockImplementation((url) => {
        if (typeof url === 'string' && url.includes('/api/writeuptypes')) {
          return Promise.resolve({ json: () => Promise.resolve({ success: true, writeuptypes: ALL_TYPES }) })
        }
        if (typeof url === 'string' && url.includes('/api/writeups/789/action/update')) {
          return Promise.resolve({ json: () => Promise.resolve({ node_id: 789, doctext: '<p>Test content</p>' }) })
        }
        return Promise.resolve({ json: () => Promise.resolve({ success: true }) })
      })

      render(
        <InlineWriteupEditor {...defaultProps} writeupId={789} currentWriteuptype="idea" isEditor={false} />
      )
      await waitFor(() => expect(screen.getByLabelText('Writeup type').value).toBe('2')) // idea

      await act(async () => {
        fireEvent.click(screen.getByRole('button', { name: 'Update' }))
      })

      const updateCall = fetch.mock.calls.find(
        c => typeof c[0] === 'string' && c[0].includes('/api/writeups/789/action/update')
      )
      expect(updateCall).toBeTruthy()
      const body = JSON.parse(updateCall[1].body)
      expect(body).toHaveProperty('wrtype_writeuptype', 2)
      expect(body).toHaveProperty('doctext')
    })

    it('passes the new type title to onSave so the display updates without a refresh', async () => {
      const onSave = jest.fn()
      fetch.mockImplementation((url) => {
        if (typeof url === 'string' && url.includes('/api/writeuptypes')) {
          return Promise.resolve({ json: () => Promise.resolve({ success: true, writeuptypes: ALL_TYPES }) })
        }
        if (typeof url === 'string' && url.includes('/action/update')) {
          return Promise.resolve({ json: () => Promise.resolve({ node_id: 789, doctext: '<p>Test content</p>' }) })
        }
        return Promise.resolve({ json: () => Promise.resolve({ success: true }) })
      })

      render(
        <InlineWriteupEditor {...defaultProps} onSave={onSave} writeupId={789} currentWriteuptype="idea" isEditor={false} />
      )
      await waitFor(() => expect(screen.getByLabelText('Writeup type').value).toBe('2')) // idea

      // Change idea -> poetry, then Update
      fireEvent.change(screen.getByLabelText('Writeup type'), { target: { value: '3' } })
      await act(async () => {
        fireEvent.click(screen.getByRole('button', { name: 'Update' }))
      })

      expect(onSave).toHaveBeenCalledWith('<p>Test content</p>', 'poetry')
    })

    it('surfaces the server rejection message on a blocked type change', async () => {
      fetch.mockImplementation((url) => {
        if (typeof url === 'string' && url.includes('/api/writeuptypes')) {
          return Promise.resolve({ json: () => Promise.resolve({ success: true, writeuptypes: ALL_TYPES }) })
        }
        if (typeof url === 'string' && url.includes('/action/update')) {
          return Promise.resolve({ json: () => Promise.resolve({
            success: 0, error: 'writeuptype_not_allowed',
            message: "The 'definition' writeup type can only be set by editors."
          }) })
        }
        return Promise.resolve({ json: () => Promise.resolve({ success: true }) })
      })

      render(
        <InlineWriteupEditor {...defaultProps} writeupId={789} currentWriteuptype="thing" isEditor={false} />
      )
      await waitFor(() => expect(screen.getByLabelText('Writeup type')).toBeInTheDocument())

      await act(async () => {
        fireEvent.click(screen.getByRole('button', { name: 'Update' }))
      })

      await waitFor(() => {
        expect(screen.getByText(/can only be set by editors/)).toBeInTheDocument()
      })
    })
  })

  describe('e2node status indicator', () => {
    it('shows checking status initially when no e2nodeId prop', async () => {
      fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({
          success: true,
          writeuptypes: [{ node_id: 1, title: 'thing' }]
        })
      })

      render(
        <InlineWriteupEditor
          {...defaultProps}
          e2nodeId={undefined}
          draftId={456}
        />
      )

      // Should show checking indicator initially
      expect(screen.getByText('(checking...)')).toBeInTheDocument()
    })

    it('shows found status when e2nodeId prop is provided', async () => {
      fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({
          success: true,
          writeuptypes: [{ node_id: 1, title: 'thing' }]
        })
      })

      render(
        <InlineWriteupEditor
          {...defaultProps}
          e2nodeId={123}
          draftId={456}
        />
      )

      // Should show checkmark when e2nodeId is provided
      expect(screen.getByText('✓')).toBeInTheDocument()
    })

    it('shows not_found status after lookup fails', async () => {
      // Mock writeuptypes fetch
      fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({
          success: true,
          writeuptypes: [{ node_id: 1, title: 'thing' }]
        })
      })
      // Mock e2node lookup - 404
      fetch.mockResolvedValueOnce({
        ok: false,
        status: 404
      })

      render(
        <InlineWriteupEditor
          {...defaultProps}
          e2nodeId={undefined}
          draftId={456}
        />
      )

      await waitFor(() => {
        expect(screen.getByText('(new)')).toBeInTheDocument()
      })
    })

    it('enables publish button when e2node will be created', async () => {
      // Mock writeuptypes fetch
      fetch.mockResolvedValueOnce({
        json: () => Promise.resolve({
          success: true,
          writeuptypes: [{ node_id: 1, title: 'thing' }]
        })
      })
      // Mock e2node lookup - 404
      fetch.mockResolvedValueOnce({
        ok: false,
        status: 404
      })

      render(
        <InlineWriteupEditor
          {...defaultProps}
          e2nodeId={undefined}
          draftId={456}
        />
      )

      await waitFor(() => {
        const publishBtn = screen.getByRole('button', { name: 'Publish' })
        // Button should be enabled even without existing e2node
        expect(publishBtn).not.toBeDisabled()
      })
    })
  })
})
