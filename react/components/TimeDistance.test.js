import React from 'react';
import { render, screen } from '@testing-library/react';
import TimeDistance from './TimeDistance';

describe('TimeDistance Component', () => {
  const NOW = 1700000000; // Fixed timestamp for testing

  describe('relative time formatting', () => {
    it('displays "just now" for times less than 5 minutes ago', () => {
      const then = NOW - 120; // 2 minutes ago
      const { container } = render(<TimeDistance then={then} now={NOW} />);
      expect(container.textContent).toBe('just now');
    });

    it('displays minutes for times less than 1 hour ago', () => {
      const then = NOW - 1800; // 30 minutes ago
      const { container } = render(<TimeDistance then={then} now={NOW} />);
      expect(container.textContent).toBe('30m ago');
    });

    it('displays hours for times less than 1 day ago', () => {
      const then = NOW - 7200; // 2 hours ago
      const { container } = render(<TimeDistance then={then} now={NOW} />);
      expect(container.textContent).toBe('2h ago');
    });

    it('displays days for times less than 1 month ago', () => {
      const then = NOW - 86400 * 5; // 5 days ago
      const { container } = render(<TimeDistance then={then} now={NOW} />);
      expect(container.textContent).toBe('5d ago');
    });

    it('displays months for times less than 1 year ago', () => {
      const then = NOW - 86400 * 60; // ~2 months ago
      const { container } = render(<TimeDistance then={then} now={NOW} />);
      expect(container.textContent).toBe('2m ago');
    });

    it('displays years for times more than 1 year ago', () => {
      const then = NOW - 86400 * 730; // ~2 years ago
      const { container } = render(<TimeDistance then={then} now={NOW} />);
      expect(container.textContent).toBe('2y ago');
    });
  });

  describe('special cases', () => {
    it('displays "forever ago" when then is 0', () => {
      const { container } = render(<TimeDistance then={0} now={NOW} />);
      expect(container.textContent).toBe('forever ago');
    });

    it('handles future times correctly', () => {
      const then = NOW + 3600; // 1 hour in the future
      const { container } = render(<TimeDistance then={then} now={NOW} />);
      expect(container.textContent).toBe('1h in the future');
    });

    it('uses current time when now is undefined', () => {
      const then = Date.now() / 1000 - 60; // 1 minute ago
      const { container } = render(<TimeDistance then={then} />);
      expect(container.textContent).toBe('just now');
    });
  });

  describe('rounding behavior', () => {
    it('rounds time values appropriately', () => {
      const then = NOW - 5400; // 1.5 hours ago
      const { container } = render(<TimeDistance then={then} now={NOW} />);
      expect(container.textContent).toBe('1.5h ago');
    });

    it('rounds to one decimal place', () => {
      const then = NOW - 5460; // 1.517 hours ago
      const { container } = render(<TimeDistance then={then} now={NOW} />);
      // Should round to 1.5h
      expect(container.textContent).toMatch(/1\.5h ago/);
    });
  });
});
