import React from 'react'
import { render, fireEvent, waitFor } from '@testing-library/react'
import ListNodesOfType from './ListNodesOfType'
import fixture from '../../__fixtures__/pagestate/gnl.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('ListNodesOfType (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<ListNodesOfType data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<ListNodesOfType data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
  it('reads the viewer node_id from the user prop, not contentData (#4399)', () => {
    // contentData no longer carries the viewer's own user_id; it comes from e2.user.
    expect(fixture.contentData.user_id).toBeUndefined()
    // Granted (non-denied) data so the viewer footer renders; node_id is sourced from the user prop.
    const grantedData = { type: 'list_nodes_of_type', access_denied: 0, node_types: [], default_type: '' }
    const { container } = render(
      <ListNodesOfType data={grantedData} e2={fixture} user={{ node_id: 424242 }} />
    )
    expect(container.textContent).toContain('424242')
  })
})

// The type pref persists through the working /api/preferences/set route (was a
// dead POST to /api/preferences/update, with the real persistence happening as a
// render-time ?setvars side-effect in the controller, #4416).
describe('ListNodesOfType type pref -> /api/preferences/set (#4416)', () => {
  const data = {
    type: 'list_nodes_of_type',
    access_denied: 0,
    node_types: [{ node_id: 9, title: 'nodelet' }, { node_id: 14, title: 'document' }],
    default_type: ''
  }
  const mockFetch = () => jest.fn((url) =>
    String(url).includes('/api/list_nodes/list')
      ? Promise.resolve({ ok: true, json: async () => ({ success: true, nodes: [], total: 0, page_size: 60 }) })
      : Promise.resolve({ ok: true, json: async () => ({}) })
  )
  afterEach(() => { delete global.fetch })

  it('changing the type POSTs ListNodesOfType_Type to /api/preferences/set, not the dead /update route', async () => {
    global.fetch = mockFetch()
    const { container } = render(<ListNodesOfType data={data} user={{ node_id: 1 }} />)
    fireEvent.change(container.querySelector('.list-nodes-of-type__select'), { target: { value: '9' } })
    await waitFor(() => {
      const setCall = global.fetch.mock.calls.find((c) => String(c[0]) === '/api/preferences/set')
      expect(setCall).toBeTruthy()
      expect(JSON.parse(setCall[1].body)).toEqual({ ListNodesOfType_Type: '9' })
    })
    expect(global.fetch.mock.calls.some((c) => String(c[0]).includes('/api/preferences/update'))).toBe(false)
  })

  it('honors the ?setvars deep-link on mount: pre-selects + persists via the API', async () => {
    const orig = window.location
    Object.defineProperty(window, 'location', { configurable: true, writable: true, value: { search: '?setvars_ListNodesOfType_Type=14' } })
    global.fetch = mockFetch()
    try {
      const { container } = render(<ListNodesOfType data={data} user={{ node_id: 1 }} />)
      await waitFor(() => {
        const setCall = global.fetch.mock.calls.find((c) => String(c[0]) === '/api/preferences/set')
        expect(setCall).toBeTruthy()
        expect(JSON.parse(setCall[1].body)).toEqual({ ListNodesOfType_Type: '14' })
      })
      expect(container.querySelector('.list-nodes-of-type__select').value).toBe('14')
    } finally {
      Object.defineProperty(window, 'location', { configurable: true, writable: true, value: orig })
    }
  })

  it('ignores a ?setvars deep-link naming a type not in the list', async () => {
    const orig = window.location
    Object.defineProperty(window, 'location', { configurable: true, writable: true, value: { search: '?setvars_ListNodesOfType_Type=99999' } })
    global.fetch = mockFetch()
    try {
      render(<ListNodesOfType data={data} user={{ node_id: 1 }} />)
      // give the mount effect a tick; it must NOT persist an out-of-list type
      await new Promise((r) => setTimeout(r, 20))
      expect(global.fetch.mock.calls.some((c) => String(c[0]) === '/api/preferences/set')).toBe(false)
    } finally {
      Object.defineProperty(window, 'location', { configurable: true, writable: true, value: orig })
    }
  })
})
