/**
 * E2E Tests for Everything Poll Creator
 *
 * CLEANUP STRATEGY: Polls remain in database (cleanup would require admin permissions)
 * TEST USERS: e2e_admin (gods, pw:test123)
 */

const { test, expect } = require('@playwright/test');

test.describe('Everything Poll Creator', () => {
  test.beforeEach(async ({ page }) => {
    // Login as e2e_admin (has poll creation permissions)
    await page.goto('/');
    await page.fill('input[name="user"]', 'e2e_admin');
    await page.fill('input[name="passwd"]', 'test123');
    await page.press('input[name="passwd"]', 'Enter');
    await page.waitForLoadState('networkidle');
  });

  test('should load poll creator page', async ({ page }) => {
    await page.goto('/title/Everything%20Poll%20Creator');

    // Check page title - look for the React component's h1
    await expect(page.getByRole('heading', { name: 'E2 Poll Creator' })).toBeVisible();

    // Check form elements are present
    await expect(page.locator('input[placeholder*="unique, descriptive title"]')).toBeVisible();
    await expect(page.locator('input[placeholder*="question"]')).toBeVisible();
    await expect(page.locator('button:has-text("Create Poll")')).toBeVisible();
  });

  test('should show validation errors for empty fields', async ({ page }) => {
    await page.goto('/title/Everything%20Poll%20Creator');

    // Try to submit without filling anything
    await page.click('button:has-text("Create Poll")');

    // Should show error message
    await expect(page.locator('text=Poll title is required')).toBeVisible();
  });

  test('should show validation error for missing question', async ({ page }) => {
    await page.goto('/title/Everything%20Poll%20Creator');

    // Fill only title
    await page.fill('input[placeholder*="unique, descriptive title"]', 'Test Poll');
    await page.click('button:has-text("Create Poll")');

    // Should show error message
    await expect(page.locator('text=Poll question is required')).toBeVisible();
  });

  test('should show validation error for insufficient options', async ({ page }) => {
    await page.goto('/title/Everything%20Poll%20Creator');

    // Fill title and question but only one option
    await page.fill('input[placeholder*="unique, descriptive title"]', 'Test Poll');
    await page.fill('input[placeholder*="question"]', 'Test question?');

    // Fill only first option
    const firstOption = page.locator('input[placeholder="Option 1..."]');
    await firstOption.fill('Only option');

    await page.click('button:has-text("Create Poll")');

    // Should show error message
    await expect(page.locator('text=At least 2 answer options are required')).toBeVisible();
  });

  test('should successfully create a poll with valid data', async ({ page }) => {
    await page.goto('/title/Everything%20Poll%20Creator');

    // Create unique poll title using timestamp
    const timestamp = Date.now();
    const pollTitle = `E2E Test Poll ${timestamp}`;

    // Fill out the form
    await page.fill('input[placeholder*="unique, descriptive title"]', pollTitle);
    await page.fill('input[placeholder*="question"]', 'What is your favorite programming language?');

    // Fill in options
    await page.fill('input[placeholder="Option 1..."]', 'JavaScript');
    await page.fill('input[placeholder="Option 2..."]', 'Python');
    await page.fill('input[placeholder="Option 3..."]', 'Perl');
    await page.fill('input[placeholder="Option 4..."]', 'Ruby');

    // Submit the form
    await page.click('button:has-text("Create Poll")');

    // Wait for success message (contains poll title and success text)
    await expect(page.locator('text=created successfully')).toBeVisible({ timeout: 10000 });

    // Form should be reset
    const titleInput = page.locator('input[placeholder*="unique, descriptive title"]');
    await expect(titleInput).toHaveValue('');
  });

  test('should add and remove poll options dynamically', async ({ page }) => {
    await page.goto('/title/Everything%20Poll%20Creator');

    // Initially 4 options should be visible
    const initialOptions = page.locator('input[placeholder^="Option"]');
    await expect(initialOptions).toHaveCount(4);

    // Click "Add Another Option" button
    await page.click('button:has-text("Add Another Option")');

    // Now 5 options should be visible
    await expect(page.locator('input[placeholder^="Option"]')).toHaveCount(5);

    // Click remove button on the last option
    const removeButtons = page.locator('button:has-text("Remove")');
    await removeButtons.last().click();

    // Back to 4 options
    await expect(page.locator('input[placeholder^="Option"]')).toHaveCount(4);
  });

  test('should show character count for title and question', async ({ page }) => {
    await page.goto('/title/Everything%20Poll%20Creator');

    // Check title character count
    await page.fill('input[placeholder*="unique, descriptive title"]', 'Test');
    await expect(page.locator('text=4 / 64 characters').first()).toBeVisible();

    // Check question character count
    await page.fill('input[placeholder*="question"]', 'Test question?');
    await expect(page.locator('text=14 / 255 characters')).toBeVisible();
  });

  test('should show "None of the above" indicator', async ({ page }) => {
    await page.goto('/title/Everything%20Poll%20Creator');

    // Check that "None of the above" indicator is visible
    await expect(page.locator('text=And finally: None of the above (automatically added)')).toBeVisible();
  });

  test('should prevent duplicate poll titles', async ({ page }) => {
    await page.goto('/title/Everything%20Poll%20Creator');

    // Use the title of an existing poll
    await page.fill('input[placeholder*="unique, descriptive title"]', 'What is your favorite programming language?');
    await page.fill('input[placeholder*="question"]', 'Some question?');
    await page.fill('input[placeholder="Option 1..."]', 'Option A');
    await page.fill('input[placeholder="Option 2..."]', 'Option B');

    await page.click('button:has-text("Create Poll")');

    // Should show error about duplicate title
    await expect(page.locator('text=already exists')).toBeVisible({ timeout: 10000 });
  });
});
