import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import UserEdit from './UserEdit'

// UserEdit is account mutation: the profile form POSTs to /api/user/edit (node_id + the field
// values + the bio doctext), and the avatar uploader POSTs a multipart body to
// /api/user/upload-image. These tests lock the payload shape + the success/error handling, plus
// the client-side image-type guard that must gate the upload.

const makeData = (overrides = {}) => ({
  user: {
    node_id: 100,
    realname: 'Real Name',
    email: 'a@b.c',
    doctext: '',
    mission: '',
    specialties: '',
    employment: '',
    motto: '',
    bookmarks: [],
    imgsrc: '',
  },
  viewer: { node_id: 100, is_admin: false },
  can_have_image: true,
  ...overrides,
})

const setField = (container, name, value) =>
  fireEvent.change(container.querySelector(`input[name="${name}"]`), { target: { name, value } })
const submit = (container) => fireEvent.submit(container.querySelector('#profile-form'))

describe('UserEdit', () => {
  afterEach(() => {
    jest.restoreAllMocks()
    delete global.fetch
  })

  it('renders nothing without a user in the payload', () => {
    const { container } = render(<UserEdit data={{}} />)
    expect(container).toBeEmptyDOMElement()
  })

  it('posts the edited profile fields (with node_id + bio) to /api/user/edit and shows success', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: true }) })
    const { container } = render(<UserEdit data={makeData()} />)

    setField(container, 'realname', 'New Name')
    setField(container, 'email', 'new@example.com')
    submit(container)

    await waitFor(() => expect(global.fetch).toHaveBeenCalledWith('/api/user/edit', expect.objectContaining({ method: 'POST' })))
    const body = JSON.parse(global.fetch.mock.calls[0][1].body)
    expect(body).toMatchObject({ node_id: 100, realname: 'New Name', email: 'new@example.com' })
    expect(body).toHaveProperty('user_doctext') // bio always included
    await waitFor(() => expect(screen.getByText(/profile updated successfully/i)).toBeInTheDocument())
  })

  it('shows the API error when the edit is rejected', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: false, error: 'email already in use' }) })
    const { container } = render(<UserEdit data={makeData()} />)
    setField(container, 'realname', 'X')
    submit(container)
    await waitFor(() => expect(screen.getByText(/email already in use/i)).toBeInTheDocument())
  })

  it('uploads a selected image as multipart to /api/user/upload-image', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: true, message: 'Image saved' }) })
    const orig = window.location
    Object.defineProperty(window, 'location', { value: { ...orig, reload: jest.fn() }, writable: true, configurable: true })
    try {
      const { container } = render(<UserEdit data={makeData()} />)
      const file = new File(['x'], 'avatar.png', { type: 'image/png' })
      fireEvent.change(container.querySelector('input[type="file"]'), { target: { files: [file] } })
      fireEvent.click(screen.getByRole('button', { name: /upload image/i }))

      await waitFor(() => expect(global.fetch).toHaveBeenCalledWith('/api/user/upload-image', expect.objectContaining({ method: 'POST' })))
      const sentBody = global.fetch.mock.calls[0][1].body
      expect(sentBody).toBeInstanceOf(FormData)
      expect(sentBody.get('imgsrc_file')).toBe(file)
      await waitFor(() => expect(window.location.reload).toHaveBeenCalled())
    } finally {
      Object.defineProperty(window, 'location', { value: orig, writable: true, configurable: true })
    }
  })

  it('rejects a non-image file client-side and does not upload', () => {
    global.fetch = jest.fn()
    const { container } = render(<UserEdit data={makeData()} />)
    const bad = new File(['x'], 'notes.txt', { type: 'text/plain' })
    fireEvent.change(container.querySelector('input[type="file"]'), { target: { files: [bad] } })
    // the rejection surfaces in the upload-status banner (same wording also appears as a static hint),
    // clears the selection, and never hits the network
    expect(container.querySelector('.user-edit-upload-status--error')).toHaveTextContent(/only jpeg, gif, and png/i)
    expect(global.fetch).not.toHaveBeenCalled()
  })
})
