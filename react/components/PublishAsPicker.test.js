import React from 'react'
import { render, screen, fireEvent } from '@testing-library/react'
import PublishAsPicker from './PublishAsPicker'

// canpublishas (#4354): the reusable "Publish as another user" selector. The
// account list comes from GET /api/drafts/publishas_options; this component is
// the presentational half (the fetch/payload contract is covered in
// PublishModal.test.js).
const CEDE_WARNING =
  /cede your copyright and lose\s+all control over your writeup/i

describe('PublishAsPicker', () => {
  it('renders nothing when there are no options (the common case)', () => {
    const { container } = render(<PublishAsPicker options={[]} value="" onChange={() => {}} />)
    expect(container).toBeEmptyDOMElement()
  })

  it('renders nothing when options is undefined', () => {
    const { container } = render(<PublishAsPicker onChange={() => {}} />)
    expect(container).toBeEmptyDOMElement()
  })

  it('renders a (yourself) default plus one option per account title', () => {
    render(
      <PublishAsPicker
        options={[
          { title: 'everyone', node_id: 919 },
          { title: 'Webster 1913', node_id: 923 }
        ]}
        value=""
        onChange={() => {}}
      />
    )

    expect(screen.getByText('Publish as:')).toBeInTheDocument()
    const select = screen.getByRole('combobox')
    const optionTexts = Array.from(select.options).map((o) => o.textContent)
    expect(optionTexts).toEqual(['(yourself)', 'everyone', 'Webster 1913'])

    // option values are the account titles (what the API expects), '' for self
    const optionValues = Array.from(select.options).map((o) => o.value)
    expect(optionValues).toEqual(['', 'everyone', 'Webster 1913'])
  })

  it('default (yourself) selection shows no cede-copyright warning', () => {
    render(
      <PublishAsPicker
        options={[{ title: 'everyone', node_id: 919 }]}
        value=""
        onChange={() => {}}
      />
    )
    expect(screen.queryByText(CEDE_WARNING)).toBeNull()
  })

  it('shows the cede-copyright warning only when a non-self account is chosen', () => {
    const { rerender } = render(
      <PublishAsPicker
        options={[{ title: 'everyone', node_id: 919 }]}
        value=""
        onChange={() => {}}
      />
    )
    expect(screen.queryByText(CEDE_WARNING)).toBeNull()

    rerender(
      <PublishAsPicker
        options={[{ title: 'everyone', node_id: 919 }]}
        value="everyone"
        onChange={() => {}}
      />
    )
    expect(screen.getByText(CEDE_WARNING)).toBeInTheDocument()
  })

  it('emits the selected account title via onChange', () => {
    const onChange = jest.fn()
    render(
      <PublishAsPicker
        options={[{ title: 'everyone', node_id: 919 }]}
        value=""
        onChange={onChange}
      />
    )
    fireEvent.change(screen.getByRole('combobox'), { target: { value: 'everyone' } })
    expect(onChange).toHaveBeenCalledWith('everyone')
  })
})
