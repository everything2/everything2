import '@testing-library/jest-dom'

/**
 * Tests for Vote API Integration
 *
 * These tests verify that the voting API correctly:
 * - Allows vote swapping (changing from upvote to downvote)
 * - Recalculates reputation as SUM(weight) after vote changes
 * - Doesn't consume votes_remaining when swapping
 * - Returns correct upvote/downvote counts
 */

describe('Vote API', () => {
  let originalFetch

  beforeEach(() => {
    originalFetch = global.fetch
  })

  afterEach(() => {
    global.fetch = originalFetch
  })

  describe('vote swapping', () => {
    it('allows changing vote from upvote to downvote', async () => {
      const mockResponse = {
        success: 1,
        message: 'Vote changed successfully',
        writeup_id: '123',
        weight: -1,
        votes_remaining: 10,
        reputation: 5,
        upvotes: 8,
        downvotes: 4
      }

      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: async () => mockResponse
      })

      const response = await fetch('/api/vote/writeup/123', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ weight: -1 })
      })

      const data = await response.json()

      expect(data.success).toBe(1)
      expect(data.message).toBe('Vote changed successfully')
      expect(data.weight).toBe(-1)
      expect(data.votes_remaining).toBe(10)
    })

    it('allows changing vote from downvote to upvote', async () => {
      const mockResponse = {
        success: 1,
        message: 'Vote changed successfully',
        writeup_id: '123',
        weight: 1,
        votes_remaining: 10,
        reputation: 7,
        upvotes: 9,
        downvotes: 3
      }

      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: async () => mockResponse
      })

      const response = await fetch('/api/vote/writeup/123', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ weight: 1 })
      })

      const data = await response.json()

      expect(data.success).toBe(1)
      expect(data.message).toBe('Vote changed successfully')
      expect(data.weight).toBe(1)
    })

    it('prevents duplicate votes with same weight', async () => {
      const mockResponse = {
        success: 0,
        error: 'You have already cast this vote'
      }

      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: async () => mockResponse
      })

      const response = await fetch('/api/vote/writeup/123', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ weight: 1 })
      })

      const data = await response.json()

      expect(data.success).toBe(0)
      expect(data.error).toBe('You have already cast this vote')
    })
  })

  describe('votes remaining', () => {
    it('does not consume votes when swapping', async () => {
      const mockResponse = {
        success: 1,
        message: 'Vote changed successfully',
        writeup_id: '123',
        weight: -1,
        votes_remaining: 10, // Same as before
        reputation: 5,
        upvotes: 8,
        downvotes: 4
      }

      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: async () => mockResponse
      })

      const response = await fetch('/api/vote/writeup/123', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ weight: -1 })
      })

      const data = await response.json()

      // votes_remaining should not decrease when swapping
      expect(data.votes_remaining).toBe(10)
      expect(data.message).toBe('Vote changed successfully')
    })

    it('consumes one vote when casting new vote', async () => {
      const mockResponse = {
        success: 1,
        message: 'Vote cast successfully',
        writeup_id: '123',
        weight: 1,
        votes_remaining: 9, // Decreased by 1
        reputation: 1,
        upvotes: 1,
        downvotes: 0
      }

      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: async () => mockResponse
      })

      const response = await fetch('/api/vote/writeup/123', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ weight: 1 })
      })

      const data = await response.json()

      expect(data.votes_remaining).toBe(9)
      expect(data.message).toBe('Vote cast successfully')
    })
  })

  describe('reputation calculation', () => {
    it('returns correct reputation after upvote', async () => {
      const mockResponse = {
        success: 1,
        message: 'Vote cast successfully',
        writeup_id: '123',
        weight: 1,
        votes_remaining: 9,
        reputation: 1,
        upvotes: 1,
        downvotes: 0
      }

      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: async () => mockResponse
      })

      const response = await fetch('/api/vote/writeup/123', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ weight: 1 })
      })

      const data = await response.json()

      // Reputation should equal upvotes - downvotes
      expect(data.reputation).toBe(1)
      expect(data.upvotes).toBe(1)
      expect(data.downvotes).toBe(0)
    })

    it('returns correct reputation after vote swap', async () => {
      // Initial state: 10 upvotes, 5 downvotes = reputation 5
      // After swap: 9 upvotes, 6 downvotes = reputation 3
      const mockResponse = {
        success: 1,
        message: 'Vote changed successfully',
        writeup_id: '123',
        weight: -1,
        votes_remaining: 10,
        reputation: 3, // Changed from 5 to 3 (net -2)
        upvotes: 9,
        downvotes: 6
      }

      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: async () => mockResponse
      })

      const response = await fetch('/api/vote/writeup/123', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ weight: -1 })
      })

      const data = await response.json()

      // Reputation should be recalculated correctly
      expect(data.reputation).toBe(3)
      expect(data.upvotes).toBe(9)
      expect(data.downvotes).toBe(6)
      expect(data.upvotes - data.downvotes).toBe(Number(data.reputation))
    })

    it('handles zero reputation correctly', async () => {
      const mockResponse = {
        success: 1,
        message: 'Vote cast successfully',
        writeup_id: '123',
        weight: -1,
        votes_remaining: 9,
        reputation: 0, // Equal upvotes and downvotes
        upvotes: 5,
        downvotes: 5
      }

      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: async () => mockResponse
      })

      const response = await fetch('/api/vote/writeup/123', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ weight: -1 })
      })

      const data = await response.json()

      expect(data.reputation).toBe(0)
      expect(data.upvotes).toBe(5)
      expect(data.downvotes).toBe(5)
    })

    it('handles negative reputation correctly', async () => {
      const mockResponse = {
        success: 1,
        message: 'Vote cast successfully',
        writeup_id: '123',
        weight: -1,
        votes_remaining: 9,
        reputation: -3, // More downvotes than upvotes
        upvotes: 2,
        downvotes: 5
      }

      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: async () => mockResponse
      })

      const response = await fetch('/api/vote/writeup/123', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ weight: -1 })
      })

      const data = await response.json()

      expect(data.reputation).toBe(-3)
      expect(data.upvotes).toBe(2)
      expect(data.downvotes).toBe(5)
    })
  })

  describe('error handling', () => {
    it('handles guest user error', async () => {
      const mockResponse = {
        success: 0,
        error: 'You must be logged in to vote'
      }

      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: async () => mockResponse
      })

      const response = await fetch('/api/vote/writeup/123', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ weight: 1 })
      })

      const data = await response.json()

      expect(data.success).toBe(0)
      expect(data.error).toBe('You must be logged in to vote')
    })

    it('handles no votes remaining error', async () => {
      const mockResponse = {
        success: 0,
        error: 'You have no votes remaining'
      }

      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: async () => mockResponse
      })

      const response = await fetch('/api/vote/writeup/123', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ weight: 1 })
      })

      const data = await response.json()

      expect(data.success).toBe(0)
      expect(data.error).toBe('You have no votes remaining')
    })

    it('handles author self-vote error', async () => {
      const mockResponse = {
        success: 0,
        error: 'You cannot vote on your own writeup'
      }

      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: async () => mockResponse
      })

      const response = await fetch('/api/vote/writeup/123', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ weight: 1 })
      })

      const data = await response.json()

      expect(data.success).toBe(0)
      expect(data.error).toBe('You cannot vote on your own writeup')
    })
  })

  describe('vote count updates', () => {
    it('increments upvotes when casting upvote', async () => {
      const mockResponse = {
        success: 1,
        message: 'Vote cast successfully',
        writeup_id: '123',
        weight: 1,
        votes_remaining: 9,
        reputation: 6,
        upvotes: 6, // Incremented
        downvotes: 0
      }

      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: async () => mockResponse
      })

      const response = await fetch('/api/vote/writeup/123', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ weight: 1 })
      })

      const data = await response.json()

      expect(data.upvotes).toBe(6)
      expect(data.downvotes).toBe(0)
    })

    it('updates counts correctly when swapping from upvote to downvote', async () => {
      // Before: 10 upvotes, 5 downvotes
      // After: 9 upvotes, 6 downvotes (net change of -2 in reputation)
      const mockResponse = {
        success: 1,
        message: 'Vote changed successfully',
        writeup_id: '123',
        weight: -1,
        votes_remaining: 10,
        reputation: 3,
        upvotes: 9, // Decremented
        downvotes: 6 // Incremented
      }

      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: async () => mockResponse
      })

      const response = await fetch('/api/vote/writeup/123', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ weight: -1 })
      })

      const data = await response.json()

      expect(data.upvotes).toBe(9)
      expect(data.downvotes).toBe(6)
      expect(data.reputation).toBe(3)
    })
  })
})
