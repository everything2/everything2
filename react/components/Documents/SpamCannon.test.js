import React from 'react'
import { render } from '@testing-library/react'
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
