# CSS Theming Migration - Visual Testing Plan

## Prerequisites

- Application running at http://localhost:9080
- Test users: `e2e_admin` (password: test123), `e2e_user` (password: test123)

---

## Phase 1: Baseline CSS Loading Verification

### 1.1 Guest User - Default Theme (Kernel Blue)

1. Open browser in incognito/private mode
2. Navigate to http://localhost:9080
3. **Open DevTools > Network tab**
4. **Verify**: Only `1973976.css` (basesheet) is loaded - NO `1882070.css` (Kernel Blue) zensheet
5. **Verify**: Page renders with Kernel Blue colors (blue-gray headers, blue links)

### 1.2 Logged-in User - Default Theme

1. Log in as `e2e_user`
2. **Open DevTools > Network tab**
3. **Verify**: Only basesheet loads (no zensheet) if user has default theme

### 1.3 Theme Switching

1. Log in as `e2e_admin`
2. Go to Settings > Advanced tab
3. Select a different theme (e.g., "Cool understatement")
4. Click "Preview" - verify zensheet changes
5. Click "Save Changes"
6. **Refresh page** and verify both basesheet AND the new zensheet load
7. Switch back to "Kernel Blue" and save
8. **Verify**: Zensheet is no longer loaded (back to basesheet-only)

---

## Phase 2: Settings Page Styling

**Test URL**: http://localhost:9080/title/Settings (logged in)

### 2.1 Main Container & Header

- [ ] Page has max-width ~900px, centered
- [ ] "Settings" h1 heading visible
- [ ] Save button area has bottom border separator
- [ ] "Save Changes" button is blue (#4060b0) when changes pending
- [ ] "Save Changes" button is gray when no changes
- [ ] Status messages appear correctly (unsaved, success, error)

### 2.2 Settings Tab - Look and Feel

- [ ] Section headers have dark blue (#38495e) bottom border
- [ ] Fieldsets have light gray border, rounded corners
- [ ] Legends are bold, blue-gray color
- [ ] Checkboxes have proper spacing
- [ ] Hint text is muted blue color (#507898)

### 2.3 Settings Tab - Other Users

- [ ] Select dropdown has proper border/padding
- [ ] "Favorite Users" and "Blocked Users" fieldsets display correctly
- [ ] Info box at bottom has gray background

### 2.4 Nodelets Tab

- [ ] Intro paragraph is muted blue
- [ ] Draggable nodelet items have:
  - [ ] White background
  - [ ] Light gray border
  - [ ] Grip handle (☰) icon in muted blue
  - [ ] Configure (⚙️) and Remove (×) buttons
- [ ] Available nodelets grid shows 2-3 columns
- [ ] Add buttons are blue-outlined
- [ ] Configuration panel (if visible) has blue border, gray background

### 2.5 Notifications Tab

- [ ] Notification labels have rounded corners
- [ ] Active (checked) notifications have light blue background
- [ ] "How Notifications Work" box has gray background
- [ ] Tip box (if visible) has yellow/warning background

---

## Phase 3: Mobile Responsive Testing

Use browser DevTools device mode (iPhone 12 Pro or similar)

### 3.1 Settings Page Mobile

- [ ] Container takes full width with reduced padding
- [ ] Input fields expand to full width
- [ ] Nodelet grid becomes single column
- [ ] Theme selection row stacks vertically
- [ ] Save button area wraps properly

---

## Phase 4: Cross-Theme Consistency

For each theme that has CSS variables defined, verify:

1. Switch to theme via Settings > Advanced
2. Check that Settings page colors adapt appropriately
3. Key elements to check:
   - Header/section borders
   - Button colors
   - Link colors
   - Background colors in fieldsets and boxes

**Test with**: "Cool understatement" (1926578) as it has its own styles

---

## Phase 5: Functional Verification

### 5.1 Settings Actually Save

1. Toggle a checkbox (e.g., "Ask for confirmation when voting")
2. "Save Changes" button should turn blue
3. Click Save
4. Success message appears
5. Refresh page - setting persists

### 5.2 Nodelet Drag-and-Drop

1. Go to Nodelets tab
2. Drag a nodelet to reorder
3. Dragging nodelet should be semi-transparent
4. Save and refresh - order persists

---

## Known Limitations (Not Yet Migrated)

The following Settings tabs still have inline styles (to be completed):

- Advanced tab (Theme, Page Display, Information, Messages, Miscellaneous sections)
- Admin tab (Editor Settings, Chatterbox Macros)
- Profile tab (Account Settings, Profile Information, Bio editor)

These should display correctly but won't be fully themeable until CSS migration is complete.

---

## Reporting Issues

If you find visual issues, note:

1. Which tab/section
2. Expected vs actual appearance
3. Browser used
4. Screenshot if possible
