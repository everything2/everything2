import React from 'react'
import { render, screen, fireEvent } from '@testing-library/react'
import E2SourceCodeFormatter from './E2SourceCodeFormatter'
import fixture from '../../__fixtures__/pagestate/e2_source_code_formatter.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('E2SourceCodeFormatter (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<E2SourceCodeFormatter data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<E2SourceCodeFormatter data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

describe('E2SourceCodeFormatter reformat/deformat', () => {
  const run = (input, buttonName) => {
    const { container } = render(<E2SourceCodeFormatter />)
    const textarea = container.querySelector('textarea')
    fireEvent.change(textarea, { target: { value: input } })
    fireEvent.click(screen.getByRole('button', { name: buttonName }))
    return textarea.value
  }

  it('escapes ampersands, angle brackets and square brackets', () => {
    expect(run('a[i] < b && c > d', 'Reformat')).toBe('a&#91;i&#93; &lt; b &amp;&amp; c &gt; d')
  })

  it('deformats back to the original source', () => {
    expect(run('a&#91;i&#93; &lt; b &amp;&amp; c &gt; d', 'DEformat')).toBe('a[i] < b && c > d')
  })

  it('deformats each entity once, so escaped entities in the source survive', () => {
    expect(run('&amp;lt; &amp;#91;', 'DEformat')).toBe('&lt; &#91;')
  })

  it('round-trips source that itself contains entities', () => {
    const source = 'puts "&lt;" if a[0] == "&#93;"'
    const { container } = render(<E2SourceCodeFormatter />)
    const textarea = container.querySelector('textarea')
    fireEvent.change(textarea, { target: { value: source } })
    fireEvent.click(screen.getByRole('button', { name: 'Reformat' }))
    fireEvent.click(screen.getByRole('button', { name: 'DEformat' }))
    expect(textarea.value).toBe(source)
  })
})
