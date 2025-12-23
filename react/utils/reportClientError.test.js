/**
 * @jest-environment jsdom
 */

import {
  reportClientError,
  fetchWithErrorReporting,
  setupGlobalErrorHandlers
} from './reportClientError';

// Mock fetch globally
global.fetch = jest.fn();

// Mock navigator.sendBeacon
global.navigator.sendBeacon = jest.fn();

describe('reportClientError', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    fetch.mockResolvedValue({ ok: true });

    // Set up window.e2 for page state extraction
    window.e2 = {
      user: {
        node_id: 123,
        title: 'testuser',
        guest: false
      },
      contentData: {
        type: 'e2node',
        node_id: 456,
        title: 'Test Node',
        writeups: [{ id: 1 }, { id: 2 }]
      },
      reactPageMode: true
    };
  });

  afterEach(() => {
    delete window.e2;
  });

  it('sends error report to /api/client_errors', async () => {
    await reportClientError('js_error', 'Test error message', {
      action: 'testing'
    });

    expect(fetch).toHaveBeenCalledWith(
      '/api/client_errors',
      expect.objectContaining({
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'same-origin'
      })
    );
  });

  it('includes error type and message in payload', async () => {
    await reportClientError('api_error', 'API failed', { action: 'fetching' });

    const call = fetch.mock.calls[0];
    const body = JSON.parse(call[1].body);

    expect(body.error_type).toBe('api_error');
    expect(body.message).toBe('API failed');
  });

  it('includes page state from window.e2', async () => {
    await reportClientError('js_error', 'Test error');

    const call = fetch.mock.calls[0];
    const body = JSON.parse(call[1].body);

    expect(body.context.page_state).toBeDefined();
    expect(body.context.page_state.user.node_id).toBe(123);
    expect(body.context.page_state.user.title).toBe('testuser');
    expect(body.context.page_state.contentData.type).toBe('e2node');
    expect(body.context.page_state.contentData.writeup_count).toBe(2);
    expect(body.context.page_state.reactPageMode).toBe(true);
  });

  it('handles missing window.e2 gracefully', async () => {
    delete window.e2;

    await reportClientError('js_error', 'Test error missing e2');

    const call = fetch.mock.calls[0];
    const body = JSON.parse(call[1].body);

    expect(body.context.page_state).toBeNull();
  });

  it('includes stack trace when provided', async () => {
    const stack = 'Error: test\n    at foo (test.js:10:5)\n    at bar (test.js:20:3)';
    await reportClientError('js_error', 'Test error with stack', {}, stack);

    const call = fetch.mock.calls[0];
    const body = JSON.parse(call[1].body);

    expect(body.stack).toBe(stack);
  });

  it('captures call stack when not provided', async () => {
    await reportClientError('js_error', 'Test error auto stack');

    const call = fetch.mock.calls[0];
    const body = JSON.parse(call[1].body);

    // Should have a stack trace (auto-captured)
    expect(body.stack).toBeDefined();
    expect(body.stack.length).toBeGreaterThan(0);
  });

  it('includes user agent', async () => {
    await reportClientError('js_error', 'Test error user agent');

    const call = fetch.mock.calls[0];
    const body = JSON.parse(call[1].body);

    expect(body.user_agent).toBe(navigator.userAgent);
  });

  it('includes URL in context', async () => {
    await reportClientError('js_error', 'Test error url context');

    const call = fetch.mock.calls[0];
    const body = JSON.parse(call[1].body);

    expect(body.context.url).toBe(window.location.href);
  });

  it('truncates long messages', async () => {
    const longMessage = 'x'.repeat(3000);
    await reportClientError('js_error', longMessage);

    const call = fetch.mock.calls[0];
    const body = JSON.parse(call[1].body);

    expect(body.message.length).toBe(2000);
  });

  it('truncates long stack traces', async () => {
    const longStack = 'x'.repeat(5000);
    await reportClientError('js_error', 'Error', {}, longStack);

    const call = fetch.mock.calls[0];
    const body = JSON.parse(call[1].body);

    expect(body.stack.length).toBe(4000);
  });

  it('debounces duplicate errors', async () => {
    await reportClientError('js_error', 'Same error', { request_url: '/api/test' });
    await reportClientError('js_error', 'Same error', { request_url: '/api/test' });
    await reportClientError('js_error', 'Same error', { request_url: '/api/test' });

    // Should only call fetch once due to debouncing
    expect(fetch).toHaveBeenCalledTimes(1);
  });

  it('does not debounce different errors', async () => {
    await reportClientError('js_error', 'Error 1');
    await reportClientError('js_error', 'Error 2');
    await reportClientError('api_error', 'Error 3');

    expect(fetch).toHaveBeenCalledTimes(3);
  });

  it('uses sendBeacon when page is hidden', async () => {
    Object.defineProperty(document, 'visibilityState', {
      value: 'hidden',
      configurable: true
    });

    await reportClientError('js_error', 'Test error sendBeacon hidden');

    expect(navigator.sendBeacon).toHaveBeenCalledWith(
      '/api/client_errors',
      expect.any(String)
    );
    expect(fetch).not.toHaveBeenCalled();

    // Reset visibility state
    Object.defineProperty(document, 'visibilityState', {
      value: 'visible',
      configurable: true
    });
  });
});

