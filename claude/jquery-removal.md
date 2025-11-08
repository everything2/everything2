# jQuery Removal and Modernization

**Date:** 2025-11-07
**Priority:** Medium (After SQL fixes and database code removal)
**Status:** Documented, not started

## Problem Statement

Everything2 currently uses **jQuery 1.11.1** (released 2014) and **jQuery UI 1.11.1**, both of which are:

1. **Severely outdated** - Released over 10 years ago
2. **Security vulnerabilities** - Known XSS and prototype pollution issues in old versions
3. **Not needed for modern browsers** - Vanilla JS can do everything jQuery did
4. **Redundant with React** - React handles DOM manipulation better
5. **Performance overhead** - Extra ~100KB of JavaScript for features browsers now have natively
6. **Maintenance burden** - Another dependency to manage

## Current jQuery Usage

### jQuery Version Loading

**File:** `ecore/Everything/Delegation/htmlcode.pm:4032-4035`

```perl
my $libraries = qq'<script src="https://code.jquery.com/jquery-1.11.1.min.js" type="text/javascript"></script>';

if($include_jquery_ui)
{
    $libraries .= qq|<script src="https://ajax.googleapis.com/ajax/libs/jqueryui/1.11.1/jquery-ui.min.js" type="text/javascript"></script>|;
}
```

**Issues:**
- jQuery 1.11.1 from May 2014 (11 years old!)
- jQuery UI 1.11.1 from October 2014
- Loaded from CDN (good for caching, but old version)
- No integrity checks (SRI hashes missing)

### jQuery Usage Statistics

**www/js/legacy.js:**
- **219 jQuery/$ calls** in a single file
- Common patterns: `jQuery('#selector')`, `$(element)`
- Heavy usage throughout

**Perl templates:**
- 10+ uses in htmlpage.pm (theme chooser, draggable widgets)
- Unknown count in inline JavaScript blocks

### Common jQuery Patterns Found

#### 1. DOM Selection
```javascript
// jQuery
var mbox = jQuery('#message')[0];
var titletext = jQuery("#widgetheading em")[0];

// Modern equivalent
const mbox = document.querySelector('#message');
const titletext = document.querySelector('#widgetheading em');
```

#### 2. Event Binding
```javascript
// jQuery
jQuery("a").bind("focus.themetest click.themetest", changehref);
jQuery(widget.theme).bind("change", function() { ... });

// Modern equivalent
document.querySelectorAll('a').forEach(link => {
  link.addEventListener('focus', changehref);
  link.addEventListener('click', changehref);
});
widget.theme.addEventListener('change', function() { ... });
```

#### 3. AJAX Requests
```javascript
// jQuery
jQuery.ajax({
  url: this.form.action,
  data: { displaytype: "choosetheme", usetheme: "ajax", theme: theme },
  success: cleanup
});

// Modern equivalent
fetch(this.form.action, {
  method: 'POST',
  headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  body: new URLSearchParams({ displaytype: "choosetheme", usetheme: "ajax", theme })
})
.then(response => response.text())
.then(cleanup);
```

#### 4. jQuery UI (Draggable)
```javascript
// jQuery UI
jQuery(widget).draggable().css("cursor","move");

// Modern equivalent (using native HTML5 drag-drop)
widget.draggable = true;
widget.style.cursor = 'move';
widget.addEventListener('dragstart', handleDragStart);
widget.addEventListener('dragend', handleDragEnd);
```

## Migration Strategy

### Phase 1: Audit and Catalog (Week 1)

**Tasks:**
1. Count all jQuery usage across codebase
2. Categorize by type (DOM, events, AJAX, animations, UI)
3. Identify jQuery UI widget usage (draggable, datepicker, etc.)
4. Document dependencies and patterns

**Deliverable:** Complete inventory of jQuery usage

### Phase 2: Create Vanilla JS Utilities (Week 2)

Create modern replacement utilities in `www/js/utils/`:

