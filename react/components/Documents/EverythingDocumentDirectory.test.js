import React from 'react'
import { render } from '@testing-library/react'
import EverythingDocumentDirectory from './EverythingDocumentDirectory'
import fixture from '../../__fixtures__/pagestate/everything_document_directory.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('EverythingDocumentDirectory (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<EverythingDocumentDirectory data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<EverythingDocumentDirectory data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// Role gating now reads admin/editor from the global e2.user prop (#4390),
// not from contentData.permissions. is_developer stays on contentData.
describe('EverythingDocumentDirectory role gating via user prop (#4390)', () => {
  const baseData = {
    type: 'everything_document_directory',
    documents: [],
    total_count: 0,
    shown_count: 0,
    limit: 60,
    current_sort: '0',
    filter_user: '',
    filter_nodetype: '',
    available_nodetypes: ['superdoc', 'document', 'superdocnolinks'],
    permissions: { is_developer: 0 }
  }

  // "node_id" also appears in the sort-dropdown labels ("node_id, ascending"),
  // so gate on the standalone <th>node_id</th> column-header text, which only
  // renders for admins. Count occurrences of the bare-header form to be robust.
  const nodeIdHeaderCount = (text) => (text.match(/node_id(?!,)/g) || []).length

  it('admin + editor user sees node_id column and List Nodes link', () => {
    const { container } = render(
      <EverythingDocumentDirectory data={baseData} e2={{}} user={{ admin: true, editor: true }} />
    )
    expect(nodeIdHeaderCount(container.textContent)).toBeGreaterThan(0)
    expect(container.textContent).toMatch(/List Nodes of Type/)
  })

  it('non-admin non-editor user hides node_id column and List Nodes link', () => {
    const { container } = render(
      <EverythingDocumentDirectory data={baseData} e2={{}} user={{ admin: false, editor: false }} />
    )
    expect(nodeIdHeaderCount(container.textContent)).toBe(0)
    expect(container.textContent).not.toMatch(/List Nodes of Type/)
  })

  it('undefined user prop does not crash and gates off both', () => {
    const { container } = render(
      <EverythingDocumentDirectory data={baseData} e2={{}} user={undefined} />
    )
    expect(container).toBeTruthy()
    expect(nodeIdHeaderCount(container.textContent)).toBe(0)
    expect(container.textContent).not.toMatch(/List Nodes of Type/)
  })
})
