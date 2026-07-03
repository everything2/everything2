import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import SQLPrompt from './SQLPrompt'
import fixture from '../../__fixtures__/pagestate/sql_prompt.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('SQLPrompt (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<SQLPrompt data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<SQLPrompt data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// Interaction coverage (#4442): the SQL execution moved to POST /api/sqlprompt/query
// and the display-format pref to POST /api/preferences, so the component now drives
// both via fetch and renders results from state (was a server-rendered POST-back).
describe('SQLPrompt interaction (#4442)', () => {
  afterEach(() => {
    jest.restoreAllMocks()
    delete global.fetch
  })

  const authData = { type: 'sql_prompt', node_id: 113, formatStyle: 0 }

  it('runs a query via POST /api/sqlprompt/query and renders results client-side', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        success: 1,
        results: {
          error: 0,
          columns: ['id', 'label'],
          rows: [{ id: { value: '42', is_node_id: 1 }, label: { value: 'hello', is_node_id: 0 } }],
          row_count: 1, rows_fetched: 1, elapsed_time: '0.0010', affected_rows: 0,
        },
      }),
    })
    render(<SQLPrompt data={authData} user={{}} />)
    fireEvent.change(screen.getByPlaceholderText('Enter SQL query...'), { target: { value: 'SELECT * FROM node' } })
    fireEvent.click(screen.getByRole('button', { name: /execute/i }))
    await waitFor(() => expect(screen.getByText('hello')).toBeInTheDocument())
    expect(global.fetch).toHaveBeenCalledWith('/api/sqlprompt/query', expect.objectContaining({ method: 'POST' }))
  })

  it('surfaces a SQL-level error from a bad query', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        success: 1,
        results: { error: 1, error_type: 'prepare', message: 'Bad SQL: nope', elapsed_time: '0.0001' },
      }),
    })
    render(<SQLPrompt data={authData} user={{}} />)
    fireEvent.change(screen.getByPlaceholderText('Enter SQL query...'), { target: { value: 'garbage' } })
    fireEvent.click(screen.getByRole('button', { name: /execute/i }))
    await waitFor(() => expect(screen.getByText(/Bad SQL: nope/)).toBeInTheDocument())
  })

  it('persists the display format via POST /api/preferences', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({}) })
    render(<SQLPrompt data={authData} user={{}} />)
    fireEvent.change(screen.getByRole('combobox'), { target: { value: '2' } })
    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/preferences', expect.objectContaining({ method: 'POST' }))
    )
  })

  it('renders the access-denied view for unauthorized users', () => {
    render(<SQLPrompt data={{ type: 'sql_prompt', error: 'unauthorized', message: 'nope' }} user={{}} />)
    expect(screen.getByText('Access Denied')).toBeInTheDocument()
  })
})
