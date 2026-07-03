import React from 'react'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import TheBorgClinic from './TheBorgClinic'
import fixture from '../../__fixtures__/pagestate/the_borg_clinic.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('TheBorgClinic (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<TheBorgClinic data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<TheBorgClinic data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// Interaction coverage (#4449): the borg-count write moved to POST /api/borgclinic/setborg
// and the lookup is a read (navigation), so the component drives both client-side and the
// page no longer mutates on render (was a server-rendered POST-back).
describe('TheBorgClinic interaction (#4449)', () => {
  let origLocation
  beforeEach(() => {
    origLocation = window.location
    delete window.location
    window.location = { href: '' }
  })
  afterEach(() => {
    window.location = origLocation
    jest.restoreAllMocks()
    delete global.fetch
  })

  const editorData = {
    type: 'the_borg_clinic', node_id: 100, clinic_user: 'victim',
    user_found: 1, user_id: 779, user_title: 'victim', borg_count: 0, show_editor: 1,
  }

  it('sets the borg count via POST /api/borgclinic/setborg then reloads', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true, json: async () => ({ success: 1, user: 'victim', borg_count: 42 }),
    })
    const { container } = render(<TheBorgClinic data={editorData} />)
    fireEvent.change(screen.getByDisplayValue('0'), { target: { value: '42' } })
    fireEvent.submit(container.querySelector('.borg-clinic__user-section'))
    await waitFor(() =>
      expect(global.fetch).toHaveBeenCalledWith('/api/borgclinic/setborg', expect.objectContaining({ method: 'POST' }))
    )
    await waitFor(() => expect(window.location.href).toContain('clinic_user=victim'))
  })

  it('shows an error when the set fails', async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ success: 0, error: 'nope' }) })
    const { container } = render(<TheBorgClinic data={editorData} />)
    fireEvent.submit(container.querySelector('.borg-clinic__user-section'))
    await waitFor(() => expect(screen.getByText('nope')).toBeInTheDocument())
  })

  it('keeps the lookup submit visible while editing and drops the "another patient" link (#4449)', () => {
    render(<TheBorgClinic data={editorData} />)
    // one "Do it!" for the lookup form + one for the borg-count editor
    expect(screen.getAllByRole('button', { name: /do it/i })).toHaveLength(2)
    expect(screen.queryByText(/another patient/i)).toBeNull()
  })

  it('renders the access-denied error for non-admins', () => {
    render(<TheBorgClinic data={{ type: 'the_borg_clinic', error: 'This page is restricted to administrators.' }} />)
    expect(screen.getByText(/restricted to administrators/i)).toBeInTheDocument()
  })

  it('looks up a user by navigating (a read, not a mutation)', () => {
    const { container } = render(<TheBorgClinic data={{ type: 'the_borg_clinic', node_id: 100, clinic_user: '', user_found: 0, show_editor: 0 }} />)
    fireEvent.change(screen.getByRole('textbox'), { target: { value: 'someone' } })
    fireEvent.submit(container.querySelector('form'))
    expect(window.location.href).toContain('clinic_user=someone')
  })
})
