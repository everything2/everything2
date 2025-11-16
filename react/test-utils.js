import React from 'react';
import { render } from '@testing-library/react';

/**
 * Custom render function that wraps components with common providers
 * Extend this as needed when you add context providers, routers, etc.
 */
export function renderWithProviders(
  ui,
  {
    e2Override = {},
    ...renderOptions
  } = {}
) {
  // Merge e2 override with default global.e2
  const originalE2 = global.e2;
  global.e2 = {
    ...originalE2,
    ...e2Override,
  };

  const result = render(ui, renderOptions);

  // Cleanup: restore original e2
  global.e2 = originalE2;

  return result;
}

/**
 * Create a mock e2 user object
 */
export function createMockUser(overrides = {}) {
  return {
    user_id: 12345,
    username: 'testuser',
    is_guest: false,
    title: 'Test User',
    level: 5,
    ...overrides,
  };
}

/**
 * Create a mock e2 guest user object
 */
export function createMockGuest() {
  return {
    user_id: 0,
    username: 'Guest',
    is_guest: true,
    title: 'Guest User',
    level: 0,
  };
}

/**
 * Create a mock e2 node object
 */
export function createMockNode(overrides = {}) {
  return {
    node_id: 99999,
    title: 'Test Node',
    type: 'writeup',
    author_user: 12345,
    createtime: 1700000000,
    ...overrides,
  };
}

/**
 * Create a complete mock e2 config object
 */
export function createMockE2Config(overrides = {}) {
  return {
    user: createMockUser(),
    node: createMockNode(),
    lastnode_id: 0,
    collapsedNodelets: '',
    fxDuration: 200,
    autoChat: false,
    ...overrides,
  };
}

/**
 * Mock fetch for API testing
 * Usage: mockFetch(200, { data: 'test' })
 */
export function mockFetch(status = 200, responseData = {}) {
  global.fetch = jest.fn(() =>
    Promise.resolve({
      ok: status >= 200 && status < 300,
      status,
      json: () => Promise.resolve(responseData),
      text: () => Promise.resolve(JSON.stringify(responseData)),
    })
  );
  return global.fetch;
}

/**
 * Wait for async operations to complete
 * Useful for testing components with useEffect, async data loading, etc.
 */
export async function waitForAsync() {
  return new Promise(resolve => setTimeout(resolve, 0));
}

/**
 * Create a mock React portal container
 * Useful for testing components that use portals
 */
export function createPortalContainer(id = 'portal-root') {
  const container = document.createElement('div');
  container.setAttribute('id', id);
  document.body.appendChild(container);
  return container;
}

/**
 * Cleanup portal container
 */
export function cleanupPortalContainer(id = 'portal-root') {
  const container = document.getElementById(id);
  if (container) {
    document.body.removeChild(container);
  }
}

// Re-export everything from React Testing Library
export * from '@testing-library/react';
export { default as userEvent } from '@testing-library/user-event';
