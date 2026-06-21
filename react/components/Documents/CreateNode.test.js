import React from 'react'
import { render, fireEvent, waitFor } from '@testing-library/react'
import CreateNode from './CreateNode'
import fixture from '../../__fixtures__/pagestate/create_node.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('CreateNode (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<CreateNode data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<CreateNode data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
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

  it('creates a node via /api/node/create and redirects to /node/<id>', async () => {
    const { container } = render(<CreateNode data={fixture.contentData} />)

    const input = container.querySelector('input[name="node"]')
    fireEvent.change(input, { target: { value: 'My New Node' } })

    fireEvent.submit(container.querySelector('form'))

    await waitFor(() => expect(global.fetch).toHaveBeenCalled())
    const call = global.fetch.mock.calls[0]
    expect(call[0]).toBe('/api/node/create')
    expect(JSON.parse(call[1].body)).toEqual({
      type: fixture.contentData.default_type,
      title: 'My New Node',
    })

    await waitFor(() => expect(window.location.href).toBe('/node/999'))
  })
})
