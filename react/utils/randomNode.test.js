import { goToRandomNode } from './randomNode'

describe('goToRandomNode', () => {
  let originalLocation

  beforeEach(() => {
    originalLocation = window.location
    delete window.location
    window.location = { href: '' }
  })

  afterEach(() => {
    window.location = originalLocation
    jest.restoreAllMocks()
  })

  it('fetches /api/randomnode and navigates to /node/<id>', async () => {
    global.fetch = jest.fn(() =>
      Promise.resolve({ ok: true, json: async () => ({ success: 1, node_id: 999 }) })
    )
    await goToRandomNode()
    expect(global.fetch).toHaveBeenCalledWith(
      '/api/randomnode',
      expect.objectContaining({ credentials: 'same-origin' })
    )
    expect(window.location.href).toBe('/node/999')
  })

  it('does not navigate when the response is not ok', async () => {
    global.fetch = jest.fn(() => Promise.resolve({ ok: false }))
    await goToRandomNode()
    expect(window.location.href).toBe('')
  })

  it('does not navigate when no node_id is returned', async () => {
    global.fetch = jest.fn(() =>
      Promise.resolve({ ok: true, json: async () => ({ success: 0 }) })
    )
    await goToRandomNode()
    expect(window.location.href).toBe('')
  })

  it('swallows fetch errors without navigating', async () => {
    global.fetch = jest.fn(() => Promise.reject(new Error('network')))
    await expect(goToRandomNode()).resolves.toBeUndefined()
    expect(window.location.href).toBe('')
  })
})
