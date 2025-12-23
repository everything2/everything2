/**
 * Report a client-side error to the server for logging
 *
 * This utility sends error details to /api/client_errors for centralized
 * logging in CloudWatch (production) or devLog (development).
 *
 * Usage:
 *   // For API errors
 *   reportClientError('api_error', 'Failed to save draft', {
 *     url: window.location.href,
 *     action: 'saving draft',
 *     request_url: '/api/drafts',
 *     response_status: 500,
 *     response_body: 'Internal server error'
 *   });
 *
 *   // For JavaScript errors
 *   reportClientError('js_error', error.message, {
 *     url: window.location.href,
 *     action: 'rendering component'
 *   }, error.stack);
 *
 *   // For network errors
 *   reportClientError('network_error', 'Request timed out', {
 *     url: window.location.href,
 *     request_url: '/api/chatter'
 *   });
 */

// Debounce to prevent flooding the server with repeated errors
const recentErrors = new Set();
const DEBOUNCE_MS = 5000; // Don't report the same error within 5 seconds

/**
 * Extract relevant page state from window.e2 for debugging
 * Excludes large content fields to keep payload size reasonable
 */
const getE2PageState = () => {
  if (typeof window === 'undefined' || !window.e2) {
    return null;
  }

  try {
    const e2 = window.e2;

    // Extract user info (safe subset)
    const user = e2.user ? {
      node_id: e2.user.node_id,
      title: e2.user.title,
      guest: e2.user.guest
    } : null;

    // Extract content data (exclude large text fields)
    let contentData = null;
    if (e2.contentData) {
      contentData = {
        type: e2.contentData.type,
        node_id: e2.contentData.node_id,
        title: e2.contentData.title
      };

      // Include writeup info if present
      if (e2.contentData.writeups) {
        contentData.writeup_count = e2.contentData.writeups.length;
      }

      // Include draft info if present
      if (e2.contentData.draft_id) {
        contentData.draft_id = e2.contentData.draft_id;
      }

      // Include error info from page if present
      if (e2.contentData.error) {
        contentData.error = e2.contentData.error;
      }
    }

    return {
      user,
      contentData,
      reactPageMode: e2.reactPageMode,
      // Include any error state that might be set
      pageError: e2.pageError || null
    };
  } catch (err) {
    // Don't let state extraction cause errors
    return { extraction_error: err.message };
  }
};

/**
 * Report a client-side error to the server
 *
 * @param {string} errorType - Type of error: 'api_error', 'js_error', 'network_error'
 * @param {string} message - Error message
 * @param {Object} context - Additional context about the error
 * @param {string} stack - JavaScript stack trace (optional)
 * @returns {Promise<boolean>} - True if error was reported, false if debounced
 */
export const reportClientError = async (errorType, message, context = {}, stack = null) => {
  // Create a unique key for debouncing
  const errorKey = `${errorType}:${message}:${context.request_url || context.url || ''}`;

  if (recentErrors.has(errorKey)) {
    return false; // Skip duplicate error within debounce window
  }

  // Add to debounce set and remove after timeout
  recentErrors.add(errorKey);
  setTimeout(() => recentErrors.delete(errorKey), DEBOUNCE_MS);

  try {
    // Get page state for debugging
    const pageState = getE2PageState();

    const payload = {
      error_type: errorType,
      message: String(message).substring(0, 2000), // Truncate long messages
      context: {
        url: window.location.href,
        ...context,
        // Include e2 page state for debugging
        page_state: pageState
      },
      user_agent: navigator.userAgent
    };

    // Use provided stack, or capture current stack if none provided
    if (stack) {
      payload.stack = String(stack).substring(0, 4000);
    } else {
      // Capture current call stack for context
      try {
        const stackCapture = new Error('Stack capture');
        // Remove first two lines (Error message and this function)
        const lines = stackCapture.stack.split('\n').slice(2);
        payload.stack = lines.join('\n').substring(0, 4000);
      } catch {
        // Stack capture not available
      }
    }

    // Use sendBeacon if available for better reliability on page unload
    // Fall back to fetch for normal cases
    const body = JSON.stringify(payload);

    if (document.visibilityState === 'hidden' && navigator.sendBeacon) {
      navigator.sendBeacon('/api/client_errors', body);
    } else {
      await fetch('/api/client_errors', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body,
        credentials: 'same-origin',
        // Don't wait for response - fire and forget
        keepalive: true
      });
    }

    return true;
  } catch (err) {
    // Don't let error reporting cause additional errors
    console.error('Failed to report client error:', err);
    return false;
  }
};

/**
 * Wrap a fetch call with automatic error reporting
 *
 * @param {string} url - The URL to fetch
 * @param {Object} options - Fetch options
 * @param {string} action - Description of what the user was doing
 * @returns {Promise<Response>} - The fetch response
 */
export const fetchWithErrorReporting = async (url, options = {}, action = 'making request') => {
  try {
    const response = await fetch(url, options);

    if (!response.ok) {
      // Report non-OK responses
      let responseBody = '';
      try {
        responseBody = await response.clone().text();
        responseBody = responseBody.substring(0, 500); // Truncate
      } catch {
        responseBody = '(could not read response body)';
      }

      reportClientError('api_error', `HTTP ${response.status}: ${response.statusText}`, {
        action,
        request_url: url,
        request_method: options.method || 'GET',
        response_status: response.status,
        response_body: responseBody
      });
    }

    return response;
  } catch (err) {
    // Report network errors
    reportClientError('network_error', err.message, {
      action,
      request_url: url,
      request_method: options.method || 'GET'
    }, err.stack);

    throw err;
  }
};

/**
 * Set up global error handlers for uncaught errors
 * Call this once at app startup
 */
export const setupGlobalErrorHandlers = () => {
  // Expose reportClientError globally for testing and debugging
  if (typeof window !== 'undefined') {
    window.reportClientError = reportClientError;
  }

  // Catch unhandled promise rejections
  window.addEventListener('unhandledrejection', (event) => {
    const error = event.reason;
    const message = error?.message || String(error);
    const stack = error?.stack || null;

    reportClientError('js_error', `Unhandled rejection: ${message}`, {
      action: 'unhandled promise rejection'
    }, stack);
  });

  // Catch global errors
  window.addEventListener('error', (event) => {
    // Don't report errors from cross-origin scripts (like ad networks)
    if (event.filename && !event.filename.includes(window.location.origin)) {
      return;
    }

    reportClientError('js_error', event.message, {
      action: 'global error',
      source_file: event.filename,
      line: event.lineno,
      column: event.colno
    }, event.error?.stack);
  });
};

export default reportClientError;
