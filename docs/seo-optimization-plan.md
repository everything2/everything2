# Everything2 SEO Optimization Plan

**Date**: 2025-11-27 (Updated 2025-11-28)
**Purpose**: Improve search engine visibility and organic traffic for Everything2.com
**Site Reviewed**: https://everything2.com (production) + development environment
**Status**: ✅ Solid foundation in place, optimization opportunities identified

## Executive Summary

After reviewing the HTML output of Everything2's production site (https://everything2.com) and comparing with the development environment, the site has a **solid SEO foundation** with some opportunities for improvement. Many critical features are already implemented correctly:

**Already Working Well** ✅:
- Canonical URLs (production)
- XML sitemaps (comprehensive, updated daily)
- CDN delivery for static assets
- Robots.txt with sitemap reference
- Good page title structure
- Clean URL structure
- Meta descriptions (fixed 2025-11-28)
- Social sharing buttons (cleaned up 2025-11-28)

**Priority Improvements Needed**:
1. Missing structured data (Schema.org) for rich search results
2. Missing Open Graph/Twitter Card tags
3. Outdated jQuery library (security + performance)
4. Guest front page still uses HTML 4.01 DOCTYPE

This document outlines specific, actionable improvements prioritized by impact.

---

## Critical Issues (High Priority)

### 1. **Canonical URLs** ✅ PRODUCTION OK / ⚠️ DEV BROKEN

**Production Status**: ✅ Working correctly
```html
<link rel="canonical" href="https://everything2.com/title/Everything2">
```

**Development Issue**: ❌ Malformed in local environment only:
```html
<link rel="canonical" href="http://development.everything2.com/title/Quick+brown+foxhttp://localhost:9080">
```

**Impact**:
- Production site is fine - no action needed for live site
- Development environment needs fix for accurate local testing

**Fix** (Development only):
```perl
# Location: Likely in HTML.pm or Application.pm where canonical URLs are built
# Ensure development environment uses correct base URL without concatenation
```

**Priority**: LOW - Production is correct; dev-only issue for testing accuracy

---

### 2. **Outdated DOCTYPE Declaration** ⚠️

**Issue**: Guest front page uses HTML 4.01 Transitional:
```html
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
```

Content pages correctly use HTML5:
```html
<!DOCTYPE html>
```

**Impact**:
- Inconsistent rendering across pages
- Missing modern HTML5 semantic elements
- Potential accessibility issues on front page

**Fix**: Update guest front page template to use HTML5 DOCTYPE

**Priority**: HIGH - Affects first impression for new visitors

---

### 3. **Missing/Truncated Meta Descriptions** ✅ FIXED (2025-11-28)

**Previous Issue**: Meta descriptions were truncated mid-word or mid-entity

