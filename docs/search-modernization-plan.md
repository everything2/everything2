# Search Bar Modernization Plan

## Goal
Replace the current search form with a modern autocomplete/typeahead component that helps with content discovery by showing suggestions as users type.

## Current State
- Search form rendered by Mason2 template `templates/helpers/searchform.mi`
- Embedded in header at `templates/zen.mc:76`
- Simple form submission (GET request to `/?node=search_term`)
- No search-as-you-type or suggestions

## Requirements for Modern Search Bar

### User Experience
- **Autocomplete**: Show suggestions as user types (minimum 2-3 characters)
- **Fast response**: Suggestions appear within 100-200ms
- **Keyboard navigation**: Arrow keys to navigate suggestions, Enter to select
- **Click-to-select**: Mouse click on any suggestion navigates to that page
- **No flicker**: Component must be present on initial page load (no React mount delay)
- **Consistent styling**: Match Kernel Blue theme colors and existing header design

### Technical Requirements

#### 1. API Endpoint for Search Suggestions
Create new API endpoint: `/api/search/suggest`

**Request:**
```
GET /api/search/suggest?q=search+term&limit=10
```

**Response:**
```json
{
  "suggestions": [
    {
      "node_id": 12345,
      "title": "Node Title",
      "type": "writeup",
      "relevance": 0.95
    }
  ]
}
```

**Implementation considerations:**
- Use MySQL full-text search or LIKE query on `node.title`
- Limit results to 10 suggestions
- Prioritize exact prefix matches
- Filter out deleted/unlisted nodes
- Cache popular search terms (Redis?)
- Rate limiting to prevent abuse

#### 2. React Component Architecture

**Component**: `SearchBar.js`
- Controlled input with debounced API calls (300ms delay)
- Dropdown suggestion list (absolute positioned)
- Keyboard event handlers (ArrowUp, ArrowDown, Enter, Escape)
- Click-outside-to-close behavior
- Loading state indicator
- Error handling for API failures

**Challenges:**
- Must mount without visual flicker
- Mason `$PAGELOAD` variable can inject content into `<head>` during page render
- Legacy delegation pages expect Mason header structure
- Need consistent behavior across all page types

#### 3. Integration Strategy

**Option A: Full React Header (Phase 4b+)**
- Migrate entire header to React
- Requires server-side rendering or very fast client-side mount
- Solves flicker problem but requires major architecture change
- Incompatible with `$PAGELOAD` injection pattern

**Option B: Hybrid Approach (Progressive Enhancement)**
- Keep Mason header structure
- Replace `<div id="search-form-container">` with React mount point
- Render basic search form as placeholder in Mason
- React hydrates/replaces on page load
- Still has potential flicker issue

**Option C: Server-Side React Rendering**
- Use React SSR to generate search bar HTML on server
- Hydrate on client for interactivity
- Eliminates flicker completely
- Requires build pipeline changes and SSR infrastructure

**Recommended: Wait for Phase 5 (Full React Pages)**
Once we have:
- All critical pages migrated to React
- Ability to render React components server-side
- Clean separation from legacy `$PAGELOAD` injection
- API infrastructure in place

Then implement search bar as part of a fully React-rendered header.

## Deferred Until

### Prerequisites
1. ✅ Phase 3 complete (sidebar fully React)
2. ⏳ Phase 4a complete (most page content in React)
3. ⏳ Phase 4b: Full page React rendering (header + content + sidebar + footer)
4. ⏳ API endpoint for search suggestions created
5. ⏳ Server-side rendering infrastructure (optional but recommended)

### Estimated Timeline
- **API endpoint**: 1-2 days development + testing
- **React component**: 2-3 days development + testing
- **Integration**: 1-2 days (depends on chosen strategy)
- **Total**: ~1 week after prerequisites are met

## Interim Solution
Continue using existing Mason search form until React migration reaches Phase 4b/5.

## Future Enhancements (Post-MVP)
- Search history (localStorage)
- Recent searches
- Popular searches
- Category/type filtering (writeup, user, e2node, etc.)
- Advanced search link
- Search analytics tracking
