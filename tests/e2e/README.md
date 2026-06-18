# Everything2 E2E Testing

## Current Status

The `.spec.js` files in this directory are the source of truth for what is covered — read them
directly rather than trusting a status snapshot here. As of 2026-06-15 there are **14 spec files**
(`ls tests/e2e/*.spec.js`). Run the suite (see "Running Tests" below) for the current pass/fail
picture.

## What Was Fixed

### 1. Login URL Correction
- **Problem**: Tests used `/login` which doesn't exist (404)
- **Solution**: E2 login is at `/title/login` OR via Sign In nodelet
- **Implemented**: Using Sign In nodelet from homepage (more convenient)

### 2. Sign In Nodelet Expansion
- **Problem**: Sign In nodelet is collapsed by default for guests
- **Solution**: Detect if nodelet is closed and expand it before login
- **Code**: Check `aria-expanded` and `is-closed` class, click header if needed

### 3. Success Message Behavior
- **Problem**: Removed success messages for regular chatter
- **Solution**: Show success messages ONLY for `/msg` commands (private messages)
- **Reason**: Regular chatter has immediate visual feedback in feed

### 4. Test Selectors
- **Username field**: `#signin_user`
- **Password field**: `#signin_passwd`
- **Submit button**: `input[type="submit"][value="Login"]`

## Running Tests

### Convenience Script (Recommended)

```bash
# Run all E2E tests
./tools/e2e-test.sh

# Run specific test file
./tools/e2e-test.sh navigation      # Run navigation.spec.js
./tools/e2e-test.sh e2e-users       # Run e2e-users.spec.js

# Run in headed mode (see browser)
./tools/e2e-test.sh --headed

# Run in debug mode (Playwright Inspector)
./tools/e2e-test.sh --debug
./tools/e2e-test.sh --debug navigation

# Run in UI mode (interactive)
./tools/e2e-test.sh --ui

# Get help
./tools/e2e-test.sh --help
```

The convenience script automatically:
- ✓ Checks if Docker containers are running
- ✓ Checks if dev server is responding
- ✓ Installs Playwright if needed
- ✓ Provides helpful error messages
- ✓ Suggests debugging tips on failure

### Direct NPM Commands

```bash
# Run all E2E tests
npm run test:e2e

# Run in headed mode (see browser)
npm run test:e2e:headed

# Run in debug mode (step through)
npm run test:e2e:debug

# Run with UI
npm run test:e2e:ui

# Run specific test file
npx playwright test tests/e2e/navigation.spec.js
```

## Test Organization

The `*.spec.js` files in this directory are the source of truth for coverage — list them with
`ls tests/e2e/*.spec.js` and read the specs for the exact scenarios. `fixtures/auth.js` holds the
shared login helpers.

## Test Results Location

When tests run, results are saved to:
- `test-results/` - Screenshots, videos, traces
- `playwright-report/` - HTML report

View HTML report:
```bash
npx playwright show-report
```

## Debugging Failed Tests

View trace for a specific test:
```bash
npx playwright show-trace test-results/[test-name]/trace.zip
```

## Next Steps

1. **Fix login selectors** - Inspect E2 login page and update auth.js
2. **Remove success message test** - Chatterbox no longer shows success messages
3. **Run tests again** - Verify they pass
4. **Add more tests** - Expand coverage as needed

## Configuration

Playwright config: `playwright.config.js`
- Base URL: http://localhost:9080
- Browser: Chromium (Chrome)
- Screenshots: On failure only
- Videos: On failure only
- Timeout: 30 seconds per test

## Notes

- Tests expect E2 dev environment running on localhost:9080
- Tests use `root` user with password `blah` (standard dev credentials)
- Some tests may need adjustment based on actual E2 behavior
