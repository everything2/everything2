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

    it('renders a user profile link', () => {
      render(<LinkNode type="user" title="testuser" />);
      const link = screen.getByRole('link');
      expect(link).toHaveAttribute('href', '/user/testuser');
      expect(link).toHaveTextContent('testuser');
    });

    it('handles special characters in title', () => {
      render(<LinkNode title="Test & Node @ Plus+" />);
      const link = screen.getByRole('link');
      const href = link.getAttribute('href');
      // Special URL chars are single-encoded — the server-side helper
      // _recover_route_params_from_request_uri decodes once on the way in.
      expect(href).toContain('%26');   // &
      expect(href).toContain('%40');   // @
      expect(href).toContain('%2B');   // +
      expect(href).not.toContain('%2526'); // not double-encoded
    });

    it('handles HTML entities in title (GitHub #3950)', () => {
      // &#9608; is the block character █
      render(<LinkNode title="Dead bear in &#9608;&#9608;&#9608;" />);
      const link = screen.getByRole('link');
      // Should decode entity to actual character before encoding for URL
      const href = link.getAttribute('href');
      // Should NOT contain the malformed encoded entity
      expect(href).not.toContain('%26%239608');
      // Should contain the decoded block characters (█)
      expect(href).toContain('█');
    });

    it('handles named HTML entities in title', () => {
      render(<LinkNode title="AT&amp;T History" />);
      const link = screen.getByRole('link');
      const href = link.getAttribute('href');
      // &amp; should decode to & then single-encode to %26.
      expect(href).toContain('%26');
      expect(href).not.toContain('%2526');  // no double-encoding
      expect(href).not.toContain('&amp;');
    });

    it('produces a URL that the server route-recovery helper can resolve (GitHub #4060)', () => {
      // Mirrors the #4060 regression: titles with '&' on the front page.
      // The href must be /title/Sense%20%26%20Sensibility (or with literal
      // space — browsers encode that on navigation), NOT the legacy
      // /title/Sense %2526 Sensibility that decoded to "Sense %26 Sensibility"
      // server-side and missed the lookup.
      render(<LinkNode title="Sense & Sensibility" />);
      const href = screen.getByRole('link').getAttribute('href');
      expect(href).toContain('%26');
      expect(href).not.toContain('%2526');
    });

    it('shows decoded title in hover text for entity titles', () => {
      render(<LinkNode title="Q&amp;A Forum" display="Q&A" />);
      const link = screen.getByRole('link');
      // Hover text should show decoded title
      expect(link).toHaveAttribute('title', 'Q&A Forum');
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

  describe('hover text (title attribute)', () => {
    it('shows node title in hover for internal links', () => {
      render(<LinkNode title="Test Node" />);
      const link = screen.getByRole('link');
      expect(link).toHaveAttribute('title', 'Test Node');
    });

    it('shows target title in hover for pipelinks (display differs from title)', () => {
      render(<LinkNode title="Actual Target" display="Click Here" />);
      const link = screen.getByRole('link');
      expect(link).toHaveAttribute('title', 'Actual Target');
      expect(link).toHaveTextContent('Click Here');
    });

    it('shows URL in hover for external links', () => {
      render(<LinkNode url="https://example.com/path" />);
      const link = screen.getByRole('link');
      expect(link).toHaveAttribute('title', 'https://example.com/path');
    });

    it('shows URL in hover for external links with custom display', () => {
      render(<LinkNode url="https://reddit.com" display="Reddit" />);
      const link = screen.getByRole('link');
      expect(link).toHaveAttribute('title', 'https://reddit.com');
      expect(link).toHaveTextContent('Reddit');
    });

    it('shows node title in hover for typed links', () => {
      render(<LinkNode type="user" title="someuser" />);
      const link = screen.getByRole('link');
      expect(link).toHaveAttribute('title', 'someuser');
    });

    it('shows node title in hover for author writeup links', () => {
      render(<LinkNode title="My Writeup" author="testuser" />);
      const link = screen.getByRole('link');
      expect(link).toHaveAttribute('title', 'My Writeup');
    });

    it('shows node title in hover for links with anchor', () => {
      render(<LinkNode title="Discussion" anchor="debatecomment_42" />);
      const link = screen.getByRole('link');
      expect(link).toHaveAttribute('title', 'Discussion');
    });

    it('does not have title attribute for node ID only links', () => {
      render(<LinkNode id="12345" />);
      const link = screen.getByRole('link');
      // No title prop provided, so no hover text
      expect(link).not.toHaveAttribute('title');
    });
  });
});
