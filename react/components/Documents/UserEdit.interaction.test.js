import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import Modal from 'react-modal'
import UserEdit, { MAX_UPLOAD_BYTES } from './UserEdit'

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
// The current-password prompt is a react-modal dialog, rendered in a portal.
const dialog = () => screen.queryByRole('dialog')
const confirmWith = (password) => {
  fireEvent.change(screen.getByLabelText('Current password'), { target: { value: password } })
  fireEvent.click(screen.getByRole('button', { name: /^confirm$/i }))
}

beforeAll(() => Modal.setAppElement(document.createElement('div')))

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
    confirmWith('my-current-pass')

    await waitFor(() => expect(global.fetch).toHaveBeenCalledWith('/api/user/edit', expect.objectContaining({ method: 'POST' })))
    const body = JSON.parse(global.fetch.mock.calls[0][1].body)
    expect(body).toMatchObject({ node_id: 100, realname: 'New Name', email: 'new@example.com', current_password: 'my-current-pass' })
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
    expect(container.querySelector('.user-edit-upload-status--error')).toHaveTextContent(/only jpeg, png, gif, webp and heic/i)
    expect(global.fetch).not.toHaveBeenCalled()
  })

  describe('image upload limits (#4643)', () => {
    // A File whose reported size we control without allocating megabytes.
    const sizedFile = (name, type, size) => {
      const file = new File(['x'], name, { type })
      Object.defineProperty(file, 'size', { value: size })
      return file
    }
    const pick = (container, file) => fireEvent.change(container.querySelector('input[type="file"]'), { target: { files: [file] } })
    const uploadButton = () => screen.queryByRole('button', { name: /upload image/i })
    const uploadError = (container) => container.querySelector('.user-edit-upload-status--error')

    it('accepts a full-size phone photo (the old 800KB cap refused these)', () => {
      const { container } = render(<UserEdit data={makeData()} />)
      pick(container, sizedFile('IMG_1234.jpg', 'image/jpeg', 4 * 1024 * 1024))
      expect(uploadError(container)).toBeNull()
      expect(uploadButton()).not.toBeNull()
    })

    it('accepts WebP and HEIC, including HEIC reported with no type', () => {
      const { container } = render(<UserEdit data={makeData()} />)
      for (const file of [
        sizedFile('saved.webp', 'image/webp', 50000),
        sizedFile('IMG_1.HEIC', 'image/heic', 2000000),
        sizedFile('IMG_2.heic', '', 2000000),
      ]) {
        pick(container, file)
        expect(uploadError(container)).toBeNull()
        expect(uploadButton()).not.toBeNull()
      }
    })

    it('refuses a file over the upload limit before uploading', () => {
      global.fetch = jest.fn()
      const { container } = render(<UserEdit data={makeData()} />)
      pick(container, sizedFile('huge.jpg', 'image/jpeg', MAX_UPLOAD_BYTES + 1))
      expect(uploadError(container)).toHaveTextContent(/maximum size is 12MB/i)
      expect(uploadButton()).toBeNull()
      expect(global.fetch).not.toHaveBeenCalled()
    })

    it('tells people the real limits', () => {
      render(<UserEdit data={makeData()} />)
      expect(screen.getByText(/JPEG, PNG, GIF, WebP or HEIC, up to 12MB/)).toBeInTheDocument()
      expect(screen.queryByText(/800KB/)).toBeNull()
    })
  })

  describe('current password (#4637)', () => {
    it('is asked for in a modal only when the password or email changes', () => {
      global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: true }) })
      const { container } = render(<UserEdit data={makeData()} />)
      expect(container.querySelector('input[name="current_password"]')).toBeNull() // no inline field

      setField(container, 'email', 'new@example.com')
      submit(container)
      expect(dialog()).not.toBeNull()
      expect(screen.getByText(/to change your email, enter your current password/i)).toBeInTheDocument()
      fireEvent.click(screen.getByRole('button', { name: /cancel/i }))
      expect(dialog()).toBeNull()

      setField(container, 'email', 'a@b.c')
      setField(container, 'passwd', 'new-pass')
      setField(container, 'email', 'new@example.com')
      fireEvent.change(screen.getByPlaceholderText(/re-enter new password/i), { target: { value: 'new-pass' } })
      submit(container)
      expect(screen.getByText(/to change your password and email, enter your current password/i)).toBeInTheDocument()
    })

    it('does not send an email change until it is confirmed', () => {
      global.fetch = jest.fn()
      const { container } = render(<UserEdit data={makeData()} />)
      setField(container, 'email', 'new@example.com')
      submit(container)
      fireEvent.click(screen.getByRole('button', { name: /cancel/i }))
      expect(global.fetch).not.toHaveBeenCalled()
      expect(container.querySelector('input[name="email"]').value).toBe('new@example.com')
    })

    it('a wrong current password keeps the modal open with the error, and a retry succeeds', async () => {
      global.fetch = jest.fn()
        .mockResolvedValueOnce({ ok: true, json: async () => ({ success: 0, code: 'current_password_incorrect', error: 'Your current password is incorrect.' }) })
        .mockResolvedValueOnce({ ok: true, json: async () => ({ success: true }) })
      const { container } = render(<UserEdit data={makeData()} />)
      setField(container, 'email', 'new@example.com')
      submit(container)

      confirmWith('wrong-pass')
      await waitFor(() => expect(screen.getByRole('alert')).toHaveTextContent(/current password is incorrect/i))
      expect(dialog()).not.toBeNull()
      expect(screen.queryByText(/profile updated successfully/i)).toBeNull()

      confirmWith('right-pass')
      await waitFor(() => expect(screen.getByText(/profile updated successfully/i)).toBeInTheDocument())
      expect(dialog()).toBeNull()
      expect(JSON.parse(global.fetch.mock.calls[1][1].body)).toMatchObject({ email: 'new@example.com', current_password: 'right-pass' })
    })

    it('other API errors close the modal and show on the page', async () => {
      global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: false, error: 'email already in use' }) })
      const { container } = render(<UserEdit data={makeData()} />)
      setField(container, 'email', 'taken@example.com')
      submit(container)
      confirmWith('right-pass')
      await waitFor(() => expect(screen.getByText(/email already in use/i)).toBeInTheDocument())
      expect(dialog()).toBeNull()
    })

    it('saves other fields without it', async () => {
      global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: true }) })
      const { container } = render(<UserEdit data={makeData()} />)
      setField(container, 'realname', 'Only The Name')
      submit(container)
      expect(dialog()).toBeNull()
      await waitFor(() => expect(global.fetch).toHaveBeenCalled())
      expect(JSON.parse(global.fetch.mock.calls[0][1].body)).not.toHaveProperty('current_password')
    })
  })

  describe('unsaved-changes state after saving (#4637)', () => {
    const leaveWarns = () => {
      const event = new Event('beforeunload', { cancelable: true })
      window.dispatchEvent(event)
      return event.defaultPrevented
    }

    it('is clean after a successful save, and dirty again after the next edit', async () => {
      global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: true }) })
      const { container } = render(<UserEdit data={makeData()} />)

      setField(container, 'realname', 'Saved Name')
      expect(leaveWarns()).toBe(true)

      submit(container)
      await waitFor(() => expect(screen.getByText(/profile updated successfully/i)).toBeInTheDocument())
      expect(leaveWarns()).toBe(false)

      setField(container, 'motto', 'a new motto')
      await waitFor(() => expect(leaveWarns()).toBe(true))
    })

    it('clears the password fields after saving a password change', async () => {
      global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: true }) })
      const { container } = render(<UserEdit data={makeData()} />)

      setField(container, 'passwd', 'new-pass')
      fireEvent.change(screen.getByPlaceholderText(/re-enter new password/i), { target: { value: 'new-pass' } })
      submit(container)
      confirmWith('old-pass')
      await waitFor(() => expect(screen.getByText(/profile updated successfully/i)).toBeInTheDocument())
      expect(container.querySelector('input[name="passwd"]').value).toBe('')
      expect(dialog()).toBeNull()
      expect(leaveWarns()).toBe(false)
    })
  })
})
