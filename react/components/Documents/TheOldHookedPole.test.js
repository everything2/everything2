import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import TheOldHookedPole from './TheOldHookedPole'
import fixture from '../../__fixtures__/pagestate/the_old_hooked_pole.json'

// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate
// payload, pinning the int-typed contract (#4152/#4108).
describe('TheOldHookedPole (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(
      <TheOldHookedPole data={fixture.contentData} e2={fixture} user={fixture.user || {}} />
    )
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
})

// API-backed behaviour: the form POSTs to /api/admin/users/cleanup and the UI
// reports the exact per-user state the API returns (deleted/locked/skipped).
describe('TheOldHookedPole (API-backed)', () => {
  afterEach(() => jest.restoreAllMocks())

  it('non-editor sees the brush-off and no form', () => {
    render(
      <TheOldHookedPole
        data={{ is_editor: 0, message: "You've got other things to snoop on, don't ya." }}
      />
    )
    expect(screen.getByText(/snoop on/)).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /Get The Hook/ })).toBeNull()
  })

  it('submits the list and reports each user state (deleted / locked / skipped)', async () => {
    const fetchMock = (global.fetch = jest.fn().mockResolvedValue({
      json: async () => ({
        success: 1,
        results: [
          { input: 'spam1', node_id: 41, title: 'spam1', action: 'deleted', reasons: [] },
          {
            input: 'realuser',
            node_id: 42,
            title: 'realuser',
            action: 'locked',
            reasons: ['Logged in at 2020-01-01!', 'Locked account.']
          },
          { input: 'ghost', node_id: 0, title: '', action: 'skipped', reasons: ["ghost isn't a valid user"] }
        ],
        saved_users: ['realuser', 'ghost']
      })
    }))

    render(<TheOldHookedPole data={{ is_editor: 1, node_id: 999, prefill: '' }} />)
    fireEvent.change(screen.getByPlaceholderText(/Enter usernames/), {
      target: { value: 'spam1\nrealuser\nghost' }
    })
    fireEvent.click(screen.getByRole('button', { name: /Get The Hook/ }))

    await waitFor(() => expect(screen.getByText('The Doomed Performers')).toBeInTheDocument())

    // each state label surfaced
    expect(screen.getByText('Deleted')).toBeInTheDocument()
    expect(screen.getAllByText('Locked').length).toBeGreaterThanOrEqual(1)
    expect(screen.getByText('Skipped')).toBeInTheDocument()
    // reasons rendered (incl. the honest lock-fallback messaging)
    expect(screen.getByText(/Locked account\./)).toBeInTheDocument()
    expect(screen.getByText(/isn't a valid user/)).toBeInTheDocument()

    // correct request shape
    const [url, opts] = fetchMock.mock.calls[0]
    expect(url).toBe('/api/admin/users/cleanup')
    expect(opts.method).toBe('POST')
    expect(JSON.parse(opts.body)).toEqual({ usernames: 'spam1\nrealuser\nghost', smite: 0 })
  })

  it('sends smite=1 when the box is checked', async () => {
    const fetchMock = (global.fetch = jest.fn().mockResolvedValue({
      json: async () => ({ success: 1, results: [], saved_users: [] })
    }))
    render(<TheOldHookedPole data={{ is_editor: 1, node_id: 1 }} />)
    fireEvent.change(screen.getByPlaceholderText(/Enter usernames/), { target: { value: 'x' } })
    fireEvent.click(screen.getByRole('checkbox'))
    fireEvent.click(screen.getByRole('button', { name: /Get The Hook/ }))
    await waitFor(() => expect(fetchMock).toHaveBeenCalled())
    expect(JSON.parse(fetchMock.mock.calls[0][1].body)).toEqual({ usernames: 'x', smite: 1 })
  })

  it('surfaces an API refusal as an error', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      json: async () => ({ success: 0, message: 'Editor access required' })
    })
    render(<TheOldHookedPole data={{ is_editor: 1, node_id: 1 }} />)
    fireEvent.click(screen.getByRole('button', { name: /Get The Hook/ }))
    await waitFor(() => expect(screen.getByRole('alert')).toHaveTextContent('Editor access required'))
  })
})