```javascript
// www/js/utils/dom.js
export const $ = (selector) => document.querySelector(selector);
export const $$ = (selector) => document.querySelectorAll(selector);

export const on = (element, event, handler) => {
  element.addEventListener(event, handler);
};

export const addClass = (element, className) => {
  element.classList.add(className);
};

// www/js/utils/ajax.js
export const get = (url) => fetch(url).then(r => r.json());
export const post = (url, data) => fetch(url, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(data)
}).then(r => r.json());

// www/js/utils/ui.js
export const makeDraggable = (element) => {
  // Native drag-drop implementation
};
```

### Phase 3: Replace jQuery in legacy.js (Week 3-4)

**Before (jQuery):**
```javascript
function replyToCB(s, onlineonly) {
  var mbox = jQuery('#message')[0];
  mbox.value = (onlineonly ? '/msg? ' : '/msg ') + s + " ";

  if (mbox.createTextRange) { // IE
    var r = mbox.createTextRange();
    r.moveStart('character', mbox.value.length);
    r.select();
  } else {
    mbox.focus();
    if (mbox.setSelectionRange)
      mbox.setSelectionRange(mbox.value.length, mbox.value.length);
  }
}
```

**After (Vanilla JS):**
```javascript
function replyToCB(s, onlineonly) {
  const mbox = document.querySelector('#message');
  if (!mbox) return;

  mbox.value = (onlineonly ? '/msg? ' : '/msg ') + s + " ";
  mbox.focus();

  // Modern browsers all support setSelectionRange
  mbox.setSelectionRange(mbox.value.length, mbox.value.length);
}
```

### Phase 4: Replace jQuery in Templates (Week 5)

**htmlpage.pm theme chooser:**

Before:
```javascript
var zenSheet = jQuery("#zensheet");
var titletext = jQuery("#widgetheading em")[0];
var widget = jQuery("#widget")[0];

jQuery(widget.theme).bind("change", function() {
  // ...
});
```

After:
```javascript
const zenSheet = document.querySelector("#zensheet");
const titletext = document.querySelector("#widgetheading em");
const widget = document.querySelector("#widget");

widget.theme.addEventListener("change", function() {
  // ...
});
```

### Phase 5: Replace jQuery UI (Week 6-7)

jQuery UI widgets need React or native HTML5 replacements:

#### Draggable Widget
**Before:** `jQuery(widget).draggable()`

**Option A - React:**
```javascript
import { DraggableCore } from 'react-draggable';

<DraggableCore onDrag={handleDrag}>
  <div className="widget">...</div>
</DraggableCore>
```

**Option B - Native:**
```javascript
element.draggable = true;
element.addEventListener('dragstart', (e) => {
  e.dataTransfer.effectAllowed = 'move';
});
```

**Option C - Third-party (if needed):**
- Sortable.js (lightweight, 28KB)
- react-beautiful-dnd (for React)

### Phase 6: Remove jQuery (Week 8)

Once all jQuery usage is replaced:

1. Remove jQuery from htmlcode.pm
2. Remove jQuery UI from htmlcode.pm
3. Add to asset pipeline if any utilities needed
4. Test thoroughly across all pages

## Browser Support Considerations

### Modern JavaScript Features E2 Can Use

All features supported in browsers from ~2017+:

| Feature | jQuery Method | Native Equivalent | Support |
|---------|---------------|-------------------|---------|
| DOM Selection | `$('#id')` | `querySelector('#id')` | ✅ All browsers |
| Multiple Selection | `$('.class')` | `querySelectorAll('.class')` | ✅ All browsers |
| Event Listeners | `.on('click')` | `.addEventListener('click')` | ✅ All browsers |
| AJAX | `$.ajax()` | `fetch()` | ✅ All browsers |
| Promises | `$.when()` | `Promise.all()` | ✅ All browsers |
| Classes | `.addClass()` | `.classList.add()` | ✅ All browsers |
| Animations | `.animate()` | CSS transitions | ✅ All browsers |

