// Jest setup file - runs before all tests
import '@testing-library/jest-dom';

// Mock window.matchMedia for responsive hooks
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: jest.fn().mockImplementation(query => ({
    matches: false, // Default to desktop view in tests
    media: query,
    onchange: null,
    addListener: jest.fn(), // deprecated
    removeListener: jest.fn(), // deprecated
    addEventListener: jest.fn(),
    removeEventListener: jest.fn(),
    dispatchEvent: jest.fn(),
  })),
});

// Mock global e2 object that's normally provided by the server
global.e2 = {
  user: {
    user_id: 0,
    username: 'Guest',
    is_guest: true,
  },
  node: {
    node_id: 0,
    title: 'Test Node',
    type: 'test',
  },
  lastnode_id: 0,
  collapsedNodelets: '',
};

// Mock window.location if needed
delete window.location;
window.location = {
  href: 'http://localhost',
  pathname: '/',
  search: '',
  hash: '',
};

// Suppress console errors in tests (optional)
const originalError = console.error;
beforeAll(() => {
  console.error = (...args) => {
    if (
      typeof args[0] === 'string' &&
      args[0].includes('Warning: ReactDOM.render')
    ) {
      return;
    }
    originalError.call(console, ...args);
  };
});

afterAll(() => {
  console.error = originalError;
});
