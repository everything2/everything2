import React from 'react';
import { render, screen } from '@testing-library/react';
import LinkNode from './LinkNode';

describe('LinkNode Component', () => {
  describe('internal links', () => {
    it('renders a link with title', () => {
      render(<LinkNode title="Test Node" />);
      const link = screen.getByRole('link');
      expect(link).toHaveAttribute('href', '/title/Test Node');
      expect(link).toHaveTextContent('Test Node');
    });

    it('renders a link with custom display text', () => {
      render(<LinkNode title="Test Node" display="Click Here" />);
      const link = screen.getByRole('link');
      expect(link).toHaveTextContent('Click Here');
    });

    it('renders a link with node type', () => {
      render(<LinkNode type="writeup" title="My Writeup" />);
      const link = screen.getByRole('link');
      expect(link).toHaveAttribute('href', '/node/writeup/My Writeup');
    });

    it('renders a link with node ID', () => {
      render(<LinkNode id="12345" />);
      const link = screen.getByRole('link');
      expect(link).toHaveAttribute('href', '/node/12345');
      expect(link).toHaveTextContent('node_id: 12345');
    });

    it('renders a link with author (user writeups)', () => {
      render(<LinkNode type="writeup" title="Test" author="testuser" />);
      const link = screen.getByRole('link');
      expect(link).toHaveAttribute('href', '/user/testuser/writeups/Test');
    });

    it('handles special characters in title', () => {
      render(<LinkNode title="Test & Node @ Plus+" />);
      const link = screen.getByRole('link');
      // Special characters should be double-encoded
      expect(link.getAttribute('href')).toContain('%');
    });

    it('adds query parameters', () => {
      render(<LinkNode title="Test" params={{ foo: 'bar', baz: 'qux' }} />);
      const link = screen.getByRole('link');
      expect(link.getAttribute('href')).toContain('?foo=bar&baz=qux');
    });

    it('adds anchor hash', () => {
      render(<LinkNode title="Test" anchor="section" />);
      const link = screen.getByRole('link');
      expect(link).toHaveAttribute('href', '/title/Test#section');
    });

    it('combines params and anchor', () => {
      render(<LinkNode title="Test" params={{ id: '123' }} anchor="top" />);
      const link = screen.getByRole('link');
      expect(link.getAttribute('href')).toMatch(/\?id=123#top$/);
    });
  });

  describe('external links', () => {
    it('renders an external URL', () => {
      render(<LinkNode url="https://example.com" />);
      const link = screen.getByRole('link');
      expect(link).toHaveAttribute('href', 'https://example.com');
      expect(link).toHaveAttribute('rel', 'nofollow');
      expect(link).toHaveClass('externalLink');
    });

    it('uses custom display text for external links', () => {
      render(<LinkNode url="https://example.com" display="Example Site" />);
      const link = screen.getByRole('link');
      expect(link).toHaveTextContent('Example Site');
    });

    it('applies custom className for external links', () => {
      render(<LinkNode url="https://example.com" className="custom-class" />);
      const link = screen.getByRole('link');
      expect(link).toHaveClass('custom-class');
    });
  });

  describe('edge cases', () => {
    it('handles undefined display with node ID', () => {
      render(<LinkNode id="999" display="Custom Display" />);
      const link = screen.getByRole('link');
      expect(link).toHaveTextContent('Custom Display');
    });

    it('handles empty params object', () => {
      render(<LinkNode title="Test" params={{}} />);
      const link = screen.getByRole('link');
      expect(link.getAttribute('href')).toBe('/title/Test');
    });

    it('renders without className for internal links', () => {
      render(<LinkNode title="Test" />);
      const link = screen.getByRole('link');
      expect(link).not.toHaveAttribute('class');
    });
  });
});
