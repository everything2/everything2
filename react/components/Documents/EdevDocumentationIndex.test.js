import React from 'react'
import { render, waitFor, fireEvent } from '@testing-library/react'
import EdevDocumentationIndex from './EdevDocumentationIndex'

// Fetch-driven (#4557): the Page is a pure gate; GET /api/edev_documentation_index on mount.
const jsonFetch = (p) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(p) }))
afterEach(() => { delete global.fetch; jest.restoreAllMocks() })

describe('EdevDocumentationIndex (fetch-driven #4557)', () => {
  it('fetches and renders the doc list', async () => {
    global.fetch = jsonFetch({ success: 1, is_developer: false, docs: [{ node_id: 9, title: 'A Dev Doc' }] })
    const { container } = render(<EdevDocumentationIndex />)
    await waitFor(() => expect(container.textContent).toMatch(/A Dev Doc/))
    expect(global.fetch.mock.calls[0][0]).toMatch(/^\/api\/edev_documentation_index/)
  })

  it('hides the create box for non-developers', async () => {
    global.fetch = jsonFetch({ success: 1, is_developer: false, docs: [] })
    const { container } = render(<EdevDocumentationIndex />)
    await waitFor(() => expect(container.textContent).toMatch(/Looks pretty lonely/))
    expect(container.querySelector('.edev-docs__create-box')).toBeFalsy()
  })

  it('shows the create box for developers', async () => {
    global.fetch = jsonFetch({ success: 1, is_developer: true, docs: [] })
    const { container } = render(<EdevDocumentationIndex />)
    await waitFor(() => expect(container.querySelector('.edev-docs__create-box')).toBeTruthy())
  })

  // Creation still goes through the generic node API (#4340) — unchanged by #4557, kept covered.
  it('posts to /api/node/create and redirects on success', async () => {
    delete window.location
    window.location = { href: '' }
    global.fetch = jest.fn((url) =>
      Promise.resolve({
        ok: true,
        json: () => Promise.resolve(
          String(url).includes('/api/node/create')
            ? { success: 1, node_id: 321 }
            : { success: 1, is_developer: true, docs: [] }
        )
      })
    )
    const { container } = render(<EdevDocumentationIndex />)
    await waitFor(() => expect(container.querySelector('.edev-docs__input')).toBeTruthy())

    fireEvent.change(container.querySelector('.edev-docs__input'), { target: { value: 'New Doc' } })
    fireEvent.submit(container.querySelector('.edev-docs__create-box form'))

    await waitFor(() => expect(window.location.href).toBe('/node/321'))
    const create = global.fetch.mock.calls.find((c) => String(c[0]).includes('/api/node/create'))
    expect(JSON.parse(create[1].body)).toEqual({ type: 'edevdoc', title: 'New Doc' })
  })

  it('does not post when the title is empty', async () => {
    global.fetch = jsonFetch({ success: 1, is_developer: true, docs: [] })
    const { container } = render(<EdevDocumentationIndex />)
    await waitFor(() => expect(container.querySelector('.edev-docs__input')).toBeTruthy())

    fireEvent.change(container.querySelector('.edev-docs__input'), { target: { value: '   ' } })
    fireEvent.submit(container.querySelector('.edev-docs__create-box form'))

    await waitFor(() => expect(global.fetch.mock.calls.length).toBe(1)) // the mount fetch only
    expect(global.fetch.mock.calls.some((c) => String(c[0]).includes('/api/node/create'))).toBe(false)
  })
})
