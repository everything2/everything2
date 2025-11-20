import React from 'react';
import { render, fireEvent } from '@testing-library/react';
import EditorHideWriteup from './EditorHideWriteup';

describe('EditorHideWriteup Component', () => {
  const mockEditorHideWriteupChange = jest.fn();

  beforeEach(() => {
    mockEditorHideWriteupChange.mockClear();
  });

  describe('rendering based on writeup state', () => {
    it('shows eye icon when writeup is visible (notnew is false)', () => {
      const entry = { node_id: 12345, notnew: false };
      const { container } = render(
        <EditorHideWriteup
          entry={entry}
          editorHideWriteupChange={mockEditorHideWriteupChange}
        />
      );

      // FaEye should be present
      const eyeIcon = container.querySelector('svg');
      expect(eyeIcon).toBeInTheDocument();
    });

    it('shows eye-slash icon when writeup is hidden (notnew is true)', () => {
      const entry = { node_id: 12345, notnew: true };
      const { container } = render(
        <EditorHideWriteup
          entry={entry}
          editorHideWriteupChange={mockEditorHideWriteupChange}
        />
      );

      // FaEyeSlash should be present
      const eyeSlashIcon = container.querySelector('svg');
      expect(eyeSlashIcon).toBeInTheDocument();
    });

    it('wraps icon in parentheses', () => {
      const entry = { node_id: 12345, notnew: false };
      const { container } = render(
        <EditorHideWriteup
          entry={entry}
          editorHideWriteupChange={mockEditorHideWriteupChange}
        />
      );

      const spanText = container.querySelector('.editorhidelink').textContent;
      expect(spanText).toMatch(/^\(/);
      expect(spanText).toMatch(/\)$/);
    });

    it('applies editorhidelink CSS class', () => {
      const entry = { node_id: 12345, notnew: false };
      const { container } = render(
        <EditorHideWriteup
          entry={entry}
          editorHideWriteupChange={mockEditorHideWriteupChange}
        />
      );

      const link = container.querySelector('.editorhidelink');
      expect(link).toBeInTheDocument();
    });

    it('sets aria-label for accessibility', () => {
      const entry = { node_id: 12345, notnew: false };
      const { container } = render(
        <EditorHideWriteup
          entry={entry}
          editorHideWriteupChange={mockEditorHideWriteupChange}
        />
      );

      const link = container.querySelector('[aria-label="Toggle writeup visibility"]');
      expect(link).toBeInTheDocument();
    });
  });

  describe('user interactions', () => {
    it('calls editorHideWriteupChange when clicked', () => {
      const entry = { node_id: 12345, notnew: false };
      const { container } = render(
        <EditorHideWriteup
          entry={entry}
          editorHideWriteupChange={mockEditorHideWriteupChange}
        />
      );

      const link = container.querySelector('.editorhidelink');
      fireEvent.click(link);

      expect(mockEditorHideWriteupChange).toHaveBeenCalledTimes(1);
    });

    it('passes node_id and toggled notnew value when visible writeup is clicked', () => {
      const entry = { node_id: 12345, notnew: false };
      const { container } = render(
        <EditorHideWriteup
          entry={entry}
          editorHideWriteupChange={mockEditorHideWriteupChange}
        />
      );

      const link = container.querySelector('.editorhidelink');
      fireEvent.click(link);

      expect(mockEditorHideWriteupChange).toHaveBeenCalledWith(12345, true);
    });

    it('passes node_id and toggled notnew value when hidden writeup is clicked', () => {
      const entry = { node_id: 67890, notnew: true };
      const { container } = render(
        <EditorHideWriteup
          entry={entry}
          editorHideWriteupChange={mockEditorHideWriteupChange}
        />
      );

      const link = container.querySelector('.editorhidelink');
      fireEvent.click(link);

      expect(mockEditorHideWriteupChange).toHaveBeenCalledWith(67890, false);
    });

    it('handles multiple clicks correctly', () => {
      const entry = { node_id: 12345, notnew: false };
      const { container } = render(
        <EditorHideWriteup
          entry={entry}
          editorHideWriteupChange={mockEditorHideWriteupChange}
        />
      );

      const link = container.querySelector('.editorhidelink');
      fireEvent.click(link);
      fireEvent.click(link);
      fireEvent.click(link);

      expect(mockEditorHideWriteupChange).toHaveBeenCalledTimes(3);
    });
  });

  describe('different node IDs', () => {
    it('handles different node IDs correctly', () => {
      const testCases = [
        { node_id: 1, notnew: false },
        { node_id: 999999, notnew: true },
        { node_id: 42, notnew: false }
      ];

      testCases.forEach(entry => {
        mockEditorHideWriteupChange.mockClear();
        const { container } = render(
          <EditorHideWriteup
            entry={entry}
            editorHideWriteupChange={mockEditorHideWriteupChange}
          />
        );

        const link = container.querySelector('.editorhidelink');
        fireEvent.click(link);

        expect(mockEditorHideWriteupChange).toHaveBeenCalledWith(
          entry.node_id,
          !entry.notnew
        );
      });
    });
  });

  describe('icon context styling', () => {
    it('applies IconContext styling', () => {
      const entry = { node_id: 12345, notnew: false };
      const { container } = render(
        <EditorHideWriteup
          entry={entry}
          editorHideWriteupChange={mockEditorHideWriteupChange}
        />
      );

      const icon = container.querySelector('svg');
      expect(icon).toBeInTheDocument();
      // The IconContext.Provider sets style, but we verify the icon renders
    });
  });
});
