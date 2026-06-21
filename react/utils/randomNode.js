// Navigate to a random content node via the randomnode API (was op=randomnode).
// The API reads the randomnodes DataStash and returns a { node_id }; we then
// hard-navigate to /node/<id>. #4335 Phase 3.
export async function goToRandomNode() {
  try {
    const res = await fetch('/api/randomnode', {
      credentials: 'same-origin',
      headers: { Accept: 'application/json' },
    })
    const data = res.ok ? await res.json() : null
    if (data && data.node_id) {
      window.location.href = `/node/${data.node_id}`
    }
  } catch (err) {
    // no-op: leave the user where they are on failure
  }
}
