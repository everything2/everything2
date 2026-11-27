# React Testing Guide

This document describes the testing framework and best practices for testing React components in Everything2.

**Last verified: 2026-11-16** — Jest 29 + jsdom, React Testing Library 14 (React 18.3). ~313 `*.test.js` files under `react/` (recount: `find react -name '*.test.js' | wc -l`).

## Table of Contents

- [Overview](#overview)
- [Getting Started](#getting-started)
- [Running Tests](#running-tests)
- [Writing Tests](#writing-tests)
- [Test Utilities](#test-utilities)
- [Best Practices](#best-practices)
- [Examples](#examples)

## Overview

The React test framework uses:

- **Jest** - Test runner and assertion library
- **React Testing Library** - Component testing utilities
- **@testing-library/jest-dom** - Custom Jest matchers for DOM assertions
- **@testing-library/user-event** - User interaction simulation

## Getting Started

### Installation

Install test dependencies:

```bash
npm install
```

### Project Structure

```
react/
├── components/
│   ├── LinkNode.js / LinkNode.test.js   # Tests are co-located: Foo.js + Foo.test.js
│   ├── Documents/                # Page-level Document components (bulk of the tests)
│   ├── Nodelets/, Editor/, Layout/, MasterControl/, ...
├── hooks/                        # Custom hooks (+ *.test.js)
├── utils/                        # linkParser, dateFormat, ... (+ *.test.js)
├── __fixtures__/pagestate/       # Captured /api/pagestate payloads (JSON)
├── __mocks__/
│   ├── styleMock.js              # CSS import mocks
│   └── fileMock.js               # Asset import mocks
├── test-setup.js                 # Jest setup file (matchMedia, scrollIntoView, global e2 stubs)
└── test-utils.js                 # Reusable test utilities
```

Jest config lives in `jest.config.js` (roots: `react/`, setup: `react/test-setup.js`); Babel in `babel.config.js`.

## Running Tests

### Available Commands

```bash
# Run all tests
npm test

# Run tests in watch mode (re-runs on file changes)
npm run test:watch

# Run tests with coverage report
npm run test:coverage

# Run tests with verbose output
npm run test:verbose
```

### Development Build Integration

`./docker/devbuild.sh` (without `--skip-tests`) runs `tools/parallel-test.sh`, which runs smoke + Perl tests (`t/run.pl` in the container) alongside the Jest suite (`npm test` on the host). On a failure it lists the failed test files, each section's Test Summary Report and the failed assertions, pulled from the whole log (`t/run.pl` runs its serial section first, so a serial failure is far above the end of the output). The full output of each suite stays in `/tmp/e2-test-output/perl.log` and `react.log` after the run (overwritten by the next one; set `E2_TEST_OUTPUT_DIR` to keep it elsewhere). Standalone runners:

```bash
# Re-run the full parallel suite (smoke + Perl + React)
./tools/parallel-test.sh

# Alternative runner with per-language flags
./docker/run-tests.sh               # Perl + React
./docker/run-tests.sh --react-only  # Jest only (with --ci --coverage)
./docker/run-tests.sh --perl-only

# Browser end-to-end tests (Playwright, tests/e2e/, dev only)
npm run test:e2e
```

### Running Specific Tests

```bash
# Run tests in a specific file
npm test TimeDistance.test.js

# Run tests matching a pattern
npm test -- --testNamePattern="displays hours"

# Run tests for changed files only
npm test -- --onlyChanged
```

## Writing Tests

### Basic Test Structure

```javascript
import React from 'react';
import { render, screen } from '@testing-library/react';
import MyComponent from './MyComponent';

describe('MyComponent', () => {
  it('renders correctly', () => {
    render(<MyComponent />);
    expect(screen.getByText('Hello')).toBeInTheDocument();
  });
});
```

### Testing User Interactions

```javascript
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

it('handles button click', async () => {
  const user = userEvent.setup();
  render(<MyButton />);

  const button = screen.getByRole('button');
  await user.click(button);

  expect(screen.getByText('Clicked!')).toBeInTheDocument();
});
```

### Testing Async Behavior

```javascript
import { render, screen, waitFor } from '@testing-library/react';

it('loads data asynchronously', async () => {
  render(<AsyncComponent />);

  await waitFor(() => {
    expect(screen.getByText('Loaded Data')).toBeInTheDocument();
  });
});
```

### Testing with E2 Context

Use the `renderWithProviders` utility to test components that depend on the global `e2` object:

```javascript
import { renderWithProviders, createMockUser } from '../test-utils';

it('displays user information', () => {
  renderWithProviders(<UserProfile />, {
    e2Override: {
      user: createMockUser({ username: 'testuser' })
    }
  });

  expect(screen.getByText('testuser')).toBeInTheDocument();
});
```

### Fixture-Backed Document Tests

Many `Documents/*.test.js` files mount the component against a real, captured `/api/pagestate` payload from `react/__fixtures__/pagestate/` (pattern: `Decloaker.test.js`). Re-capture fixtures after the pagestate contract changes with `tools/capture-pagestate-fixtures.sh [base_url] [node_id[:displaytype] ...]` (set `E2_LOGIN_USER`/`E2_LOGIN_PASS` for authed views).

For API-driven Documents, prefer the submit → result → error interaction pattern over render-only checks; templates: `Documents/TheOldHookedPole.test.js`, `Documents/EverythingsMostWanted.test.js`.

## Test Utilities

### Available Utilities

#### `renderWithProviders(ui, options)`
Renders a component with e2 context override:

```javascript
renderWithProviders(<MyComponent />, {
  e2Override: {
    user: createMockUser({ username: 'alice' })
  }
});
```

#### `createMockUser(overrides)`
Creates a mock user object:

```javascript
const user = createMockUser({
  username: 'testuser',
  level: 10
});
```

#### `createMockGuest()`
Creates a mock guest user:

```javascript
const guest = createMockGuest();
```

#### `createMockNode(overrides)`
Creates a mock node object:

```javascript
const node = createMockNode({
  title: 'Test Writeup',
  type: 'writeup'
});
```

#### `createMockE2Config(overrides)`
Creates a complete e2 config object:

```javascript
const e2 = createMockE2Config({
  user: createMockUser(),
  node: createMockNode()
});
```

#### `mockFetch(status, responseData)`
Mocks the global fetch API:

```javascript
mockFetch(200, { data: 'test response' });
```

#### Portal Utilities

```javascript
// Create a portal container for testing portal components
const container = createPortalContainer('my-portal');

// Cleanup after test
cleanupPortalContainer('my-portal');
```

## Best Practices

### 1. Test User Behavior, Not Implementation

❌ **Don't do this:**
```javascript
expect(component.state.value).toBe('test');
```

✅ **Do this:**
```javascript
expect(screen.getByDisplayValue('test')).toBeInTheDocument();
```

### 2. Use Accessible Queries

Prefer queries in this order:
1. `getByRole` - Most accessible
2. `getByLabelText` - For form elements
3. `getByPlaceholderText` - For inputs
4. `getByText` - For non-interactive elements
5. `getByTestId` - Last resort

```javascript
// Good
const button = screen.getByRole('button', { name: /submit/i });

// Less ideal
const button = screen.getByTestId('submit-button');
```

### 3. Avoid Testing Implementation Details

❌ **Don't test:**
- Component state
- Internal methods
- Exact HTML structure

✅ **Do test:**
- Rendered output
- User interactions
- Accessibility
- Error states

### 4. Use Describe Blocks for Organization

```javascript
describe('MyComponent', () => {
  describe('rendering', () => {
    it('renders with default props', () => { ... });
    it('renders with custom props', () => { ... });
  });

  describe('user interactions', () => {
    it('handles click events', () => { ... });
    it('handles form submission', () => { ... });
  });

  describe('edge cases', () => {
    it('handles empty data', () => { ... });
    it('handles errors', () => { ... });
  });
});
```

### 5. Clean Up After Tests

```javascript
afterEach(() => {
  jest.clearAllMocks();
  // Cleanup any side effects
});
```

### 6. Test Accessibility

```javascript
it('is accessible', () => {
  const { container } = render(<MyComponent />);

  // Check for proper ARIA attributes
  expect(screen.getByRole('button')).toHaveAttribute('aria-label');

  // Check for keyboard navigation
  const input = screen.getByRole('textbox');
  expect(input).toHaveFocus();
});
```

## Examples

### Example 1: Simple Component Test

```javascript
// components/Greeting.js
export default function Greeting({ name }) {
  return <h1>Hello, {name}!</h1>;
}

// components/Greeting.test.js
import { render, screen } from '@testing-library/react';
import Greeting from './Greeting';

describe('Greeting', () => {
  it('displays greeting with name', () => {
    render(<Greeting name="Alice" />);
    expect(screen.getByText('Hello, Alice!')).toBeInTheDocument();
  });
});
```

### Example 2: Interactive Component Test

```javascript
// components/Counter.js
import { useState } from 'react';

export default function Counter() {
  const [count, setCount] = useState(0);

  return (
    <div>
      <p>Count: {count}</p>
      <button onClick={() => setCount(count + 1)}>Increment</button>
    </div>
  );
}

// components/Counter.test.js
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import Counter from './Counter';

describe('Counter', () => {
  it('increments count when button is clicked', async () => {
    const user = userEvent.setup();
    render(<Counter />);

    expect(screen.getByText('Count: 0')).toBeInTheDocument();

    const button = screen.getByRole('button', { name: /increment/i });
    await user.click(button);

    expect(screen.getByText('Count: 1')).toBeInTheDocument();
  });
});
```

### Example 3: Async Component Test

```javascript
// components/UserData.js
import { useState, useEffect } from 'react';

export default function UserData({ userId }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch(`/api/user/${userId}`)
      .then(res => res.json())
      .then(data => {
        setUser(data);
        setLoading(false);
      });
  }, [userId]);

  if (loading) return <div>Loading...</div>;
  return <div>Username: {user.username}</div>;
}

// components/UserData.test.js
import { render, screen, waitFor } from '@testing-library/react';
import { mockFetch } from '../test-utils';
import UserData from './UserData';

describe('UserData', () => {
  it('loads and displays user data', async () => {
    mockFetch(200, { username: 'alice' });

    render(<UserData userId={123} />);

    expect(screen.getByText('Loading...')).toBeInTheDocument();

    await waitFor(() => {
      expect(screen.getByText('Username: alice')).toBeInTheDocument();
    });
  });
});
```

### Example 4: Testing with E2 Context

```javascript
// components/UserGreeting.js
export default function UserGreeting() {
  const user = window.e2.user;

  if (user.is_guest) {
    return <div>Welcome, Guest!</div>;
  }

  return <div>Welcome back, {user.username}!</div>;
}

// components/UserGreeting.test.js
import { renderWithProviders, createMockUser, createMockGuest } from '../test-utils';
import { screen } from '@testing-library/react';
import UserGreeting from './UserGreeting';

describe('UserGreeting', () => {
  it('displays guest greeting for guest users', () => {
    renderWithProviders(<UserGreeting />, {
      e2Override: {
        user: createMockGuest()
      }
    });

    expect(screen.getByText('Welcome, Guest!')).toBeInTheDocument();
  });

  it('displays personalized greeting for logged-in users', () => {
    renderWithProviders(<UserGreeting />, {
      e2Override: {
        user: createMockUser({ username: 'alice' })
      }
    });

    expect(screen.getByText('Welcome back, alice!')).toBeInTheDocument();
  });
});
```

## Coverage Reports

After running `npm run test:coverage`, view the HTML coverage report:

```bash
open coverage/react/lcov-report/index.html
```

(`coverageDirectory` is `coverage/react`; a `json-summary` is written there too.) The enforced global thresholds in `jest.config.js` are low (10% lines/branches/statements, 5% functions) — they are a floor, not a target.

The coverage report shows:
- **Statements** - Individual executable statements
- **Branches** - If/else branches
- **Functions** - Function definitions
- **Lines** - Lines of code

Aim for at least 80% coverage for critical components.

## Continuous Integration

To run tests in CI/CD:

```bash
# Run tests once without watch mode
npm test -- --ci --coverage --maxWorkers=2
```

## Troubleshooting

### Common Issues

**Issue: "Cannot find module" errors**
- Ensure all dependencies are installed: `npm install`
- Check that imports use correct paths

**Issue: "window is not defined"**
- Ensure `testEnvironment: 'jsdom'` is set in jest.config.js
- Check that test-setup.js is being loaded

**Issue: Tests timeout**
- Increase timeout: `jest.setTimeout(10000)` in test file
- Check for unresolved promises or missing await

**Issue: "act(...)" warnings**
- Wrap state updates in `await waitFor(() => ...)`
- Use `userEvent` instead of `fireEvent` for interactions

## Additional Resources

- [Jest Documentation](https://jestjs.io/)
- [React Testing Library](https://testing-library.com/react)
- [Testing Library Queries Cheatsheet](https://testing-library.com/docs/queries/about)
- [Common Testing Mistakes](https://kentcdodds.com/blog/common-mistakes-with-react-testing-library)
