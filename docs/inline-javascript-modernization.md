# Inline JavaScript Modernization

**Date:** 2025-11-07
**Priority:** Medium (Lower than SQL injection and database code removal)
**Status:** Documented, not started

## Problem Statement

Many E2 pages directly print JavaScript code inline within HTML output instead of using the asset deployment pipeline. This creates several issues:

### Issues with Inline JavaScript

1. **Not Minified** - Inline JS bypasses the asset pipeline, so it's not minified via Terser
2. **Not Compressed** - Missing gzip/brotli compression from the asset pipeline
3. **No Caching** - Inline code is sent with every request instead of being cached by browser
4. **Larger Page Size** - Increases HTML payload size unnecessarily
5. **No Content Security Policy** - Inline scripts violate CSP best practices
6. **Harder to Maintain** - JavaScript scattered throughout Perl code instead of in dedicated JS files
7. **No Version Control** - Can't track which JS version is deployed (asset pipeline uses git commit hashes)
8. **Duplicate Code** - Same JS functions may be duplicated across multiple pages

## Current Asset Pipeline

### Build Process

From [docker/buildspec.yml](../docker/buildspec.yml):

```yaml
pre_build:
  - npm install

build:
  - npx webpack --config etc/webpack.config.js  # Build React
  - ./tools/asset_pipeline.rb --assets=$ASSETS_BUCKET  # Process assets
```

### Asset Pipeline Features

The [tools/asset_pipeline.rb](../tools/asset_pipeline.rb) script:

1. **Processes directories:**
   - `www/js/` - JavaScript files
   - `www/css/` - CSS files
   - `www/react/` - React bundles

2. **For each asset:**
   - Minifies JS with Terser (`npx terser`)
   - Minifies CSS with clean-css-cli
   - Creates 4 versions: uncompressed, gzip, brotli, deflate
   - Uploads to S3 bucket with git commit hash as path

3. **S3 Structure:**
   ```
   s3://deployed.everything2.com/
     ├── {git-commit-hash}/
     │   ├── legacy.js (minified)
     │   ├── gzip/legacy.js (gzip compressed)
     │   ├── br/legacy.js (brotli compressed)
     │   ├── deflate/legacy.js (deflate compressed)
     │   └── ... (all other assets)
   ```

4. **Asset Expiration:**
   - Keeps last 9 git commits worth of assets
   - Auto-deletes older versions

5. **CDN Integration:**
   - Assets served via `$APP->asset_uri("filename")`
   - Returns versioned URL with git commit hash
   - Browser caches for 1 year (`max-age=31536000`)

### Currently in Asset Pipeline

**JavaScript files in www/js/:**
- `legacy.js` - Legacy JavaScript functions

**React bundles in www/react/:**
- `main.bundle.js` - React application bundle (created by Webpack)

**CSS files in www/css/:**
- Various stylesheets

## Inline JavaScript Found

### Location: ecore/Everything/Delegation/htmlcode.pm

**Examples:**

#### 1. Group Editor Functions (lines 601-685)

```perl
my $str = "
  <script language=\"JavaScript\">
  function saveForm()
  {
    var myForm;
    var myOption;
    var i;

    for(i=1; i <= document.forms.f$id.group.length; i++)
    {
      myForm = eval(\"document.forms.f\" + \"$id\");
      myOption = eval(\"document.forms.f\" + \"$id\" + \".group\");
      myForm[i].value = myOption.options[i-1].value;
    }

    return true;
  }

  function swapUp()
  {
    with(document.forms.f$id.group){
      var x=selectedIndex;
      if(x == -1) { return; }
      if(options.length > 0 && x > 0) {
        tmp = new Option(options[x].text, options[x].value);
        options[x].text = options[x-1].text;
        options[x].value = options[x-1].value;
        options[x-1].text = tmp.text;
        options[x-1].value = tmp.value;
      }
    }
  }
  // ... more functions
  </script>
";
```

**Issues:**
- ~85 lines of unminified JavaScript
- Embedded in Perl string with escaping nightmares (`\"`)
- Uses deprecated `eval()` and `with()`
- Duplicated for each group editor instance

#### 2. HTML Tag Inserter (line 1190)

```perl
return "<SCRIPT language=\"javascript\">
function Insert$num(text)
{
  parent.opener.document.displayForm.doctext.value +=
  opener.document.displayForm.doctext.value.substring(0,
    opener.document.displayForm.doctext.selectionStart)
  + text + opener.document.displayForm.doctext.value.substring(
    opener.document.displayForm.doctext.selectionEnd,
    opener.document.displayForm.doctext.value.length);
  // ...
}
</SCRIPT>";
```

