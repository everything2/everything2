import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import NoteletEditor from './NoteletEditor'
import fixture from '../../__fixtures__/pagestate/notelet_editor.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('NoteletEditor (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<NoteletEditor data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<NoteletEditor data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// Interaction coverage (#4479, Refs #4298): the save/castrate writes moved to POST /api/notelet;
// the page is now pure-render. The component posts and re-renders from the response payload.
describe('NoteletEditor interaction (#4479)', () => {
  const baseData = {
    notelet_raw: 'hello world',
    notelet_screened: 'hello world',
    char_count: 11,
    max_length: 2000,
    user_level: 5,
    notelet_enabled: true,
    keep_comments: false,
  }
  const okPayload = (over = {}) => ({
    ok: true,
    json: async () => ({ success: 1, notelet_raw: '', notelet_screened: '', char_count: 0, keep_comments: false, ...over }),
  })

  afterEach(() => {
    jest.restoreAllMocks()
    delete global.fetch
  })

  it('Castrate posts to /api/notelet/castrate and re-renders from the response', async () => {
    global.fetch = jest.fn().mockResolvedValue(
      okPayload({ message: 'Notelet castrated successfully!', notelet_raw: '// hello world', char_count: 14 })
    )
    render(<NoteletEditor data={baseData} />)
    fireEvent.click(screen.getByRole('button', { name: /castrate notelet/i }))

    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/notelet/castrate', expect.objectContaining({ method: 'POST' }))
    )
    await waitFor(() => expect(screen.getByText(/castrated successfully/i)).toBeInTheDocument())
    expect(screen.getByRole('textbox')).toHaveValue('// hello world')
  })

  it('Submit posts the source + keep_comments to /api/notelet/save and shows success', async () => {
    global.fetch = jest.fn().mockResolvedValue(okPayload({ message: 'Notelet saved successfully!' }))
    render(<NoteletEditor data={baseData} />)
    fireEvent.change(screen.getByRole('textbox'), { target: { value: 'new note text' } })
    fireEvent.click(screen.getByRole('button', { name: /^submit$/i }))

    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/notelet/save', expect.objectContaining({ method: 'POST' }))
    )
    // "Remove HTML comments" is checked by default -> keep_comments false
    expect(JSON.parse(global.fetch.mock.calls[0][1].body)).toEqual({ notelet_source: 'new note text', keep_comments: false })
    await waitFor(() => expect(screen.getByText(/saved successfully/i)).toBeInTheDocument())
  })

  it('surfaces a 200 + {success:0} reject as an error (not a save)', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: 0, error: 'nope' }) })
    render(<NoteletEditor data={baseData} />)
    fireEvent.click(screen.getByRole('button', { name: /^submit$/i }))
    await waitFor(() => expect(screen.getByText('nope')).toBeInTheDocument())
  })
})
