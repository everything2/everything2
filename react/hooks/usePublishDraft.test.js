import { renderHook, act, waitFor } from '@testing-library/react'
import { usePublishDraft, usePublishAsOptions } from './usePublishDraft'

// Both hooks go through fetchWithErrorReporting, which calls global.fetch and
// inspects response.ok. Mocked responses must set ok:true so we don't trip the
// error-reporting branch.
const okJson = (data) => Promise.resolve({ ok: true, json: () => Promise.resolve(data) })

describe('usePublishAsOptions (canpublishas #4354)', () => {
  afterEach(() => jest.restoreAllMocks())

  it('fetches /api/drafts/publishas_options and exposes the account list', async () => {
    global.fetch = jest.fn(() =>
      okJson({
        success: 1,
        options: [
          { title: 'everyone', node_id: 919 },
          { title: 'Klaproth', node_id: 1000 }
        ]
      })
    )

    const { result } = renderHook(() => usePublishAsOptions())

    await waitFor(() => expect(result.current.options.length).toBe(2))
    expect(global.fetch).toHaveBeenCalledWith(
      '/api/drafts/publishas_options',
      expect.anything()
    )
    expect(result.current.options.map((o) => o.title)).toEqual(['everyone', 'Klaproth'])
    // default selection is "yourself"
    expect(result.current.publishAs).toBe('')
  })

  it('yields an empty list (no picker) when the user has no options', async () => {
    global.fetch = jest.fn(() => okJson({ success: 1, options: [] }))
    const { result } = renderHook(() => usePublishAsOptions())
    await waitFor(() => expect(result.current.loading).toBe(false))
    expect(result.current.options).toEqual([])
  })

  it('skip=true does not fetch', () => {
    global.fetch = jest.fn()
    renderHook(() => usePublishAsOptions({ skip: true }))
    expect(global.fetch).not.toHaveBeenCalled()
  })
})

describe('usePublishDraft publish_as payload (canpublishas #4354)', () => {
  afterEach(() => jest.restoreAllMocks())

  const setup = () => {
    const fetchMock = jest.fn(() => okJson({ success: true, writeup_id: 7 }))
    global.fetch = fetchMock
    const { result } = renderHook(() =>
      usePublishDraft({ draftId: 42, onSuccess: jest.fn() })
    )
    return { fetchMock, result }
  }

  const bodyOf = (fetchMock) => {
    const call = fetchMock.mock.calls.find(([url]) => /\/publish$/.test(url))
    return JSON.parse(call[1].body)
  }

  it('includes publish_as when a non-self account is chosen', async () => {
    const { fetchMock, result } = setup()

    await act(async () => {
      await result.current.publishDraft({
        parentE2nodeId: 555,
        writeuptypeId: 1,
        publishAs: 'everyone'
      })
    })

    const body = bodyOf(fetchMock)
    expect(body.publish_as).toBe('everyone')
    expect(body.parent_e2node).toBe(555)
    expect(body.wrtype_writeuptype).toBe(1)
  })

  it('omits publish_as entirely when publishing as yourself (empty)', async () => {
    const { fetchMock, result } = setup()

    await act(async () => {
      await result.current.publishDraft({
        parentE2nodeId: 555,
        writeuptypeId: 1,
        publishAs: ''
      })
    })

    const body = bodyOf(fetchMock)
    expect('publish_as' in body).toBe(false)
  })

  it('omits publish_as when not provided at all (back-compat default)', async () => {
    const { fetchMock, result } = setup()

    await act(async () => {
      await result.current.publishDraft({ parentE2nodeId: 555, writeuptypeId: 1 })
    })

    const body = bodyOf(fetchMock)
    expect('publish_as' in body).toBe(false)
  })
})
