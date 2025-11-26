# Everything2 E2E Testing

## Current Status

✅ **Phase 1 Complete** - Setup and configuration
- Playwright installed
- Test directory structure created
- Configuration file created (playwright.config.js)
- Auth fixtures created

✅ **Phase 2 Complete** - Core test scenarios written
- Chatterbox tests (5 tests - removed success message test)
- Messages tests (2 tests)
- Wheel tests (3 tests)
- Navigation tests (6 tests)
- **Total**: 16 test scenarios

⚠️  **Tests Partially Working** - 10/16 tests passing (62.5%)

### Passing Tests (10)
- ✅ Chatterbox: Error message covers chat commands link
- ✅ Chatterbox: Special commands render correctly
- ✅ Chatterbox: Input retains focus after sending
- ✅ Chatterbox: Character counter works
- ✅ Messages: Loads initial messages without API call
- ✅ Messages: Mini messages visibility logic
- ✅ Navigation: Homepage loads for guests
- ✅ Wheel: Blocks spin with insufficient GP
- ✅ Wheel: Admin can sanctify themselves

### Failing Tests (6)
- ❌ Chatterbox: Layout shift test (timeout waiting for #chatterbox)
- ❌ Wheel: Display spin result (timeout)
- ❌ Navigation: Login flow works (too many "root" elements on page)
- ❌ Navigation: Chatterbox appears after login (timeout)
- ❌ Navigation: React page content loads (login issue)
- ❌ Navigation: Mason2 pages still work (login issue)
- ❌ Navigation: Sidebar nodelets render (login issue)

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

```
tests/e2e/
├── fixtures/
│   └── auth.js           # Login helpers
├── chatterbox.spec.js    # Chatterbox functionality tests
├── e2e-users.spec.js     # E2E test user login/permission tests
├── messages.spec.js      # Mini messages tests
├── navigation.spec.js    # Basic navigation tests
├── wheel.spec.js         # Wheel of Surprise tests
└── README.md             # This file
```

## What's Tested

### E2E Test Users (e2e-users.spec.js)
- ✓ All 6 E2E test users can login (e2e_admin, e2e_editor, e2e_developer, e2e_chanop, e2e_user, "e2e user space")
- ✓ e2e_admin has admin privileges (Master Control access)
- ✓ e2e_editor has editor privileges
- ✓ e2e_user has no special privileges (Master Control blocked)
- **Note**: All E2E test users have password `test123` for consistency

### Chatterbox (chatterbox.spec.js)
- ✓ Sends message without layout shift
- ✓ Success message fades in and out (needs removal)
- ✓ Error message covers chat commands link
- ✓ Special commands render correctly (/me, /roll)
- ✓ Input retains focus after sending
- ✓ Character counter works

### Mini Messages (messages.spec.js)
- ✓ Loads initial messages without API call
- ✓ Only shows when Messages nodelet not in sidebar

### Wheel of Surprise (wheel.spec.js)
- ✓ Displays spin result
- ✓ Blocks spin with insufficient GP
- ✓ Admin can sanctify themselves

### Navigation (navigation.spec.js)
- ✓ Homepage loads for guests
- ✓ Login flow works
- ✓ Chatterbox appears for logged-in users
- ✓ React page content loads
- ✓ Mason2 pages still work
- ✓ Sidebar nodelets render

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
- This is Phase 1 & 2 implementation - more tests will be added over time
