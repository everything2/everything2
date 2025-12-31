import React from 'react';
import { render, screen } from '@testing-library/react';
import TimeDistance from './TimeDistance';

describe('TimeDistance Component', () => {
  const NOW = 1700000000; // Fixed timestamp for testing

  describe('relative time formatting', () => {
    it('displays seconds for times less than 1 minute ago', () => {
      const then = NOW - 30; // 30 seconds ago
      const { container } = render(<TimeDistance then={then} now={NOW} />);
      expect(container.textContent).toBe('30 seconds ago');
    });

    it('displays singular second correctly', () => {
      const then = NOW - 1;
      const { container } = render(<TimeDistance then={then} now={NOW} />);
      expect(container.textContent).toBe('1 second ago');
    });

    it('displays minutes for times less than 1 hour ago', () => {
      const then = NOW - 1800; // 30 minutes ago
      const { container } = render(<TimeDistance then={then} now={NOW} />);
      expect(container.textContent).toBe('30 minutes ago');
    });

    it('displays singular minute correctly', () => {
      const then = NOW - 60;
      const { container } = render(<TimeDistance then={then} now={NOW} />);
      expect(container.textContent).toBe('1 minute ago');
    });

    it('displays hours for times less than 1 day ago', () => {
      const then = NOW - 7200; // 2 hours ago
      const { container } = render(<TimeDistance then={then} now={NOW} />);
      expect(container.textContent).toBe('2 hours ago');
    });

    it('displays singular hour correctly', () => {
      const then = NOW - 3600;
      const { container } = render(<TimeDistance then={then} now={NOW} />);
      expect(container.textContent).toBe('1 hour ago');
    });

    it('displays days for times less than 1 week ago', () => {
      const then = NOW - 86400 * 5; // 5 days ago
      const { container } = render(<TimeDistance then={then} now={NOW} />);
      expect(container.textContent).toBe('5 days ago');
    });

    it('displays singular day correctly', () => {
      const then = NOW - 86400;
      const { container } = render(<TimeDistance then={then} now={NOW} />);
      expect(container.textContent).toBe('1 day ago');
    });

    it('displays weeks for times less than 1 month ago', () => {
      const then = NOW - 86400 * 14; // 2 weeks ago
      const { container } = render(<TimeDistance then={then} now={NOW} />);
      expect(container.textContent).toBe('2 weeks ago');
    });

    it('displays singular week correctly', () => {
      const then = NOW - 86400 * 7;
      const { container } = render(<TimeDistance then={then} now={NOW} />);
      expect(container.textContent).toBe('1 week ago');
    });

    it('displays months for times less than 1 year ago', () => {
      const then = NOW - 86400 * 60; // ~2 months ago
      const { container } = render(<TimeDistance then={then} now={NOW} />);
      expect(container.textContent).toBe('2 months ago');
    });

    it('displays singular month correctly', () => {
      const then = NOW - 86400 * 30;
      const { container } = render(<TimeDistance then={then} now={NOW} />);
      expect(container.textContent).toBe('1 month ago');
    });

    it('displays years for times more than 1 year ago', () => {
      const then = NOW - 86400 * 730; // ~2 years ago
      const { container } = render(<TimeDistance then={then} now={NOW} />);
      expect(container.textContent).toBe('2 years ago');
    });

    it('displays singular year correctly', () => {
      const then = NOW - 86400 * 365;
      const { container } = render(<TimeDistance then={then} now={NOW} />);
      expect(container.textContent).toBe('1 year ago');
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
      expect(container.textContent).toBe('1 hour in the future');
    });

    it('uses current time when now is undefined', () => {
      const then = Math.floor(Date.now() / 1000) - 120; // 2 minutes ago
      const { container } = render(<TimeDistance then={then} />);
      expect(container.textContent).toBe('2 minutes ago');
    });
  });

  describe('boundary cases', () => {
    it('shows hours at exactly 1 hour', () => {
      const then = NOW - 3600; // exactly 1 hour
      const { container } = render(<TimeDistance then={then} now={NOW} />);
      expect(container.textContent).toBe('1 hour ago');
    });

    it('shows days at exactly 1 day', () => {
      const then = NOW - 86400; // exactly 1 day
      const { container } = render(<TimeDistance then={then} now={NOW} />);
      expect(container.textContent).toBe('1 day ago');
    });

    it('shows weeks at 7 days', () => {
      const then = NOW - 86400 * 7; // exactly 1 week
      const { container } = render(<TimeDistance then={then} now={NOW} />);
      expect(container.textContent).toBe('1 week ago');
    });
  });
});
