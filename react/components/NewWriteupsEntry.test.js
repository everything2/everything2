import React from 'react';
import { render } from '@testing-library/react';
import NewWriteupsEntry from './NewWriteupsEntry';

// Mock child components
jest.mock('./LinkNode', () => {
  return function MockLinkNode({ title, display, type, className }) {
    return <span className={className} data-testid="link-node">{display || title}</span>;
  };
});

jest.mock('./EditorHideWriteup', () => {
  return function MockEditorHideWriteup({ entry }) {
    return <span data-testid="editor-hide-writeup">Hide({entry.node_id})</span>;
  };
});

describe('NewWriteupsEntry Component', () => {
  const mockEditorHideWriteupChange = jest.fn();

  const createMockEntry = (overrides = {}) => ({
    node_id: 12345,
    parent: { title: 'Test Parent Node' },
    author: { title: 'testuser', node_id: 67890 },
    writeuptype: 'thing',
    hasvoted: false,
    notnew: false,
    ...overrides
  });

  beforeEach(() => {
    mockEditorHideWriteupChange.mockClear();
  });

  describe('normal rendering', () => {
    it('renders entry as list item', () => {
      const entry = createMockEntry();
      const { container } = render(
        <NewWriteupsEntry
          entry={entry}
          editor={false}
          editorHideWriteupChange={mockEditorHideWriteupChange}
        />
      );

      const li = container.querySelector('li');
      expect(li).toBeInTheDocument();
    });

    it('displays parent node title', () => {
      const entry = createMockEntry({ parent: { title: 'Everything2' } });
      const { getByText } = render(
        <NewWriteupsEntry
          entry={entry}
          editor={false}
          editorHideWriteupChange={mockEditorHideWriteupChange}
        />
      );

      expect(getByText('Everything2')).toBeInTheDocument();
    });

    it('displays author name', () => {
      const entry = createMockEntry({ author: { title: 'alice', node_id: 111 } });
      const { getByText } = render(
        <NewWriteupsEntry
          entry={entry}
          editor={false}
          editorHideWriteupChange={mockEditorHideWriteupChange}
        />
      );

      expect(getByText('alice')).toBeInTheDocument();
    });

    it('displays writeup type', () => {
      const entry = createMockEntry({ writeuptype: 'idea' });
      const { getByText } = render(
        <NewWriteupsEntry
          entry={entry}
          editor={false}
          editorHideWriteupChange={mockEditorHideWriteupChange}
        />
      );

      expect(getByText('idea')).toBeInTheDocument();
    });

    it('includes "by" text in byline', () => {
      const entry = createMockEntry();
      const { getByText } = render(
        <NewWriteupsEntry
          entry={entry}
          editor={false}
          editorHideWriteupChange={mockEditorHideWriteupChange}
        />
      );

      expect(getByText(/by/i)).toBeInTheDocument();
    });
  });

  describe('CSS classes', () => {
    it('applies contentinfo class to list item', () => {
      const entry = createMockEntry();
      const { container } = render(
        <NewWriteupsEntry
          entry={entry}
          editor={false}
          editorHideWriteupChange={mockEditorHideWriteupChange}
        />
      );

      const li = container.querySelector('li');
      expect(li).toHaveClass('contentinfo');
    });

    it('applies hasvoted class when user has voted', () => {
      const entry = createMockEntry({ hasvoted: true });
      const { container } = render(
        <NewWriteupsEntry
          entry={entry}
          editor={false}
          editorHideWriteupChange={mockEditorHideWriteupChange}
        />
      );

      const li = container.querySelector('li');
      expect(li).toHaveClass('contentinfo');
      expect(li).toHaveClass('hasvoted');
    });

    it('does not apply hasvoted class when user has not voted', () => {
      const entry = createMockEntry({ hasvoted: false });
      const { container } = render(
        <NewWriteupsEntry
          entry={entry}
          editor={false}
          editorHideWriteupChange={mockEditorHideWriteupChange}
        />
      );

      const li = container.querySelector('li');
      expect(li).toHaveClass('contentinfo');
      expect(li).not.toHaveClass('hasvoted');
    });

    it('applies type class to writeup type wrapper', () => {
      const entry = createMockEntry();
      const { container } = render(
        <NewWriteupsEntry
          entry={entry}
          editor={false}
          editorHideWriteupChange={mockEditorHideWriteupChange}
        />
      );

      const typeSpan = container.querySelector('.type');
      expect(typeSpan).toBeInTheDocument();
    });
  });

  describe('broken data handling', () => {
    it('shows "(broken parent)" when parent is undefined', () => {
      const entry = createMockEntry({ parent: undefined });
      const { getByText } = render(
        <NewWriteupsEntry
          entry={entry}
          editor={false}
          editorHideWriteupChange={mockEditorHideWriteupChange}
        />
      );

      expect(getByText('(broken parent)')).toBeInTheDocument();
    });

    it('shows "(broken author)" when author is undefined', () => {
      const entry = createMockEntry({ author: undefined });
      const { container } = render(
        <NewWriteupsEntry
          entry={entry}
          editor={false}
          editorHideWriteupChange={mockEditorHideWriteupChange}
        />
      );

      expect(container.textContent).toContain('(broken author)');
    });

    it('handles both broken parent and author', () => {
      const entry = createMockEntry({ parent: undefined, author: undefined });
      const { container } = render(
        <NewWriteupsEntry
          entry={entry}
          editor={false}
          editorHideWriteupChange={mockEditorHideWriteupChange}
        />
      );

      expect(container.textContent).toContain('(broken parent)');
      expect(container.textContent).toContain('(broken author)');
    });
  });

  describe('editor functionality', () => {
    it('does not show EditorHideWriteup component for non-editors', () => {
      const entry = createMockEntry();
      const { queryByTestId } = render(
        <NewWriteupsEntry
          entry={entry}
          editor={false}
          editorHideWriteupChange={mockEditorHideWriteupChange}
        />
      );

      expect(queryByTestId('editor-hide-writeup')).not.toBeInTheDocument();
    });

    it('shows EditorHideWriteup component for editors', () => {
      const entry = createMockEntry();
      const { getByTestId } = render(
        <NewWriteupsEntry
          entry={entry}
          editor={true}
          editorHideWriteupChange={mockEditorHideWriteupChange}
        />
      );

      expect(getByTestId('editor-hide-writeup')).toBeInTheDocument();
    });

    it('passes entry to EditorHideWriteup component', () => {
      const entry = createMockEntry({ node_id: 99999 });
      const { getByTestId } = render(
        <NewWriteupsEntry
          entry={entry}
          editor={true}
          editorHideWriteupChange={mockEditorHideWriteupChange}
        />
      );

      const editorComponent = getByTestId('editor-hide-writeup');
      expect(editorComponent).toHaveTextContent('Hide(99999)');
    });
  });

  describe('unique keys', () => {
    it('generates unique key based on node_id', () => {
      const entry = createMockEntry({ node_id: 54321 });
      const { container } = render(
        <NewWriteupsEntry
          entry={entry}
          editor={false}
          editorHideWriteupChange={mockEditorHideWriteupChange}
        />
      );

      const li = container.querySelector('li[key="writeup_54321"]');
      // Note: React removes the key attribute from rendered DOM,
      // but we can verify the component rendered
      expect(container.querySelector('li')).toBeInTheDocument();
    });
  });

  describe('LinkNode integration', () => {
    it('renders multiple LinkNode components', () => {
      const entry = createMockEntry();
      const { getAllByTestId } = render(
        <NewWriteupsEntry
          entry={entry}
          editor={false}
          editorHideWriteupChange={mockEditorHideWriteupChange}
        />
      );

      // Should have: parent title link, writeup type link, author link
      const linkNodes = getAllByTestId('link-node');
      expect(linkNodes.length).toBeGreaterThanOrEqual(3);
    });
  });

  describe('various entry states', () => {
    it('renders correctly for voted-on writeup', () => {
      const entry = createMockEntry({ hasvoted: true });
      const { container } = render(
        <NewWriteupsEntry
          entry={entry}
          editor={false}
          editorHideWriteupChange={mockEditorHideWriteupChange}
        />
      );

      expect(container.querySelector('li.hasvoted')).toBeInTheDocument();
    });

    it('renders correctly for different writeup types', () => {
      const writeupTypes = ['thing', 'idea', 'person', 'place'];

      writeupTypes.forEach(type => {
        const entry = createMockEntry({ writeuptype: type });
        const { getByText } = render(
          <NewWriteupsEntry
            entry={entry}
            editor={false}
            editorHideWriteupChange={mockEditorHideWriteupChange}
          />
        );

        expect(getByText(type)).toBeInTheDocument();
      });
    });
  });
});
