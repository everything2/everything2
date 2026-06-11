import React from 'react'
import { render, fireEvent, screen, waitFor } from '@testing-library/react'
import BlindVotingBooth from './BlindVotingBooth'
import fixture from '../../__fixtures__/pagestate/blind_voting_booth.json'
// Fixture-backed coverage (PageState 2a, #4255): real normalized /api/pagestate payload,
// pinning the int-typed contract (#4152/#4108).
describe('BlindVotingBooth (real pagestate fixture)', () => {
  it('mounts against the captured payload', () => {
    const { container } = render(<BlindVotingBooth data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    expect(container).toBeTruthy()
  })
  it('fixture has integer node_ids, never strings (#4152)', () => {
    expect(JSON.stringify(fixture).match(/"node_id":"\d/g)).toBeNull()
  })
  it('no React key warnings', () => {
    const errs = []
    const spy = jest.spyOn(console, 'error').mockImplementation((...a) => errs.push(a.join(' ')))
    render(<BlindVotingBooth data={fixture.contentData} e2={fixture} user={fixture.user || {}} />)
    spy.mockRestore()
    expect(errs.filter((x) => /unique "key"|each child in a list/i.test(x))).toEqual([])
  })
})

// The blind-booth reveal (#4266): the booth is BLIND -- the server never sends
// the author. The author arrives ONLY in the POST /api/vote response and is
// unmasked client-side after the vote. Regression-guards the bug where the old
// op=vote opcode round-trip (removed in #4266) was the only thing that revealed
// the author, leaving "by ???" stuck forever once React stopped sending op=vote.
describe('BlindVotingBooth author reveal', () => {
  const votableData = {
    type: 'blind_voting_booth',
    writeup: { node_id: 999, title: 'A Test Writeup', doctext: 'some body text', reputation: null },
    parent: { node_id: 1000, title: 'a test node' },
    votesLeft: 5,
    nodeId: 42,
  }

  afterEach(() => {
    if (global.fetch && global.fetch.mockRestore) global.fetch.mockRestore()
  })

  it('hides the author before voting, reveals it from the API response after', async () => {
    global.fetch = jest.fn(() =>
      Promise.resolve({
        json: () =>
          Promise.resolve({
            success: true,
            votes_remaining: 4,
            reputation: 3,
            author: { node_id: 12345, title: 'revealeduser' },
          }),
      })
    )

    render(<BlindVotingBooth data={votableData} e2={{}} user={{}} />)

    // Blind: author hidden, no author payload present pre-vote.
    expect(screen.getByText('by ???')).toBeTruthy()
    expect(screen.queryByText('revealeduser')).toBeNull()

    // Cast a vote.
    fireEvent.click(screen.getByTitle('Upvote this writeup'))
    fireEvent.click(screen.getByText('Cast Vote'))

    // Reveal: author from the API response replaces "by ???".
    await waitFor(() => expect(screen.getByText('revealeduser')).toBeTruthy())
    expect(screen.queryByText('by ???')).toBeNull()
    expect(global.fetch).toHaveBeenCalledWith('/api/vote/writeup/999', expect.any(Object))
  })
})