describe('fetchWithErrorReporting', () => {
  let testCounter = 0;

  beforeEach(() => {
    jest.clearAllMocks();
    fetch.mockResolvedValue({ ok: true }); // Default for error reporting calls
    window.e2 = { user: { node_id: 1, guest: false } };
    testCounter++;
  });

  afterEach(() => {
    delete window.e2;
  });

  it('returns response for successful requests', async () => {
    const mockResponse = {
      ok: true,
      status: 200,
      json: () => Promise.resolve({ success: true })
    };
    fetch.mockResolvedValueOnce(mockResponse);

    const response = await fetchWithErrorReporting('/api/test-success');

    expect(response).toBe(mockResponse);
  });

  it('reports error for non-OK responses', async () => {
    const uniqueUrl = `/api/protected-${testCounter}-${Date.now()}`;
    const mockResponse = {
      ok: false,
      status: 403,
      statusText: 'Forbidden',
      clone: () => ({
        text: () => Promise.resolve('Access denied')
      })
    };

    // First call returns error response, subsequent calls return OK (for error reporting)
    fetch.mockResolvedValueOnce(mockResponse);

    await fetchWithErrorReporting(uniqueUrl, { method: 'GET' }, 'accessing protected resource');

    // Wait for async error reporting to complete
    await new Promise(resolve => setTimeout(resolve, 50));

    // Should have called fetch twice: once for the request, once for error report
    expect(fetch).toHaveBeenCalledTimes(2);
    const errorCall = fetch.mock.calls[1];
    const body = JSON.parse(errorCall[1].body);

    expect(body.error_type).toBe('api_error');
    expect(body.message).toContain('403');
    expect(body.context.action).toBe('accessing protected resource');
    expect(body.context.response_status).toBe(403);
  });

  it('reports network errors', async () => {
    const uniqueUrl = `/api/network-${testCounter}-${Date.now()}`;
    const networkError = new Error(`Network failure ${testCounter}`);

    // First call rejects, subsequent calls resolve (for error reporting)
    fetch.mockRejectedValueOnce(networkError);

    await expect(
      fetchWithErrorReporting(uniqueUrl, {}, 'testing network')
    ).rejects.toThrow(`Network failure ${testCounter}`);

    // Wait for async error reporting to complete
    await new Promise(resolve => setTimeout(resolve, 50));

    // Error should have been reported
    expect(fetch).toHaveBeenCalledTimes(2);
    const errorCall = fetch.mock.calls[1];
    const body = JSON.parse(errorCall[1].body);

    expect(body.error_type).toBe('network_error');
    expect(body.message).toBe(`Network failure ${testCounter}`);
  });
});

describe('setupGlobalErrorHandlers', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    fetch.mockResolvedValue({ ok: true });
  });

  it('exposes reportClientError on window', () => {
    setupGlobalErrorHandlers();
    expect(window.reportClientError).toBe(reportClientError);
  });

  it('sets up unhandledrejection listener', () => {
    const addEventListenerSpy = jest.spyOn(window, 'addEventListener');

    setupGlobalErrorHandlers();

    expect(addEventListenerSpy).toHaveBeenCalledWith(
      'unhandledrejection',
      expect.any(Function)
    );

    addEventListenerSpy.mockRestore();
  });

  it('sets up error listener', () => {
    const addEventListenerSpy = jest.spyOn(window, 'addEventListener');

    setupGlobalErrorHandlers();

    expect(addEventListenerSpy).toHaveBeenCalledWith(
      'error',
      expect.any(Function)
    );

    addEventListenerSpy.mockRestore();
  });
});
