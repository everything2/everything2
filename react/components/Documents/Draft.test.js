import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import Draft from './Draft'

// Heavy descendants — none of these are under test here, mock them out so
// we can focus on Draft.js's own toolbar behavior (specifically Mark Reviewed,
// issue 'review feature' / Part 2).
jest.mock('../WriteupDisplay', () => function MockWriteupDisplay() { return <div data-testid="writeup-display" /> })
jest.mock('../InlineWriteupEditor', () => function MockInlineEditor() { return <div data-testid="inline-editor" /> })
jest.mock('./PublishModal', () => function MockPublishModal() { return null })
jest.mock('../DraftAdminModal', () => function MockDraftAdminModal() { return null })
jest.mock('../LinkNode', () => function MockLinkNode({ title }) { return <span>{title}</span> })

describe('Draft - Mark Reviewed button', () => {
  const baseDraft = {
    node_id: 5001,
    title: 'a draft in review',
    author: { node_id: 100, title: 'someauthor' },
    is_author: false,
    can_edit: true,
    publication_status: 'review',
    doctext: 'hello world',
    createtime: '2026-05-28 10:00:00'
  }

  const editorUser = { node_id: 200, is_editor: true, is_admin: false }
  const plainUser  = { node_id: 200, is_editor: false, is_admin: false }
  const authorViewer = { node_id: 100, is_editor: false, is_admin: false }

  beforeEach(() => {
    jest.clearAllMocks()
  })

  afterEach(() => {
    delete global.fetch
  })

  it('renders the Mark Reviewed button when viewer is an editor and draft is in review', () => {
    render(<Draft data={{ draft: baseDraft, user: editorUser }} />)
    expect(screen.getByRole('button', { name: /mark reviewed/i })).toBeInTheDocument()
  })

  it('styles the Mark Reviewed button as an e2-action-chip', () => {
    render(<Draft data={{ draft: baseDraft, user: editorUser }} />)
    expect(screen.getByRole('button', { name: /mark reviewed/i })).toHaveClass('e2-action-chip')
  })

  it('styles all author-visible draft toolbar buttons as e2-action-chips', () => {
    // is_author=true author viewing their own private draft → edit/publish/delete
    const ownDraft = { ...baseDraft, is_author: true, publication_status: 'private' }
    render(<Draft data={{ draft: ownDraft, user: { ...editorUser, node_id: 100 } }} />)
    const edit    = screen.getByRole('button', { name: /edit/i })
    const publish = screen.getByRole('button', { name: /publish/i })
    const remove  = screen.getByRole('button', { name: /delete/i })
    expect(edit).toHaveClass('e2-action-chip')
    expect(publish).toHaveClass('e2-action-chip')
    expect(remove).toHaveClass('e2-action-chip')
  })

  it('hides the Mark Reviewed button for non-editor viewers', () => {
    render(<Draft data={{ draft: baseDraft, user: plainUser }} />)
    expect(screen.queryByRole('button', { name: /mark reviewed/i })).not.toBeInTheDocument()
  })

  it('hides the Mark Reviewed button when draft is not in review (e.g. private)', () => {
    render(<Draft data={{ draft: { ...baseDraft, publication_status: 'private' }, user: editorUser }} />)
    expect(screen.queryByRole('button', { name: /mark reviewed/i })).not.toBeInTheDocument()
  })

  it('still shows the button even if the editor is also the author (review-by-self is allowed)', () => {
    // The button gate is "isEditor && in review". An editor reviewing their own
    // draft is unusual but not blocked — gate it on the API side instead.
    render(<Draft data={{ draft: { ...baseDraft, is_author: true }, user: { ...editorUser, node_id: 100 } }} />)
    expect(screen.getByRole('button', { name: /mark reviewed/i })).toBeInTheDocument()
  })

  it('POSTs to /api/drafts/:id/mark_reviewed and hides itself on success', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve({ success: true, status: 'private', message: 'Draft marked reviewed' })
    })

    render(<Draft data={{ draft: baseDraft, user: editorUser }} />)
    fireEvent.click(screen.getByRole('button', { name: /mark reviewed/i }))

    await waitFor(() => {
      expect(global.fetch).toHaveBeenCalledWith(
        '/api/drafts/5001/mark_reviewed',
        expect.objectContaining({ method: 'POST' })
      )
    })

    // After success, button drops out of the toolbar (because effectiveStatus moves to 'private')
    await waitFor(() => {
      expect(screen.queryByRole('button', { name: /mark reviewed/i })).not.toBeInTheDocument()
    })
  })

  it('shows an error and keeps the button when the API fails', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: false,
      json: () => Promise.resolve({ success: 0, error: 'permission_denied', message: 'nope' })
    })

    render(<Draft data={{ draft: baseDraft, user: editorUser }} />)
    fireEvent.click(screen.getByRole('button', { name: /mark reviewed/i }))

    await waitFor(() => {
      expect(screen.getByText(/Error: nope/i)).toBeInTheDocument()
    })
    expect(screen.getByRole('button', { name: /mark reviewed/i })).toBeInTheDocument()
  })

  it('handles network errors gracefully', async () => {
    global.fetch = jest.fn().mockRejectedValue(new Error('offline'))

    render(<Draft data={{ draft: baseDraft, user: editorUser }} />)
    fireEvent.click(screen.getByRole('button', { name: /mark reviewed/i }))

    await waitFor(() => {
      expect(screen.getByText(/Error: offline/i)).toBeInTheDocument()
    })
  })
})
