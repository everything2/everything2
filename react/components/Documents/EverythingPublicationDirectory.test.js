import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import EverythingPublicationDirectory from './EverythingPublicationDirectory'
import fixture from '../../__fixtures__/pagestate/everything_publication_directory.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
// Renders LinkNode, which is a plain anchor helper (no react-router), so no router provider needed.
describe('EverythingPublicationDirectory (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<EverythingPublicationDirectory data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<EverythingPublicationDirectory data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// Migration from op=new to POST /api/node/create (#4340).
describe('EverythingPublicationDirectory create-debate API migration', () => {
  let originalLocation

  beforeEach(() => {
    originalLocation = window.location
    delete window.location
    window.location = { href: '' }
    global.fetch = jest.fn(() =>
      Promise.resolve({ ok: true, json: async () => ({ success: 1, node_id: 999 }) })
    )
  })

  afterEach(() => {
    window.location = originalLocation
    jest.restoreAllMocks()
  })

  const parseBody = (call) => JSON.parse(call[1].body)

  it('creates a debate via /api/node/create and redirects to /node/<id>', async () => {
    render(<EverythingPublicationDirectory data={{ debates: [], can_create: true }} />)

    fireEvent.change(screen.getByPlaceholderText('Enter discussion title...'), {
      target: { value: 'My Discussion' },
    })
    fireEvent.click(screen.getByRole('button', { name: 'Create Debate' }))

    await waitFor(() => expect(global.fetch).toHaveBeenCalled())
    const call = global.fetch.mock.calls[0]
    expect(call[0]).toBe('/api/node/create')
    expect(parseBody(call)).toMatchObject({ type: 'debate', title: 'My Discussion' })

    await waitFor(() => expect(window.location.href).toBe('/node/999'))
  })

  it('does not call the API when the title is empty', () => {
    jest.spyOn(window, 'alert').mockImplementation(() => {})
    render(<EverythingPublicationDirectory data={{ debates: [], can_create: true }} />)

    fireEvent.change(screen.getByPlaceholderText('Enter discussion title...'), {
      target: { value: '   ' },
    })
    fireEvent.click(screen.getByRole('button', { name: 'Create Debate' }))

    expect(global.fetch).not.toHaveBeenCalled()
  })
})
