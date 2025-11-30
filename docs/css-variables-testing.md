# CSS Variables A/B Testing System

## Overview

This system allows A/B testing of CSS variable-based stylesheets alongside the original hardcoded versions without affecting production users.

**Created**: 2025-11-29
**Status**: Phase 1 - Initial Implementation
**Goal**: Validate CSS variable conversion doesn't break user themes before migration

---

## How It Works

### Query Parameter: `?csstest=1`

Add `?csstest=1` to any URL to load CSS variable versions of stylesheets:

```
# Normal (original CSS):
https://everything2.com/title/Settings

# A/B test (CSS variables):
https://everything2.com/title/Settings?csstest=1
```

### Backend Implementation

**File**: [ecore/Everything/Controller.pm](ecore/Everything/Controller.pm#L38-49)

```perl
# Check for ?csstest=1 parameter to enable CSS variable testing
my $css_test_mode = $REQUEST->param("csstest");
my $basesheet_url = $basesheet->cdn_link;
my $zensheet_url = $zensheet->cdn_link;

# If csstest=1, use -var.css versions
if ($css_test_mode && $css_test_mode eq "1") {
  $basesheet_url =~ s/\.css$/-var.css/;
  $zensheet_url =~ s/\.css$/-var.css/;
}
```

**How it modifies URLs**:
- `1882070.css` → `1882070-var.css` (Kernel Blue)
- `1965235.css` → `1965235-var.css` (Understatement)
- `2047530.css` → `2047530-var.css` (Responsive2)

### CSS Variable Naming Convention

All CSS variable versions follow this naming pattern:

**Primary Colors**:
- `--e2-color-primary` - Main theme color (headers, borders, accents)
- `--e2-color-link` - Link color
- `--e2-color-link-visited` - Visited link color
- `--e2-color-link-active` - Active/hover/focus link color

**Background Colors**:
- `--e2-bg-body` - Main page background
- `--e2-bg-content` - Content area background
- `--e2-bg-nodelet` - Nodelet background
- `--e2-bg-header` - Header/footer background
- `--e2-bg-oddrow` - Alternating table row background
- `--e2-bg-table-header` - Table header background
- `--e2-bg-table-cell` - Table cell background
- `--e2-bg-writeup-header` - Writeup header background
- `--e2-bg-writeup-content` - Writeup content background
- `--e2-bg-writeup-footer` - Writeup footer background

**Text Colors**:
- `--e2-text-body` - Primary text color
- `--e2-text-header` - Header/footer text color
- `--e2-text-nodelet-title` - Nodelet title text color
- `--e2-text-error` - Error/warning text color
- `--e2-text-error-hover` - Error/warning hover color

**Border Colors**:
- `--e2-border-primary` - Primary border color
- `--e2-border-light` - Light/subtle border color
- `--e2-border-medium` - Medium border color (section dividers)
- `--e2-border-dark` - Dark/emphasis border color

**Mobile-Specific**:
- `--e2-mobile-tab-bg` - Mobile tab background
- `--e2-mobile-tab-selected` - Selected mobile tab background
- `--e2-mobile-tab-link` - Mobile tab link color
- `--e2-mobile-tab-link-visited` - Visited mobile tab link color

---

## Implementation Status

### ✅ Completed (Phase 1)

1. **Backend Support** ([Controller.pm:38-49](ecore/Everything/Controller.pm))
   - `?csstest=1` parameter handling
   - Automatic -var.css suffix replacement
   - Falls back to CDN if -var version doesn't exist

2. **CSS Variable System Design**
   - Comprehensive naming convention
   - 20+ variables covering all theme aspects
   - Backwards-compatible approach

3. **Tier 1 Stylesheets Converted**
   - ✅ [1882070-var.css](www/css/1882070-var.css) - Kernel Blue (COMPLETE)
   - ⏳ 1965235-var.css - Understatement (PENDING)
   - ⏳ 2047530-var.css - Responsive2 (PENDING)

### 🔄 In Progress (Phase 2)

4. **Convert Remaining Stylesheets**
   - Tier 2 stylesheets (mikoyan25 family, Deep Ice, etc.)
   - Total: 16 more stylesheets to convert

5. **Testing & Validation**
   - Manual A/B testing with `?csstest=1`
   - Visual comparison screenshots
   - User feedback collection

### 📋 Planned (Phase 3)

6. **React Component Migration**
   - Update inline styles to use CSS variables
   - Replace hardcoded colors with `var(--e2-color-link)`
   - Ensures React components respect user themes

7. **Asset Pipeline Integration**
   - Upload -var.css files to S3/CDN
   - Compression and caching
   - Version management

8. **Production Rollout**
   - Monitor A/B test usage via analytics
   - Collect user feedback
   - Gradual migration once validated

---

## How to Create -var.css Versions

### Manual Conversion Process

1. **Read Original Stylesheet**
   ```bash
   cat www/css/NODEID.css
   ```

2. **Identify All Colors**
   Extract all hex colors: `#RRGGBB` or `#RGB`

3. **Map to CSS Variables**
   Replace hardcoded colors with variables:
   ```css
   /* BEFORE */
   a:link {
     color: #4060b0;
   }

   /* AFTER */
   :root {
     --e2-color-link: #4060b0;
   }
   a:link {
     color: var(--e2-color-link);
   }
   ```

4. **Save as NODEID-var.css**
   ```bash
   # Example: Kernel Blue (node 1882070)
   www/css/1882070-var.css
   ```

5. **Add Header Comment**
   ```css
   /* NODEID-var.css (Theme Name by Author - CSS Variables Edition) */
   /* This is a CSS variable-based version for A/B testing with ?csstest=1 */
   ```

### Automated Conversion Script (TODO)

Future enhancement: Create a script to automate color extraction and replacement.

```bash
# Proposed usage:
./tools/convert-css-to-vars.pl www/css/1882070.css
# Outputs: www/css/1882070-var.css
```

---

## Testing Workflow

### For Developers

1. **Create -var.css version** of stylesheet
2. **Test locally** with `?csstest=1`:
   ```bash
   # Start dev environment
   ./docker/devbuild.sh --skip-tests

   # Test in browser
   http://localhost:9080/title/Settings?csstest=1
   ```

3. **Visual comparison**:
   - Open two browser tabs side-by-side
   - Tab 1: Normal CSS (`/title/Settings`)
   - Tab 2: Variable CSS (`/title/Settings?csstest=1`)
   - Compare for visual differences

4. **Fix discrepancies** if colors don't match

### For Users (Future)

1. **Enable A/B test mode** by adding `?csstest=1` to any URL
2. **Navigate site normally** - parameter persists in links
3. **Report issues** if styling looks broken
4. **Disable** by removing `?csstest=1` from URL

---

## Browser Compatibility

**CSS Variables (Custom Properties)** are supported in:
- ✅ Chrome 49+ (March 2016)
- ✅ Firefox 31+ (July 2014)
- ✅ Safari 9.1+ (March 2016)
- ✅ Edge 15+ (April 2017)
- ❌ IE 11 (not supported)

**Fallback Strategy**: If browser doesn't support CSS variables, the regular `.css` file will be loaded instead (via CDN 404 → fallback).

---

## Known Limitations

1. **Softlink Colors Not Variablized**
   - Gradient colors (td#sl1 through td#sl64) remain hardcoded
   - Reason: 64 individual color stops, impractical to variablize
   - Impact: Minimal - softlink gradients are decorative

2. **React Inline Styles**
   - 328 inline styles in React components still use hardcoded colors
   - Plan: Migrate to CSS variables in Phase 3
   - Current: React components assume Kernel Blue palette

3. **Custom User Styles**
   - User's custom CSS (Settings → Custom Stylesheet) not affected
   - Users must manually update their custom CSS to use variables

4. **External Assets**
   - Background images (e.g., Bookwormier theme) not affected by variables
   - Colors within image files cannot be themed dynamically

---

## File Locations

**Backend Logic**:
- [ecore/Everything/Controller.pm](ecore/Everything/Controller.pm#L38-49) - Query parameter handling

**CSS Files**:
- [www/css/1882070-var.css](www/css/1882070-var.css) - Kernel Blue (variables)
- [www/css/1882070.css](www/css/1882070.css) - Kernel Blue (original)

**Documentation**:
- [docs/stylesheet-system.md](stylesheet-system.md) - Comprehensive stylesheet analysis
- [docs/css-variables-testing.md](css-variables-testing.md) - This document

**Templates**:
- [templates/zen.mc:55-57](templates/zen.mc#L55-57) - Stylesheet <link> tags

---

## Metrics & Success Criteria

**Phase 1 Success**:
- ✅ `?csstest=1` parameter works
- ✅ Kernel Blue -var.css renders identically to original
- ✅ No JavaScript errors
- ✅ No CSS parsing errors in browser console

**Phase 2 Success** (Target: 2 weeks):
- ⏳ All Tier 1 stylesheets converted (3 stylesheets)
- ⏳ Visual regression testing passes
- ⏳ User feedback collected (target: 10+ users)

**Phase 3 Success** (Target: 1-2 months):
- ⏳ React components migrated to CSS variables
- ⏳ All Tier 2 stylesheets converted (10+ stylesheets)
- ⏳ Zero reported visual bugs

**Production Rollout** (Target: 3+ months):
- ⏳ Analytics show 100+ users testing with `?csstest=1`
- ⏳ 95%+ positive feedback on visual accuracy
- ⏳ Remove `?csstest=1` requirement - make variables default
- ⏳ Deprecate original `.css` files

---

## Future Enhancements

1. **Automated Conversion Script**
   - Parse CSS, extract colors
   - Generate variable declarations
   - Reduce manual effort

2. **Theme Customization UI**
   - Let users override variables via Settings page
   - Real-time preview
   - Export custom theme

3. **Dark Mode Support**
   - Single stylesheet with `prefers-color-scheme` media query
   - Variable overrides for dark mode
   - No separate dark theme needed

4. **Visual Regression Testing**
   - Automated screenshot comparison
   - CI/CD integration
   - Catch breaking changes before deployment

---

## References

- **CSS Variables Specification**: https://www.w3.org/TR/css-variables-1/
- **MDN Documentation**: https://developer.mozilla.org/en-US/docs/Web/CSS/Using_CSS_custom_properties
- **Browser Support**: https://caniuse.com/css-variables

---

**Questions or Issues?**
File an issue: https://github.com/everything2/everything2/issues