**Action Taken**:
- Fixed truncation logic in [Application.pm:1228-1238](ecore/Everything/Application.pm#L1228)
- Now truncates at 155 chars at word boundary (not mid-word)
- Properly handles E2 soft link syntax: `[target|display text]` → uses display text
- Strips HTML tags and brackets correctly
- Adds `...` ellipsis only when truncated
- Created comprehensive test suite: [t/045_meta_description.t](t/045_meta_description.t) (7 tests, all passing)

**Example Output**:
```html
<!-- Before: -->
<meta name="description" content="The quick brown fox jumped over the lazy do...">

<!-- After: -->
<meta name="description" content="The quick brown fox jumped over the lazy dog...">
```

**Benefits**:
- ✅ Better click-through rates from search results
- ✅ Professional appearance in search snippets
- ✅ Proper handling of E2 link syntax for natural-reading text
- ✅ Comprehensive test coverage

**Status**: COMPLETE - No further action needed

**Previous Recommendation**:
- E2node pages: Extract first 155 characters of highest-rated writeup, with proper ellipsis
- Writeup pages: Extract first 155 characters of writeup content
- Ensure descriptions are complete sentences when possible
- Example: "The quick brown fox jumped over the lazy dog. A classic pangram used in typography and design."

**Priority**: HIGH - Directly affects click-through rate

---

### 4. **Missing Structured Data (Schema.org)**

**Issue**: Pages have basic schema markup but miss critical content types:
```html
<body class="writeuppage e2node" itemscope itemtype="http://schema.org/WebPage">
```

**What's Missing**:
- Article schema for writeups
- Author information
- Date published/modified
- Aggregate ratings
- Breadcrumb navigation
- CreativeWork schema for poetry/fiction

**Impact**:
- No rich snippets in search results
- Missing featured snippet opportunities
- Lower visibility compared to competitors

**Recommendation**: Implement JSON-LD structured data:

```html
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Article",
  "headline": "Quick brown fox",
  "author": {
    "@type": "Person",
    "name": "normaluser1",
    "url": "https://everything2.com/user/normaluser1"
  },
  "datePublished": "2025-11-27T21:12:43Z",
  "publisher": {
    "@type": "Organization",
    "name": "Everything2",
    "logo": {
      "@type": "ImageObject",
      "url": "https://everything2.com/images/logo.png"
    }
  },
  "description": "The quick brown fox jumped over the lazy dog",
  "articleBody": "The quick brown fox jumped over the lazy dog",
  "genre": ["Creative Writing", "Fiction"],
  "aggregateRating": {
    "@type": "AggregateRating",
    "ratingValue": "5",
    "reviewCount": "1",
    "bestRating": "5"
  }
}
</script>
```

**Priority**: MEDIUM-HIGH - Enables rich search results

---

### 5. **Missing Open Graph and Twitter Card Meta Tags**

**Issue**: Social sharing meta tags are absent

**Impact**:
- Poor preview cards when shared on social media
- Missed referral traffic opportunities
- Unprofessional appearance when linked

**Recommendation**: Add to all pages:

```html
<!-- Open Graph -->
<meta property="og:title" content="Quick brown fox - Everything2.com">
<meta property="og:description" content="The quick brown fox jumped over the lazy dog">
<meta property="og:type" content="article">
<meta property="og:url" content="https://everything2.com/title/Quick+brown+fox">
<meta property="og:site_name" content="Everything2">
<meta property="article:author" content="normaluser1">
<meta property="article:published_time" content="2025-11-27T21:12:43Z">

<!-- Twitter Card -->
<meta name="twitter:card" content="summary">
<meta name="twitter:title" content="Quick brown fox">
<meta name="twitter:description" content="The quick brown fox jumped over the lazy dog">
<meta name="twitter:site" content="@everything2">
```

**Priority**: MEDIUM - Improves social sharing

---

### 6. **Obsolete Social Sharing Buttons** ✅ FIXED (2025-11-28)

**Previous Issue**: Footer included outdated services (Delicious, Digg, StumbleUpon)

**Action Taken**:
- Removed defunct social networks from sharing widget in [htmlcode.pm:9770-9776](ecore/Everything/Delegation/htmlcode.pm#L9770)
- Removed from default list: Delicious (shut down 2017), Digg (deprecated), StumbleUpon (shut down 2018)
- Removed from full list: Yahoo Bookmarks, Google Bookmarks, BlinkList, Magnolia, Windows Live, Propellor, Technorati, Newsvine (all defunct)
- **Currently showing**: Twitter, Facebook, Reddit only

**Benefits**:
- ✅ Only functional sharing links displayed
- ✅ Professional, modern appearance
- ✅ Reduced page clutter
- ✅ Better user experience

**Status**: COMPLETE - No further action needed

---

## Structural Improvements

### 7. **Semantic HTML Elements**

**Current State**: Uses generic `<div>` elements throughout

**Recommendation**: Use HTML5 semantic elements:
- `<header>` for page header
- `<nav>` for navigation
- `<main>` for primary content
- `<article>` for individual writeups
- `<aside>` for sidebar
- `<footer>` for footer
- `<time>` for dates with datetime attribute

**Example**:
```html
<article class="writeup" itemscope itemtype="https://schema.org/Article">
  <header>
    <h1 itemprop="headline">Quick brown fox</h1>
    <p>by <span itemprop="author">normaluser1</span></p>
    <time itemprop="datePublished" datetime="2025-11-27T21:12:43Z">Thu Nov 27 2025 at 21:12:43</time>
  </header>
  <div itemprop="articleBody">
    <p>The quick brown fox jumped over the lazy dog</p>
  </div>
</article>
```

**Priority**: MEDIUM - Improves accessibility and SEO

---

### 8. **Heading Hierarchy Issues**

**Current State**:
- E2node pages: `<h1>` for title ✓
- Guest page: `<h3>` for "Best of The Week", `<h2>` for "News for Noders"
- Missing logical heading structure

**Recommendation**:
- Maintain single `<h1>` per page (page title)
- Use `<h2>` for major sections
- Use `<h3>` for subsections
- Never skip heading levels

**Example**:
```html
<h1>Quick brown fox</h1>
<h2>Writeups</h2>
<article>
  <h3>By normaluser1</h3>
  <!-- writeup content -->
</article>
```

**Priority**: MEDIUM - Affects accessibility and SEO

---

### 9. **Internal Linking Optimization**

**Current State**: Good internal linking via softlinks and content links

**Improvements**:
- Add breadcrumb navigation to all pages
- Implement "Related Content" sections
- Add "Recently Popular" content blocks
- Cross-link between user profiles and their writeups
- Link from writeups to topic/category pages

**Example Breadcrumb**:
```html
<nav aria-label="Breadcrumb">
  <ol itemscope itemtype="https://schema.org/BreadcrumbList">
    <li itemprop="itemListElement" itemscope itemtype="https://schema.org/ListItem">
      <a itemprop="item" href="/">
        <span itemprop="name">Home</span>
      </a>
      <meta itemprop="position" content="1" />
    </li>
    <li itemprop="itemListElement" itemscope itemtype="https://schema.org/ListItem">
      <a itemprop="item" href="/title/Quick+brown+fox">
        <span itemprop="name">Quick brown fox</span>
      </a>
      <meta itemprop="position" content="2" />
    </li>
  </ol>
</nav>
```

**Priority**: MEDIUM - Improves crawlability and user experience

---

### 10. **Image Optimization**

**Current State**: No `<img>` tags observed in sample pages, but likely used elsewhere

**Recommendation**:
- Add `alt` attributes to all images (accessibility + SEO)
- Use descriptive filenames (e.g., `e2-logo.png` not `img123.png`)
- Implement lazy loading for below-fold images
- Serve images in modern formats (WebP with fallbacks)
- Add width/height attributes to prevent layout shift

**Priority**: MEDIUM - If images are used on content pages

---

## Technical SEO Improvements

### 11. **XML Sitemap** ✅ ALREADY IMPLEMENTED

**Current Status**: Site has comprehensive sitemap system at `https://everything2.com/sitemap/index.xml`

**Verified Structure**:
- Sitemap index with 12+ individual sitemaps
- All sitemaps updated daily (lastmod: 2025-11-28)
- Proper XML format following sitemaps.org schema
- Listed in robots.txt: `Sitemap: https://everything2.com/sitemap/index.xml`

**Example**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <sitemap>
    <loc>https://everything2.com/sitemap/1.xml</loc>
    <lastmod>2025-11-28</lastmod>
  </sitemap>
  <!-- ...12+ sitemaps total -->
</sitemapindex>
```

**Recommendation**: ✅ No action needed - Already well implemented

**Priority**: NONE - Already complete and working correctly

---

### 12. **Robots.txt Optimization** ⚠️ NEEDS REVIEW

**Current Status**: robots.txt exists with sitemap reference but blocks several major crawlers

**Current Content**:
```
Sitemap: https://everything2.com/sitemap/index.xml

User-Agent: 008
Disallow: /

user-agent: AhrefsBot
Disallow: /

User-agent: Yandex
Crawl-delay: 2

User-Agent: GPTBot
Disallow: /

User-Agent: DotBot
Disallow: /

User-agent: TerraCotta
Disallow: /
```

**Issues**:
- ✅ Sitemap correctly referenced
- ✅ Blocking AI scrapers (GPTBot) - good for preventing unauthorized LLM training
- ✅ Blocking aggressive SEO tools (AhrefsBot, DotBot) - reduces server load
- ⚠️ Yandex has crawl-delay but not disallowed (acceptable)
- ❓ Should verify 008 and TerraCotta are intended blocks

**Recommendations**:
1. Keep current bot blocks (they're reasonable)
2. Consider adding explicit Allow rules for assets:
   ```
   User-agent: *
   Allow: /css/
   Allow: /js/
   Allow: /*.css$
   Allow: /*.js$
   ```
3. Document the rationale for blocked bots
4. Monitor server logs to ensure no legitimate crawlers are inadvertently blocked

**Priority**: LOW - Current implementation is reasonable, minor optimization possible

---

### 13. **Performance Optimization** 🚀 PARTIALLY IMPLEMENTED

**Current Status**:
- ✅ Static assets served from S3/CDN: `https://s3-us-west-2.amazonaws.com/deployed.everything2.com/`
- ✅ Assets versioned by git commit hash: `/2f6f9eaed92d0d57022e711e17627183a1be8312/`
- ✅ Separate CSS files for screen/print media
- ⚠️ Large inline JSON in `<script id="nodeinfojson">` (multiple KB per page)
- ❌ Using jQuery 1.11.1 (ancient, from 2014)
- ❓ HTML compression/minification status unknown from sample

**Good Practices Already in Place**:
```html
<!-- CDN delivery with cache busting -->
<link rel="stylesheet" href="https://s3-us-west-2.amazonaws.com/deployed.everything2.com/2f6f9eaed92d0d57022e711e17627183a1be8312/1882070.css">

<!-- Separate print stylesheet -->
<link rel="stylesheet" href="...2004473.css" media="print">
```

**Recommendations**:
1. **CRITICAL**: Upgrade jQuery from 1.11.1 to 3.x (security + performance)
2. **HIGH**: Consider lazy-loading window.e2 data or compressing it
3. **MEDIUM**: Add `defer` to non-critical JavaScript
4. **MEDIUM**: Implement preconnect hints for external resources
5. **LOW**: Consider HTTP/2 push for critical CSS

**Example Improvements**:
```html
<link rel="preconnect" href="https://s3-us-west-2.amazonaws.com">
<script src="https://code.jquery.com/jquery-3.7.1.min.js" defer></script>
<script src="/react/main.bundle.js" defer></script>
```

**Priority**: MEDIUM-HIGH - CDN is good, but jQuery upgrade needed for security

---

### 14. **Mobile Optimization**

**Current State**: Has viewport meta tag ✓
```html
<meta name="viewport" content="width=device-width, initial-scale=1.0">
```

**Verify**:
- Responsive design works across devices
- Touch targets are at least 48x48px
- Text is readable without zooming
- No horizontal scrolling

**Priority**: HIGH - Mobile-first indexing is standard

---

## Content Recommendations

### 15. **Page Titles Optimization**

**Current State**:
- Guest page: "Everything2" (good)
- E2node: "Quick brown fox - Everything2.com" (good)
- Writeup: "Quick brown fox (thing) by normaluser1 - Everything2.com" (good)

**Recommendation**: Maintain current format, it's excellent!
- Pattern: `[Title] [(Type)] by [Author] - Everything2.com`
- Keep under 60 characters when possible
- Most important keywords first

**Priority**: NONE - Already well optimized ✓

---

### 16. **URL Structure**

**Current State**:
- `/title/Quick+brown+fox` (e2node)
- `/user/normaluser1/writeups/Quick+brown+fox` (writeup)
- `/` (front page)

**Assessment**: Good, clean URL structure ✓

**Minor Improvement**: Consider URL-encoding spaces as dashes instead of plus signs:
- `/title/quick-brown-fox` (more readable)
- But this would require 301 redirects for all existing URLs

**Priority**: LOW - Current URLs are acceptable

---

### 17. **Content Quality Signals**

**Recommendations**:
- Display word count on writeups (signals substantial content)
- Show "Reading time: X minutes"
- Highlight updated dates for edited writeups
- Display author reputation/level
- Show related articles

**Priority**: LOW-MEDIUM - User experience + dwell time

---

## Implementation Roadmap

### Phase 1: High-Impact Quick Wins (Week 1)
**Focus**: Features that improve search visibility with minimal code changes

1. 🎯 **Update guest page DOCTYPE** to HTML5 (template change only)
2. ✅ **Improve meta descriptions** - Extract first 155 chars properly (DONE 2025-11-28)
3. 🎯 **Add Open Graph tags** to all pages
4. 🎯 **Add Twitter Card tags** to all pages
5. ✅ **Remove obsolete social buttons** (DONE 2025-11-28)

**Estimated Effort**: 4-8 hours (reduced from 8-16, 2 tasks complete)
**Expected Impact**: +10-15% CTR from search results
**Progress**: 2/5 complete (40%)

### Phase 2: Structured Data Implementation (Weeks 2-3)
**Focus**: Rich search results and featured snippets

1. 🎯 **Article schema** for writeups (JSON-LD)
2. 🎯 **Person schema** for author information
3. 🎯 **Breadcrumb schema** for navigation
4. 🎯 **AggregateRating schema** for cooled writeups
5. 🎯 **CreativeWork schema** for poetry/fiction writeups

**Estimated Effort**: 16-24 hours
**Expected Impact**: +20-30% visibility through rich results

### Phase 3: Performance & Security (Weeks 3-4)
**Focus**: Page speed and security improvements

1. 🎯 **Upgrade jQuery** from 1.11.1 to 3.7.1 (CRITICAL for security)
2. 🎯 **Add defer attributes** to non-critical scripts
3. 🎯 **Implement preconnect hints** for CDN
4. 🎯 **Optimize window.e2 data** delivery
5. 🎯 **Review and test** for jQuery compatibility

**Estimated Effort**: 16-32 hours (jQuery upgrade needs testing)
**Expected Impact**: +5-10% rankings (page speed factor)

### Phase 4: Semantic HTML & Accessibility (Weeks 4-5)
**Focus**: Code quality and accessibility

1. 🎯 **Convert divs to semantic elements** (article, nav, aside, etc.)
2. 🎯 **Fix heading hierarchy** across all templates
3. 🎯 **Add ARIA labels** where appropriate
4. 🎯 **Implement breadcrumb navigation** UI
5. 🎯 **Add time elements** with datetime attributes

**Estimated Effort**: 24-40 hours
**Expected Impact**: +5-10% accessibility + UX

### Phase 5: Content Enhancement (Ongoing)
**Focus**: User experience and engagement

1. 🎯 **Add related content sections**
2. 🎯 **Implement "reading time" indicators**
3. 🎯 **Show word count** on writeups
4. 🎯 **Highlight author reputation** badges
5. 🎯 **Cross-link topic/category pages**

**Estimated Effort**: Ongoing improvements
**Expected Impact**: +10-20% dwell time

---

## Measurement & Success Metrics

**Key Performance Indicators**:
- Organic search traffic (target: +30% in 6 months)
- Search impressions (Google Search Console)
- Average click-through rate (target: >3%)
- Page load time (target: <2 seconds)
- Mobile usability score (Google PageSpeed Insights)
- Featured snippets obtained
- Rich result appearances in search

**Tools**:
- Google Search Console
- Google Analytics
- PageSpeed Insights
- Schema.org Validator
- Mobile-Friendly Test

---

## Notes

**Quick Wins** (Implement first):
1. ~~Fix canonical URLs~~ ✅ Already working in production
2. ~~Improve meta descriptions~~ ✅ DONE (2025-11-28)
3. Add Open Graph/Twitter Card tags
4. ~~Remove obsolete social buttons~~ ✅ DONE (2025-11-28)
5. Update guest page to HTML5

**Long-term Strategic**:
1. Structured data implementation (Schema.org JSON-LD)
2. jQuery upgrade (security critical)
3. Semantic HTML elements
4. Performance optimization (defer scripts, preconnect)
5. Content enhancement (related articles, reading time)

---

## Technical Implementation Locations

Based on codebase structure:

**Canonical URL** (Development environment only):
- Already working in production ✅
- Dev environment: Check `ecore/Everything/HTML.pm` or `ecore/Everything/Controller.pm`
- Ensure development environment uses correct base URL configuration

**Meta Tags**:
- Templates in `templates/zen.mc` or `templates/Base.mc`
- Page-specific templates for e2node/writeup pages
- May need Application.pm changes for data extraction

**Structured Data**:
- Add to `templates/pages/*.mc` templates
- Create helper function in Application.pm: `buildStructuredData()`
- Returns JSON-LD formatted data based on page type

**DOCTYPE Fix**:
- Guest front page template (likely `templates/pages/guest_front_page.mc`)

---

## Estimated Impact

**High Impact** (30-50% improvement potential):
- ✅ Canonical URLs already working
- 🎯 Structured data implementation (rich search results)
- ✅ Meta description optimization (CTR increase) - DONE 2025-11-28
- 🎯 Open Graph/Twitter Card tags (social traffic)

**Medium Impact** (15-30% improvement):
- 🎯 jQuery upgrade (page speed + security)
- 🎯 Script optimization (defer, preconnect)
- ✅ Mobile optimization (viewport already set)
- 🎯 Semantic HTML (accessibility)

**Low Impact** (5-15% improvement):
- 🎯 DOCTYPE update (standards compliance)
- 🎯 Heading hierarchy (minor SEO)
- ✅ Social button cleanup (UX) - DONE 2025-11-28
- 🎯 Breadcrumb navigation (UX + minor SEO)

**Total Expected Organic Traffic Increase**:
- **Conservative**: 25-35% within 6 months
- **Optimistic**: 40-60% within 6 months (with full Phase 1-4 implementation)

**Note**: Production site already has solid foundation (canonical URLs, sitemaps, CDN). Improvements focus on rich results, metadata, and modern best practices rather than fixing critical issues.
