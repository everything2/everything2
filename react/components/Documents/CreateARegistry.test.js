import React from 'react'
import { render, waitFor, fireEvent } from '@testing-library/react'
import CreateARegistry from './CreateARegistry'

// Fetch-driven (#4550): the Page is a pure gate; GET /api/create_a_registry gates the form.
// state:'guest' for guests; can_create false shows the level warning; creation POSTs /api/node/create.
const jsonFetch = (p) => jest.fn(() => Promise.resolve({ json: () => Promise.resolve(p) }))
afterEach(() => { delete global.fetch; jest.restoreAllMocks() })

describe('CreateARegistry (fetch-driven #4550)', () => {
  it('shows the form when can_create', async () => {
    global.fetch = jsonFetch({ success: 1, can_create: true, current_level: 12, level_required: 8 })
    const { container } = render(<CreateARegistry />)
    await waitFor(() => expect(container.querySelector('.create-registry__form')).toBeTruthy())
    expect(global.fetch.mock.calls[0][0]).toMatch(/^\/api\/create_a_registry/)
    expect(container.textContent).toMatch(/Answer style/) // input styles are React config
  })

  it('shows the level warning when not can_create', async () => {
    global.fetch = jsonFetch({ success: 1, can_create: false, current_level: 3, level_required: 8 })
    const { container } = render(<CreateARegistry />)
    await waitFor(() => expect(container.textContent).toMatch(/would need to be/i))
    expect(container.textContent).toMatch(/level 8/)
    expect(container.textContent).toMatch(/Your current level: 3/)
    expect(container.querySelector('.create-registry__form')).toBeFalsy()
  })

  it('shows the guest message on state:guest', async () => {
    global.fetch = jsonFetch({ success: 0, state: 'guest' })
    const { container } = render(<CreateARegistry />)
    await waitFor(() => expect(container.textContent).toMatch(/must be logged in to create a registry/i))
  })

  // #4554: the chosen answer style + description must reach the server. The old submit posted
  // {type,title} to the generic /api/node/create, which dropped both -- every registry came out
  // free-text no matter what you picked.
  it('submits the selected answer style and description, not just the title', async () => {
    global.fetch = jest.fn((url) =>
      Promise.resolve({
        ok: true,
        json: () => Promise.resolve(
          String(url).endsWith('/create_a_registry/create')
            ? { success: 1, node_id: 42, input_style: 'yes/no' }
            : { success: 1, can_create: true, current_level: 12, level_required: 8 }
        )
      })
    )
    const { container } = render(<CreateARegistry />)
    await waitFor(() => expect(container.querySelector('.create-registry__form')).toBeTruthy())

    fireEvent.change(container.querySelector('.create-registry__text-input'), { target: { value: 'My Registry' } })
    fireEvent.change(container.querySelector('.create-registry__textarea'), { target: { value: 'Pick one' } })
    fireEvent.change(container.querySelector('.create-registry__select'), { target: { value: 'yes/no' } })
    fireEvent.submit(container.querySelector('.create-registry__form'))

    await waitFor(() => expect(global.fetch.mock.calls.length).toBe(2))
    const [url, opts] = global.fetch.mock.calls[1]
    expect(url).toBe('/api/create_a_registry/create')
    expect(JSON.parse(opts.body)).toEqual({
      title: 'My Registry', description: 'Pick one', input_style: 'yes/no'
    })
  })
})
