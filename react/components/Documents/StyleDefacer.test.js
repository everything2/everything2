import React from 'react'
import { render, fireEvent, waitFor } from '@testing-library/react'
import StyleDefacer from './StyleDefacer'
import fixture from '../../__fixtures__/pagestate/style_defacer.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('StyleDefacer (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<StyleDefacer data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<StyleDefacer data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// customstyle now persists via /api/preferences/set (was a render-time setVars
// from a ?vandalism POST param, #4416); the textarea no longer carries a form name.
describe('StyleDefacer save -> /api/preferences/set (#4416)', () => {
  const data = { type: 'style_defacer', customstyle: 'a { color: red; }', shredder_id: 1, nirvana_id: 2 }
  afterEach(() => { delete global.fetch })

  it('the textarea no longer POSTs as a page param (no name="vandalism", no legacy form action)', () => {
    const { container } = render(<StyleDefacer data={data} />)
    expect(container.querySelector('textarea[name="vandalism"]')).toBeNull()
    expect(container.querySelector('form').getAttribute('action')).toBeNull()
  })

  it('submitting POSTs customstyle to /api/preferences/set and shows success', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({}) })
    const { container, getByText } = render(<StyleDefacer data={data} />)
    fireEvent.change(container.querySelector('textarea'), { target: { value: 'body { background: #111; }' } })
    fireEvent.submit(container.querySelector('form'))
    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/preferences/set', expect.objectContaining({ method: 'POST' }))
    )
    expect(JSON.parse(global.fetch.mock.calls[0][1].body)).toEqual({ customstyle: 'body { background: #111; }' })
    await waitFor(() => expect(getByText(/have been saved/i)).toBeInTheDocument())
  })

  it('shows the length-cap error when the API rejects (non-ok)', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: false, status: 401, json: async () => ({}) })
    const { container, getByText } = render(<StyleDefacer data={data} />)
    fireEvent.submit(container.querySelector('form'))
    await waitFor(() => expect(getByText(/too long/i)).toBeInTheDocument())
  })
})
