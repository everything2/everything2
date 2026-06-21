import React from 'react'
import { render, screen, fireEvent } from '@testing-library/react'
import EdevDocumentationIndex from './EdevDocumentationIndex'
import fixture from '../../__fixtures__/pagestate/edev_documentation_index.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('EdevDocumentationIndex (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<EdevDocumentationIndex data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<EdevDocumentationIndex data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// Covers the op=new -> POST /api/node/create migration (#4340 Phase 2).
describe('EdevDocumentationIndex create flow', () => {
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

  it('posts to /api/node/create and redirects on success', async () => {
    global.fetch = jest.fn(() =>
      Promise.resolve({ ok: true, json: async () => ({ success: 1, node_id: 999 }) })
    )

    render(<EdevDocumentationIndex data={{ docs: [], is_developer: true }} />)

    const input = screen.getByPlaceholderText('Enter document title...')
    fireEvent.change(input, { target: { value: 'My New Doc' } })
    fireEvent.submit(input.closest('form'))

    // Let the async handler's promise chain settle.
    await new Promise((resolve) => setTimeout(resolve, 0))

    expect(global.fetch).toHaveBeenCalledTimes(1)
    const [url, opts] = global.fetch.mock.calls[0]
    expect(url).toBe('/api/node/create')
    expect(opts.method).toBe('POST')
    expect(JSON.parse(opts.body)).toEqual({ type: 'edevdoc', title: 'My New Doc' })
    expect(window.location.href).toBe('/node/999')
  })

  it('does not post when the title is empty', () => {
    global.fetch = jest.fn()

    render(<EdevDocumentationIndex data={{ docs: [], is_developer: true }} />)

    const input = screen.getByPlaceholderText('Enter document title...')
    fireEvent.submit(input.closest('form'))

    expect(global.fetch).not.toHaveBeenCalled()
  })
})
