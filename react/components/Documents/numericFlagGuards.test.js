import React from 'react'
import { render } from '@testing-library/react'
import BadSpellingsListing from './BadSpellingsListing'

// #4108 regression — Perl serializes per-page/per-API permission flags as numeric
// 0/1 (e.g. `is_admin => $is_admin ? 1 : 0`), NOT JSON booleans. A bare
// `{is_admin && <JSX>}` then renders a literal "0" for every non-admin/non-editor.
// This sweep wrapped 31 such guards across 19 components in `!!`.
//
// Robust, text-merge-proof assertion: render a flag as the NUMBER 0 and again as the
// boolean false. The fixed component coerces both with `!!` -> false -> identical
// output. The bug (`0 && X`) renders "0" for the number but nothing for false, so the
// two renders would differ. Independent of surrounding text and of fixtures.
// BadSpellingsListing stands in for the whole batch (same `!!flag` fix everywhere).

const html = (el) => {
  const { container, unmount } = render(el)
  const out = container.innerHTML
  unmount()
  return out
}

describe('#4108 numeric-flag guards do not leak a stray "0"', () => {
  it('BadSpellingsListing: is_admin/is_editor as 0 render identically to false', () => {
    const base = { spellings: [], shown_count: 0, total_count: 0, setting_node_id: 1 }
    const asZero = html(<BadSpellingsListing data={{ ...base, is_admin: 0, is_editor: 0 }} />)
    const asFalse = html(<BadSpellingsListing data={{ ...base, is_admin: false, is_editor: false }} />)
    expect(asZero).toBe(asFalse)
    expect(asZero).not.toMatch(/>0</) // no bare "0" element leaked
  })
})
