import React from 'react'
import { render, fireEvent, waitFor } from '@testing-library/react'
import RenunciationChainsaw from './RenunciationChainsaw'
import fixture from '../../__fixtures__/pagestate/renunciation_chainsaw.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('RenunciationChainsaw (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<RenunciationChainsaw data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<RenunciationChainsaw data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// #4414: transfer + generate-nodelist drive the renunciation API; the result is
// held in client state (was a POST form that reparented inside the controller).
describe('RenunciationChainsaw — transfer/generate via API (#4414)', () => {
  const base = { data: { type: 'renunciation_chainsaw' }, e2: { node: { node_id: 555 } } }

  it('renders the form (Generate nodelist + Do It), no legacy POST action/hidden input', () => {
    const { container, getByText, getByRole } = render(<RenunciationChainsaw {...base} />)
    expect(getByText('Generate nodelist')).toBeInTheDocument()
    expect(getByRole('button', { name: /do it/i })).toBeInTheDocument()
    expect(container.querySelector('form').getAttribute('action')).toBeNull()
    expect(container.querySelector('input[name="node_id"]')).toBeNull()
  })

  it('Generate nodelist POSTs to /api/renunciation/nodes and fills the textarea', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ success: 1, generated_list: { user_id: 1, user_title: 'alice', nodes: [{ node_id: 10, title: 'Foo' }, { node_id: 11, title: 'Bar' }] } }),
    })
    try {
      const { getByText, getAllByRole, container } = render(<RenunciationChainsaw {...base} />)
      fireEvent.change(getAllByRole('textbox')[0], { target: { value: 'alice' } }) // from-user
      fireEvent.click(getByText('Generate nodelist'))
      await waitFor(() => expect(global.fetch).toHaveBeenCalledWith('/api/renunciation/nodes', expect.objectContaining({ method: 'POST' })))
      await waitFor(() => expect(container.querySelector('textarea').value).toBe('Foo\nBar'))
    } finally { delete global.fetch }
  })

  it('Do It POSTs to /api/renunciation/transfer, shows the result, and back resets to the form', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ success: 1, processed: 1, from_user: { id: 1, title: 'alice' }, to_user: { id: 2, title: 'bob' }, reparented: [{ node_id: 42, title: 'Foo' }], nonexistent: [], no_writeup: [], bad_owner: [], bad_type: [] }),
    })
    try {
      const { container, getByRole, getAllByRole } = render(<RenunciationChainsaw {...base} />)
      const tb = getAllByRole('textbox') // [from, to, namelist]
      fireEvent.change(tb[0], { target: { value: 'alice' } })
      fireEvent.change(tb[1], { target: { value: 'bob' } })
      fireEvent.change(tb[2], { target: { value: 'Foo' } })
      fireEvent.click(getByRole('button', { name: /do it/i }))
      await waitFor(() => expect(global.fetch).toHaveBeenCalledWith('/api/renunciation/transfer', expect.objectContaining({ method: 'POST' })))
      await waitFor(() => expect(container.textContent).toMatch(/1 writeups re-ownered/))
      const body = JSON.parse(global.fetch.mock.calls.find((c) => c[0].includes('transfer'))[1].body)
      expect(body).toMatchObject({ user_from: 'alice', user_to: 'bob', namelist: 'Foo' })
      // back resets to the form
      fireEvent.click(getByRole('button', { name: /^back$/i }))
      expect(getByRole('button', { name: /do it/i })).toBeInTheDocument()
    } finally { delete global.fetch }
  })
})
