import React from 'react'
import { render, fireEvent } from '@testing-library/react'
import CreateARegistry from './CreateARegistry'
import fixture from '../../__fixtures__/pagestate/create_a_registry.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('CreateARegistry (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<CreateARegistry data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<CreateARegistry data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// Generic create API migration (was op=new). #4340 Phase 2.
describe('CreateARegistry submit -> /api/node/create', () => {
  const origLocation = window.location

  beforeEach(() => {
    delete window.location
    window.location = { href: '' }
  })

  afterEach(() => {
    window.location = origLocation
    jest.restoreAllMocks()
  })

  it('POSTs to /api/node/create and redirects on success', async () => {
    global.fetch = jest.fn(() =>
      Promise.resolve({ ok: true, json: async () => ({ success: 1, node_id: 999 }) })
    )

    const { container } = render(<CreateARegistry data={{ can_create: 1 }} />)

    const titleInput = container.querySelector('input[name="node"]')
    expect(titleInput).toBeTruthy()
    fireEvent.change(titleInput, { target: { value: 'My Registry' } })

    const form = container.querySelector('form')
    fireEvent.submit(form)

    // allow the async handler microtasks to resolve
    await Promise.resolve()
    await Promise.resolve()

    expect(global.fetch).toHaveBeenCalledWith(
      '/api/node/create',
      expect.objectContaining({ method: 'POST' })
    )
    const body = JSON.parse(global.fetch.mock.calls[0][1].body)
    expect(body).toEqual({ type: 'registry', title: 'My Registry' })
    expect(window.location.href).toBe('/node/999')
  })
})