**No polyfills needed** for E2's target audience (modern browsers).

## React Overlap

Many jQuery use cases are better handled by React:

### DOM Manipulation
**jQuery approach:**
```javascript
$('#counter').text(count);
$('#list').append('<li>' + item + '</li>');
```

**React approach:**
```javascript
const [count, setCount] = useState(0);
const [items, setItems] = useState([]);

return (
  <>
    <div id="counter">{count}</div>
    <ul id="list">
      {items.map(item => <li key={item.id}>{item.text}</li>)}
    </ul>
  </>
);
```

### Event Handling
**jQuery approach:**
```javascript
$('#button').on('click', function() {
  // handler
});
```

**React approach:**
```javascript
<button onClick={handleClick}>Click me</button>
```

### AJAX
**jQuery approach:**
```javascript
$.ajax({ url: '/api/data', success: processData });
```

**React approach:**
```javascript
const { data } = useQuery('data', () => fetch('/api/data').then(r => r.json()));
```

## Performance Impact

### Current State (with jQuery)

**Page load with jQuery:**
```
jQuery 1.11.1 minified: ~96 KB
jQuery UI 1.11.1: ~270 KB
Total: ~366 KB (uncompressed)
```

**With compression:**
- Gzip: ~100 KB
- Brotli: ~80 KB

**From CDN:** Cached across sites, but still old version

### After Removal (Vanilla JS + React)

**Without jQuery:**
```
Custom utilities: ~5-10 KB
React (already loaded): 0 KB additional
Total: ~5-10 KB
```

**Savings:**
- ~90 KB less JavaScript per page load
- Faster parse/execute time
- Modern, secure code

## Security Concerns

### Known Vulnerabilities in jQuery 1.11.1

**CVE-2015-9251** - XSS via location.hash
- Severity: Medium
- Fixed in: jQuery 3.0.0

**CVE-2019-11358** - Prototype pollution
- Severity: Medium
- Fixed in: jQuery 3.4.0

**CVE-2020-11022** - XSS in HTML parsing
- Severity: Medium
- Fixed in: jQuery 3.5.0

**Recommendation:** Even if keeping jQuery, must upgrade to 3.7+ (current stable)

## Migration Checklist

### Quick Wins (Can do immediately)

- [ ] Replace simple `$('#id')` with `querySelector`
- [ ] Replace `$.each()` with `forEach()`
- [ ] Replace `$.ajax()` with `fetch()`
- [ ] Remove IE-specific code (IE11 is dead)

### Medium Effort

- [ ] Replace jQuery event binding with addEventListener
- [ ] Convert jQuery animations to CSS transitions
- [ ] Replace jQuery utilities with native equivalents

### High Effort

- [ ] Replace jQuery UI widgets with React components
- [ ] Rewrite theme chooser with vanilla JS
- [ ] Convert draggable widgets to React or native drag-drop

### Testing Requirements

- [ ] Test on Chrome, Firefox, Safari, Edge
- [ ] Test all interactive elements (forms, buttons, etc.)
- [ ] Test AJAX functionality
- [ ] Test animations and transitions
- [ ] Regression test existing functionality

## Estimated Effort

### By Phase

| Phase | Duration | Complexity |
|-------|----------|------------|
| Audit & Catalog | 1 week | Low |
| Create Utilities | 1 week | Low |
| Replace legacy.js | 2 weeks | Medium |
| Replace Templates | 1 week | Medium |
| Replace jQuery UI | 2 weeks | High |
| Remove & Test | 1 week | Medium |
| **Total** | **8 weeks** | **Medium** |

### Team Size Impact

- **1 developer:** 8 weeks
- **2 developers:** 4-5 weeks (parallel work on different files)

## Priority Rationale

**Why Medium Priority:**

1. **Not blocking other work** - Can modernize alongside jQuery
2. **Security risk is manageable** - Can upgrade to jQuery 3.7 as interim fix
3. **Performance impact is modest** - ~80-90KB savings
4. **Higher priorities exist:**
   - Database code removal (security, profiling)
   - SQL injection fixes (security)
   - Mobile responsiveness (user experience)

