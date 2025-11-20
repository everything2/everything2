import React from 'react';
import { render, fireEvent } from '@testing-library/react';
import NewWriteupsFilter from './NewWriteupsFilter';

describe('NewWriteupsFilter Component', () => {
  const mockNewWriteupsChange = jest.fn();
  const mockNoJunkChange = jest.fn();

  beforeEach(() => {
    mockNewWriteupsChange.mockClear();
    mockNoJunkChange.mockClear();
  });

  describe('guest user behavior', () => {
    it('renders nothing for guest users', () => {
      const guestUser = { guest: true, editor: false };
      const { container } = render(
        <NewWriteupsFilter
          limit={10}
          newWriteupsChange={mockNewWriteupsChange}
          noJunk={false}
          noJunkChange={mockNoJunkChange}
          user={guestUser}
        />
      );

      expect(container.querySelector('select')).not.toBeInTheDocument();
      expect(container.querySelector('input')).not.toBeInTheDocument();
    });
  });

  describe('logged-in non-editor user', () => {
    const regularUser = { guest: false, editor: false };

    it('renders dropdown for logged-in user', () => {
      const { container } = render(
        <NewWriteupsFilter
          limit={10}
          newWriteupsChange={mockNewWriteupsChange}
          noJunk={false}
          noJunkChange={mockNoJunkChange}
          user={regularUser}
        />
      );

      const select = container.querySelector('select');
      expect(select).toBeInTheDocument();
    });

    it('does not show junk filter checkbox for non-editors', () => {
      const { queryByText, container } = render(
        <NewWriteupsFilter
          limit={10}
          newWriteupsChange={mockNewWriteupsChange}
          noJunk={false}
          noJunkChange={mockNoJunkChange}
          user={regularUser}
        />
      );

      expect(queryByText('No junk')).not.toBeInTheDocument();
      expect(container.querySelector('input[type="checkbox"]')).not.toBeInTheDocument();
    });

    it('renders all count options (1, 5, 10, 15, 20, 25, 30, 40)', () => {
      const { container } = render(
        <NewWriteupsFilter
          limit={10}
          newWriteupsChange={mockNewWriteupsChange}
          noJunk={false}
          noJunkChange={mockNoJunkChange}
          user={regularUser}
        />
      );

      const options = container.querySelectorAll('option');
      expect(options).toHaveLength(8);
      expect(Array.from(options).map(opt => opt.value)).toEqual([
        '1', '5', '10', '15', '20', '25', '30', '40'
      ]);
    });

    it('sets correct selected value in dropdown', () => {
      const { container } = render(
        <NewWriteupsFilter
          limit={20}
          newWriteupsChange={mockNewWriteupsChange}
          noJunk={false}
          noJunkChange={mockNoJunkChange}
          user={regularUser}
        />
      );

      const select = container.querySelector('select');
      expect(select.value).toBe('20');
    });

    it('calls newWriteupsChange when dropdown value changes', () => {
      const { container } = render(
        <NewWriteupsFilter
          limit={10}
          newWriteupsChange={mockNewWriteupsChange}
          noJunk={false}
          noJunkChange={mockNoJunkChange}
          user={regularUser}
        />
      );

      const select = container.querySelector('select');
      fireEvent.change(select, { target: { value: '25' } });

      expect(mockNewWriteupsChange).toHaveBeenCalledTimes(1);
      expect(mockNewWriteupsChange).toHaveBeenCalledWith('25');
    });
  });

  describe('editor user', () => {
    const editorUser = { guest: false, editor: true };

    it('renders dropdown for editors', () => {
      const { container } = render(
        <NewWriteupsFilter
          limit={10}
          newWriteupsChange={mockNewWriteupsChange}
          noJunk={false}
          noJunkChange={mockNoJunkChange}
          user={editorUser}
        />
      );

      const select = container.querySelector('select');
      expect(select).toBeInTheDocument();
    });

    it('shows junk filter checkbox for editors', () => {
      const { getByText, container } = render(
        <NewWriteupsFilter
          limit={10}
          newWriteupsChange={mockNewWriteupsChange}
          noJunk={false}
          noJunkChange={mockNoJunkChange}
          user={editorUser}
        />
      );

      expect(getByText('No junk')).toBeInTheDocument();
      expect(container.querySelector('input[type="checkbox"]')).toBeInTheDocument();
    });

    it('checkbox is unchecked when noJunk is false', () => {
      const { container } = render(
        <NewWriteupsFilter
          limit={10}
          newWriteupsChange={mockNewWriteupsChange}
          noJunk={false}
          noJunkChange={mockNoJunkChange}
          user={editorUser}
        />
      );

      const checkbox = container.querySelector('input[type="checkbox"]');
      expect(checkbox.checked).toBe(false);
    });

    it('checkbox is checked when noJunk is true', () => {
      const { container } = render(
        <NewWriteupsFilter
          limit={10}
          newWriteupsChange={mockNewWriteupsChange}
          noJunk={true}
          noJunkChange={mockNoJunkChange}
          user={editorUser}
        />
      );

      const checkbox = container.querySelector('input[type="checkbox"]');
      expect(checkbox.checked).toBe(true);
    });

    it('calls noJunkChange when checkbox is toggled', () => {
      const { container } = render(
        <NewWriteupsFilter
          limit={10}
          newWriteupsChange={mockNewWriteupsChange}
          noJunk={false}
          noJunkChange={mockNoJunkChange}
          user={editorUser}
        />
      );

      const checkbox = container.querySelector('input[type="checkbox"]');
      fireEvent.click(checkbox);

      expect(mockNoJunkChange).toHaveBeenCalledTimes(1);
      expect(mockNoJunkChange).toHaveBeenCalledWith(true);
    });

    it('calls noJunkChange with false when unchecking', () => {
      const { container } = render(
        <NewWriteupsFilter
          limit={10}
          newWriteupsChange={mockNewWriteupsChange}
          noJunk={true}
          noJunkChange={mockNoJunkChange}
          user={editorUser}
        />
      );

      const checkbox = container.querySelector('input[type="checkbox"]');
      fireEvent.click(checkbox);

      expect(mockNoJunkChange).toHaveBeenCalledWith(false);
    });
  });

  describe('option keys', () => {
    it('generates unique keys for each option', () => {
      const regularUser = { guest: false, editor: false };
      const { container } = render(
        <NewWriteupsFilter
          limit={10}
          newWriteupsChange={mockNewWriteupsChange}
          noJunk={false}
          noJunkChange={mockNoJunkChange}
          user={regularUser}
        />
      );

      const options = container.querySelectorAll('option');
      const keys = Array.from(options).map(opt => opt.getAttribute('value'));
      const uniqueKeys = new Set(keys);

      expect(uniqueKeys.size).toBe(keys.length);
    });
  });
});
