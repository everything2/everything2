const { defineConfig, devices } = require('@playwright/test')

/**
 * Playwright E2E Testing Configuration for Everything2
 *
 * This configuration runs headless browser tests against the local development
 * environment to verify UI behavior, animations, and user interactions.
 */

module.exports = defineConfig({
  testDir: './tests/e2e',

  // Maximum time one test can run for
  timeout: 30000,

  // Test execution settings
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : 3,

  // Reporter to use
  reporter: [
    ['html'],
    ['list']
  ],

  use: {
    // Base URL for all tests
    baseURL: 'http://localhost:9080',

    // Capture screenshots on failure
    screenshot: 'only-on-failure',

    // Record video on failure
    video: 'retain-on-failure',

    // Collect trace on failure
    trace: 'retain-on-failure',

    // Browser viewport
    viewport: { width: 1280, height: 720 },
  },

  // Configure projects for different browsers
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],

  // Run local dev server before starting tests (optional)
  // webServer: {
  //   command: './docker/devbuild.sh',
  //   url: 'http://localhost:9080',
  //   reuseExistingServer: !process.env.CI,
  // },
})