**Why Not Low Priority:**

1. **Security vulnerabilities** - Old jQuery has known CVEs
2. **Technical debt** - Blocks React adoption
3. **Performance** - Unnecessary 100KB+ overhead
4. **Modern web standards** - Should use native features
5. **Developer experience** - Easier to work with vanilla JS

**Recommended Timeline:** Q2 2025 after React frontend is more mature

## Quick Path: Upgrade Instead of Remove

**If removal is too much work, interim solution:**

### Option A: Upgrade to jQuery 3.7.1 (Current Stable)

```perl
# Change in htmlcode.pm
my $libraries = qq'<script src="https://code.jquery.com/jquery-3.7.1.min.js" integrity="sha256-/JqT3SQfawRcv/BIHPThkBvs0OEvtFFmqPF/lYI/Cxo=" crossorigin="anonymous"></script>';
```

**Pros:**
- Minimal code changes (mostly compatible)
- Fixes security vulnerabilities
- Better performance than 1.11.1
- 1-2 day effort

**Cons:**
- Still dependent on jQuery
- Still ~30KB overhead (gzipped)
- Doesn't move toward React

### Option B: jQuery Slim (No AJAX, No Effects)

If only using jQuery for DOM selection:

```html
<script src="https://code.jquery.com/jquery-3.7.1.slim.min.js"></script>
```

**Savings:** ~10KB smaller than full jQuery

## Integration with React Migration

jQuery removal should align with React adoption:

### Strategy: Gradual Migration

1. **Phase 1:** Keep jQuery, add React components
2. **Phase 2:** New features use React (no new jQuery code)
3. **Phase 3:** Convert jQuery widgets to React
4. **Phase 4:** Remove jQuery entirely

**Timeline:**
- Q1 2025: React expansion (keep jQuery)
- Q2 2025: jQuery → Vanilla JS conversion
- Q3 2025: jQuery → React conversion
- Q4 2025: Remove jQuery

## Alternative: Keep jQuery for Legacy Pages

**Hybrid approach:**

- **New React pages:** No jQuery
- **Legacy pages:** Keep jQuery 3.7.1
- **Gradually convert:** One page at a time

**Benefits:**
- Less risky
- Incremental improvement
- Can focus on high-value pages first

**Tradeoffs:**
- Longer timeline
- Maintaining two systems
- Some pages load jQuery unnecessarily

## References

- Current jQuery: [code.jquery.com/jquery-1.11.1.min.js](https://code.jquery.com/jquery-1.11.1.min.js)
- Latest jQuery: [jquery.com](https://jquery.com) (3.7.1)
- You Might Not Need jQuery: [youmightnotneedjquery.com](http://youmightnotneedjquery.com/)
- jQuery CVEs: [cve.mitre.org](https://cve.mitre.org/cgi-bin/cvekey.cgi?keyword=jquery)

## Next Steps

### Immediate (This Week)
1. Audit jQuery usage count across codebase
2. Categorize usage patterns
3. Identify quick wins for replacement

### Short Term (This Month)
1. **Security fix:** Upgrade to jQuery 3.7.1 (2 days)
2. Document all jQuery UI widget usage
3. Create plan for React component replacements

### Medium Term (Q2 2025)
1. Start vanilla JS conversions in legacy.js
2. Convert inline jQuery to vanilla JS
3. Replace simple DOM manipulation with React

### Long Term (Q3-Q4 2025)
1. Convert all jQuery UI widgets to React
2. Remove jQuery dependency entirely
3. Achieve 100% React + vanilla JS codebase

---

**Document Status:** Complete analysis
**Last Updated:** 2025-11-07
**Priority:** Medium (Q2 2025)
**Estimated Effort:** 8 weeks (full removal) or 2 days (upgrade to 3.7.1)
**Security Risk:** Medium (known CVEs in 1.11.1)
