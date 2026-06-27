// Centralized int-key coercion for the window.e2 page-state blob.
//
// React treats a string "0" as truthy in `{flag && <JSX/>}`, so integer-valued strings in
// the blob (ids, counts, flags) must be real numbers or you get the #4108 stray-"0" class of
// bug. The server used to coerce these in Everything::PageState::normalize_types; that compute
// moved here (client-side) as the cheap interim -- the page state is API-served and rendered
// client-side, so the client is the right owner. This is explicitly a stopgap; the long-term
// fix is source/model coercion on the server, after which this can be deleted. See #4383.
//
// INT_KEYS mirrors Everything::PageState %INT_KEYS exactly -- keep the two lists in lockstep.
export const INT_KEYS = new Set([
  'node_id',
  'user_id',
  'parent_e2node',
  'author_user',
  'type_nodetype',
  'lastnode_id',
  'to_node',
  'from_node',
  'reputation',
  'numwriteups',
  'use_local_assets',
])

// Recursively coerce integer-valued strings under INT_KEYS to numbers, mutating in place.
// Predicate matches the Perl _coerce_ints exactly: a defined, non-ref, /^-?\d+$/ string only
// (so a non-numeric string or a nested structure under an INT_KEY is recursed, not coerced).
// Idempotent: already-numeric values are skipped, so it's safe to run even while the server
// still types the blob.
export function normalizeIntKeys(value) {
  if (Array.isArray(value)) {
    for (const v of value) normalizeIntKeys(v)
  } else if (value && typeof value === 'object') {
    for (const k of Object.keys(value)) {
      const v = value[k]
      if (INT_KEYS.has(k) && typeof v === 'string' && /^-?\d+$/.test(v)) {
        value[k] = Number(v)
      } else {
        normalizeIntKeys(v)
      }
    }
  }
  return value
}

export default normalizeIntKeys