**Issues:**
- Dynamic function name (`Insert$num`) created per instance
- Manipulates parent.opener (popup window pattern)
- Not minified

#### 3. Node Info JSON (line 4040)

```perl
<script type='text/javascript' name='nodeinfojson' id='nodeinfojson'>
  window.nodeinfojson = {...};  // JSON data
</script>
```

**Issues:**
- Data injection should use `data-*` attributes or dedicated JSON endpoint
- Creates global variable pollution

#### 4. Library Loading (lines 4032-4038)

```perl
my $libraries = qq'<script src="https://code.jquery.com/jquery-1.11.1.min.js" type="text/javascript"></script>';
if($include_jquery_ui)
{
    $libraries .= qq|<script src="https://ajax.googleapis.com/ajax/libs/jqueryui/1.11.1/jquery-ui.min.js" type="text/javascript"></script>|;
}
$libraries .= qq|<script src="|.$APP->asset_uri("legacy.js").qq|" type="text/javascript"></script>|;
$libraries .= qq|<script src="|.$APP->asset_uri("react/main.bundle.js").qq|" type="text/javascript"></script>|;
```

**Note:** These are actually external script tags, not inline JS - these are fine!

## Examples from Other Files

### ecore/Everything/Delegation/document.pm

(Need to analyze - contains `<script` tags)

### ecore/Everything/Delegation/htmlpage.pm

(Need to analyze - contains `<script` tags)

## Migration Strategy

### Phase 1: Identify and Catalog (This Document)

- [x] Document the problem
- [x] Identify inline JavaScript locations
- [ ] Count total lines of inline JS
- [ ] Categorize by type (functions, data injection, etc.)

### Phase 2: Extract to Files (Week 1-2)

For each inline JavaScript block:

