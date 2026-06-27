import { normalizeIntKeys, INT_KEYS } from './normalizeE2'

describe('normalizeIntKeys (client-side page-state int coercion, #4381/#4383)', () => {
  it('coerces integer-valued strings under INT_KEYS to numbers', () => {
    const e2 = { node_id: '12345', title: 'x', reputation: '-3' }
    normalizeIntKeys(e2)
    expect(e2.node_id).toBe(12345)
    expect(typeof e2.node_id).toBe('number')
    expect(e2.reputation).toBe(-3)
    expect(e2.title).toBe('x') // non-INT key untouched
  })

  it('recurses into nested objects and arrays', () => {
    const e2 = {
      node: { node_id: '7', title: 't' },
      newWriteups: [
        { node_id: '1', author_user: '99' },
        { node_id: '2', author_user: '100' },
      ],
    }
    normalizeIntKeys(e2)
    expect(e2.node.node_id).toBe(7)
    expect(e2.newWriteups[0].node_id).toBe(1)
    expect(e2.newWriteups[1].author_user).toBe(100)
  })

  it('matches the Perl predicate: non-INT keys and non-numeric INT values are left alone', () => {
    const e2 = { title: '0', node_id: 'abc', lastnode_id: '0' }
    normalizeIntKeys(e2)
    expect(e2.title).toBe('0') // not an INT key -> string "0" stays
    expect(e2.node_id).toBe('abc') // INT key but non-numeric -> untouched
    expect(e2.lastnode_id).toBe(0) // INT key + numeric -> number
  })

  it('is idempotent (already-numeric values skipped) so it is safe alongside server typing', () => {
    const e2 = { node_id: 5, author_user: 42 }
    normalizeIntKeys(e2)
    expect(e2.node_id).toBe(5)
    expect(e2.author_user).toBe(42)
  })

  it('fixes the #4108 stray-"0" class: a string flag becomes a falsy number', () => {
    const e2 = { use_local_assets: '0' }
    normalizeIntKeys(e2)
    expect(e2.use_local_assets).toBe(0)
    expect(!!e2.use_local_assets).toBe(false) // string "0" would have been truthy
  })

  it('INT_KEYS mirrors the documented Everything::PageState set', () => {
    expect(INT_KEYS.has('node_id')).toBe(true)
    expect(INT_KEYS.has('lastnode_id')).toBe(true)
    expect(INT_KEYS.has('author_user')).toBe(true)
    expect(INT_KEYS.has('title')).toBe(false)
  })
})
