import setEditorContent from './setEditorContent'

// A destroyed TipTap editor has no command manager: reading .commands throws.
const destroyed = () => ({
  isDestroyed: true,
  get commands() { throw new TypeError("Cannot read properties of null (reading 'commands')") },
})

describe('setEditorContent', () => {
  it('loads the content into a live editor without firing an update', () => {
    const setContent = jest.fn()
    expect(setEditorContent({ isDestroyed: false, commands: { setContent } }, '<p>hi</p>')).toBe(true)
    expect(setContent).toHaveBeenCalledWith('<p>hi</p>', { emitUpdate: false })
  })

  it('does nothing for a destroyed editor', () => {
    expect(() => setEditorContent(destroyed(), '<p>hi</p>')).not.toThrow()
    expect(setEditorContent(destroyed(), '<p>hi</p>')).toBe(false)
  })

  it('does nothing when there is no editor yet', () => {
    expect(setEditorContent(null, '<p>hi</p>')).toBe(false)
    expect(setEditorContent(undefined, '<p>hi</p>')).toBe(false)
  })
})