1. **Create dedicated JS file in www/js/**
   ```
   www/js/
     ├── group-editor.js (new)
     ├── html-tag-inserter.js (new)
     ├── legacy.js (existing)
     └── ...
   ```

2. **Extract JavaScript code**
   ```javascript
   // www/js/group-editor.js
   export function initGroupEditor(formId) {
     function saveForm() {
       // ... extracted code
     }

     function swapUp() {
       // ... extracted code
     }

     // Attach to form
     document.addEventListener('DOMContentLoaded', () => {
       if (document.forms['f' + formId]) {
         // Initialize
       }
     });
   }
   ```

3. **Replace inline code with script tag**
   ```perl
   # Old:
   my $str = "<script>... 85 lines ...</script>";

   # New:
   my $str = '<script src="' . $APP->asset_uri("group-editor.js") . '"></script>';
   $str .= '<script>initGroupEditor(' . $id . ');</script>';
   ```

### Phase 3: Modernize JavaScript (Week 3-4)

1. **Remove deprecated patterns:**
   - Replace `eval()` with proper selectors
   - Replace `with()` with explicit references
   - Use `const`/`let` instead of `var`
   - Add `'use strict';`

2. **Add ES6+ features:**
   - Arrow functions
   - Template literals
   - Destructuring
   - Modules

3. **Example modernization:**
   ```javascript
   // Old (inline, deprecated)
   function swapUp() {
     with(document.forms.f123.group) {
       var x = selectedIndex;
       // ...
     }
   }

   // New (modern ES6+)
   const swapUp = (formId) => {
     const select = document.querySelector(`#f${formId} select[name="group"]`);
     const selectedIndex = select.selectedIndex;
     if (selectedIndex <= 0) return;
     // ...
   };
   ```

### Phase 4: Bundle and Optimize (Week 5)

1. **Add to Webpack bundle:**
   ```javascript
   // etc/webpack.config.js
   entry: {
     main: './react/index.js',
     legacy: './www/js/legacy.js',
     'group-editor': './www/js/group-editor.js',  // New
     'html-inserter': './www/js/html-inserter.js', // New
   }
   ```

2. **Or keep in asset pipeline:**
   - Asset pipeline already processes `www/js/` directory
   - Files automatically minified, compressed, and versioned
   - No Webpack changes needed if keeping separate

### Phase 5: Data Injection Modernization

For `nodeinfojson` and similar data injection:

**Option A: Use data attributes**
```html
<div id="e2-react-root"
     data-node-id="123"
     data-user-id="456"
     data-config='{"foo":"bar"}'>
</div>

<script>
  const config = JSON.parse(
    document.getElementById('e2-react-root').dataset.config
  );
</script>
```

**Option B: JSON API endpoint**
```javascript
// Fetch data instead of inline injection
const nodeInfo = await fetch('/api/nodes/123').then(r => r.json());
```

**Option C: Keep inline but minimize**
```html
<script id="initial-state" type="application/json">
  {"node_id": 123, "user_id": 456}
</script>
<script src="/assets/app.js"></script>
```

## Content Security Policy (CSP)

Once inline JavaScript is eliminated, can enable strict CSP:

```http
Content-Security-Policy:
  default-src 'self';
  script-src 'self' https://deployed.everything2.com;
  style-src 'self' https://deployed.everything2.com;
  img-src 'self' https://*.everything2.com;
```

Benefits:
- Prevents XSS attacks
- Blocks unauthorized external scripts
- Industry best practice

**Current blockers:**
- Inline `<script>` tags (need to extract)
- Inline event handlers (`onclick=`, `onload=`)
- `eval()` and `Function()` usage

## Performance Impact

### Current State (Inline JS)

Example: Group editor page
```
HTML size: 45 KB (includes 5 KB of inline JS)
Network: 1 request (HTML)
Cacheable: No (HTML changes, JS embedded)
```

### After Migration (Asset Pipeline)

```
HTML size: 40 KB (just markup + script tag)
JS file: 2 KB minified + gzip
Network: 2 requests (HTML + JS)
Cacheable: Yes (JS cached for 1 year)
```

**Benefit for repeat visits:**
- First visit: 40 KB + 2 KB = 42 KB (similar)
- Repeat visit: 40 KB + 0 KB (cached) = 40 KB (15% faster)
- 10 pages with same JS: 400 KB vs 420 KB (5% savings)

### Additional Benefits

- **Parallel download** - Browser can download JS while parsing HTML
- **HTTP/2 multiplexing** - Multiple assets downloaded simultaneously
- **Brotli compression** - Better than gzip (15-20% smaller)
- **CDN caching** - Served from edge locations (faster)

## Estimated Effort

### Discovery Phase (2-3 days)
- Catalog all inline JavaScript blocks
- Measure total size and complexity
- Identify duplicate code

### Extraction Phase (1-2 weeks)
- Extract ~10-15 inline JS blocks to files
- Test each extraction
- Add to asset pipeline

### Modernization Phase (1-2 weeks)
- Remove deprecated patterns
- Add ES6+ features
- Code review and testing

### CSP Phase (3-5 days)
- Remove remaining inline scripts
- Add CSP headers
- Test across all pages

**Total: 4-6 weeks**

## Priority Rationale

**Why Medium Priority (not High):**

1. **Not a security vulnerability** - Unlike SQL injection or database code eval
2. **Performance impact is modest** - ~5-15% improvement, not dramatic
3. **Functional code works** - Inline JS is ugly but functional
4. **Higher priorities exist:**
   - Database code removal (security, profiling)
   - SQL injection fixes (security)
   - Mobile responsiveness (user experience)
   - Testing infrastructure (code quality)

**Why Not Low Priority:**

1. **CSP blocker** - Prevents modern security headers
2. **Developer experience** - Perl strings with escaped quotes are painful
3. **Maintainability** - Hard to find and update JS in Perl files
4. **Performance** - Small but real impact on page load
5. **Technical debt** - Should be fixed during modernization

**Recommended Timeline:** Q2-Q3 2025 after higher priorities are complete

## Quick Wins

Can start with high-impact, low-effort items:

### Quick Win #1: Extract Group Editor (2-3 days)
- ~85 lines of inline JS
- Self-contained functionality
- Used in multiple places
- Clear performance win

### Quick Win #2: Extract HTML Tag Inserter (1-2 days)
- ~30 lines of inline JS
- Simple extraction
- Improve popup window handling

### Quick Win #3: Modernize Data Injection (2-3 days)
- Move `nodeinfojson` to data attributes
- Reduce global scope pollution
- Enable CSP for data

## References

- Asset pipeline: [tools/asset_pipeline.rb](../tools/asset_pipeline.rb)
- Build process: [docker/buildspec.yml](../docker/buildspec.yml)
- Webpack config: [etc/webpack.config.js](../etc/webpack.config.js)
- Main htmlcode file: [ecore/Everything/Delegation/htmlcode.pm](../ecore/Everything/Delegation/htmlcode.pm)

## Next Steps

1. Complete catalog of all inline JavaScript (grep through codebase)
2. Measure total size and impact
3. Create prioritized list of blocks to extract
4. Start with Quick Win #1 (group editor) when ready
5. Establish pattern for future JS (all in www/js/, no inline)

---

**Document Status:** Initial analysis complete
**Last Updated:** 2025-11-07
**Priority:** Medium (Q2-Q3 2025)
**Estimated Effort:** 4-6 weeks total
