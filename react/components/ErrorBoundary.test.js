import React from 'react';
import { render } from '@testing-library/react';
import ErrorBoundary from './ErrorBoundary';

// Component that throws an error for testing
const ThrowError = ({ shouldThrow }) => {
  if (shouldThrow) {
    throw new Error('Test error');
  }
  return <div>No error</div>;
};

describe('ErrorBoundary Component', () => {
  // Suppress console.error for error boundary tests
  const originalError = console.error;
  beforeAll(() => {
    console.error = jest.fn();
  });

  afterAll(() => {
    console.error = originalError;
  });

  describe('normal rendering', () => {
    it('renders children when there is no error', () => {
      const { getByText } = render(
        <ErrorBoundary>
          <div>Test content</div>
        </ErrorBoundary>
      );

      expect(getByText('Test content')).toBeInTheDocument();
    });

    it('renders multiple children when there is no error', () => {
      const { getByText } = render(
        <ErrorBoundary>
          <div>First child</div>
          <div>Second child</div>
        </ErrorBoundary>
      );

      expect(getByText('First child')).toBeInTheDocument();
      expect(getByText('Second child')).toBeInTheDocument();
    });
  });

  describe('error handling', () => {
    it('renders error message when child component throws', () => {
      const { getByText, queryByText } = render(
        <ErrorBoundary>
          <ThrowError shouldThrow={true} />
        </ErrorBoundary>
      );

      expect(getByText('Client Error!')).toBeInTheDocument();
      expect(queryByText('No error')).not.toBeInTheDocument();
    });

    it('applies correct styling to error message', () => {
      const { container } = render(
        <ErrorBoundary>
          <ThrowError shouldThrow={true} />
        </ErrorBoundary>
      );

      const errorFont = container.querySelector('font[color="#CC0000"]');
      expect(errorFont).toBeInTheDocument();
      expect(errorFont.querySelector('b')).toBeInTheDocument();
    });

    it('catches errors from deeply nested components', () => {
      const { getByText } = render(
        <ErrorBoundary>
          <div>
            <div>
              <ThrowError shouldThrow={true} />
            </div>
          </div>
        </ErrorBoundary>
      );

      expect(getByText('Client Error!')).toBeInTheDocument();
    });
  });

  describe('error recovery', () => {
    it('shows error state once triggered', () => {
      const { rerender, getByText } = render(
        <ErrorBoundary>
          <ThrowError shouldThrow={true} />
        </ErrorBoundary>
      );

      expect(getByText('Client Error!')).toBeInTheDocument();

      // Even after rerender with non-throwing component, error state persists
      // (This is standard React ErrorBoundary behavior - needs remounting to reset)
      rerender(
        <ErrorBoundary>
          <ThrowError shouldThrow={false} />
        </ErrorBoundary>
      );

      expect(getByText('Client Error!')).toBeInTheDocument();
    });
  });
});
