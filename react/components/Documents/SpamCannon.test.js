import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import SpamCannon from './SpamCannon'
import fixture from '../../__fixtures__/pagestate/spam_cannon.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('SpamCannon (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<SpamCannon data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<SpamCannon data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
  it('gates on user.editor: editor sees the tool, non-editor is denied (#4390)', () => {
    const editor = render(<SpamCannon data={fixture.contentData} e2={fixture} user={{ editor: true }} />)
    expect(editor.container.textContent).toContain('The Spam Cannon sends a single /msg')
    expect(editor.container.textContent).not.toContain('Permission Denied')

    const nonEditor = render(<SpamCannon data={fixture.contentData} e2={fixture} user={{ editor: false }} />)
    expect(nonEditor.container.textContent).toContain('Permission Denied')
    expect(nonEditor.container.textContent).not.toContain('The Spam Cannon sends a single /msg')
  })
  it('viewer username comes from the user prop, not contentData (#4399)', () => {
    const { container } = render(
      <SpamCannon data={fixture.contentData} e2={fixture} user={{ editor: true, title: 'TestViewer' }} />
    )
    expect(container.textContent).toContain('TestViewer')
  })
  it('does not crash and denies when user prop is undefined (#4390)', () => {
    const { container } = render(<SpamCannon data={fixture.contentData} e2={fixture} user={undefined} />)
    expect(container.textContent).toContain('Permission Denied')
  })
})

// Interaction coverage: the bulk /msg posts to /api/spamcannon. Client-side validation
// (empty fields, recipient cap) must gate the network call.
describe('SpamCannon interaction', () => {
  const editor = { editor: true, title: 'Ed' }
  const recipientsBox = () => screen.getByPlaceholderText(/username1/)
  const messageBox = () => screen.getByPlaceholderText(/your message here/i)
  const send = () => fireEvent.click(screen.getByRole('button', { name: /^send$/i }))

  afterEach(() => {
    jest.restoreAllMocks()
    delete global.fetch
  })

  it('blocks submit with an error when fields are empty (no network call)', () => {
    global.fetch = jest.fn()
    render(<SpamCannon data={{ max_recipients: 20 }} user={editor} />)
    send()
    expect(screen.getByText(/enter both recipients and a message/i)).toBeInTheDocument()
    expect(global.fetch).not.toHaveBeenCalled()
  })

  it('rejects more recipients than the cap without calling the API', () => {
    global.fetch = jest.fn()
    render(<SpamCannon data={{ max_recipients: 2 }} user={editor} />)
    fireEvent.change(recipientsBox(), { target: { value: 'a\nb\nc' } })
    fireEvent.change(messageBox(), { target: { value: 'hi' } })
    send()
    expect(screen.getByText(/maximum is 2/i)).toBeInTheDocument()
    expect(global.fetch).not.toHaveBeenCalled()
  })

  it('posts the parsed recipient list + message and renders the sent-to list, clearing the form', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ success: true, message: 'hi there', sent_to: ['alice', 'bob'] }),
    })
    render(<SpamCannon data={{ max_recipients: 20 }} user={editor} />)
    fireEvent.change(recipientsBox(), { target: { value: 'alice\n  bob \n\n' } })
    fireEvent.change(messageBox(), { target: { value: 'hi there' } })
    send()

    await waitFor(() => expect(global.fetch).toHaveBeenCalledWith('/api/spamcannon', expect.objectContaining({ method: 'POST' })))
    const body = JSON.parse(global.fetch.mock.calls[0][1].body)
    // blank lines dropped, each recipient trimmed
    expect(body).toEqual({ recipients: ['alice', 'bob'], message: 'hi there' })

    await waitFor(() => expect(screen.getByRole('link', { name: 'alice' })).toBeInTheDocument())
    expect(screen.getByRole('link', { name: 'bob' })).toBeInTheDocument()
    // form cleared on success
    expect(recipientsBox()).toHaveValue('')
  })

  it('renders the API error box on a failed send', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: false, error: 'no such usergroup' }) })
    render(<SpamCannon data={{ max_recipients: 20 }} user={editor} />)
    fireEvent.change(recipientsBox(), { target: { value: 'alice' } })
    fireEvent.change(messageBox(), { target: { value: 'hi' } })
    send()
    await waitFor(() => expect(screen.getByText(/no such usergroup/i)).toBeInTheDocument())
  })
})
