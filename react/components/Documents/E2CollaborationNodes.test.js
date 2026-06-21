import React from 'react'
import { render, fireEvent, waitFor } from '@testing-library/react'
import E2CollaborationNodes from './E2CollaborationNodes'
import fixture from '../../__fixtures__/pagestate/e2_collaboration_nodes.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('E2CollaborationNodes (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<E2CollaborationNodes data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<E2CollaborationNodes data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// Migration from op=new to POST /api/node/create (#4340 Phase 2).
describe('create-node API migration', () => {
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

  it('creates a collaboration via /api/node/create and redirects to /node/<id>', async () => {
    const { getByPlaceholderText } = render(<E2CollaborationNodes data={fixture.contentData} />)

    const input = getByPlaceholderText('New node title')
    fireEvent.change(input, { target: { value: 'My Collab' } })

    fireEvent.submit(input.closest('form'))

    await waitFor(() => expect(global.fetch).toHaveBeenCalled())
    const call = global.fetch.mock.calls[0]
    expect(call[0]).toBe('/api/node/create')
    expect(JSON.parse(call[1].body)).toEqual({ type: 'collaboration', title: 'My Collab' })

    await waitFor(() => expect(window.location.href).toBe('/node/999'))
  })

  it('does not call the API when the title is empty', () => {
    const { getByPlaceholderText } = render(<E2CollaborationNodes data={fixture.contentData} />)
    fireEvent.submit(getByPlaceholderText('New node title').closest('form'))
    expect(global.fetch).not.toHaveBeenCalled()
  })
})
