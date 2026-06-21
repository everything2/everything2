import React from 'react'
import { render, fireEvent } from '@testing-library/react'
import ClientdevHome from './ClientdevHome'
import fixture from '../../__fixtures__/pagestate/clientdev_home.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
// Renders LinkNode, which is a plain anchor helper (no react-router), so no router provider needed.
describe('ClientdevHome (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<ClientdevHome data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<ClientdevHome data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// Register-client create-form migration: op=new -> POST /api/node/create (#4340 Phase 2).
describe('ClientdevHome register-client create form', () => {
  let originalLocation
  beforeEach(() => {
    originalLocation = window.location
    delete window.location
    window.location = { href: '' }
  })
  afterEach(() => {
    window.location = originalLocation
    jest.restoreAllMocks()
  })

  it('POSTs to /api/node/create and redirects on success', async () => {
    const fetchMock = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ success: 1, node_id: 999 }),
    })
    global.fetch = fetchMock

    const { container, getByDisplayValue } = render(
      <ClientdevHome data={{ clients: [], can_create: true }} e2={{}} user={{}} />
    )

    const input = container.querySelector('input[name="node"]')
    fireEvent.change(input, { target: { value: 'My Client' } })

    const form = getByDisplayValue('Register Client').closest('form')
    fireEvent.submit(form)

    // Flush the async handler.
    await Promise.resolve()
    await Promise.resolve()

    expect(fetchMock).toHaveBeenCalledTimes(1)
    const [url, opts] = fetchMock.mock.calls[0]
    expect(url).toBe('/api/node/create')
    expect(JSON.parse(opts.body)).toEqual({ type: 'e2client', title: 'My Client' })
    expect(window.location.href).toBe('/node/999')
  })
})
