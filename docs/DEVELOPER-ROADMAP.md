# Everything2 Developer Roadmap

**Created**: 2025-12-17
**Last Updated**: 2025-12-17
**Status**: Living Document
**Owner**: Jay Bonci

## Executive Summary

This document outlines the comprehensive technical roadmap for Everything2's evolution from legacy architecture to modern, scalable infrastructure. It covers API modernization, revenue optimization, React migration, guest user optimization, SEO improvements, and database optimization - all optimized for our database constraints and rapid iteration development model.

---

## Site History & Architectural Evolution

Everything2 has evolved significantly since its founding in 1999, transitioning through multiple architectural paradigms:

### Era 1: Pure Database Code (1999-2015)
- **Everything stored in database nodes** - Code, templates, content all in MySQL
- **eval() execution at runtime** - Perl code executed from database strings
- **Procedural Perl** - Function-based, no object-oriented patterns
- **Innovation**: Revolutionary for its time - user-editable codebase
- **Legacy**: Security concerns (arbitrary code execution), no profiling, no git history

### Era 2: Delegation Pattern (2015-2020)
- **Code migrated to filesystem** - Database code → Everything::Delegation::* modules
- **Moose OOP adoption begins** - Modern Perl object system introduced
- **Mason2 templates** - Interim MVC layer for server-side rendering
- **Progress**: 81% of database code migrated (222 htmlcode, 99 htmlpage, 47 opcode nodes)
- **Remaining**: 45 achievement nodes, room criteria, 129 superdoc templates with `[% perl %]` blocks

### Era 3: React Integration (2020-2025)
- **REST APIs implemented** - Modern API-first architecture begins
- **React components for interactivity** - 29 components (~1,094 LOC) as of Nov 2025
- **Hybrid rendering** - Server-side Mason + client-side React
- **AWS containerization** - Docker, ECS Fargate, CloudFormation IaC
- **Infrastructure modernization** (Dec 2025):
  - IPv6 dual-stack support
  - CloudFront CDN with origin verification
  - WAF with bot control (later eliminated via S3 caching strategy)
  - HTTP-only internal traffic (ALB→ECS)

### Era 4: Modern Architecture (2025-Present)
- **Full React migration** - 26 nodelets + 21 pages migrated (Nov-Dec 2025)
- **API modernization** - 50+ endpoints, RESTful patterns, comprehensive testing
- **Mason2 elimination** - Only 3 base templates remain
- **Testing infrastructure** - Mock-based unit tests, shared test libraries
- **Developer experience** - Modern tooling, fast iteration, type safety

### Future Target: Modern SPA & Performance (2026+)
- **Full React frontend** - Complete Mason2 elimination
- **PSGI/Plack backend** - Modern Perl application server
- **Mobile-first responsive design** - CSS modernization, touch optimization
- **Guest user optimization** - S3 caching, eliminate 95% of database hits
- **SEO optimization** - Canonical URLs, structured feeds
- **Database modernization** - DBIx::Class ORM, optimized queries
- **Microservices-ready architecture** - Clean API boundaries, independent scaling

**Key Milestones**:
- **1999**: Site founded, everything in database
- **2015**: Delegation pattern migration begins
- **2020**: React integration starts
- **Nov 2025**: All 26 nodelets migrated to React
- **Dec 2025**: API modernization phase begins, testing infrastructure complete
- **Q1 2026**: Guest user optimization (S3 caching) planned
- **2026**: PSGI/Plack migration, full mobile support planned

---

## Current State (December 2025)

### What We Have
- **Legacy APIs**: Originally developed as a tech demo
- **Limited Adoption**: Small developer community (few people)
- **Rapid Iteration Cycle**: Moving fast, breaking things, fixing quickly
- **Infrastructure**: Modern AWS deployment (IPv6, CloudFront, WAF, ALB, ECS)

### What We're Doing Now (Phase 2)
- ✅ **Phase 1 Complete**: Converting legacy APIClient tests to modern mock-based tests
- ✅ **Shared Mock Infrastructure**: Created reusable testing framework
- 🔄 **Making APIs Production-Ready**: Shoring up reliability, testing, documentation
- 🔄 **API Modernization**: Converting command_post patterns to RESTful routes

## Strategic Vision: Phase Overview

### Quick Reference
1. **Phase 1**: Foundation ✅ **COMPLETE** - Modern testing infrastructure established
2. **Phase 2**: API Cleanup ⏳ **CURRENT** - Production-ready APIs with full test suite and docs
3. **Phase 2.5**: Stylesheet Validation 🔜 **NEXT** - Gate before shipping major features
4. **Phase 3**: Revenue Optimization 💰 **AFTER PHASE 2.5** - Maximize AdSense, improve guest UX, increase engagement
5. **Phase 4**: React Migration 🔜 **AFTER PHASE 3** - Documents, htmlpages, writeups, e2nodes
6. **Phase 5**: Container/Mason Consolidation 🔜 **AFTER PHASE 4** - React renders entire page, eliminate legacy.js
7. **Phase 5.5**: Search Enhancements & Live Search 🔍 **AFTER PHASE 5** - Autocomplete, better relevance, mobile search
   - **5.5a**: Search API Backend (Week 1-2) - Multi-field ranking, relevance scoring
   - **5.5b**: Live Search React Component (Week 2-3) - As-you-type autocomplete
   - **5.5c**: Search Analytics (Week 3) - Track queries, optimize results
   - **5.5d**: Mobile Search UI (Week 4) - Full-screen mobile search
   - **5.5e**: Testing & Performance (Week 4) - E2E tests, load testing
8. **Phase 6**: Guest User Optimization 🔥 **Q1 2025** - S3 caching, eliminate DB hits for guests (requires full React + no legacy.js)
9. **Phase 6.5**: Mobile Display & CSS Modernization 📱 **CRITICAL GAP** - Mobile-responsive design, touch optimization
   - **6.5a**: CSS Audit & Variable Completion (Week 1) - Complete CSS variable migration
   - **6.5b**: Mobile Breakpoints & Responsive Grid (Week 2) - 320px-1200px responsive grid
   - **6.5c**: Mobile Navigation (Week 3) - Hamburger menu, touch-friendly controls
   - **6.5d**: Touch Optimization (Week 4) - 44px touch targets, swipe gestures
   - **6.5e**: Layout Testing (Week 5) - Multi-device testing, edge cases
   - **6.5f**: Kernel Blue CSS Removal (Week 6) - Eliminate legacy kernel.css
   - **6.5g**: Mobile Performance Optimization (Week 7) - Reduce bundle size, optimize images
   - **6.5h**: Documentation & Rollout (Week 8) - Mobile guidelines, user communication
10. **Phase 7**: FastCGI/PSGI Migration 🔧 **INFRASTRUCTURE CLEANUP** - Move from mod_perl to modern PSGI/Plack
11. **Phase 8**: SEO Optimization 🔍 **AFTER INFRASTRUCTURE** - SEO-friendly URLs, canonical links, structured feeds
12. **Phase 9**: Database Optimization 🔮 **FUTURE** - Address primary bottleneck
13. **Phase 9.5**: Settings/Preferences Modernization 🔧 **TECHNICAL DEBT** - Move from VARS to structured settings
   - **9.5a**: Settings Audit (Week 1) - Catalog all VARS, categorize settings
   - **9.5b**: JSON Schema Definition (Week 2) - Define structured schema
   - **9.5c**: Migration Script (Week 3-4) - VARS → new settings format
   - **9.5d**: API Updates (Week 5) - RESTful preferences API
   - **9.5e**: Backward Compatibility Layer (Week 6) - Support legacy VARS access
   - **9.5f**: React Integration (Week 7) - Settings UI components
   - **9.5g**: Legacy VARS Deprecation (Week 8) - Remove old VARS code
14. **Phase 10**: Social Login Integration 👥 **USER ACQUISITION** - Google/Facebook/Apple login to reduce signup friction
15. **Phase 11**: MySQL 8.4 Migration ⚡ **INFRASTRUCTURE** - Upgrade before RDS LTS sunset (priority may increase near deadline)
16. **Phase 12**: React 19 Migration 🔧 **FRONTEND** - Upgrade to React 19 after Phase 4-5 complete (React Compiler, better performance)

---

## Detailed Phase Breakdown

### Phase 1: Foundation ✅ COMPLETE (Dec 2025)
**Goal**: Establish robust testing infrastructure and convert legacy tests

**Completed Work**:
- Converted 6 APIClient tests to mock-based (172 tests passing)
- Created shared MockUser/MockRequest infrastructure (t/lib/)
- Modernized vote.pm and cool.pm to RESTful routes
- Documented API gaps and improvements needed

**Why This Matters**:
- Can iterate quickly with confidence
- Tests run in seconds, not minutes
- Clear patterns for future API development

**Files Created**:
- `t/lib/MockUser.pm` - Comprehensive mock user class
- `t/lib/MockRequest.pm` - Mock request wrapper
- `t/060_writeups_api.t` through `t/065_e2nodes_api.t` - 6 new test files

**Documentation**:
- [api-test-conversion-summary.md](api-test-conversion-summary.md)
- [SHARED-MOCKS-REFACTORING.md](SHARED-MOCKS-REFACTORING.md)
- [api-improvements-needed.md](api-improvements-needed.md)

---

### Phase 2: API Cleanup and Consolidation (Current Phase)
**Goal**: Production-ready APIs with comprehensive testing and documentation

**Why This Phase**:
- APIs were initially tech demos, not production code
- Limited developer adoption requires bulletproof reliability
- Rapid iteration needs comprehensive test coverage
- Documentation enables community contribution

**Work Required**:

**2a. API Testing (Week 1-3)**:
- Add edge case tests for all APIs (security, validation, error handling)
- Create smoke tests for every API endpoint
- Document test coverage in API.md
- Target: 100% of APIs have comprehensive test coverage

**2b. API Documentation (Week 4)**:
- Document all 50 APIs in API.md
- Include parameters, return values, error codes, examples
- Add test coverage metrics to each API
- Target: Every API fully documented with examples

**2c. API Consolidation (Week 5-6)**:
- Continue converting command_post patterns to RESTful routes
- Standardize response formats
- Improve error messages and validation
- Target: Consistent API patterns across all endpoints

**Success Metrics**:
- [ ] 100% of APIs have unit tests (mock-based)
- [ ] 100% of APIs have smoke tests
- [ ] All APIs documented in API.md
- [ ] All command_post patterns converted to RESTful routes
- [ ] Edge cases covered (SQL injection, XSS, boundary values)

**Timeline**: 6-8 weeks (Current Phase)

**Blocking Issues**:
- None - can proceed independently

**See Also**: [api-testing-plan.md](api-testing-plan.md) for detailed testing strategy

---

### Phase 2.5: Stylesheet Validation (Gate Before Phase 3)
**Goal**: Verify barely-supported stylesheets still work before shipping e2node/writeup APIs

**Context**:
- E2 has multiple legacy stylesheets with minimal support
- React migration may have inadvertently broken some stylesheet features
- Need to verify nothing is "outright broken" before shipping major features
- **NOT tackling CSS variables** - that's future work

**Work Required**:
- Minor scrub of only-barely-supported stylesheets
- Test major UI components with different stylesheets
- Fix any glaring breakages
- Document known issues (but don't fix minor problems)

**Gate Criteria**:
- No major visual breakage in any supported stylesheet
- Core functionality works (navigation, reading, voting, cooling)
- UI is usable even if not perfect
- Document any known minor issues for future work

**Timeline**: Quick pass before starting Phase 3 work

---

### Phase 3: Revenue Optimization (After Phase 2.5)
**Goal**: Maximize AdSense revenue by increasing monetizable page views and improving guest user experience

**Context**:
- **Financial sustainability** - AdSense is primary revenue source
- **Guest user focus** - Most traffic is anonymous users
- **Prerequisite for React migration** - Optimize revenue before major architectural changes
- **Low-risk, high-return** - Incremental improvements with measurable impact

**Current Challenges**:
- **Limited ad placement opportunities** - Not all pages monetized
- **Ad experience issues** - Ads may interfere with user experience
- **Guest user bounce rate** - Users leave quickly without engaging
- **Content discoverability** - Valuable content not surfaced effectively

**Target State**:
1. **Maximize monetizable pages**
   - Ensure AdSense on all appropriate guest-accessible pages
   - Remove barriers to ad display (technical, content policy)
   - Optimize ad placement without degrading UX

2. **Improve guest user engagement**
   - Encourage longer sessions (more page views = more ad impressions)
   - Better content navigation and discovery
   - Reduce bounce rate on landing pages

3. **Optimize ad experience**
   - Balance revenue with user experience
   - A/B test ad placements and formats
   - Monitor ad performance metrics
   - Ensure ads don't break mobile experience

**Implementation Strategy**:

**Phase 3a: Ad Coverage Audit (Week 1-2)**

Identify pages without ads and evaluate opportunities:

```perl
# Audit ad placement across page types
my %page_types = (
    'e2node'    => { has_ads => 1, monetizable => 1 },
    'writeup'   => { has_ads => 1, monetizable => 1 },
    'user'      => { has_ads => 0, monetizable => 1 },  # Add ads?
    'superdoc'  => { has_ads => 0, monetizable => 0 },  # Policy pages
    'document'  => { has_ads => 1, monetizable => 1 },
    # ... audit all page types
);
```

**Deliverables**:
- Spreadsheet of all page types with ad status
- List of pages where ads can be added
- List of technical barriers to ad display
- AdSense policy review (which pages CAN'T have ads)

**Phase 3b: Ad Placement Optimization (Week 3-4)**

Implement ads on newly identified pages:

```javascript
// React component for flexible ad placement
function AdUnit({ slot, format, className }) {
    return (
        <div className={`ad-container ${className}`}>
            <ins className="adsbygoogle"
                 style={{ display: 'block' }}
                 data-ad-client="ca-pub-XXXXXXXXXXXXXXXX"
                 data-ad-slot={slot}
                 data-ad-format={format}
                 data-full-width-responsive="true">
            </ins>
        </div>
    );
}

// Usage in page components
<AdUnit slot="1234567890" format="auto" className="content-ad" />
```

**Ad Placement Strategy**:
- **In-content ads**: Between writeups, after every 3-4 writeups
- **Sidebar ads**: In nodelet area for desktop users
- **Mobile ads**: Bottom sticky ads (non-intrusive)
- **Avoid**: Ads on login, signup, settings pages (policy violation)

**Deliverables**:
- Ad components in React (AdUnit, StickyAd, InContentAd)
- Ads deployed to 90%+ of guest-accessible pages
- A/B test framework for ad placement experimentation

**Phase 3c: Guest User Engagement (Week 5-6)**

Improve content discovery and navigation:

**Related Content Recommendations**:
```javascript
// In WriteupDisplay component
function RelatedWriteups({ currentNodeId }) {
    const [related, setRelated] = useState([]);

    useEffect(() => {
        fetch(`/api/recommendations/node/${currentNodeId}`)
            .then(r => r.json())
            .then(data => setRelated(data.recommendations));
    }, [currentNodeId]);

    return (
        <div className="related-content">
            <h3>You might also enjoy:</h3>
            <ul>
                {related.map(node => (
                    <li key={node.node_id}>
                        <Link to={`/node/${node.node_id}`}>{node.title}</Link>
                    </li>
                ))}
            </ul>
        </div>
    );
}
```

**Engagement Features**:
- **Related content links**: Surface similar/related writeups
- **Popular content widgets**: Trending today, popular this week
- **Better search**: Improved search results, "did you mean" suggestions
- **Reading progress**: "You've read X writeups, explore more in this category"
- **Guest user onboarding**: Show value prop, encourage exploration

**Deliverables**:
- Recommendations API endpoint
- Related content components
- Popular content widgets
- Improved guest user onboarding flow

**Phase 3d: Performance Optimization for Ads (Week 7)**

Ensure ads don't degrade user experience:

```javascript
// Lazy load ads using IntersectionObserver
function LazyAd({ slot, format }) {
    const [isVisible, setIsVisible] = useState(false);
    const adRef = useRef(null);

    useEffect(() => {
        const observer = new IntersectionObserver(
            ([entry]) => {
                if (entry.isIntersecting) {
                    setIsVisible(true);
                    observer.disconnect();
                }
            },
            { rootMargin: '200px' } // Load 200px before visible
        );

        if (adRef.current) {
            observer.observe(adRef.current);
        }

        return () => observer.disconnect();
    }, []);

    return (
        <div ref={adRef}>
            {isVisible && <AdUnit slot={slot} format={format} />}
        </div>
    );
}
```

**Performance Optimizations**:
- **Lazy loading**: Load ads only when near viewport
- **Async loading**: Don't block page rendering
- **Resource hints**: Preconnect to ad domains
- **Mobile optimization**: Smaller ad units, fewer ads on mobile

**Phase 3e: Analytics and Iteration (Week 8)**

Measure impact and iterate:

**Metrics to Track**:
- **Ad coverage**: % of pages with ads (target: 90%+)
- **Ad impressions**: Total impressions per day (baseline + growth)
- **RPM (Revenue per Mille)**: Revenue per 1000 impressions
- **Guest user engagement**:
  - Pages per session (target: +15%)
  - Bounce rate (target: -15%)
  - Session duration (target: +20%)
- **User experience**:
  - Page load time (should not degrade)
  - Mobile usability score
  - User complaints (monitor feedback)

**A/B Testing Framework**:
```javascript
// Simple A/B test for ad placement
function ExperimentalAdPlacement({ nodeId }) {
    const variant = getUserVariant(nodeId); // A or B

    if (variant === 'A') {
        return <AdUnit slot="1234" format="rectangle" />;
    } else {
        return <AdUnit slot="5678" format="horizontal" />;
    }
}
```

**Success Metrics**:
- [ ] AdSense coverage on 90%+ guest-accessible pages
- [ ] 20% increase in ad impressions (more page views)
- [ ] 10% improvement in RPM (better placement/engagement)
- [ ] 15% reduction in bounce rate
- [ ] 15% increase in pages per session
- [ ] No degradation in page load times

**Timeline**: 8 weeks (can run in parallel with Phase 2 completion)

**Why This Phase is Important**:
- **Financial runway**: Increased revenue funds React migration work
- **User engagement**: Better guest experience supports all future phases
- **Low risk**: Incremental changes, easy to roll back if issues arise
- **Measurable**: Clear metrics for success/failure
- **Foundation**: Improves guest user experience as a side benefit
- **Analytics**: Sets up better analytics infrastructure for future optimization

---

### Phase 4: React Migration - Documents and Htmlpages (After Phase 3)
**Goal**: Complete React-based conversion of remaining server-side rendered content

**Context**:
- **Prerequisite**: Phase 3 (Revenue Optimization) and Phase 2.5 (Stylesheet Validation) must be complete
- **Not urgent** - No current CPU load issues on webservers
- **Long-term scalability** - Proactive infrastructure improvement
- **Database remains bottleneck** - CPU load is fine, but database connections are the constraint

**Primary Migration Targets**:
1. **Everything::Delegation::document** - Document rendering logic → React components
2. **Everything::Delegation::htmlpages** - HTML page generation → React components

**Important Notes on Htmlpages**:
- **Htmlpages are internally facing** - Admin/developer tools, not user-facing content
- **Will use developer source map** - Code will no longer be editable in database
- Migrating to filesystem-based React components improves maintainability
- Source control for admin tools (version history, code review, etc.)

**High-Traffic User-Facing Content** (Part of Phase 4):
1. **Writeup Display API + React Component** - Individual writeup rendering
2. **E2node Display API + React Component** - Node page rendering

**Why This Migration Matters**:
- Move editable content out of database (htmlpages → filesystem)
- Standardize on React for all UI rendering
- Enable better tooling (linting, testing, source maps)
- Improve developer experience with modern workflows

**Current Architecture Challenge**:
```
User Request → Apache/mod_perl → Mason Templates → Database
                    ↓
              Heavy server-side rendering
              Blocking I/O operations
              Database connections tied up during rendering
```

**Target Architecture**:
```
User Request → CloudFront → React Frontend
                              ↓
                         API Calls (async)
                              ↓
                         Cached JSON responses (CloudFront edge)
                              ↓
                         Database (optimized queries, fewer connections)
```

**Why This Matters for Scalability**:
- **Database connection pooling** - Shorter-lived API calls vs long rendering cycles
- API responses can be cached at CloudFront edge
- Async loading reduces perceived latency
- Progressive enhancement (load content as needed)
- Better separation of concerns (frontend/backend)

**Benefits**:
- Offload rendering from webserver to browser
- Cache API responses at CDN edge (CloudFront)
- Reduce database round-trips with optimized JSON queries
- Enable client-side caching and optimistic updates
- Scale reads independently from writes

#### Critical Architectural Constraint: React Routing Challenge

**The Problem**: Everything2's node-based architecture creates a unique routing challenge for React-based routing.

**Current System**:
- Nodes can be accessed by **node_id** (numeric) OR **title** (string)
- URLs like `/node/123` or `/title/Some+Title` both work
- **No execution context from URL alone** - You can't determine what type of content you're rendering without querying the database first
- Example: Is node_id 123 an e2node? A writeup? A user profile? A superdoc? Unknown until you query.

**Why This Breaks Traditional React Routing**:
```javascript
// ❌ DOESN'T WORK - Can't determine which component to render
<Route path="/node/:id" component={???} />  // What component? Unknown!

// ❌ DOESN'T WORK - Would need database query before React even loads
// React needs to know which component to mount, but determining that requires:
// 1. Query database for node_id
// 2. Check node type
// 3. Route to appropriate component
// This is a chicken-and-egg problem
```

**Current Server-Side Solution**:
```perl
# Server does this BEFORE rendering any HTML
my $node = $DB->getNodeById($node_id);
my $type = $node->{type}{title};  # e2node, writeup, user, etc.
# Then routes to appropriate Page class based on type
```

**The Challenge for Phase 4**:
- **React needs to know what to render** - But determining that requires a database query
- **Can't make database queries from client-side routing** - Guest users shouldn't hit database
- **Server-side rendering** (SSR) would work but defeats the purpose of Phase 6 (guest caching)

**Potential Solutions** (To Be Evaluated):

1. **Hybrid Approach - Initial Server Context**:
   ```
   Server renders minimal HTML shell with node metadata in data attributes:
   <div id="root" data-node-type="e2node" data-node-id="123">
   React reads data attributes and routes to appropriate component
   ```
   - **Pro**: Single database query, then React takes over
   - **Pro**: Works with guest caching (cache the HTML shell)
   - **Con**: Still requires initial server hit for node metadata

2. **API-First Routing with Metadata Endpoint**:
   ```
   GET /api/node/123/metadata → {type: "e2node", title: "..."}
   React queries metadata API, then routes to appropriate component
   ```
   - **Pro**: Clean separation of concerns
   - **Pro**: Metadata can be cached at CloudFront edge
   - **Con**: Extra API roundtrip for every page load
   - **Con**: Guest users still hit an API (though cached)

3. **URL Convention Change** (Breaking change):
   ```
   /e2node/123 - Explicit type in URL
   /writeup/456 - Explicit type in URL
   /node/123 - Redirect to canonical URL with type
   ```
   - **Pro**: React can route directly without database query
   - **Pro**: SEO-friendly, semantic URLs
   - **Con**: BREAKING CHANGE - All existing links break
   - **Con**: Would need massive redirect infrastructure

4. **Server-Side Rendering (SSR) for Initial Load**:
   ```
   Server renders full React component on first load
   Client-side React hydrates and takes over routing
   ```
   - **Pro**: Best of both worlds (SEO + React)
   - **Pro**: No routing ambiguity
   - **Con**: Defeats Phase 6 guest optimization (still hits server/database)
   - **Con**: Complex infrastructure (Node.js SSR + Perl backend)

**Recommended Approach** (Based on Current Architecture):

**Page Context API - Leveraging Everything::Application**:

The solution is to extract the page context building logic that already exists in Everything::Application and expose it as an API.

**Current Architecture** (`Everything::Application`):
```perl
# Everything::Application already builds page context:
sub buildPageContext {
    my ($self, $node_id_or_title) = @_;

    # Resolves node by ID or title
    my $node = $self->resolveNode($node_id_or_title);

    # Determines type and builds context
    my $type = $node->{type}{title};
    my $page_class = $self->getPageClass($type);

    # Returns context with all metadata needed for rendering
    return {
        node_id => $node->{node_id},
        title => $node->{title},
        type => $type,
        page_class => $page_class,
        # ... other context data
    };
}
```

**New API Endpoint** (`Everything::API::page_context` or similar):
```perl
# GET /api/page/context?node_id=123
# GET /api/page/context?title=Some+Title

sub get_context {
    my ($self, $REQUEST) = @_;

    # Single Everything::Application call (or extracted module)
    my $context = $APP->buildPageContext(
        $REQUEST->param('node_id') || $REQUEST->param('title')
    );

    return [$self->HTTP_OK, $context];
}
```

**Implementation Strategy**:
1. **Extract existing logic** from Everything::Application's page routing
2. **Create API endpoint** that returns page context (node type, metadata, routing info)
3. **Cache at CloudFront** - Context is static per URL, highly cacheable
4. **React queries context API** on initial load
5. **React routes** to appropriate component based on context.type
6. **React makes additional API calls** for dynamic content as needed

**Flow**:
```
1. User requests: /node/123
2. Server returns minimal HTML shell (cached at CloudFront for guests)
3. React mounts and queries: GET /api/page/context?node_id=123
   - This API call is ALSO cached at CloudFront (per URL)
   - For guests: Both HTML and context API are served from edge cache
4. API returns: {type: "e2node", node_id: 123, title: "...", ...}
5. React routes to <E2NodeDisplay> component
6. Component makes additional API calls as needed (also cached)
```

**Benefits**:
- ✅ **Leverages existing code** - Everything::Application already does this
- ✅ **Single source of truth** - Page context logic in one place
- ✅ **Highly cacheable** - Context rarely changes (cache at CloudFront edge)
- ✅ **Guest optimization compatible** - Works with Phase 6 S3 caching
- ✅ **No breaking changes** - All existing URLs continue to work
- ✅ **Incremental migration** - Can migrate page types one at a time

**Success Metrics**:
- [ ] All document types migrated to React components
- [ ] All htmlpages migrated to React components (developer source map)
- [ ] E2node/writeup display fully React-based
- [ ] Context API implemented and cached at CloudFront
- [ ] Database queries reduced (fewer N+1 patterns)
- [ ] Webserver load reduced (rendering moved to client)

**Timeline**: After Phase 3 (Revenue Optimization) complete

---

### Phase 4 Partial Completion Summary ✅ (Nov-Dec 2025)

**Status**: Phase 4a COMPLETE - Nodelets & Content Documents Migrated

While full Phase 4 (all documents/htmlpages/writeups/e2nodes) is still in progress, significant foundational work has been completed:

#### ✅ Completed Work (Phase 4a)

**All 26 Sidebar Nodelets Migrated** (Nov 21-24, 2025):
- Vitals, SignIn, NewWriteups, RecommendedReading, NewLogs, EverythingDeveloper, NeglectedDrafts, RandomNodes
- Epicenter, ReadThis, MasterControl, Chatterbox (with React polling), Notifications (with dismiss)
- OtherUsers (10+ social features), ForReview, PersonalLinks, Messages, EverythingUserSearch
- Bookmarks, Categories, CurrentUserPoll, FavoriteNoders, MostWanted, RecentNodes, UsergroupWriteups, CoolArchive

**21 Content Pages Migrated** (Nov 28, 2025):
- **18 content documents**: about_nobody, wheel_of_surprise, silver_trinkets, sanctify, seasonal pages (christmas, halloween, new year, april fools), a_year_ago_today, node_tracker2, your_ignore_list, your_insured_writeups, your_nodeshells, recent_node_notes, ipfrom, everything2_elsewhere, online_only_msg, chatterbox_help_topics
- **3 special pages**:
  - Full-Text Search (Google CSE integration) → [FullTextSearch.js](../react/components/Documents/FullTextSearch.js)
  - Sign Up (user registration with reCAPTCHA v3) → [SignUp.js](../react/components/Documents/SignUp.js)
  - Maintenance Display (system status)

**Architecture Improvements**:
- ✅ React owns entire sidebar (all 26 nodelets)
- ✅ React owns content area for migrated pages
- ✅ Double rendering issue fixed (react_handled flags)
- ✅ Controller optimization (eliminated 16+ nodelet-specific methods)
- ✅ 50+ API endpoints created for React components

**Current State**:
- Mason2 page templates: Only 3 base templates remain (react_page.mc, react_fullpage.mc, Base.mc)
- All user-facing content pages: React-rendered
- Remaining work: High-traffic pages (writeup, user, e2node, etc.) - see Phase 4b below

**Documentation**: See [mason2-migration-status.md](mason2-migration-status.md) for detailed status

#### 🔲 Remaining Work (Phase 4b-c)

**Phase 4b: React Owns Page Structure** (Future - Q1 2026)
- React controls full page layout (header, footer, wrapper)
- Mason-rendered content injected as HTML for non-migrated pages
- Enables incremental migration of remaining page types

**Phase 4c: High-Traffic Page Migration** (Future - Q2-Q4 2026)
- Writeup display pages (~30-40% of traffic)
- User profile pages
- E2node pages
- Usergroup, poll, search, and other page types (~30-40 types remain)

**Decision**: Defer Phase 4b-c until after Phase 6 (Guest User Optimization) and Phase 7 (PSGI/Plack Migration) to prioritize infrastructure modernization.

---

### Phase 5: Container/Mason Template Consolidation (After Phase 4)
**Goal**: Eliminate differentiation between Everything::Delegation::container and Mason templates, making React render the entire page

**Context**:
- After document and htmlpage migration to React, Mason templates will be simplified
- **Mason templates will act as light shell** - Minimal logic, primarily routing to React
- This is an interim state while we complete the migration phases
- Eventually, most Mason functionality will be replaced by React + API architecture

**Current State**:
- Everything::Delegation::container provides container logic
- Mason templates (.mc files) handle page structure and rendering
- Duplication between container delegation and Mason template logic
- Mason templates have significant embedded Perl logic
- **legacy.js** contains jQuery-based interactivity scattered throughout the codebase

**Target State**:
- **Mason templates as thin routing layer** - Minimal Perl, mostly just:
  - Request routing to appropriate Everything::Page
  - Initial HTML shell for React mounting
  - Meta tags and basic SEO elements
- **React components handle all UI rendering** - Complete page rendering in React
- **Eliminate legacy.js** - All JavaScript moved to React components
- APIs provide all data
- Container logic moved to appropriate layers (Page classes, APIs, Application.pm)

**Work Required**:
1. Audit current Mason template usage
2. Identify logic that should move to Page classes
3. Identify logic that should move to APIs
4. Identify logic that should move to Application.pm
5. Simplify Mason templates to minimal routing shells
6. **Migrate legacy.js functionality to React components**
   - Audit all legacy.js functions
   - Identify jQuery dependencies
   - Create React equivalents for interactive features
   - Test all functionality in React
7. **Remove legacy.js** after migration complete
8. Document the new separation of concerns

**Legacy.js Migration Strategy**:

**Current legacy.js Issues**:
- jQuery-based (old library, security concerns)
- Global functions scattered across files
- Difficult to test
- No module system
- Hard to track dependencies

**Migration Approach**:
```javascript
// ❌ OLD - legacy.js with jQuery
$(document).ready(function() {
    $('.vote-button').click(function() {
        var writeupId = $(this).data('writeup-id');
        $.post('/api/vote', { writeup_id: writeupId }, function(data) {
            $('.vote-count').text(data.votes);
        });
    });
});

// ✅ NEW - React component
function VoteButton({ writeupId, initialVotes }) {
    const [votes, setVotes] = useState(initialVotes);
    const [loading, setLoading] = useState(false);

    const handleVote = async () => {
        setLoading(true);
        const response = await fetch(`/api/vote/writeup/${writeupId}`, {
            method: 'POST',
            credentials: 'include'
        });
        const data = await response.json();
        setVotes(data.votes);
        setLoading(false);
    };

    return (
        <button onClick={handleVote} disabled={loading}>
            Vote ({votes})
        </button>
    );
}
```

**Why This Matters**:
- Reduces complexity and duplication
- Clear separation of concerns (routing vs rendering vs data)
- Easier to maintain and reason about
- Prepares for potential future migration away from Mason entirely
- **Gateway to FastCGI/PSGI migration** - Thin routing layer is ideal for FastCGI
- **Enables Phase 6 guest caching** - No client-side JS to worry about for cached pages
- **Security improvement** - Modern React patterns vs legacy jQuery
- **Page load performance** - Eliminating legacy jQuery significantly speeds up page loads

**Performance Benefits of jQuery Elimination**:

**Current State** (with legacy.js + jQuery):
```html
<script src="/js/jquery.min.js"></script>  <!-- ~85KB minified -->
<script src="/js/legacy.js"></script>      <!-- ~150KB of jQuery-dependent code -->
```
- **~235KB JavaScript** to download and parse
- **jQuery initialization overhead**: ~50-100ms on page load
- **Global jQuery scope pollution**: Slows down all JS execution
- **Blocking parser**: Old jQuery patterns block HTML parsing

**Target State** (React only):
```html
<!-- React bundle already loaded for page rendering -->
<!-- NO additional jQuery download needed -->
```
- **~0KB additional JavaScript** (React already loaded for UI)
- **No jQuery initialization**: React is already running
- **Clean module scope**: Faster execution, better optimization
- **Non-blocking**: Modern ES6 modules don't block parser

**Expected Performance Improvements**:
- **Page load time**: 20-30% faster (especially on slow connections)
- **Time to Interactive**: 200-400ms improvement (no jQuery parse)
- **Bundle size**: Reduce by 235KB (~20% smaller)
- **Mobile performance**: Significantly faster on low-end devices
- **Lighthouse score**: +5-10 points in performance metric

**Security Benefits of Eliminating Inline JavaScript**:

As React migration completes and jQuery is eliminated, inline JavaScript blocks in Perl code are also removed:

**Current State** (inline JavaScript in htmlcode.pm, document.pm):
- ~200-300 lines of inline JS scattered across Perl strings
- Inline event handlers (`onclick=`, `onload=`)
- Dynamic script generation with `eval()`
- **Blocks Content Security Policy** - Cannot enable CSP with inline scripts

**After React Migration**:
- All interactivity handled by React components
- No inline `<script>` tags needed
- No inline event handlers
- **Enables Content Security Policy (CSP)**:
  ```http
  Content-Security-Policy:
    default-src 'self';
    script-src 'self' https://deployed.everything2.com;
    style-src 'self' https://deployed.everything2.com;
  ```

**CSP Benefits**:
- **Prevents XSS attacks** - No inline script execution
- **Blocks unauthorized scripts** - Only whitelisted sources
- **Modern security best practice** - Industry standard
- **Reduced attack surface** - Limits what attackers can inject

**Timeline**: After Phase 4 document/htmlpage migration complete

**Key Deliverable**: Once this phase is complete:
- ✅ React renders the entire page
- ✅ All legacy.js + jQuery eliminated (235KB JavaScript removed)
- ✅ Mason templates reduced to thin routing shells
- ✅ 20-30% faster page loads
- ✅ Better mobile performance
- ✅ Ready for Phase 6 guest user optimization
- ✅ Infrastructure ready for Phase 7 FastCGI/PSGI migration

---

### Phase 5.5: Search Enhancements & Live Search
**Goal**: Improve search functionality with live search, better relevance, and mobile-optimized search UI

**Context**:
- **Prerequisite**: Phase 5 complete (React infrastructure in place)
- **Why now**: Search is critical for user experience and SEO
- **Builds on**: React component infrastructure from Phase 4-5
- **Enables**: Better user engagement before mobile optimization (Phase 6.5)

**Current State - Search Limitations**:
- **Basic search**: Simple MySQL FULLTEXT search
  - No ranking/relevance scoring
  - Poor handling of multi-word queries
  - No stemming or fuzzy matching
  - Limited to title/body text
- **No live search**: Users must submit form and wait for full page load
- **Poor mobile UX**: Desktop-oriented search form
- **No search analytics**: Can't track what users search for

**Target State**:
1. **Live Search (Autocomplete)**:
   - As-you-type suggestions
   - Show top 5-10 results instantly
   - Highlight matching text
   - Keyboard navigation (arrow keys, Enter)

2. **Improved Search Relevance**:
   - Multi-field ranking (title weight > body)
   - Boost recent/popular content
   - Typo tolerance (fuzzy matching)
   - Phrase matching

3. **Mobile-Optimized Search UI**:
   - Full-screen search on mobile
   - Touch-optimized result cards
   - Clear/cancel buttons
   - Recent searches saved locally

4. **Search Analytics**:
   - Track popular searches
   - Identify zero-result queries
   - A/B test ranking algorithms

**Implementation Plan**:

**Phase 5.5a: Search API Backend (Week 1-2)**

Create dedicated search API endpoint with better relevance:

```perl
# ecore/Everything/API/search.pm
package Everything::API::search;
use Moose;
extends 'Everything::API';

sub quick_search {
    my ($self, $REQUEST) = @_;

    my $query = $REQUEST->param('q') || '';
    my $limit = $REQUEST->param('limit') || 10;

    # Sanitize query
    $query =~ s/[^\w\s]//g;
    return [$self->HTTP_OK, { success => 0, results => [] }] if length($query) < 2;

    # Multi-field search with relevance scoring
    my $sql = qq{
        SELECT
            n.node_id,
            n.title,
            n.createtime,
            t.title as type,
            -- Relevance scoring
            (
                MATCH(n.title) AGAINST(? IN BOOLEAN MODE) * 10 +  -- Title weight: 10x
                MATCH(d.doctext) AGAINST(? IN BOOLEAN MODE) * 1    -- Body weight: 1x
            ) as relevance,
            -- Excerpt with matching text
            SUBSTRING(d.doctext, 1, 200) as excerpt
        FROM node n
        INNER JOIN node t ON n.type_nodetype = t.node_id
        LEFT JOIN document d ON n.node_id = d.document_id
        WHERE
            (MATCH(n.title) AGAINST(? IN BOOLEAN MODE)
             OR MATCH(d.doctext) AGAINST(? IN BOOLEAN MODE))
            AND n.type_nodetype IN (
                -- Only searchable types
                SELECT node_id FROM node WHERE title IN ('writeup', 'e2node', 'user')
            )
        ORDER BY relevance DESC, n.createtime DESC
        LIMIT ?
    };

    my @results = $DB->sqlSelectMany($sql, $query, $query, $query, $query, $limit);

    # Format results
    my @formatted = map {
        {
            node_id => $_->{node_id},
            title => $_->{title},
            type => $_->{type},
            excerpt => $self->highlightQuery($_->{excerpt}, $query),
            url => "/node/$_->{node_id}",
            createtime => $_->{createtime},
        }
    } @results;

    return [$self->HTTP_OK, {
        success => 1,
        query => $query,
        results => \@formatted,
        count => scalar(@formatted),
    }];
}

sub highlightQuery {
    my ($self, $text, $query) = @_;

    # Highlight matching words in excerpt
    my @words = split /\s+/, $query;
    foreach my $word (@words) {
        $text =~ s/\b(\Q$word\E)\b/<mark>$1<\/mark>/gi;
    }

    return $text;
}

__PACKAGE__->meta->make_immutable;
1;
```

**API Routes**:
```perl
# In Everything::Application routing
{
    path => '/api/search/quick',
    api_class => 'Everything::API::search',
    method => 'quick_search',
    auth_required => 0,  # Public search
},
```

**Phase 5.5b: Live Search React Component (Week 2-3)**

Build live search autocomplete component:

```javascript
// react/components/LiveSearch.js
import React, { useState, useEffect, useRef } from 'react';
import { debounce } from 'lodash';

function LiveSearch({ placeholder = 'Search Everything2...' }) {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState([]);
  const [isOpen, setIsOpen] = useState(false);
  const [selectedIndex, setSelectedIndex] = useState(-1);
  const [isLoading, setIsLoading] = useState(false);
  const inputRef = useRef(null);
  const resultsRef = useRef(null);

  // Debounced search function
  const performSearch = useRef(
    debounce(async (searchQuery) => {
      if (searchQuery.length < 2) {
        setResults([]);
        setIsOpen(false);
        return;
      }

      setIsLoading(true);

      try {
        const response = await fetch(
          `/api/search/quick?q=${encodeURIComponent(searchQuery)}&limit=10`
        );
        const data = await response.json();

        if (data.success) {
          setResults(data.results);
          setIsOpen(data.results.length > 0);
        }
      } catch (error) {
        console.error('Search error:', error);
      } finally {
        setIsLoading(false);
      }
    }, 300)  // 300ms debounce
  ).current;

  // Handle input change
  const handleInputChange = (e) => {
    const value = e.target.value;
    setQuery(value);
    setSelectedIndex(-1);
    performSearch(value);
  };

  // Keyboard navigation
  const handleKeyDown = (e) => {
    if (!isOpen) return;

    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault();
        setSelectedIndex((prev) =>
          prev < results.length - 1 ? prev + 1 : prev
        );
        break;

      case 'ArrowUp':
        e.preventDefault();
        setSelectedIndex((prev) => (prev > 0 ? prev - 1 : -1));
        break;

      case 'Enter':
        e.preventDefault();
        if (selectedIndex >= 0 && results[selectedIndex]) {
          window.location.href = results[selectedIndex].url;
        } else if (query.length > 0) {
          // Full search page
          window.location.href = `/search?q=${encodeURIComponent(query)}`;
        }
        break;

      case 'Escape':
        setIsOpen(false);
        setSelectedIndex(-1);
        break;
    }
  };

  // Click outside to close
  useEffect(() => {
    const handleClickOutside = (e) => {
      if (
        resultsRef.current &&
        !resultsRef.current.contains(e.target) &&
        !inputRef.current.contains(e.target)
      ) {
        setIsOpen(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  // Scroll selected item into view
  useEffect(() => {
    if (selectedIndex >= 0 && resultsRef.current) {
      const selectedElement = resultsRef.current.children[selectedIndex];
      if (selectedElement) {
        selectedElement.scrollIntoView({ block: 'nearest' });
      }
    }
  }, [selectedIndex]);

  return (
    <div className="live-search">
      <div className="search-input-wrapper">
        <input
          ref={inputRef}
          type="text"
          className="search-input"
          placeholder={placeholder}
          value={query}
          onChange={handleInputChange}
          onKeyDown={handleKeyDown}
          onFocus={() => query.length >= 2 && setIsOpen(true)}
          aria-label="Search"
          aria-autocomplete="list"
          aria-expanded={isOpen}
        />
        <button
          className="search-icon"
          onClick={() => {
            if (query.length > 0) {
              window.location.href = `/search?q=${encodeURIComponent(query)}`;
            }
          }}
          aria-label="Search"
        >
          🔍
        </button>
        {isLoading && <div className="search-spinner">⏳</div>}
      </div>

      {isOpen && results.length > 0 && (
        <div className="search-results" ref={resultsRef}>
          {results.map((result, index) => (
            <a
              key={result.node_id}
              href={result.url}
              className={`search-result ${
                index === selectedIndex ? 'selected' : ''
              }`}
              onMouseEnter={() => setSelectedIndex(index)}
            >
              <div className="result-title">
                <span dangerouslySetInnerHTML={{ __html: result.title }} />
                <span className="result-type">{result.type}</span>
              </div>
              {result.excerpt && (
                <div
                  className="result-excerpt"
                  dangerouslySetInnerHTML={{ __html: result.excerpt }}
                />
              )}
            </a>
          ))}
          <div className="search-footer">
            Press Enter for full results
          </div>
        </div>
      )}
    </div>
  );
}

export default LiveSearch;
```

**Live Search CSS**:
```css
/* react/styles/live-search.css */
.live-search {
  position: relative;
  width: 100%;
  max-width: 600px;
}

.search-input-wrapper {
  position: relative;
  display: flex;
  align-items: center;
}

.search-input {
  width: 100%;
  padding: var(--spacing-md) var(--spacing-lg);
  padding-right: 80px; /* Space for icons */
  border: 2px solid var(--color-primary);
  border-radius: 24px;
  font-size: var(--font-size-base);
  outline: none;
  transition: border-color 0.2s;
}

.search-input:focus {
  border-color: var(--color-secondary);
  box-shadow: 0 0 0 3px rgba(102, 153, 51, 0.1);
}

.search-icon {
  position: absolute;
  right: var(--spacing-md);
  background: none;
  border: none;
  font-size: 20px;
  cursor: pointer;
  padding: var(--spacing-sm);
}

.search-spinner {
  position: absolute;
  right: 50px;
  font-size: 16px;
}

.search-results {
  position: absolute;
  top: calc(100% + 8px);
  left: 0;
  right: 0;
  background: white;
  border: 1px solid #ddd;
  border-radius: 8px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  max-height: 400px;
  overflow-y: auto;
  z-index: 1000;
}

.search-result {
  display: block;
  padding: var(--spacing-md);
  border-bottom: 1px solid #eee;
  text-decoration: none;
  color: var(--color-text);
  cursor: pointer;
  transition: background-color 0.15s;
}

.search-result:hover,
.search-result.selected {
  background-color: #f5f5f5;
}

.result-title {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: var(--spacing-xs);
  font-weight: 600;
}

.result-title mark {
  background-color: yellow;
  padding: 2px 0;
}

.result-type {
  font-size: var(--font-size-sm);
  color: #666;
  text-transform: lowercase;
  font-weight: normal;
}

.result-excerpt {
  font-size: var(--font-size-sm);
  color: #666;
  line-height: 1.4;
}

.result-excerpt mark {
  background-color: yellow;
  padding: 2px 0;
}

.search-footer {
  padding: var(--spacing-sm) var(--spacing-md);
  text-align: center;
  font-size: var(--font-size-sm);
  color: #999;
  background-color: #f9f9f9;
  border-top: 1px solid #eee;
}

/* Mobile optimizations */
@media (max-width: 767px) {
  .live-search {
    max-width: 100%;
  }

  .search-input {
    font-size: 16px; /* Prevent iOS zoom */
    padding: var(--spacing-md);
    padding-right: 70px;
  }

  /* Full-screen search on mobile */
  .search-results {
    position: fixed;
    top: 60px; /* Below header */
    left: 0;
    right: 0;
    max-height: calc(100vh - 60px);
    border-radius: 0;
    border-left: none;
    border-right: none;
  }

  .search-result {
    padding: var(--spacing-lg) var(--spacing-md);
    min-height: 60px; /* Touch targets */
  }
}
```

**Phase 5.5c: Search Analytics (Week 3)**

Track search queries for optimization:

```javascript
// Track search analytics
function trackSearch(query, resultCount) {
  // Send to analytics endpoint (non-blocking)
  fetch('/api/analytics/search', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      query,
      result_count: resultCount,
      timestamp: new Date().toISOString(),
    }),
  }).catch(() => {
    // Fail silently
  });
}

// In LiveSearch component
useEffect(() => {
  if (results.length >= 0 && query.length >= 2) {
    trackSearch(query, results.length);
  }
}, [results]);
```

**Search Analytics Backend**:
```perl
# ecore/Everything/API/analytics.pm
sub log_search {
    my ($self, $REQUEST) = @_;

    my $data = $self->parseJSON($REQUEST->POSTDATA);
    my $query = $data->{query};
    my $result_count = $data->{result_count} || 0;

    # Log to database for analytics
    $DB->sqlInsert('search_log', {
        query => $query,
        result_count => $result_count,
        user_id => $REQUEST->user ? $REQUEST->user->node_id : undef,
        ip_address => $REQUEST->remote_ip,
        timestamp => \'NOW()',
    });

    return [$self->HTTP_OK, { success => 1 }];
}
```

**Analytics Queries**:
```sql
-- Top searches (last 7 days)
SELECT query, COUNT(*) as count
FROM search_log
WHERE timestamp > DATE_SUB(NOW(), INTERVAL 7 DAY)
GROUP BY query
ORDER BY count DESC
LIMIT 20;

-- Zero-result queries (need content!)
SELECT query, COUNT(*) as count
FROM search_log
WHERE result_count = 0
  AND timestamp > DATE_SUB(NOW(), INTERVAL 7 DAY)
GROUP BY query
ORDER BY count DESC
LIMIT 20;

-- Search trends over time
SELECT DATE(timestamp) as date, COUNT(*) as searches
FROM search_log
WHERE timestamp > DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY DATE(timestamp)
ORDER BY date;
```

**Phase 5.5d: Mobile Search UI (Week 4)**

Mobile-optimized full-screen search:

```javascript
// react/components/MobileSearch.js
function MobileSearch() {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <>
      {/* Search trigger button */}
      <button
        className="mobile-search-trigger"
        onClick={() => setIsOpen(true)}
        aria-label="Open search"
      >
        🔍
      </button>

      {/* Full-screen search overlay */}
      {isOpen && (
        <div className="mobile-search-overlay">
          <div className="mobile-search-header">
            <LiveSearch placeholder="Search Everything2..." />
            <button
              className="close-search"
              onClick={() => setIsOpen(false)}
              aria-label="Close search"
            >
              ✕
            </button>
          </div>

          {/* Recent searches */}
          <RecentSearches />
        </div>
      )}
    </>
  );
}

function RecentSearches() {
  const [recent, setRecent] = useState([]);

  useEffect(() => {
    // Load from localStorage
    const stored = localStorage.getItem('recentSearches');
    if (stored) {
      setRecent(JSON.parse(stored));
    }
  }, []);

  const handleRecentClick = (query) => {
    window.location.href = `/search?q=${encodeURIComponent(query)}`;
  };

  if (recent.length === 0) return null;

  return (
    <div className="recent-searches">
      <h3>Recent Searches</h3>
      {recent.slice(0, 5).map((query, index) => (
        <button
          key={index}
          className="recent-search-item"
          onClick={() => handleRecentClick(query)}
        >
          🕐 {query}
        </button>
      ))}
    </div>
  );
}
```

**Mobile Search CSS**:
```css
.mobile-search-trigger {
  display: none;
  background: none;
  border: none;
  font-size: 24px;
  padding: var(--spacing-sm);
  min-width: var(--touch-target-min);
  min-height: var(--touch-target-min);
}

@media (max-width: 767px) {
  .mobile-search-trigger {
    display: block;
  }

  .mobile-search-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: white;
    z-index: 9999;
    overflow-y: auto;
  }

  .mobile-search-header {
    display: flex;
    align-items: center;
    padding: var(--spacing-md);
    gap: var(--spacing-sm);
    border-bottom: 1px solid #eee;
    position: sticky;
    top: 0;
    background: white;
  }

  .close-search {
    background: none;
    border: none;
    font-size: 28px;
    padding: var(--spacing-sm);
    min-width: var(--touch-target-min);
    min-height: var(--touch-target-min);
  }

  .recent-searches {
    padding: var(--spacing-md);
  }

  .recent-searches h3 {
    font-size: var(--font-size-base);
    color: #666;
    margin-bottom: var(--spacing-md);
  }

  .recent-search-item {
    display: block;
    width: 100%;
    text-align: left;
    padding: var(--spacing-md);
    margin-bottom: var(--spacing-sm);
    background: #f5f5f5;
    border: none;
    border-radius: 8px;
    font-size: var(--font-size-base);
    cursor: pointer;
  }
}
```

**Phase 5.5e: Testing & Performance (Week 4)**

```javascript
// Playwright tests for live search
test.describe('Live Search', () => {
  test('shows results as you type', async ({ page }) => {
    await page.goto('http://localhost:9080/');

    // Type in search box
    await page.fill('.search-input', 'everything');

    // Wait for results
    await page.waitForSelector('.search-results', { timeout: 1000 });

    // Should show results
    const results = await page.locator('.search-result').count();
    expect(results).toBeGreaterThan(0);
  });

  test('keyboard navigation works', async ({ page }) => {
    await page.goto('http://localhost:9080/');

    await page.fill('.search-input', 'test');
    await page.waitForSelector('.search-results');

    // Press arrow down
    await page.keyboard.press('ArrowDown');

    // First result should be selected
    const selected = page.locator('.search-result.selected');
    await expect(selected).toBeVisible();

    // Press Enter to navigate
    await page.keyboard.press('Enter');

    // Should navigate to result page
    await expect(page).toHaveURL(/\/node\/\d+/);
  });

  test('mobile full-screen search', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto('http://localhost:9080/');

    // Click mobile search trigger
    await page.click('.mobile-search-trigger');

    // Overlay should appear
    await expect(page.locator('.mobile-search-overlay')).toBeVisible();

    // Type query
    await page.fill('.search-input', 'test');

    // Results should appear
    await page.waitForSelector('.search-results');
  });
});
```

**Success Metrics**:
- [ ] Live search autocomplete working (300ms debounce)
- [ ] Keyboard navigation functional (arrow keys, Enter, Escape)
- [ ] Search results show in <200ms (cached queries)
- [ ] Mobile full-screen search UI working
- [ ] Recent searches saved in localStorage
- [ ] Search analytics tracking all queries
- [ ] Zero-result queries identified and tracked
- [ ] Touch targets meet 44px minimum on mobile
- [ ] Search engagement: 20-30% increase in search usage
- [ ] Faster user navigation: 40-50% fewer clicks to find content

**Timeline**: 4 weeks

**Prerequisites**:
- ✅ Phase 5 complete (React component infrastructure)
- ✅ MySQL FULLTEXT indexes on node.title and document.doctext

**Enables**:
- Better user engagement and content discovery
- Foundation for advanced search features (filters, facets)
- SEO benefits (search analytics inform content strategy)

---

### Phase 6: Guest User Database Optimization (Q1 2025 - AFTER CONTAINER/MASON CONSOLIDATION)
**Goal**: Eliminate database queries for guest users through S3-based page state caching

**Context**:
- **Primary bottleneck**: Database connections, not CPU or webserver load
- **Guest users are 95%+ of traffic** - Massive optimization opportunity
- **Prerequisite**: Phase 5 must be complete (React renders entire page, no legacy.js)
- **Cost reduction**: WAF elimination ($200-500/month), reduced database load

**Why Guest Optimization Requires Full React + No legacy.js**:
- **S3 cache serves JSON page state** - React hydrates on client
- **No server-side rendering** - HTML shell is static
- **No legacy.js execution** - All interactivity in React
- **Cookie-free domain possible** - Static content served from everything2static.com

**Current Problem**:
- Every guest user hits database (page load, navigation, search)
- WAF needed to protect against bot traffic
- Database connection pool exhaustion during traffic spikes
- Expensive infrastructure to handle mostly-read-only traffic

**Target State**:
- **Guest users NEVER hit database** - All content served from S3 cache
- **5-minute TTL** - Fresh enough for community content
- **Invalidation queue** - Real-time updates for important changes (new C!s, votes, etc.)
- **WAF elimination** - Bot traffic hits S3, not database (harmless)
- **Read-only mode capability** - Site can run without database for guests

**S3 Cache Architecture**:

```
Guest User Request → CloudFront → S3 Cache (JSON) → React Hydration
                                     ↓
                              (Cache Hit: No DB)

Authenticated User Request → CloudFront → ALB → ECS → Database
                                                  ↓
                                           Page State API
```

**Implementation Strategy**:

**Phase 6a: S3 Cache Infrastructure (Week 1-2)**

```perl
# In Everything::Application or new Everything::Cache module
sub cachePageStateToS3 {
    my ($self, $node_id, $page_state) = @_;

    my $s3_client = $self->getS3Client();
    my $cache_keys = $self->generateCacheKeys($node_id, $page_state->{node});

    foreach my $key (@$cache_keys) {
        $s3_client->put_object(
            Bucket => 'e2-page-cache',
            Key    => $key,
            Body   => encode_json($page_state),
            ContentType => 'application/json',
            CacheControl => 'public, max-age=300',  # 5 minutes
            Metadata => {
                'generated-at' => time(),
                'node-id' => $node_id,
                'expires-at' => time() + 300
            }
        );
    }
}

sub generateCacheKeys {
    my ($self, $node_id, $node) = @_;

    my @keys;

    # Primary key: node_id
    push @keys, "pages/node/$node_id.json";

    # Secondary key: type/title (for /title/Some+Title URLs)
    my $title_safe = $self->urlEncode($node->{title});
    my $type = $node->{type}{title};
    push @keys, "pages/$type/$title_safe.json";

    # Tertiary key: SEO-friendly slug (for future Phase 8)
    my $slug = $self->generateSlug($node->{title});
    push @keys, "pages/seo/$slug.json";

    return \@keys;
}
```

**S3 Three-Way Indexing**:
- **Node ID**: `/pages/node/123.json` - Primary lookup
- **Type/Title**: `/pages/e2node/Everything2+Explained.json` - Legacy URL support
- **SEO Slug**: `/pages/seo/everything2-explained.json` - Future Phase 8 SEO URLs

**Why Three Keys**:
- Supports all URL formats without database query
- Temporary 3x storage cost (acceptable for short term)
- Will consolidate to single SEO slug in Phase 8

**Phase 6b: Cache Invalidation System (Week 3)**

**ECS Scheduled Tasks**:
```yaml
# EventBridge scheduled rules
InvalidateCacheTask:
  Schedule: rate(1 minute)
  Task: process-invalidation-queue
  Description: Check invalidation queue, purge stale S3 objects

RegenerateCacheTask:
  Schedule: rate(5 minutes)
  Task: regenerate-popular-pages
  Description: Proactively regenerate high-traffic pages
```

**Invalidation Queue**:
```perl
# When a node is modified (new C!, vote, softlink, etc.)
sub invalidateNodeCache {
    my ($self, $node_id, $reason) = @_;

    # Add to invalidation queue (DynamoDB or RDS table)
    $self->addToInvalidationQueue({
        node_id => $node_id,
        reason => $reason,
        queued_at => time()
    });
}

# ECS task processes queue every minute
sub processInvalidationQueue {
    my ($self) = @_;

    my @pending = $self->getInvalidationQueue();

    foreach my $item (@pending) {
        $self->deleteS3CacheForNode($item->{node_id});
        $self->regenerateS3CacheForNode($item->{node_id});
        $self->markInvalidationProcessed($item);
    }
}
```

**Phase 6c: Guest User Cookie Detection (Week 4)**

**React Flow**:
```javascript
// In React component (e.g., E2NodePage.js)
async function loadPageState(nodeId) {
    const userpassCookie = getCookie('userpass');

    if (userpassCookie) {
        // User has cookie - try page state API first
        const response = await fetch(`/api/pagestate/node/${nodeId}`, {
            credentials: 'include'
        });

        const data = await response.json();

        if (data.user && data.user.is_guest) {
            // API returned guest user - delete cookie for future S3 cache use
            deleteCookie('userpass');
            console.log('Deleted stale guest user cookie');

            // Fall through to S3 cache for this request
            return await fetchFromS3Cache(nodeId);
        }

        // Authenticated user - use API response
        return data;
    }

    // No cookie - go directly to S3 cache
    return await fetchFromS3Cache(nodeId);
}

async function fetchFromS3Cache(nodeId) {
    // Fetch from S3 via CloudFront (or cookie-free domain)
    const response = await fetch(`https://everything2static.com/pages/node/${nodeId}.json`, {
        credentials: 'omit'  // Don't send cookies
    });

    if (!response.ok) {
        // Cache miss - fall back to page state API
        return await fetch(`/api/pagestate/node/${nodeId}`).then(r => r.json());
    }

    const cachedState = await response.json();

    // Hydrate guest user defaults (nodelets, etc.)
    return hydrateGuestDefaults(cachedState);
}

function hydrateGuestDefaults(pageState) {
    // Add default guest user settings (not stored in S3 to save space)
    return {
        ...pageState,
        user: {
            is_guest: true,
            node_id: 0,
            title: 'Guest User',
            settings: DEFAULT_GUEST_SETTINGS
        },
        nodelets: DEFAULT_GUEST_NODELETS
    };
}
```

**Why This Works**:
- Stale guest cookies are detected and cleaned up
- Future requests from that browser go straight to S3 (no API call)
- Minimal page state in S3 (guest defaults hydrated client-side)
- Authenticated users still get full page state API

**Phase 6d: Cookie-Free Domain (Week 5)**

**Problem**: Cloudflare charges for CDN bandwidth when cookies are present. Cookies add overhead to every request.

**Solution**: Serve cached guest content from separate cookie-free domain.

**Architecture**:
```
Main Site (everything2.com):
- Serves authenticated user traffic
- Handles all write operations
- Cookie-based sessions
- Behind AWS ALB + ECS (not behind Cloudflare CDN to avoid high egress costs)

Cache Domain (everything2static.com):
- Serves guest user cached content (S3/R2)
- NO cookies (faster, better caching)
- Behind Cloudflare CDN (free tier or low-cost Pro plan)
- Zero egress fees (Cloudflare R2 → Cloudflare CDN)
- Faster edge caching (no cookie variation)
- Separate domain ensures no cookie scope overlap
```

**DNS Configuration**:
```
everything2.com:
- A record → AWS ALB (52.x.x.x)
- Handles: Authentication, writes, personalized content
- SSL: AWS Certificate Manager

everything2static.com:
- CNAME → Cloudflare CDN
- Origin: Cloudflare R2 or AWS S3
- Handles: Guest page state cache (JSON)
- SSL: Cloudflare SSL
```

**Cost Comparison**:
```
CloudFront (with cookies):
- Data transfer: $0.085/GB (first 10TB)
- Requests: $0.0075 per 10K
- Estimated: $50-100/month for cache traffic

Cloudflare (cookie-free domain):
- Data transfer: $0/month (zero egress from R2)
- Requests: Included in free tier
- R2 storage: $0.015/GB/month
- Estimated: $2-5/month for same traffic
```

**82% cost reduction** by using cookie-free domain on Cloudflare.

**Phase 6e: HTTP Method Filtering (Week 5)**

**Problem**: POST/PUT/PATCH/DELETE requests to cached URLs could bypass cache and hit origin (database).

**Solution**: CloudFront Functions to block write methods at edge.

```javascript
// CloudFront Function (edge computing)
function handler(event) {
    var request = event.request;
    var method = request.method;

    // Only allow GET and HEAD for cached content
    if (method !== 'GET' && method !== 'HEAD') {
        return {
            statusCode: 405,
            statusDescription: 'Method Not Allowed',
            headers: {
                'content-type': { value: 'application/json' }
            },
            body: JSON.stringify({
                success: 0,
                error: 'Only GET and HEAD methods allowed for cached content'
            })
        };
    }

    return request;
}
```

**Alternatively**: CloudFront AllowedMethods configuration.

```yaml
# CloudFront distribution config
CacheBehavior:
  PathPattern: /pages/*
  AllowedMethods: [GET, HEAD]
  CachedMethods: [GET, HEAD]
```

**Phase 6f: Special Cases (Week 6)**

**Findings Page Exception**:
- **Problem**: Findings allows searching by any title (infinite variations)
- **Solution**: Don't cache Findings page, serve from API
- **Why**: No way to pre-generate all possible search results

```javascript
// In React routing
if (pageType === 'findings') {
    // Always fetch from API, never use S3 cache
    return await fetch(`/api/pagestate/node/${nodeId}`).then(r => r.json());
}
```

**Dynamic Content Pages**:
- Front page (constantly changing)
- Cool archive (updates frequently)
- New writeups (real-time)

**Solution**: Shorter TTL (1-2 minutes) and proactive regeneration.

```perl
my %CACHE_TTL = (
    'default' => 300,      # 5 minutes
    'frontpage' => 60,     # 1 minute
    'cool_archive' => 120, # 2 minutes
    'new_writeups' => 120, # 2 minutes
    'findings' => 0        # Never cache
);
```

**Phase 6g: Cost Control (Ongoing)**

**S3 Storage Monitoring**:
```perl
# Weekly cleanup of stale cache entries
sub cleanupStaleCache {
    my ($self) = @_;

    my $s3 = $self->getS3Client();
    my @objects = $s3->list_objects(Bucket => 'e2-page-cache');

    foreach my $obj (@objects) {
        my $age_days = (time() - $obj->{LastModified}) / 86400;

        # Delete objects older than 7 days (stale/unused)
        if ($age_days > 7) {
            $s3->delete_object(
                Bucket => 'e2-page-cache',
                Key => $obj->{Key}
            );
        }
    }
}
```

**S3 Lifecycle Policies**:
```json
{
  "Rules": [
    {
      "Id": "DeleteOldCacheObjects",
      "Status": "Enabled",
      "Expiration": {
        "Days": 7
      },
      "Filter": {
        "Prefix": "pages/"
      }
    }
  ]
}
```

**Cost Budgets**:
- AWS Budget: Alert if S3 costs exceed $100/month
- Monitor S3 storage size (should stay under 50GB)
- Track PUT/GET request counts

**Expected Costs**:
```
S3 Cache (with 3x indexing):
- Storage (30GB): $0.69/month
- PUT requests (300K/day): $45/month
- GET requests (100K/day): $1.20/month
- Total: ~$47/month (temporary)

Post-consolidation (single index):
- Storage (10GB): $0.23/month
- PUT requests (100K/day): $15/month
- GET requests (100K/day): $1.20/month
- Total: ~$17/month

Infrastructure Savings:
- WAF removal: $200-500/month ✅
- Reduced RDS needs: TBD
- Reduced ECS task count: TBD

Net savings: $150-450/month
```

**Phase 6h: WAF Elimination (Week 7)**

**Current State**:
- AWS WAF protects against bot traffic ($200-500/month)
- Bots hammer database with page requests
- WAF rate limiting prevents database exhaustion

**Post-S3 Cache**:
- Bots hit S3, not database (harmless)
- S3 scales infinitely, costs are minimal
- CloudFront handles DDoS automatically
- No need for expensive WAF

**Migration Plan**:
1. Enable S3 cache for all guest users
2. Monitor database connection count (should drop 80-90%)
3. Monitor S3 costs (should be <$50/month)
4. Gradually reduce WAF rules (start with least critical)
5. Disable WAF completely after 2 weeks of stable operation
6. Monitor for any abuse (should be none)

**Rollback Plan**:
- Re-enable WAF immediately if database load spikes
- Investigate cache bypass attempts
- Add CloudFront Functions for basic protection if needed

**Phase 6i: Read-Only Mode (Week 8)**

**Capability**: Site can serve guest content without database.

**Use Cases**:
- Database maintenance (upgrades, migrations)
- Emergency operations (database outage)
- Cost reduction (temporary read-only mode)
- Business shutdown (archive mode)

**Implementation**:
```perl
# In Everything::Application
sub isReadOnlyMode {
    my ($self) = @_;
    return $ENV{E2_READ_ONLY_MODE} || $self->getSetting('read_only_mode');
}

sub handleReadOnlyRequest {
    my ($self, $REQUEST) = @_;

    # Allow all GET requests (served from S3 cache)
    return undef if $REQUEST->method eq 'GET';

    # Block all write operations
    if ($REQUEST->method =~ /^(POST|PUT|DELETE)$/) {
        return {
            success => 0,
            error => 'Site is currently in read-only mode for maintenance',
            read_only_mode => 1
        };
    }
}
```

**Activation**:
```bash
# Set environment variable
export E2_READ_ONLY_MODE=1

# Restart ECS tasks
aws ecs update-service --cluster e2-cluster --service e2-app --force-new-deployment

# Stop database (optional for extended maintenance)
aws rds stop-db-instance --db-instance-identifier e2-production
```

**Cost Analysis - Read-Only Mode**:
```
Full Operation:
- RDS: $150-300/month
- ECS: $100-200/month
- ALB: $20/month
- S3 cache: $47/month
- CloudFront: $50/month
- Total: ~$367-617/month

Read-Only Mode:
- RDS: $0 (stopped)
- ECS: $0 (not needed)
- ALB: $0 (not needed)
- S3 cache: $47/month
- CloudFront: $50/month
- Total: ~$97/month

Savings: 70-84% reduction
```

**Long-Term Archival** (Business Shutdown):
```
Permanent Archive (Cloudflare):
- R2 storage (100GB): $1.50/month
- R2 egress: $0/month (zero egress fees)
- Cloudflare CDN: $0/month (free tier)
- Total: ~$2/month

vs AWS:
- S3 storage (100GB): $2.30/month
- CloudFront transfer: ~$10/month
- Total: ~$13/month

Cloudflare is 85% cheaper for archival.
```

**Success Metrics**:
- [ ] S3 cache serving 95%+ of guest requests
- [ ] Database queries from guests: <5%
- [ ] S3 cache hit rate: >90%
- [ ] Average cache invalidation latency: <1 minute
- [ ] WAF eliminated (cost savings: $200-500/month)
- [ ] S3 costs: <$50/month (temporary with 3x indexing)
- [ ] Read-only mode capability tested and documented
- [ ] Cookie-free domain operational (everything2static.com)

**Timeline**: 8 weeks (Q1 2025)

**Prerequisites**:
- ✅ Phase 5 complete (React renders entire page, no legacy.js)
- ✅ Container/Mason consolidation complete
- ✅ All page types support JSON page state

---

### Phase 6.5: Mobile Display & CSS Modernization
**Goal**: Add mobile-responsive design and complete CSS cleanup away from legacy Kernel Blue structures

**Context**:
- **Prerequisite**: Phase 6 (S3 caching) should be complete or in final stages
- **Why now**: Mobile users represent growing traffic segment, need responsive design
- **Builds on**: React component infrastructure from Phases 4-5
- **Enables**: Better mobile UX for guest users benefiting from S3 caching

**Current State - CSS Technical Debt**:
- **Legacy Kernel Blue CSS**: 20+ year old stylesheet structure
  - Fixed-width layouts (800px desktop-only)
  - Table-based layouts in some areas
  - Inline styles scattered throughout
  - No responsive breakpoints
- **Mixed CSS systems**: Partially migrated to CSS variables, but incomplete
- **No mobile optimization**:
  - Touch targets too small (<44px)
  - Text too small on mobile screens
  - Horizontal scrolling on narrow screens
  - No mobile navigation patterns
- **Testing gaps**: No automated tests for layout breakage

**Target State**:
1. **Fully Responsive Layouts**:
   - Mobile-first CSS with progressive enhancement
   - Breakpoints: 320px (mobile), 768px (tablet), 1024px (desktop)
   - Fluid typography and spacing
   - Touch-optimized UI (44px minimum tap targets)

2. **Complete CSS Variable Migration**:
   - All colors, spacing, typography via CSS variables
   - Support for dark mode themes (Phase 3 revenue optimization)
   - Easy theming without CSS changes

3. **Mobile Navigation Patterns**:
   - Collapsible hamburger menu on mobile
   - Bottom navigation for key actions
   - Sticky headers with minimal height
   - Swipe gestures for navigation

4. **Layout Testing**:
   - End-to-end tests for layout integrity
   - Visual regression testing
   - Mobile device testing (iOS/Android)

**Implementation Plan**:

**Phase 6.5a: CSS Audit & Variable Completion (Week 1)**

Audit current CSS and complete CSS variable migration:

```css
/* Complete CSS variable system */
:root {
  /* Legacy Kernel Blue colors → CSS variables */
  --color-primary: #336699;
  --color-secondary: #669933;
  --color-background: #ffffff;
  --color-text: #000000;
  --color-link: #0066cc;
  --color-link-hover: #003366;

  /* Spacing system */
  --spacing-xs: 4px;
  --spacing-sm: 8px;
  --spacing-md: 16px;
  --spacing-lg: 24px;
  --spacing-xl: 32px;

  /* Typography */
  --font-base: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  --font-mono: "Courier New", monospace;
  --font-size-sm: 14px;
  --font-size-base: 16px;
  --font-size-lg: 18px;
  --font-size-xl: 24px;

  /* Breakpoints (for media queries) */
  --breakpoint-mobile: 320px;
  --breakpoint-tablet: 768px;
  --breakpoint-desktop: 1024px;

  /* Touch targets */
  --touch-target-min: 44px;

  /* Layout */
  --max-content-width: 1200px;
  --sidebar-width: 300px;
  --header-height: 60px;
  --header-height-mobile: 56px;
}

/* Dark mode support (Phase 3 ad optimization) */
@media (prefers-color-scheme: dark) {
  :root {
    --color-background: #1a1a1a;
    --color-text: #e0e0e0;
    --color-primary: #5599cc;
    --color-secondary: #88bb55;
  }
}
```

**Audit Checklist**:
- [ ] Find all hardcoded color values (grep for `#[0-9a-f]{3,6}`)
- [ ] Find all hardcoded spacing values (grep for `margin:`, `padding:`)
- [ ] Find all fixed-width layouts (grep for `width: [0-9]+px`)
- [ ] Document all inline styles that need extraction
- [ ] List all table-based layouts needing flexbox/grid conversion

**Phase 6.5b: Mobile Breakpoints & Responsive Grid (Week 2)**

Convert fixed-width layouts to responsive grid:

```css
/* Base layout system */
.container {
  width: 100%;
  max-width: var(--max-content-width);
  margin: 0 auto;
  padding: 0 var(--spacing-md);
}

/* Responsive grid system */
.grid {
  display: grid;
  gap: var(--spacing-md);
  grid-template-columns: 1fr;
}

/* Tablet: 2 columns */
@media (min-width: 768px) {
  .grid {
    grid-template-columns: repeat(2, 1fr);
  }

  .grid-with-sidebar {
    grid-template-columns: 1fr var(--sidebar-width);
  }
}

/* Desktop: 3 columns */
@media (min-width: 1024px) {
  .grid {
    grid-template-columns: repeat(3, 1fr);
  }
}

/* Typography responsiveness */
body {
  font-size: 14px;
}

@media (min-width: 768px) {
  body {
    font-size: var(--font-size-base);
  }
}

/* Touch targets on mobile */
button, a, input[type="checkbox"], input[type="radio"] {
  min-height: var(--touch-target-min);
  min-width: var(--touch-target-min);
}
```

**React Layout Components**:

```javascript
// Responsive container component
function ResponsiveLayout({ children, sidebar }) {
  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    const checkMobile = () => {
      setIsMobile(window.innerWidth < 768);
    };

    checkMobile();
    window.addEventListener('resize', checkMobile);
    return () => window.removeEventListener('resize', checkMobile);
  }, []);

  return (
    <div className="container">
      {isMobile ? (
        // Mobile: stacked layout
        <>
          <main>{children}</main>
          {sidebar && <aside className="mobile-sidebar">{sidebar}</aside>}
        </>
      ) : (
        // Desktop: side-by-side layout
        <div className="grid-with-sidebar">
          <main>{children}</main>
          {sidebar && <aside>{sidebar}</aside>}
        </div>
      )}
    </div>
  );
}
```

**Phase 6.5c: Mobile Navigation (Week 3)**

Add mobile-optimized navigation patterns:

```javascript
// Mobile hamburger menu
function MobileNav({ user }) {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <nav className="mobile-nav">
      <button
        className="hamburger"
        onClick={() => setIsOpen(!isOpen)}
        aria-label="Toggle menu"
      >
        {isOpen ? '✕' : '☰'}
      </button>

      {isOpen && (
        <div className="mobile-menu">
          <Link to="/">Home</Link>
          <Link to="/writeups">Writeups</Link>
          <Link to="/cool">Cool Archive</Link>
          {user ? (
            <>
              <Link to="/messages">Messages</Link>
              <Link to="/settings">Settings</Link>
              <Link to="/logout">Logout</Link>
            </>
          ) : (
            <Link to="/login">Login</Link>
          )}
        </div>
      )}
    </nav>
  );
}
```

**Mobile Navigation CSS**:
```css
/* Desktop: horizontal nav */
.main-nav {
  display: flex;
  gap: var(--spacing-md);
}

.hamburger {
  display: none;
}

/* Mobile: hamburger menu */
@media (max-width: 767px) {
  .main-nav {
    display: none;
  }

  .hamburger {
    display: block;
    font-size: 24px;
    background: none;
    border: none;
    padding: var(--spacing-sm);
    min-width: var(--touch-target-min);
    min-height: var(--touch-target-min);
  }

  .mobile-menu {
    position: fixed;
    top: var(--header-height-mobile);
    left: 0;
    right: 0;
    background: var(--color-background);
    box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
    padding: var(--spacing-md);
    z-index: 1000;
  }

  .mobile-menu a {
    display: block;
    padding: var(--spacing-md);
    border-bottom: 1px solid #eee;
    text-decoration: none;
    color: var(--color-text);
  }
}
```

**Phase 6.5d: Touch Optimization (Week 4)**

Optimize all interactive elements for touch:

```css
/* Increase tap target sizes on mobile */
@media (max-width: 767px) {
  /* Buttons */
  button {
    padding: var(--spacing-md) var(--spacing-lg);
    font-size: var(--font-size-base);
  }

  /* Links in lists */
  .link-list a {
    display: block;
    padding: var(--spacing-md);
    min-height: var(--touch-target-min);
  }

  /* Form inputs */
  input, textarea, select {
    font-size: 16px; /* Prevents zoom on iOS */
    padding: var(--spacing-md);
    min-height: var(--touch-target-min);
  }

  /* Checkboxes and radio buttons */
  input[type="checkbox"],
  input[type="radio"] {
    width: 24px;
    height: 24px;
  }

  /* Action buttons on cards */
  .card-actions button {
    margin: var(--spacing-sm);
  }
}

/* Hover states don't work on touch devices */
@media (hover: hover) {
  button:hover {
    background-color: var(--color-primary-dark);
  }
}

/* Touch feedback */
button:active {
  transform: scale(0.98);
  transition: transform 0.1s;
}
```

**Phase 6.5e: Layout Testing (Week 5)**

Add end-to-end tests for layout integrity:

```javascript
// Playwright mobile layout tests
import { test, expect, devices } from '@playwright/test';

test.describe('Mobile Layouts', () => {
  test.use({ ...devices['iPhone 12'] });

  test('writeup page renders correctly on mobile', async ({ page }) => {
    await page.goto('http://localhost:9080/node/1');

    // Check viewport
    const viewportSize = page.viewportSize();
    expect(viewportSize.width).toBe(390); // iPhone 12 width

    // Check no horizontal scroll
    const scrollWidth = await page.evaluate(() => document.documentElement.scrollWidth);
    const clientWidth = await page.evaluate(() => document.documentElement.clientWidth);
    expect(scrollWidth).toBeLessThanOrEqual(clientWidth);

    // Check hamburger menu visible
    await expect(page.locator('.hamburger')).toBeVisible();

    // Check desktop nav hidden
    await expect(page.locator('.main-nav')).not.toBeVisible();

    // Check touch targets meet minimum size
    const buttons = page.locator('button');
    const count = await buttons.count();
    for (let i = 0; i < count; i++) {
      const box = await buttons.nth(i).boundingBox();
      expect(box.height).toBeGreaterThanOrEqual(44);
      expect(box.width).toBeGreaterThanOrEqual(44);
    }
  });

  test('mobile navigation works', async ({ page }) => {
    await page.goto('http://localhost:9080/');

    // Click hamburger
    await page.click('.hamburger');

    // Menu should appear
    await expect(page.locator('.mobile-menu')).toBeVisible();

    // Click link
    await page.click('.mobile-menu a[href="/writeups"]');

    // Should navigate
    await expect(page).toHaveURL(/\/writeups/);
  });

  test('forms are usable on mobile', async ({ page }) => {
    await page.goto('http://localhost:9080/login');

    // Input should be at least 16px to prevent zoom
    const usernameInput = page.locator('input[name="username"]');
    const fontSize = await usernameInput.evaluate(el =>
      window.getComputedStyle(el).fontSize
    );
    expect(parseInt(fontSize)).toBeGreaterThanOrEqual(16);

    // Should be able to tap input
    await usernameInput.click();
    await usernameInput.fill('testuser');

    // Submit button should be tappable
    const submitButton = page.locator('button[type="submit"]');
    const box = await submitButton.boundingBox();
    expect(box.height).toBeGreaterThanOrEqual(44);
  });
});

test.describe('Tablet Layouts', () => {
  test.use({ ...devices['iPad Pro'] });

  test('tablet uses 2-column layout', async ({ page }) => {
    await page.goto('http://localhost:9080/');

    // Check grid columns
    const grid = page.locator('.grid');
    const gridTemplate = await grid.evaluate(el =>
      window.getComputedStyle(el).gridTemplateColumns
    );

    // Should have 2 columns on tablet
    expect(gridTemplate.split(' ').length).toBe(2);
  });
});

test.describe('Desktop Layouts', () => {
  test.use({ viewport: { width: 1920, height: 1080 } });

  test('desktop uses full navigation', async ({ page }) => {
    await page.goto('http://localhost:9080/');

    // Desktop nav visible
    await expect(page.locator('.main-nav')).toBeVisible();

    // Hamburger hidden
    await expect(page.locator('.hamburger')).not.toBeVisible();
  });
});
```

**Visual Regression Testing**:
```javascript
// Percy visual regression tests
import percySnapshot from '@percy/playwright';

test('visual regression - homepage', async ({ page }) => {
  await page.goto('http://localhost:9080/');

  // Take snapshot on mobile
  await page.setViewportSize({ width: 375, height: 667 });
  await percySnapshot(page, 'Homepage - Mobile');

  // Take snapshot on tablet
  await page.setViewportSize({ width: 768, height: 1024 });
  await percySnapshot(page, 'Homepage - Tablet');

  // Take snapshot on desktop
  await page.setViewportSize({ width: 1920, height: 1080 });
  await percySnapshot(page, 'Homepage - Desktop');
});
```

**Phase 6.5f: Kernel Blue CSS Removal (Week 6)**

Systematically remove legacy Kernel Blue CSS:

```bash
# Find all Kernel Blue CSS references
grep -r "kernelblue" ecore/ templates/ react/

# Find table-based layouts
grep -r "<table" templates/ | grep -v "data-table"

# Find inline styles
grep -r "style=" templates/ react/
```

**Migration Strategy**:
1. Convert `<table>` layouts to `<div>` with flexbox/grid
2. Replace inline styles with CSS classes
3. Remove Kernel Blue color constants
4. Update all components to use CSS variables
5. Remove legacy CSS files

**Before (Kernel Blue)**:
```html
<table width="100%" cellpadding="0" cellspacing="0">
  <tr>
    <td width="600" style="background-color: #336699;">
      <font color="#ffffff" size="3"><b>Everything2</b></font>
    </td>
    <td width="200" align="right" style="background-color: #669933;">
      <a href="/login"><font color="#ffffff">Login</font></a>
    </td>
  </tr>
</table>
```

**After (Modern CSS)**:
```javascript
function Header({ user }) {
  return (
    <header className="site-header">
      <div className="header-content">
        <h1 className="site-title">Everything2</h1>
        <nav className="header-nav">
          {user ? (
            <Link to="/logout" className="nav-link">Logout</Link>
          ) : (
            <Link to="/login" className="nav-link">Login</Link>
          )}
        </nav>
      </div>
    </header>
  );
}
```

```css
.site-header {
  background: linear-gradient(90deg, var(--color-primary), var(--color-secondary));
  color: white;
  padding: var(--spacing-md);
}

.header-content {
  max-width: var(--max-content-width);
  margin: 0 auto;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

@media (max-width: 767px) {
  .site-header {
    padding: var(--spacing-sm);
  }

  .site-title {
    font-size: var(--font-size-lg);
  }
}
```

**Phase 6.5g: Mobile Performance Optimization (Week 7)**

Optimize for mobile performance:

```javascript
// Lazy load images with mobile-optimized sizes
function ResponsiveImage({ src, alt, sizes }) {
  return (
    <picture>
      <source
        media="(max-width: 767px)"
        srcSet={`${src}?w=400 1x, ${src}?w=800 2x`}
      />
      <source
        media="(max-width: 1023px)"
        srcSet={`${src}?w=800 1x, ${src}?w=1600 2x`}
      />
      <img
        src={`${src}?w=1200`}
        alt={alt}
        loading="lazy"
        className="responsive-image"
      />
    </picture>
  );
}

// Code splitting for mobile
const MobileChatterbox = lazy(() => import('./components/MobileChatterbox'));
const DesktopChatterbox = lazy(() => import('./components/DesktopChatterbox'));

function Chatterbox() {
  const isMobile = useMediaQuery('(max-width: 767px)');

  return (
    <Suspense fallback={<LoadingSpinner />}>
      {isMobile ? <MobileChatterbox /> : <DesktopChatterbox />}
    </Suspense>
  );
}
```

**Mobile Performance Metrics**:
```javascript
// Monitor mobile performance
if ('performance' in window) {
  const observer = new PerformanceObserver((list) => {
    for (const entry of list.getEntries()) {
      if (entry.entryType === 'largest-contentful-paint') {
        console.log('LCP:', entry.renderTime || entry.loadTime);
      }
      if (entry.entryType === 'first-input') {
        console.log('FID:', entry.processingStart - entry.startTime);
      }
    }
  });

  observer.observe({ entryTypes: ['largest-contentful-paint', 'first-input'] });
}
```

**Phase 6.5h: Documentation & Rollout (Week 8)**

**Documentation**:
- CSS variable reference guide
- Mobile breakpoint guidelines
- Touch target best practices
- Testing procedures

**Rollout Plan**:
1. Deploy to staging with mobile device testing
2. Run full Playwright test suite across devices
3. Visual regression test review
4. Gradual production rollout (10% → 50% → 100%)
5. Monitor mobile analytics (bounce rate, session duration)

**Success Metrics**:
- [ ] All CSS migrated to CSS variables (0 hardcoded colors/spacing)
- [ ] Mobile breakpoints working correctly (320px, 768px, 1024px)
- [ ] Touch targets meet 44px minimum on all interactive elements
- [ ] No horizontal scrolling on mobile viewports
- [ ] Hamburger menu functional on mobile
- [ ] Layout tests passing for mobile/tablet/desktop
- [ ] Visual regression tests passing
- [ ] Kernel Blue CSS completely removed
- [ ] Mobile page load: <3 seconds on 3G
- [ ] Lighthouse mobile score: >90
- [ ] Mobile bounce rate: decrease by 10-20%

**Timeline**: 8 weeks

**Prerequisites**:
- ✅ Phase 5 complete (React components infrastructure)
- ✅ Phase 6 in progress or complete (S3 caching for guest users)

**Enables**:
- Better mobile user experience for guest users (Phase 6 S3 caching)
- Foundation for mobile-first ad optimization (Phase 3 revenue)
- Modern CSS foundation for future theming work

---

### Phase 7: FastCGI/PSGI Migration (Infrastructure Cleanup)
**Goal**: Move from Apache/mod_perl to modern PSGI/Plack application server with FastCGI

**Context**:
- **Prerequisite**: Phase 5 complete (thin Mason routing layer)
- **Why now**: Thin routing layer is ideal for FastCGI/PSGI
- **Infrastructure cleanup**: Modernize Perl application server before SEO work
- **Performance**: FastCGI is lighter weight than mod_perl

**Current Bottleneck** (mod_perl):
- Heavy Apache/mod_perl overhead for each request
- Process-based concurrency model
- Memory-heavy worker processes
- Startup overhead for each Apache worker

**Target Architecture** (FastCGI + PSGI/Plack):
```
Nginx (or Apache as reverse proxy)
  ↓
FastCGI → PSGI/Plack Application (Everything::Application)
  ↓
Thin Mason routing layer → React Page classes → APIs
```

**Why FastCGI/PSGI**:
- **Lighter weight**: Less memory per request
- **Faster startup**: Pre-forked workers stay warm
- **Better scaling**: More requests per server
- **Modern tooling**: PSGI ecosystem (Plack::Middleware, etc.)
- **Easier deployment**: Standard PSGI app, works with many servers

**Benefits**:
- Reduce memory footprint (fewer ECS tasks needed)
- Faster request handling (lower latency)
- Better suited for thin routing layer (minimal overhead)
- Standard PSGI interface (portable across servers)

**PSGI Application**:
```perl
# app.psgi
use Everything::Application;
use Plack::Builder;

my $app = sub {
    my $env = shift;

    # Convert PSGI env to Everything::Request
    my $REQUEST = Everything::Request->from_psgi_env($env);

    # Everything::Application handles routing
    my $response = $APP->handleRequest($REQUEST);

    # Convert to PSGI response
    return $response->to_psgi;
};

builder {
    enable "Plack::Middleware::ReverseProxy";
    enable "Plack::Middleware::AccessLog";
    $app;
};
```

**Deployment Options**:
- **Starman**: High-performance PSGI server (recommended)
- **uWSGI**: Fast, supports multiple protocols
- **Nginx + FastCGI**: Classic FastCGI approach

**Migration Strategy**:
1. Create PSGI adapter for Everything::Application
2. Test in development with Starman
3. Deploy to staging with Nginx + FastCGI
4. Load test (compare to mod_perl baseline)
5. Gradual rollout to production (canary deployment)

**Success Metrics**:
- [ ] PSGI application running in production
- [ ] Memory usage per request reduced 30-50%
- [ ] Request latency improved 20-30%
- [ ] Fewer ECS tasks needed (cost savings)
- [ ] Apache/mod_perl completely removed

**Timeline**: 4-6 weeks (after Phase 6 complete)

---

### Phase 8: SEO Optimization (After Infrastructure Cleanup)
**Goal**: Improve search engine optimization through SEO-friendly URLs, canonical links, and structured content feeds

**Context**:
- **Prerequisite**: Phase 6 (S3 caching) and Phase 7 (FastCGI/PSGI) complete
- **Why after Phase 7**: Infrastructure is modern and clean, ready for URL changes
- **S3 three-way indexing**: Already supports SEO URLs (built in Phase 6)
- **Gradual migration**: Use HTTP 303 redirects and canonical headers to guide bots without breaking legacy URLs

**Current State - URL Challenges**:
- **Multiple URL formats** for same content:
  - `/node/123` (node_id based)
  - `/title/Some+Title` (type/title based)
  - No SEO-friendly slug URLs yet
- **No canonical URL signals** - Search engines see duplicate content
- **Mixed content feeds**:
  - Atom feeds, XML feeds, JSON feeds served from same paths
  - No clear URL structure for feed content types
- **Legacy hardcoded URLs**: 25+ years of external links point to old URL formats
- **Bot behavior**: Well-behaved bots follow redirects and canonical headers, legacy URLs will persist

**Target State**:
1. **SEO-Friendly URLs in React Links**:
   - Internal React links use SEO slugs: `/writeup/everything2-explained`
   - Legacy URL formats still work (backward compatibility)
   - Canonical headers indicate preferred URL format

2. **HTTP 303 Redirects for Select Nodes**:
   - High-value content redirects to SEO-friendly equivalents
   - Example: `/node/123` → HTTP 303 → `/writeup/everything2-explained`
   - Headers include `Link: <canonical-url>; rel="canonical"`
   - Guest users served from S3 cache (no database hit for cached redirects)

3. **Structured Feed Paths**:
   - Atom feeds: `/atom/recent-writeups`, `/atom/cool-archive`
   - XML feeds: `/xml/recent-writeups`, `/xml/cool-archive`
   - JSON feeds: `/json/recent-writeups`, `/json/cool-archive`
   - OR consolidated: `/feed/atom/recent-writeups`, `/feed/xml/cool-archive`, etc.
   - Cached separately in S3 with appropriate TTLs

4. **Canonical Headers Everywhere**:
   - Every page returns `Link` header with canonical URL
   - Helps search engines understand preferred URL format
   - HTML `<link rel="canonical">` tags in page head

**Implementation Strategy**:

**Phase 8a: React Internal Link Migration** (First - No Backend Changes)
```javascript
// In React components - change all internal links to use SEO slugs

// ❌ OLD - node_id based links
<Link to={`/node/${node.node_id}`}>{node.title}</Link>

// ✅ NEW - SEO-friendly slugs
<Link to={`/writeup/${generateSlug(node.title)}`}>{node.title}</Link>

// Utility function
function generateSlug(title) {
    return title
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-|-$/g, '');
}

// Examples:
// "Everything2 Explained" → "/writeup/everything2-explained"
// "How to use E2" → "/e2node/how-to-use-e2"
```

**Phase 8b: Canonical Headers** (Backend - Application.pm)
```perl
# In Everything::Application response headers
sub addCanonicalHeaders {
    my ($self, $node) = @_;

    my $canonical_url = $self->generateCanonicalURL($node);

    # HTTP Link header
    $self->addHeader("Link", "<$canonical_url>; rel=\"canonical\"");

    # Store for HTML <link> tag (rendered by React)
    return $canonical_url;
}

sub generateCanonicalURL {
    my ($self, $node) = @_;

    my $slug = $self->generateSlug($node->{title});
    my $type = $node->{type}{title};

    # SEO-friendly format
    return "https://everything2.com/$type/$slug";
}
```

**Phase 8c: HTTP 303 Redirects for High-Value Content**
```perl
# In Everything::Application routing
sub shouldRedirectToCanonical {
    my ($self, $node, $current_path) = @_;

    # Only redirect if:
    # 1. Guest user (authenticated users may have bookmarks)
    # 2. High-value content (popular nodes, featured content)
    # 3. Current path is not already canonical

    return 0 unless $self->isGuest();

    my $canonical_path = $self->generateCanonicalPath($node);
    return 0 if $current_path eq $canonical_path;

    # Check if node is high-value (reputation, traffic, etc.)
    return $node->{reputation} > 50 || $node->{hit_count} > 1000;
}

sub handleNodeRequest {
    my ($self, $path) = @_;

    my $node = $self->resolveNodeFromPath($path);

    if ($self->shouldRedirectToCanonical($node, $path)) {
        my $canonical_url = $self->generateCanonicalURL($node);

        # HTTP 303 See Other - indicates "this content is at this other URL"
        return $self->redirect(303, $canonical_url, {
            'Link' => "<$canonical_url>; rel=\"canonical\"",
            'Cache-Control' => 'public, max-age=300'
        });
    }

    # Normal handling
    return $self->serveNode($node);
}
```

**Phase 8d: Structured Feed Paths**
```perl
# New URL routes for feeds
# Option 1: Separate top-level paths
/atom/recent-writeups    → Atom feed
/xml/cool-archive        → XML feed
/json/new-nodes          → JSON feed

# Option 2: Consolidated under /feed/
/feed/atom/recent-writeups    → Atom feed
/feed/xml/cool-archive        → XML feed
/feed/json/new-nodes          → JSON feed

# Route configuration
sub configureFeedRoutes {
    my ($self) = @_;

    # Atom feeds
    $self->addRoute('GET', '/atom/:feed_type', 'Everything::Feed::Atom', 'serve');

    # XML feeds
    $self->addRoute('GET', '/xml/:feed_type', 'Everything::Feed::XML', 'serve');

    # JSON feeds
    $self->addRoute('GET', '/json/:feed_type', 'Everything::Feed::JSON', 'serve');
}

# S3 cache keys for feeds
sub generateFeedCacheKey {
    my ($self, $format, $feed_type) = @_;

    return "feeds/$format/$feed_type.xml";  # or .json, .atom
}

# Feed-specific TTLs (shorter than regular pages)
my %FEED_TTL = (
    'recent-writeups' => 120,   # 2 minutes
    'cool_archive'    => 300,   # 5 minutes
    'new-nodes'       => 180,   # 3 minutes
);
```

**S3 Cache Integration** (Leverages Phase 6 Infrastructure):

The S3 cache from Phase 6 already supports SEO URLs via three-way indexing:
```perl
# Already implemented in Phase 6
my @cache_keys = (
    "pages/node/$node_id.json",              # node_id key
    "pages/$type/$title.json",               # type/title key
    "pages/seo/$slug.json"                   # SEO slug key ← Already exists!
);

# For Phase 8, we just start USING the SEO key
# React links → SEO URLs → S3 cache hit on seo/$slug.json
```

**Canonical Header in S3 Cached Pages**:
```json
// S3 cached page state includes canonical URL
{
  "node": { ... },
  "metadata": {
    "canonical_url": "https://everything2.com/writeup/everything2-explained",
    "cached_at": "2025-01-20T12:00:00Z"
  }
}
```

**React Component Rendering**:
```javascript
// React component reads canonical URL from page state
function E2NodeDisplay({ pageState }) {
    return (
        <>
            <Helmet>
                <link rel="canonical" href={pageState.metadata.canonical_url} />
            </Helmet>
            {/* ... page content ... */}
        </>
    );
}
```

**Slug Collision Resolution**:
```perl
sub resolveSlugCollision {
    my ($self, $slug) = @_;

    my @nodes = $DB->getNodesBySlug($slug);

    # If single match, serve it
    return $nodes[0] if scalar(@nodes) == 1;

    # If multiple matches, append node_id to disambiguate
    # Example: everything2-explained-123, everything2-explained-456
    # Or serve a disambiguation page listing all matches
}
```

**Benefits**:
- ✅ **SEO improvement**: Search engines see clean, descriptive URLs
- ✅ **Duplicate content resolution**: Canonical headers tell search engines preferred URL
- ✅ **User experience**: Prettier URLs in address bar and shares
- ✅ **Analytics**: Cleaner URL tracking in analytics tools
- ✅ **Backward compatibility**: Legacy URLs still work (no broken links)
- ✅ **Gradual migration**: Well-behaved bots follow redirects, legacy hardcoded URLs persist
- ✅ **Zero database cost**: S3 cache serves both old and new URL formats
- ✅ **Feed organization**: Clear structure for different content types

**Migration Approach**:
1. **No breaking changes**: All legacy URLs continue to work
2. **Gradual bot guidance**: Use 303 redirects and canonical headers to nudge bots
3. **React-first**: New internal links use SEO format immediately
4. **Legacy URL tolerance**: Accept that 25+ years of external links will persist
5. **Well-behaved bot focus**: Modern search engines follow canonical signals

**Challenges and Tradeoffs**:
- **Legacy hardcoded URLs**: Cannot eliminate old URL formats (too many external links)
- **Redirect overhead**: HTTP 303 adds a roundtrip (mitigated by caching redirect responses)
- **Slug collisions**: Multiple nodes with same slug (need disambiguation strategy)
- **Title changes**: If node title changes, slug changes (need redirect mapping)

**Success Metrics**:
- [ ] All React internal links use SEO-friendly URLs
- [ ] Canonical headers present on all pages
- [ ] S3 cache consolidated to single SEO slug index (eliminate 3x duplication from Phase 6)
- [ ] HTTP 303 redirects work for high-value content
- [ ] Search engine indexing improves (measure in Google Search Console)
- [ ] No broken links (legacy URLs still work)
- [ ] Page headers return appropriate canonical URLs

**Timeline**: 6-8 weeks (after Phase 7 complete)

**Decision Required**:
- Feed URL structure: Separate paths (`/atom/`, `/xml/`, `/json/`) vs consolidated (`/feed/atom/`, etc.)
- Redirect strategy: Which nodes get 303 redirects? (high-traffic only, all nodes eventually, etc.)
- Slug collision handling: Append node_id, use different delimiter, maintain slug → node_id mapping table?

---

### Phase 9: Database Optimization & ORM Migration (Future - 9+ months)
**Goal**: Modernize database layer through migration to DBIx::Class ORM, eliminate Everything::NodeBase legacy code, and establish automated migration framework

**Context**:
- **After all other phases**: Database is the final bottleneck, but infrastructure must be modern first
- **Prerequisites**: Phase 7 (PSGI/Plack) complete - clean application server foundation required
- **Why last**: Other phases reduce database load by 80-90%, making migration safer and easier to measure
- **Biggest codebase change**: Touches every database interaction across entire codebase
- **Detailed plan**: See [orm-migration-plan.md](orm-migration-plan.md) for comprehensive migration strategy

**Current State - Everything::NodeBase Issues**:

Everything2 uses a sophisticated custom ORM built in 1999:
- **Everything::NodeBase** (2,925 lines) - Manual SQL construction, no query builder
- **Everything::Node** (458 lines) - Blessed hashref pattern, inconsistent access
- **Everything::NodeCache** (795 lines) - Multi-process caching with version tracking

**Problems**:
- **Manual SQL everywhere**: SQL strings scattered throughout codebase
- **No schema management**: Schema changes are manual, error-prone, undocumented
- **Security risks**: Manual query construction prone to SQL injection
- **No migration framework**: Database changes not tracked or automated
- **Difficult to test**: Database tightly coupled to application logic
- **Performance issues**: N+1 queries, missing indexes, inefficient JOINs
- **Hard to add features**: Every database change requires careful manual SQL

**Target State - Modern ORM with DBIx::Class**:

**Why DBIx::Class**:
- **Industry standard**: Most widely-used Perl ORM, 17+ years mature
- **Multi-table inheritance**: Native support for E2's node inheritance pattern
- **Schema versioning**: Built-in migration support (DBIx::Class::Migration)
- **Query optimization**: Automatic JOIN optimization, prepared statements, prefetch
- **Type safety**: Compile-time checking prevents SQL errors
- **Testing support**: Easy to mock, fixtures, comparison tests
- **Active development**: Regular releases, security fixes, large community

**Benefits**:
- ✅ **Automated migrations**: Schema changes tracked in version control
- ✅ **SQL injection protection**: Query builder prevents injection attacks
- ✅ **Better performance**: Prepared statements, prefetch, query optimization
- ✅ **Faster development**: Add features without writing SQL
- ✅ **Easier testing**: Mock database layer, faster tests
- ✅ **Clear schema**: Schema definition in code (not just database)
- ✅ **Production push automation**: Migrations run automatically on deployment

---

**Implementation Strategy - Phased Migration**:

This is the most complex migration in the roadmap. The strategy is incremental to minimize risk:

**Phase 9a: Preparation (Months 1-3)**

Set up DBIx::Class infrastructure:

```bash
# Generate initial schema from production database
dbicdump -o dump_directory=./lib \
         Everything::Schema \
         'dbi:mysql:database=everything' \
         username password
```

**Deliverables**:
- `lib/Everything/Schema.pm` - Main schema class
- `lib/Everything/Schema/Result/*.pm` - Result classes (one per table: Node, User, Document, Writeup, etc.)
- `Everything::DB::Compatibility` - Adapter layer for dual-mode operation
- `share/migrations/` - Migration framework setup
- Comprehensive test infrastructure

**Phase 9b: Read Operations (Months 4-7)**

Migrate read-only operations to DBIx::Class while Everything::NodeBase handles writes:

```perl
# Dual-mode compatibility layer
package Everything::DB;

sub getNode {
    my ($self, $title, $type) = @_;

    # Use DBIC if type is migrated
    if ($self->_is_migrated_type($type)) {
        my $result = $self->schema->resultset($type)->search(
            { 'node.title' => $title },
            { prefetch => 'node' }  # Avoid N+1 queries
        )->single;

        return $self->_result_to_hashref($result);  # Convert for legacy code
    }

    # Fall back to NodeBase for un-migrated types
    return $self->nodebase->getNode($title, $type);
}
```

**Migration order**:
1. Simple reads: `getNode()`, `getNodeById()` for core types
2. Type system: `Nodetype->derive()` (inheritance resolution)
3. Group nodes: `flatten_group()` (recursive group membership)
4. Complex queries: Multi-JOIN, aggregations

**Phase 9c: Write Operations (Months 8-10)**

Migrate inserts, updates, and deletes:

```perl
package Everything::Schema::Result::User;

around 'insert' => sub {
    my ($orig, $self, @args) = @_;

    # Transaction wrapper
    $self->result_source->schema->txn_do(sub {
        # Insert base node first
        my $node = $self->result_source->schema->resultset('Node')->create({
            title => $self->title,
            type_nodetype => $self->_user_type_id,
            author_user => $self->author_user,
            createtime => \'NOW()',
        });

        # Set user_id to match node_id (multi-table inheritance)
        $self->user_id($node->node_id);

        # Insert user-specific data
        $self->$orig(@args);

        # Run maintenance hook (backward compatibility)
        $self->_run_maintenance_hook('user_create');

        # Invalidate cache
        $self->_increment_version;
    });

    return $self;
};
```

**Critical**: All writes use transactions for ACID compliance

**Phase 9d: Specialized Features (Months 11-13)**

Integrate with existing systems:

1. **Cache integration**: Hook DBIx::Class into Everything::NodeCache with version checking
2. **Permission system**: Migrate `canReadNode()`, `canUpdateNode()`, `canDeleteNode()`
3. **Node parameters**: Migrate `getNodeParam()`, `setNodeParam()` (nodeparam table)
4. **Maintenance hooks**: Ensure delegation functions still fire on insert/update/delete

**Phase 9e: Everything::NodeBase Elimination (Months 14-15)**

Remove legacy code entirely:

1. Delete `ecore/Everything/NodeBase.pm` (2,925 lines of legacy code)
2. Delete compatibility layer
3. Update all callers to use DBIx::Class directly
4. Clean up blessed hashref patterns → DBIx::Class Result objects

```perl
# ❌ OLD - blessed hashref
my $node = $DB->getNode(123);
my $title = $node->{title};  # Hash access
my $type = $node->{type}{title};

# ✅ NEW - DBIx::Class Result object
my $node = $schema->resultset('Node')->find(123);
my $title = $node->title;  # Method call
my $type = $node->nodetype->title;  # Relationship traversal
```

**Phase 9f: Database Migration Framework (Months 16-17)**

Set up automated production deployment with migrations:

```bash
# Install DBIx::Class::Migration
cpanm DBIx::Class::Migration

# Create migration for schema changes
dbic-migration --schema_class Everything::Schema prepare

# Generates:
# share/migrations/MySQL/deploy/1/001-auto.sql
# share/migrations/MySQL/upgrade/1-2/001-auto.sql
```

**Example migration**:
```sql
-- Add reputation_cache column (denormalization)
ALTER TABLE node ADD COLUMN reputation_cache INT DEFAULT 0;
CREATE INDEX idx_reputation_cache ON node(reputation_cache);

-- Backfill from existing data
UPDATE node SET reputation_cache = (
    SELECT SUM(weight) FROM vote WHERE node_id = node.node_id
);
```

**Automated deployment script**:
```bash
#!/bin/bash
# deploy.sh - Zero-downtime deployment with migrations

# 1. Backup database
mysqldump everything > backup-$(date +%Y%m%d-%H%M%S).sql

# 2. Pull latest code
git pull origin main

# 3. Run database migrations automatically
perl -I./lib -MDBIx::Class::Migration -MEverything::Schema -e '
    my $schema = Everything::Schema->connect(@dsn);
    my $migration = DBIx::Class::Migration->new(
        schema => $schema,
        target_dir => "share/migrations"
    );
    $migration->upgrade();  # Apply pending migrations
'

# 4. Restart application (graceful reload)
systemctl reload everything2-psgi

# 5. Run smoke tests
./tools/smoke-test.rb
```

**Phase 9g: Query Optimization (Months 18-20)**

Optimize database performance using DBIx::Class features:

**N+1 Query Elimination**:
```perl
# ❌ BAD - N+1 queries (separate query for each author)
my @nodes = $schema->resultset('Node')->search({ type => 'e2node' });
foreach my $node (@nodes) {
    my $author = $node->author;  # NEW QUERY!
    say $author->title;
}

# ✅ GOOD - Single query with JOIN
my @nodes = $schema->resultset('Node')->search(
    { type => 'e2node' },
    { prefetch => 'author' }  # JOIN in single query
);
foreach my $node (@nodes) {
    say $node->author->title;  # No additional query
}
```

**Add Missing Indexes**:
```sql
-- Identify slow queries
SHOW PROCESSLIST;
EXPLAIN SELECT * FROM node WHERE author_user = 123;

-- Add missing indexes
CREATE INDEX idx_author_user ON node(author_user);
CREATE INDEX idx_type_nodetype ON node(type_nodetype);
CREATE INDEX idx_createtime ON node(createtime);
```

**Denormalize Hot Paths**:
```sql
-- Cache reputation to avoid aggregation query
ALTER TABLE node ADD COLUMN reputation_cache INT DEFAULT 0;

-- Cache vote count
ALTER TABLE writeup ADD COLUMN vote_count INT DEFAULT 0;
```

**Phase 9h: Read Replicas (Months 21-22)**

Scale reads independently from writes:

```perl
# Master-slave replication
use DBIx::Class::Storage::DBI::Replicated;

my $schema = Everything::Schema->connect(@master_dsn);
$schema->storage_type('::DBI::Replicated');

$schema->storage->connect_replicants(
    [ $slave1_dsn ],
    [ $slave2_dsn ],
);

# Reads automatically go to replicas
my $node = $schema->resultset('Node')->find(123);  # SELECT from replica

# Writes go to master
$node->update({ title => 'New Title' });  # UPDATE on master
```

**Phase 9i: Caching Layer (Optional - Months 23-24)**

Add Redis for frequently-accessed nodes:

```perl
use Redis;

sub cached_find {
    my ($self, $id) = @_;

    my $redis = Redis->new();
    my $cache_key = "node:$id";

    # Try cache first
    if (my $cached = $redis->get($cache_key)) {
        return decode_json($cached);
    }

    # Cache miss - query database
    my $node = $self->find($id);

    # Store in cache (5 minute TTL)
    $redis->setex($cache_key, 300, encode_json($node->as_hash));

    return $node;
}
```

---

**Why Phase 9 Requires Phase 7 (PSGI/Plack)**:

**Phase 7 provides clean foundation**:
- ✅ **Thin routing layer**: PSGI/Plack removes homespun router complexity
- ✅ **Modern Perl patterns**: PSGI ecosystem aligns with DBIx::Class patterns
- ✅ **Clear separation**: Application logic vs HTTP layer vs database layer
- ✅ **Easier testing**: PSGI apps + DBIC = fully testable without Apache

**Without Phase 7**:
- ❌ Mixing mod_perl + DBIC = messy integration
- ❌ Legacy routing logic complicates database migration
- ❌ Harder to test (need Apache running)

**Phase 7 → Phase 9 progression**:
```
Phase 7: Apache/mod_perl → PSGI/Plack (modernize HTTP layer)
    ↓
Clean application server with standard patterns
    ↓
Phase 9: Everything::NodeBase → DBIx::Class (modernize database layer)
    ↓
Fully modern Perl stack: PSGI + DBIx::Class
```

**Long-term architecture** (after both phases):
```
Browser → Apache → FastCGI → Plack → Everything::Application
                                          ↓
                                  DBIx::Class (ORM)
                                          ↓
                                  MySQL (with migrations)
```

**Additional benefit - Threaded model** (Phase 7 + Phase 9):

Once both PSGI/Plack (Phase 7) and DBIx::Class (Phase 9) are in place, we can move to a fully threaded model:

```perl
# Threaded PSGI server with connection pooling
use Starman;  # Multi-threaded PSGI server

# DBIx::Class handles connection pooling automatically
my $schema = Everything::Schema->connect(@dsn, {
    mysql_enable_utf8 => 1,
    on_connect_call => 'set_strict_mode',
    # Connection pooling built-in
});
```

**Benefits of threaded model**:
- ✅ Lower memory usage (threads vs processes)
- ✅ Faster request handling
- ✅ Better connection pooling
- ✅ Scale to higher concurrency

---

**Success Metrics**:

- [ ] Everything::NodeBase completely removed (2,925 lines deleted)
- [ ] All database operations use DBIx::Class
- [ ] Automated migration framework operational
- [ ] Query response time: <100ms for p95
- [ ] Connection pool utilization: <70%
- [ ] Lock contention reduced by 50%
- [ ] N+1 queries eliminated (verify with query logs)
- [ ] Support 10x traffic without database upgrade
- [ ] Feature development velocity increased 2x (easier to add features)
- [ ] Test suite 50% faster (mock database layer)
- [ ] Zero-downtime deployments with automated migrations
- [ ] Schema changes tracked in version control (share/migrations/)
- [ ] Production push procedure fully automated

**Timeline**: 24 months (~2 years) - can be done in parallel with other development

**Risk Level**: **HIGH** - Touches every database interaction in codebase

**Mitigation Strategies**:
1. **Dual-mode operation**: Run NodeBase and DBIC side-by-side during migration
2. **Comprehensive testing**: Comparison tests ensure DBIC matches NodeBase behavior
3. **Incremental rollout**: Migrate one node type at a time
4. **Feature flags**: Instant rollback capability (`use_dbic = 0`)
5. **Performance monitoring**: Continuous benchmarking at each phase

**Dependencies**:
- ✅ Phase 7 (PSGI/Plack) must be complete
- ✅ Phase 8 (SEO) should be complete (reduces guest database load)
- ✅ Clean separation between application and database logic

**Why This is Phase 9 (Last)**:
- **Largest refactor**: Touches every database interaction across entire codebase
- **Highest risk**: Database is critical infrastructure, can't afford mistakes
- **Prerequisites needed**: Earlier phases reduce database load, making migration safer
- **Modern infrastructure required**: PSGI/Plack provides clean foundation
- **Feature velocity payoff**: Makes future development MUCH faster, but requires stable foundation first

**See Also**:
- [orm-migration-plan.md](orm-migration-plan.md) - Comprehensive DBIx::Class migration strategy
- [psgi-plack-migration-plan.md](psgi-plack-migration-plan.md) - Phase 7 PSGI/Plack details

---

### Phase 9.5: Settings/Preferences Modernization (Technical Debt Reduction)
**Goal**: Migrate from legacy $VARS hash to structured JSON-encoded settings, eliminate obsolete preferences, and clean up settings codebase

**Context**:
- **After Phase 9**: DBIx::Class makes schema changes easy with migrations
- **Technical debt**: 25+ years of cruft accumulated in settings system
- **$VARS problems**: Unstructured hash, no validation, obsolete keys never removed
- **Performance**: Serialized Perl blobs are inefficient and opaque
- **Maintainability**: Hard to track what settings exist and which are actually used

**Current State - Legacy $VARS System**:

```perl
# Current user settings storage (user table)
CREATE TABLE user (
    user_id INT PRIMARY KEY,
    vars TEXT,  -- Serialized Perl hash with Storable
    -- Stores everything: preferences, state, metadata, legacy cruft
);

# Accessing settings
my $user = $DB->getNode('username', 'user');
my $hide_nodeinfo = $user->{vars}{vit_hidenodeinfo};  # Untyped, no validation
my $collapsed = $user->{vars}{collapsedNodelets};     # Could be anything
my $old_setting = $user->{vars}{some_ancient_setting_from_2003};  # Who knows?
```

**Problems**:
- **Unstructured data**: Hash can contain anything, no schema
- **No validation**: Can store invalid types, corrupt data
- **Obsolete keys**: 25 years of settings never removed
- **Binary blob**: Can't query in SQL, must deserialize to inspect
- **Performance**: Storable serialization/deserialization overhead
- **Hard to audit**: Can't see what settings exist without loading all users
- **Migration pain**: Can't evolve settings schema easily
- **No defaults**: Missing keys return undef, scattered default logic

**Target State - Modern JSON Settings**:

```sql
-- New user_settings table (normalized)
CREATE TABLE user_settings (
    user_id INT PRIMARY KEY,
    settings JSON NOT NULL,  -- Structured JSON with schema validation
    settings_version INT DEFAULT 1,  -- Schema version for migrations
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES node(node_id) ON DELETE CASCADE,
    INDEX idx_updated_at (updated_at)
);

-- Example JSON structure (validated schema)
{
    "display": {
        "hide_nodeinfo": false,
        "hide_misc": false,
        "collapsed_nodelets": ["epicenter"]
    },
    "notifications": {
        "email_on_message": true,
        "email_frequency": "daily"
    },
    "editor": {
        "preview_mode": "live",
        "autosave": true
    },
    "_version": 1  // Schema version
}
```

**Benefits**:
- ✅ **Structured schema**: Clear definition of what settings exist
- ✅ **Type validation**: Enforce boolean/string/array types
- ✅ **SQL queryable**: Can query settings in MySQL (JSON functions)
- ✅ **Human readable**: JSON is text, easy to inspect and debug
- ✅ **Better defaults**: Clear default values in schema definition
- ✅ **Schema versioning**: Can migrate settings as schema evolves
- ✅ **Pruning**: Remove obsolete settings during migration
- ✅ **Documentation**: JSON schema documents what settings exist

---

**Implementation Strategy**:

**Phase 9.5a: Settings Audit (Week 1)**

Identify all current settings and their usage:

```bash
# Find all VARS access in codebase
grep -r '\$.*->{vars}' ecore/ react/ templates/

# Common patterns:
# $user->{vars}{key}
# $USER->{VARS}{key}
# $request->user->VARS()
```

**Audit tasks**:
1. **List all settings keys**: Scan codebase for all VARS access
2. **Categorize settings**:
   - **Active**: Used in React or recent code
   - **Legacy**: Only in old Mason templates
   - **Obsolete**: Not referenced anywhere (dead code)
3. **Document each setting**: Type, purpose, default value
4. **Identify deprecation candidates**: Settings for removed features

**Example findings**:
```perl
# Active settings (keep)
vit_hidenodeinfo => boolean (hide node info box)
collapsedNodelets => string (comma-separated nodelet names)
email_on_message => boolean (email notifications)

# Legacy settings (evaluate)
old_chatterbox_height => number (from old UI, unused in React)
preferred_stylesheet => string (may be obsolete if stylesheets consolidated)

# Obsolete settings (remove)
use_java_chatterbox => boolean (Java applet from 2002, definitely dead)
enable_flash_player => boolean (Flash is dead)
```

**Deliverables**:
- Spreadsheet of all settings with status (active/legacy/obsolete)
- Mapping document: old key → new JSON path
- Deprecation list: Settings to remove

**Phase 9.5b: JSON Schema Definition (Week 2)**

Define structured schema for settings:

```javascript
// settings-schema.json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "display": {
      "type": "object",
      "properties": {
        "hide_nodeinfo": {
          "type": "boolean",
          "default": false,
          "description": "Hide node information box"
        },
        "hide_misc": {
          "type": "boolean",
          "default": false,
          "description": "Hide miscellaneous content"
        },
        "collapsed_nodelets": {
          "type": "array",
          "items": { "type": "string" },
          "default": [],
          "description": "List of collapsed nodelet names"
        }
      }
    },
    "notifications": {
      "type": "object",
      "properties": {
        "email_on_message": {
          "type": "boolean",
          "default": true
        },
        "email_frequency": {
          "type": "string",
          "enum": ["instant", "daily", "weekly", "never"],
          "default": "daily"
        }
      }
    },
    "editor": {
      "type": "object",
      "properties": {
        "preview_mode": {
          "type": "string",
          "enum": ["live", "manual", "off"],
          "default": "live"
        },
        "autosave": {
          "type": "boolean",
          "default": true
        }
      }
    },
    "_version": {
      "type": "integer",
      "default": 1,
      "description": "Settings schema version"
    }
  },
  "additionalProperties": false
}
```

**Schema validation in Perl**:
```perl
use JSON::Validator;

my $validator = JSON::Validator->new;
$validator->schema('settings-schema.json');

sub validate_user_settings {
    my ($self, $settings_json) = @_;

    my @errors = $validator->validate($settings_json);

    if (@errors) {
        die "Invalid settings: " . join(", ", @errors);
    }

    return 1;
}
```

**Phase 9.5c: Migration Script (Week 3-4)**

Convert existing $VARS to JSON settings:

```perl
#!/usr/bin/env perl
# migrate_settings.pl - Convert legacy VARS to JSON

use strict;
use warnings;
use Everything;
use JSON::MaybeXS;
use Storable qw(thaw);

initEverything('production');

my $json = JSON::MaybeXS->new(utf8 => 1, pretty => 1);

# Settings mapping: old VARS key => new JSON path
my %SETTINGS_MAP = (
    'vit_hidenodeinfo' => ['display', 'hide_nodeinfo'],
    'vit_hidemisc' => ['display', 'hide_misc'],
    'collapsedNodelets' => ['display', 'collapsed_nodelets'],
    'email_on_message' => ['notifications', 'email_on_message'],
    'preferred_editor_mode' => ['editor', 'preview_mode'],
    # ... more mappings
);

# Obsolete keys to skip
my @OBSOLETE_KEYS = qw(
    use_java_chatterbox
    enable_flash_player
    old_chatterbox_height
    preferred_java_version
);

sub migrate_user_settings {
    my ($user_id) = @_;

    # Get user with legacy VARS
    my $user = $DB->getNodeById($user_id);
    return unless $user;

    my $old_vars = $user->{vars} || {};

    # Build new JSON structure
    my $new_settings = {
        display => {},
        notifications => {},
        editor => {},
        _version => 1
    };

    # Map old VARS to new JSON structure
    foreach my $old_key (keys %$old_vars) {
        # Skip obsolete keys
        next if grep { $_ eq $old_key } @OBSOLETE_KEYS;

        # Look up mapping
        if (my $path = $SETTINGS_MAP{$old_key}) {
            my ($section, $key) = @$path;
            my $value = $old_vars->{$old_key};

            # Type conversion if needed
            if ($key eq 'collapsed_nodelets') {
                # Convert "epicenter!readthis!" to ["epicenter", "readthis"]
                $value = [split /!/, $value] if $value;
            }

            $new_settings->{$section}{$key} = $value;
        } else {
            warn "Unknown setting key: $old_key for user $user_id\n";
        }
    }

    # Validate against schema
    eval {
        validate_user_settings($json->encode($new_settings));
    };
    if ($@) {
        warn "Validation failed for user $user_id: $@\n";
        return;
    }

    # Insert into new user_settings table
    $dbh->do(
        "INSERT INTO user_settings (user_id, settings, settings_version) VALUES (?, ?, ?)",
        undef,
        $user_id,
        $json->encode($new_settings),
        1
    );

    return $new_settings;
}

# Process all users
my @users = @{ $DB->getNodeWhere({}, 'user') };
my $migrated = 0;
my $failed = 0;

foreach my $user (@users) {
    eval {
        migrate_user_settings($user->{user_id});
        $migrated++;
    };
    if ($@) {
        warn "Failed to migrate user $user->{user_id}: $@\n";
        $failed++;
    }

    # Progress indicator
    print "." if $migrated % 100 == 0;
}

print "\nMigration complete: $migrated migrated, $failed failed\n";
```

**Phase 9.5d: API Updates (Week 5)**

Update preferences API to use new JSON settings:

```perl
package Everything::API::preferences;

use JSON::MaybeXS;
use JSON::Validator;

my $json = JSON::MaybeXS->new(utf8 => 1);
my $validator = JSON::Validator->new->schema('settings-schema.json');

sub get_preferences {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;

    # For guest users, return defaults from schema
    if ($user->is_guest) {
        return [$self->HTTP_OK, $self->get_default_settings()];
    }

    # Fetch settings from user_settings table
    my $settings_json = $dbh->selectrow_array(
        "SELECT settings FROM user_settings WHERE user_id = ?",
        undef,
        $user->node_id
    );

    # If no settings yet, return defaults
    unless ($settings_json) {
        return [$self->HTTP_OK, $self->get_default_settings()];
    }

    my $settings = $json->decode($settings_json);

    return [$self->HTTP_OK, $settings];
}

sub set_preferences {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;

    # Guest users can't save settings
    return [$self->HTTP_UNAUTHORIZED, { error => 'Must be logged in' }]
        if $user->is_guest;

    my $updates = $REQUEST->JSON_POSTDATA;

    # Get current settings
    my $current_json = $dbh->selectrow_array(
        "SELECT settings FROM user_settings WHERE user_id = ?",
        undef,
        $user->node_id
    ) || $json->encode($self->get_default_settings());

    my $settings = $json->decode($current_json);

    # Apply updates (deep merge)
    foreach my $section (keys %$updates) {
        foreach my $key (keys %{ $updates->{$section} }) {
            $settings->{$section}{$key} = $updates->{$section}{$key};
        }
    }

    # Validate against schema
    my @errors = $validator->validate($settings);
    if (@errors) {
        return [$self->HTTP_BAD_REQUEST, {
            error => 'Invalid settings',
            details => \@errors
        }];
    }

    # Save to database
    $dbh->do(
        "INSERT INTO user_settings (user_id, settings, settings_version)
         VALUES (?, ?, ?)
         ON DUPLICATE KEY UPDATE settings = ?, updated_at = NOW()",
        undef,
        $user->node_id,
        $json->encode($settings),
        1,
        $json->encode($settings)
    );

    return [$self->HTTP_OK, $settings];
}

sub get_default_settings {
    my ($self) = @_;

    # Extract defaults from JSON schema
    # (or hard-code defaults here)
    return {
        display => {
            hide_nodeinfo => 0,
            hide_misc => 0,
            collapsed_nodelets => []
        },
        notifications => {
            email_on_message => 1,
            email_frequency => 'daily'
        },
        editor => {
            preview_mode => 'live',
            autosave => 1
        },
        _version => 1
    };
}
```

**Phase 9.5e: Backward Compatibility Layer (Week 6)**

Maintain compatibility during transition:

```perl
package Everything::Node::User;

# Legacy VARS() method - reads from new JSON settings
sub VARS {
    my $self = shift;

    # Check if already loaded
    return $self->{_cached_vars} if $self->{_cached_vars};

    # Fetch from user_settings table
    my $settings_json = $dbh->selectrow_array(
        "SELECT settings FROM user_settings WHERE user_id = ?",
        undef,
        $self->node_id
    );

    unless ($settings_json) {
        # Return empty hash for backward compatibility
        return {};
    }

    my $settings = decode_json($settings_json);

    # Convert back to flat VARS format for legacy code
    my $legacy_vars = {
        vit_hidenodeinfo => $settings->{display}{hide_nodeinfo},
        vit_hidemisc => $settings->{display}{hide_misc},
        collapsedNodelets => join('!', @{ $settings->{display}{collapsed_nodelets} || [] }),
        email_on_message => $settings->{notifications}{email_on_message},
        # ... more mappings
    };

    $self->{_cached_vars} = $legacy_vars;
    return $legacy_vars;
}

# New settings() method - returns structured JSON
sub settings {
    my $self = shift;

    my $settings_json = $dbh->selectrow_array(
        "SELECT settings FROM user_settings WHERE user_id = ?",
        undef,
        $self->node_id
    );

    return decode_json($settings_json || '{}');
}
```

**Phase 9.5f: React Integration (Week 7)**

Update React to use new settings structure:

```javascript
// React hook for user settings
function useUserSettings() {
    const [settings, setSettings] = useState(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        fetchSettings();
    }, []);

    const fetchSettings = async () => {
        const response = await fetch('/api/preferences');
        const data = await response.json();
        setSettings(data);
        setLoading(false);
    };

    const updateSetting = async (section, key, value) => {
        const updates = {
            [section]: {
                [key]: value
            }
        };

        const response = await fetch('/api/preferences', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(updates),
            credentials: 'include'
        });

        const updated = await response.json();
        setSettings(updated);
    };

    return { settings, loading, updateSetting };
}

// Usage in components
function SettingsPanel() {
    const { settings, loading, updateSetting } = useUserSettings();

    if (loading) return <Spinner />;

    return (
        <div className="settings-panel">
            <h3>Display Settings</h3>

            <Checkbox
                checked={settings.display.hide_nodeinfo}
                onChange={(e) => updateSetting('display', 'hide_nodeinfo', e.target.checked)}
                label="Hide Node Info"
            />

            <Checkbox
                checked={settings.display.hide_misc}
                onChange={(e) => updateSetting('display', 'hide_misc', e.target.checked)}
                label="Hide Miscellaneous"
            />

            <h3>Notification Settings</h3>

            <Checkbox
                checked={settings.notifications.email_on_message}
                onChange={(e) => updateSetting('notifications', 'email_on_message', e.target.checked)}
                label="Email on Message"
            />

            <Select
                value={settings.notifications.email_frequency}
                onChange={(e) => updateSetting('notifications', 'email_frequency', e.target.value)}
                options={['instant', 'daily', 'weekly', 'never']}
                label="Email Frequency"
            />
        </div>
    );
}
```

**Phase 9.5g: Legacy VARS Deprecation (Week 8)**

Remove old VARS column and legacy code:

```sql
-- After migration complete and verified

-- 1. Backup old VARS data (just in case)
CREATE TABLE user_vars_backup AS
SELECT user_id, vars FROM user;

-- 2. Drop VARS column from user table
ALTER TABLE user DROP COLUMN vars;

-- 3. Update indexes if needed
-- (user table may have had indexes on serialized vars)
```

**Cleanup Perl code**:
```perl
# Remove compatibility layer
# Delete VARS() method from Everything::Node::User

# Update all code to use settings() instead:
# OLD: my $hide = $user->{vars}{vit_hidenodeinfo};
# NEW: my $hide = $user->settings->{display}{hide_nodeinfo};

# Or better yet, use the API:
# my $prefs = $api->get_preferences($REQUEST);
# my $hide = $prefs->{display}{hide_nodeinfo};
```

---

**Success Metrics**:

- [ ] All active settings identified and documented
- [ ] Obsolete settings removed (estimate: 30-50% of legacy keys)
- [ ] JSON schema defined and validated
- [ ] 100% of users migrated to new user_settings table
- [ ] APIs updated to read/write JSON settings
- [ ] React components use structured settings
- [ ] Legacy VARS column dropped
- [ ] Settings queries 50% faster (JSON vs Storable deserialization)
- [ ] Settings now SQL-queryable (can run reports on user preferences)
- [ ] Schema versioning enables future migrations
- [ ] Clear documentation of all available settings

**Timeline**: 8 weeks (2 months)

**Dependencies**:
- ✅ Phase 9 (DBIx::Class) complete - Makes schema changes easy
- ✅ Automated migration framework operational
- ✅ React-based settings UI (Phase 4)

**Why Between Phase 9 and Phase 10**:
- **Builds on Phase 9**: Leverages DBIx::Class migration framework
- **Technical debt cleanup**: Remove cruft before adding new features
- **Prepares for Phase 10**: Clean settings system for social login preferences
- **Low risk**: Non-breaking change with compatibility layer
- **Performance win**: JSON is faster than Storable

**Benefits Beyond Technical Debt**:

1. **Feature Development Velocity**: Clear settings schema makes adding new preferences trivial
2. **Analytics**: Can query settings in SQL for user behavior analysis
3. **A/B Testing**: Can segment users by settings for testing
4. **Support**: Can inspect user settings without deserializing blobs
5. **Security**: JSON schema prevents injection of malicious settings

**Example Analytics Queries** (now possible with JSON):

```sql
-- How many users hide node info?
SELECT COUNT(*) FROM user_settings
WHERE JSON_EXTRACT(settings, '$.display.hide_nodeinfo') = true;

-- What's the most popular email frequency?
SELECT
    JSON_EXTRACT(settings, '$.notifications.email_frequency') as frequency,
    COUNT(*) as count
FROM user_settings
GROUP BY frequency
ORDER BY count DESC;

-- Which nodelets do users collapse?
SELECT
    nodelet,
    COUNT(*) as users
FROM user_settings,
    JSON_TABLE(
        settings,
        '$.display.collapsed_nodelets[*]' COLUMNS (nodelet VARCHAR(255) PATH '$')
    ) as nodelets
GROUP BY nodelet
ORDER BY users DESC;
```

**See Also**:
- JSON Schema specification: https://json-schema.org/
- MySQL JSON functions: https://dev.mysql.com/doc/refman/8.0/en/json-functions.html
- JSON::Validator (Perl): https://metacpan.org/pod/JSON::Validator

---

### Phase 10: Social Login Integration (User Acquisition & Retention)
**Goal**: Add Google/Facebook/Apple login to reduce signup friction and improve new user acquisition and retention

**Context**:
- **User acquisition challenge**: Traditional account creation has high friction
- **Password fatigue**: Users prefer single sign-on (SSO) with existing accounts
- **Mobile-first users**: Apple/Google auth is standard on mobile
- **Trust signal**: Social login provides verified email addresses
- **Retention**: Easier to return if no password to remember

**Current State - Traditional Account Creation**:

```
New User Journey (Current):
1. Click "Create Account"
2. Choose username (often taken - frustration)
3. Enter email
4. Create password (must meet requirements)
5. Confirm password
6. Email verification (often lost/delayed)
7. Return to site, log in
8. Finally start using E2

Friction points: 6-7 steps, email verification, password requirements
Dropout rate: ~60-70% (typical for email/password signup)
```

**Target State - Social Login**:

```
New User Journey (with Social Login):
1. Click "Sign in with Google/Facebook/Apple"
2. Authorize E2 (one click)
3. Auto-create account with verified email
4. Choose username (optional, can suggest from social profile)
5. Immediately start using E2

Friction points: 2-3 steps, no email verification needed
Dropout rate: ~20-30% (much lower with social login)
```

**Implementation Strategy**:

**Phase 10a: OAuth Infrastructure (Weeks 1-2)**

Set up OAuth 2.0 authentication infrastructure:

```perl
# Install OAuth modules
cpanm Net::OAuth2::Client
cpanm Net::OAuth2::Profile
cpanm LWP::Protocol::https  # For secure OAuth

# Create OAuth configuration
package Everything::OAuth;

use Moose;
use Net::OAuth2::Client;

has 'google_client' => (
    is => 'ro',
    lazy => 1,
    builder => '_build_google_client'
);

has 'facebook_client' => (
    is => 'ro',
    lazy => 1,
    builder => '_build_facebook_client'
);

has 'apple_client' => (
    is => 'ro',
    lazy => 1,
    builder => '_build_apple_client'
);

sub _build_google_client {
    return Net::OAuth2::Profile::WebServer->new(
        client_id => $ENV{GOOGLE_CLIENT_ID},
        client_secret => $ENV{GOOGLE_CLIENT_SECRET},
        authorize_url => 'https://accounts.google.com/o/oauth2/auth',
        access_token_url => 'https://oauth2.googleapis.com/token',
        scope => 'email profile',
        redirect_uri => 'https://everything2.com/oauth/google/callback'
    );
}
```

**Deliverables**:
- OAuth client configuration for Google, Facebook, Apple
- Secure credential storage (AWS Secrets Manager)
- OAuth callback endpoints
- Token verification infrastructure

**Phase 10b: Account Linking System (Weeks 3-4)**

Create database schema for linking social accounts to E2 users:

```sql
-- Create social_auth table
CREATE TABLE social_auth (
    social_auth_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    provider VARCHAR(50) NOT NULL,  -- 'google', 'facebook', 'apple'
    provider_user_id VARCHAR(255) NOT NULL,  -- OAuth user ID
    email VARCHAR(255),
    profile_data TEXT,  -- JSON: name, avatar, etc.
    access_token TEXT,  -- Encrypted OAuth token
    refresh_token TEXT,  -- Encrypted refresh token
    token_expires_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES node(node_id) ON DELETE CASCADE,
    UNIQUE KEY (provider, provider_user_id),
    INDEX idx_user_provider (user_id, provider),
    INDEX idx_email (email)
);
```

**Account Linking Logic**:
```perl
package Everything::API::social_auth;

sub link_social_account {
    my ($self, $REQUEST) = @_;

    my $provider = $REQUEST->param('provider');  # 'google', 'facebook', 'apple'
    my $oauth_client = $self->get_oauth_client($provider);

    # Exchange authorization code for access token
    my $token = $oauth_client->get_access_token($REQUEST->param('code'));

    # Fetch user profile from provider
    my $profile = $self->fetch_user_profile($provider, $token);

    # Check if this social account is already linked
    if (my $existing = $self->find_social_auth($provider, $profile->{id})) {
        # Log in existing user
        my $user = $DB->getNodeById($existing->{user_id});
        return $self->create_session($user);
    }

    # Check if email matches existing E2 user
    if ($profile->{email}) {
        if (my $user = $DB->getNode($profile->{email}, 'user')) {
            # Link social account to existing E2 user
            $self->create_social_auth_link($user, $provider, $profile, $token);
            return $self->create_session($user);
        }
    }

    # Create new E2 user from social profile
    my $new_user = $self->create_user_from_social($provider, $profile);
    $self->create_social_auth_link($new_user, $provider, $profile, $token);

    return $self->create_session($new_user);
}
```

**Phase 10c: UI Integration (Weeks 5-6)**

Add social login buttons to login/signup UI:

```javascript
// React component for social login
function SocialLoginButtons({ returnTo }) {
    const handleSocialLogin = async (provider) => {
        // Redirect to OAuth authorization URL
        const authUrl = `/api/oauth/${provider}/authorize?return_to=${encodeURIComponent(returnTo)}`;
        window.location.href = authUrl;
    };

    return (
        <div className="social-login-buttons">
            <button
                className="social-login-btn google"
                onClick={() => handleSocialLogin('google')}
            >
                <GoogleIcon /> Sign in with Google
            </button>

            <button
                className="social-login-btn facebook"
                onClick={() => handleSocialLogin('facebook')}
            >
                <FacebookIcon /> Sign in with Facebook
            </button>

            <button
                className="social-login-btn apple"
                onClick={() => handleSocialLogin('apple')}
            >
                <AppleIcon /> Sign in with Apple
            </button>

            <div className="social-login-divider">
                <span>or</span>
            </div>

            <button className="traditional-login-btn">
                Sign in with email
            </button>
        </div>
    );
}
```

**Mobile-Optimized Flow**:
- **Apple Sign In**: Required for iOS apps, best mobile UX on Apple devices
- **Google Sign In**: Best for Android users, widely trusted
- **Facebook Sign In**: Good for existing Facebook users

**Phase 10d: Username Selection Flow (Week 7)**

Handle username selection for new social login users:

```javascript
function UsernameSelectionModal({ suggestedUsername, onComplete }) {
    const [username, setUsername] = useState(suggestedUsername);
    const [checking, setChecking] = useState(false);
    const [available, setAvailable] = useState(null);

    const checkAvailability = async (name) => {
        setChecking(true);
        const response = await fetch(`/api/user/check-username?username=${name}`);
        const data = await response.json();
        setAvailable(data.available);
        setChecking(false);
    };

    return (
        <Modal title="Choose Your Username">
            <p>Welcome to Everything2! Please choose a username.</p>

            <Input
                value={username}
                onChange={(e) => {
                    setUsername(e.target.value);
                    checkAvailability(e.target.value);
                }}
                placeholder="Username"
            />

            {checking && <Spinner />}
            {available === true && <CheckIcon color="green" />}
            {available === false && <span className="error">Username taken</span>}

            <button
                disabled={!available || checking}
                onClick={() => onComplete(username)}
            >
                Continue
            </button>
        </Modal>
    );
}
```

**Auto-suggest usernames**:
```perl
sub suggest_username {
    my ($self, $social_profile) = @_;

    # Try full name
    my $suggested = $self->sanitize_username($social_profile->{name});

    # If taken, try variations
    my $attempt = 0;
    while ($self->username_exists($suggested) && $attempt < 10) {
        $attempt++;
        $suggested = $self->sanitize_username($social_profile->{name}) . $attempt;
    }

    return $suggested;
}
```

**Phase 10e: Privacy & Security (Week 8)**

Implement privacy controls and security best practices:

**User Privacy Controls**:
```javascript
function SocialAccountSettings({ user }) {
    const [linkedAccounts, setLinkedAccounts] = useState([]);

    return (
        <div className="social-account-settings">
            <h3>Linked Accounts</h3>

            {linkedAccounts.map(account => (
                <div key={account.provider} className="linked-account">
                    <ProviderIcon provider={account.provider} />
                    <span>{account.email}</span>
                    <button onClick={() => unlinkAccount(account.provider)}>
                        Unlink
                    </button>
                </div>
            ))}

            <h4>Link Additional Account</h4>
            <SocialLoginButtons mode="link" />

            <div className="privacy-notice">
                <p>We only request basic profile information (name, email) and never post to your social media without your permission.</p>
            </div>
        </div>
    );
}
```

**Security Measures**:
- **CSRF protection**: State parameter in OAuth flow
- **Token encryption**: Encrypt access/refresh tokens at rest
- **Email verification**: Still verify email even with social login
- **Account takeover prevention**: Require password to link social account if E2 password exists
- **Rate limiting**: Prevent OAuth callback abuse

**Phase 10f: Migration Path for Existing Users (Week 9)**

Allow existing E2 users to link social accounts:

```perl
# API endpoint: Link social account to existing user
sub link_to_existing_user {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;

    # Must be logged in to link
    return [$self->HTTP_UNAUTHORIZED, { error => 'Must be logged in' }]
        unless $user && !$user->is_guest;

    # Verify password before linking (security)
    my $password = $REQUEST->JSON_POSTDATA->{password};
    return [$self->HTTP_UNAUTHORIZED, { error => 'Invalid password' }]
        unless $self->verify_password($user, $password);

    # Proceed with OAuth flow
    my $provider = $REQUEST->param('provider');
    return $self->initiate_oauth_flow($provider, mode => 'link', user_id => $user->node_id);
}
```

**Benefits for Existing Users**:
- **Easier login**: No password to remember
- **Password recovery**: Can use social login if forgot E2 password
- **Cross-device**: Easy to log in from new devices

**Phase 10g: Analytics & Optimization (Week 10)**

Track social login effectiveness:

**Metrics to Track**:
- **Signup conversion rate**: Traditional vs social login
- **Provider preference**: Google vs Facebook vs Apple
- **Mobile vs desktop**: Platform differences
- **Retention**: Do social login users return more?
- **Engagement**: Activity levels of social login users

```perl
# Track social login events
sub track_social_login_event {
    my ($self, $event, $provider, $user_id) = @_;

    # Log to analytics system
    $self->log_event({
        event => $event,  # 'signup', 'login', 'link'
        provider => $provider,
        user_id => $user_id,
        device_type => $self->detect_device_type(),
        timestamp => time()
    });
}
```

---

**Success Metrics**:

- [ ] Social login accounts for 40%+ of new signups
- [ ] Signup conversion rate increases 50-100%
- [ ] Signup completion time reduced from ~5 minutes to ~30 seconds
- [ ] Email verification dropout eliminated (~30% of traditional signups)
- [ ] Mobile signup success rate increases 2-3x
- [ ] User retention improves (easier to return)
- [ ] 60%+ of new users choose social login over traditional
- [ ] Apple Sign In adoption on iOS: 70%+
- [ ] Google Sign In adoption on Android: 80%+
- [ ] Zero password reset requests from social login users

**Timeline**: 10 weeks (2.5 months)

**Dependencies**:
- ✅ Modern authentication infrastructure
- ✅ React-based login/signup UI (Phase 4)
- ✅ Secure credential management (AWS Secrets Manager or equivalent)
- ✅ Email system (for account notifications)

**User Acquisition Impact**:

**Before Social Login**:
- Signup friction: High (7 steps, email verification)
- Signup completion rate: 30-40%
- New users per month: 100

**After Social Login**:
- Signup friction: Low (2-3 steps, instant)
- Signup completion rate: 60-80%
- New users per month: 150-200 (50-100% increase)

**Retention Impact**:

**Password Users**:
- "Forgot password" requests: ~20% of returning users
- Account abandonment: ~10% (lost password, give up)

**Social Login Users**:
- "Forgot password" requests: 0%
- Account abandonment: <1% (can always re-authenticate)
- Easier cross-device usage (mobile → desktop)

**Mobile App Enablement**:

Social login is **essential** for future mobile apps:
- Apple requires "Sign in with Apple" if offering other social logins
- Google/Facebook login is standard in mobile apps
- Users expect social login on mobile (password entry is painful)

**Timeline**: After Phase 4 (React Migration) complete

**Risk Level**: LOW - Non-invasive addition, doesn't change existing auth

**See Also**:
- OAuth 2.0 specification: https://oauth.net/2/
- OpenID Connect: https://openid.net/connect/
- Apple Sign In guidelines: https://developer.apple.com/sign-in-with-apple/
- Google Sign In: https://developers.google.com/identity
- Facebook Login: https://developers.facebook.com/docs/facebook-login

---

### Phase 11: MySQL 8.4 Migration (Infrastructure - Time-Sensitive)
**Goal**: Upgrade from MySQL 8.0 to MySQL 8.4 before AWS RDS long-term support (LTS) sunset

**Context**:
- **AWS RDS LTS Policy**: AWS provides extended support for MySQL versions, but eventually sunsets older versions
- **MySQL 8.0 LTS End Date**: Check AWS RDS documentation for exact sunset date
- **Current Version**: MySQL 8.0+ (as of Dec 2025)
- **Target Version**: MySQL 8.4 LTS
- **Priority**: Currently LOW, but will increase to CRITICAL as sunset date approaches

**Why This Matters**:
- **Forced upgrade**: After LTS sunset, AWS will either force upgrade or charge premium support fees
- **Breaking changes**: Better to upgrade proactively with testing than reactively under pressure
- **Performance improvements**: MySQL 8.4 includes query optimizer improvements, better JSON handling
- **Security updates**: Newer versions include security patches and vulnerability fixes
- **Cost**: Avoiding premium extended support fees

**Current State**:
```sql
SELECT VERSION();
-- MySQL 8.0.x (exact version TBD)

SHOW VARIABLES LIKE 'innodb_version';
-- InnoDB 8.0.x
```

**MySQL 8.4 New Features** (Relevant to E2):
1. **Improved JSON Performance**: Faster JSON operations (E2 uses JSON in several places)
2. **Query Optimizer Enhancements**: Better execution plans for complex JOINs
3. **InnoDB Improvements**: Better handling of concurrent writes
4. **Character Set Updates**: Better UTF-8 handling (important for international content)

**Implementation Strategy**:

**Phase 11a: Pre-Migration Assessment (Week 1)**

Assess compatibility and breaking changes:

```bash
# Check for deprecated features we're using
mysqlcheck --check-upgrade -u root -p everything

# Identify queries using deprecated syntax
grep -r "SQL_CALC_FOUND_ROWS" ecore/
grep -r "GROUP BY" ecore/ | grep -v "aggregate"  # Check for implicit grouping

# Review stored procedures (we have 2)
SHOW PROCEDURE STATUS WHERE Db = 'everything';
```

**Compatibility Checks**:
- [ ] Audit all SQL queries for deprecated features
- [ ] Check for implicit `GROUP BY` behavior changes
- [ ] Review stored procedures for compatibility
- [ ] Test character set handling (UTF-8 edge cases)
- [ ] Verify JSON query performance doesn't regress

**Phase 11b: Development Environment Testing (Week 2)**

Test in Docker development environment first:

```dockerfile
# docker/Dockerfile.mysql (update)
FROM mysql:8.4

# Copy existing database schema
COPY schema.sql /docker-entrypoint-initdb.d/
```

```bash
# Update docker-compose.yml
services:
  e2devdb:
    image: mysql:8.4
    environment:
      MYSQL_ROOT_PASSWORD: blah
      MYSQL_DATABASE: everything

# Test all functionality
./docker/devbuild.sh --skip-tests
./docker/run-tests.sh  # Run full test suite
./tools/smoke-test.rb  # Smoke test all pages
```

**Testing Checklist**:
- [ ] All Perl tests pass (t/*.t)
- [ ] All React tests pass (npm test)
- [ ] Smoke tests pass (./tools/smoke-test.rb)
- [ ] Manual testing of critical flows:
  - [ ] User login/signup
  - [ ] Writeup creation/editing
  - [ ] Voting and cooling
  - [ ] Node creation
  - [ ] Search functionality
  - [ ] JSON API responses

**Phase 11c: Staging Environment Migration (Week 3)**

Create staging RDS instance with MySQL 8.4:

```bash
# Create RDS parameter group for MySQL 8.4
aws rds create-db-parameter-group \
  --db-parameter-group-name e2-mysql84-params \
  --db-parameter-group-family mysql8.4 \
  --description "E2 MySQL 8.4 parameters"

# Create staging RDS instance
aws rds create-db-instance \
  --db-instance-identifier e2-staging-mysql84 \
  --db-instance-class db.t3.medium \
  --engine mysql \
  --engine-version 8.4 \
  --master-username admin \
  --master-user-password <secure-password> \
  --allocated-storage 100 \
  --db-parameter-group-name e2-mysql84-params \
  --vpc-security-group-ids sg-xxxxx \
  --db-subnet-group-name e2-db-subnet-group \
  --backup-retention-period 7 \
  --no-multi-az  # Staging doesn't need multi-AZ

# Restore from production snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier e2-staging-mysql84 \
  --db-snapshot-identifier <latest-prod-snapshot>
```

**Staging Testing** (1 week):
- [ ] Deploy application to staging ECS pointing at MySQL 8.4
- [ ] Run comprehensive smoke tests
- [ ] Monitor for errors in CloudWatch logs
- [ ] Performance testing (compare query times vs. MySQL 8.0)
- [ ] Load testing (simulate production traffic)

**Phase 11d: Production Migration (Week 4 - Maintenance Window)**

**Migration Approach**: Blue/Green Deployment

```bash
# Step 1: Take final snapshot of production MySQL 8.0
aws rds create-db-snapshot \
  --db-instance-identifier e2-production \
  --db-snapshot-identifier e2-prod-pre-mysql84-$(date +%Y%m%d)

# Step 2: Create new MySQL 8.4 instance from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier e2-production-mysql84 \
  --db-snapshot-identifier e2-prod-pre-mysql84-20260315 \
  --db-instance-class db.r5.xlarge \
  --engine-version 8.4 \
  --multi-az \
  --publicly-accessible false

# Step 3: Wait for restore (monitor with aws rds wait)
aws rds wait db-instance-available \
  --db-instance-identifier e2-production-mysql84

# Step 4: Update application to point to new instance
# (Update CloudFormation stack with new RDS endpoint)
aws cloudformation update-stack \
  --stack-name everything2-production \
  --use-previous-template \
  --parameters ParameterKey=DBEndpoint,ParameterValue=<new-endpoint>

# Step 5: Monitor for 24-48 hours
# Step 6: If successful, delete old MySQL 8.0 instance
# Step 7: If issues, rollback to old instance
```

**Rollback Plan**:
```bash
# If issues detected within 48 hours:
# 1. Update CloudFormation to point back to old MySQL 8.0 instance
# 2. Deploy previous application version
# 3. Monitor for stability
# 4. Investigate MySQL 8.4 compatibility issues
```

**Production Migration Checklist**:
- [ ] Schedule maintenance window (announce 1 week in advance)
- [ ] Take final snapshot before migration
- [ ] Create MySQL 8.4 instance from snapshot
- [ ] Update application configuration (database endpoint)
- [ ] Deploy application with new database endpoint
- [ ] Monitor CloudWatch logs for errors (24 hours)
- [ ] Monitor application metrics (response times, error rates)
- [ ] Verify critical functionality manually
- [ ] Keep old MySQL 8.0 instance running for 7 days (rollback safety)

**Success Metrics**:
- [ ] Zero downtime during migration (blue/green deployment)
- [ ] No increase in error rates post-migration
- [ ] Query performance equal or better than MySQL 8.0
- [ ] All tests passing in production
- [ ] No user-reported issues for 7 days
- [ ] Old MySQL 8.0 instance safely deleted after monitoring period

**Timeline**: 4 weeks (1 month)
- Week 1: Compatibility assessment and query auditing
- Week 2: Development environment testing
- Week 3: Staging environment testing and validation
- Week 4: Production migration with monitoring

**Priority Triggers**:
- **LOW PRIORITY** (Current): >18 months until LTS sunset
- **MEDIUM PRIORITY**: 12-18 months until LTS sunset
- **HIGH PRIORITY**: 6-12 months until LTS sunset
- **CRITICAL PRIORITY**: <6 months until LTS sunset

**Dependencies**:
- ✅ Access to AWS RDS management
- ✅ Ability to create staging database instances
- ✅ Blue/green deployment capability
- ✅ Comprehensive test suite (Phase 1-2)
- ⏳ CloudFormation stack automation (for easy endpoint switching)

**Cost Impact**:
- **Staging instance**: ~$50/month during testing (t3.medium, 1 month)
- **Blue/green migration**: Temporary duplication of RDS instance (~$500-1000/month for 1 week)
- **Extended support fees (if delayed)**: $$$$ (avoid by migrating proactively)

**Risk Level**: LOW (if done proactively with proper testing)
**Risk Level**: HIGH (if forced to migrate reactively without testing)

**Monitoring Post-Migration**:
```bash
# CloudWatch metrics to watch
- DatabaseConnections (should be stable)
- ReadLatency (should not increase)
- WriteLatency (should not increase)
- CPUUtilization (should be similar or better)
- FreeableMemory (should be stable)

# Application logs to monitor
- SQL errors (should be zero)
- Query timeouts (should not increase)
- API response times (should be stable)
```

**See Also**:
- AWS RDS MySQL 8.4 Release Notes: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/MySQL.Concepts.VersionMgmt.html
- MySQL 8.4 What's New: https://dev.mysql.com/doc/refman/8.4/en/mysql-nutshell.html
- MySQL 8.0 to 8.4 Upgrade Guide: https://dev.mysql.com/doc/refman/8.4/en/upgrading.html
- AWS RDS Blue/Green Deployments: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/blue-green-deployments.html

---

### Phase 12: React 19 Migration (Future - Frontend Modernization)
**Goal**: Upgrade from React 18.2 to React 19 to leverage new features and performance improvements

**Context**:
- **Current Version**: React 18.2 (as of Dec 2025)
- **Target Version**: React 19 (released April 2024)
- **Priority**: LOW - Wait until React migration is complete (Phase 4-5) before upgrading
- **Timeline**: After Phase 5 complete (2026+)

**Why This Matters**:
- **New features**: React Compiler, Server Components, improved Suspense
- **Performance**: Automatic memoization, faster reconciliation
- **Developer experience**: Better TypeScript support, improved error messages
- **Future-proofing**: Stay current with ecosystem

**React 19 Key Features** (Relevant to E2):
1. **React Compiler** - Automatic optimization (no more manual useMemo/useCallback)
2. **Server Components** - Better SSR performance (future benefit with PSGI)
3. **Document Metadata** - Built-in `<title>` and `<meta>` management
4. **Actions** - Better form handling with useActionState/useFormStatus
5. **use() Hook** - Simplified data fetching patterns
6. **Improved Suspense** - Better loading states and error boundaries

**Prerequisites**:
- ✅ **Phase 4 Complete**: All pages migrated to React
- ✅ **Phase 5 Complete**: jQuery eliminated, React owns entire page
- ✅ **Test Suite Complete**: Comprehensive React component tests
- ⏳ **Bundle Analysis**: Understand current React usage patterns

**Implementation Details**:

See [react-19-migration.md](react-19-migration.md) for comprehensive migration guide including:
- Breaking changes analysis
- Component-by-component migration strategy
- Testing approach
- Rollback procedures
- Performance benchmarks

**Quick Summary of Migration Steps**:

1. **Assessment (Week 1)**:
   - Audit all React components for breaking changes
   - Check third-party dependencies for React 19 compatibility
   - Test in development environment

2. **Development Testing (Week 2)**:
   - Update React and ReactDOM to v19
   - Run full test suite
   - Fix breaking changes (componentWillReceiveProps, etc.)

3. **Staging Validation (Week 3)**:
   - Deploy to staging with React 19
   - Run comprehensive smoke tests
   - Performance testing and benchmarking

4. **Production Deployment (Week 4)**:
   - Blue/green deployment
   - Monitor performance metrics
   - Gradual rollout with monitoring

**Success Metrics**:
- [ ] All React tests passing
- [ ] No performance regressions
- [ ] Bundle size stable or smaller
- [ ] React Compiler enabled (optional, future enhancement)
- [ ] Zero console warnings in production

**Timeline**: 4 weeks (1 month) - After Phase 5 complete

**Priority**: LOW until Phase 4-5 complete
- Phase 4-5 establishes React infrastructure
- React 19 upgrade is straightforward after infrastructure is in place
- No urgent security or compatibility issues with React 18.2

**Dependencies**:
- ✅ Phase 4 Complete (React Migration)
- ✅ Phase 5 Complete (Container/Mason Consolidation)
- ✅ Comprehensive test suite
- ⏳ All third-party React libraries compatible with React 19

**Risk Level**: LOW
- React 19 is backwards-compatible for most use cases
- Comprehensive test suite catches breaking changes
- Gradual rollout minimizes impact

**Cost Impact**: Minimal
- Development time only (no infrastructure changes)
- Potential bundle size reduction (React Compiler optimizations)

**See Also**:
- [react-19-migration.md](react-19-migration.md) - Comprehensive migration guide
- React 19 Release Notes: https://react.dev/blog/2024/04/25/react-19
- React 19 Upgrade Guide: https://react.dev/blog/2024/04/25/react-19-upgrade-guide
- React Compiler: https://react.dev/learn/react-compiler

---

## Traffic Optimization Strategy

### Current Bottleneck Analysis

**Primary Constraint**: Database
- Connection limits
- Query performance
- Lock contention on writes
- Table scans on complex queries

**Secondary Constraint**: Webserver (not significant)
- Apache/mod_perl handles current load
- Recent infrastructure upgrades (ECS, ALB) provide headroom
- Not the optimization target

### Phase 4 Traffic Optimization Plan

#### 1. E2node Display API
**Current**: Server-side Mason template rendering
**Target**: React component + JSON API

**Database Impact**:
```perl
# Before (server-side)
- Query for e2node
- Query for all writeups
- Query for each writeup's author
- Query for voting data
- Query for cool data
- Render everything server-side

# After (API)
- Single optimized query with JOINs
- Return denormalized JSON
- Cache at CloudFront edge (60s TTL?)
- Browser can cache and update incrementally
```

**Expected Improvement**:
- Reduce database queries from N+1 to 1 for page load
- Cache responses at edge (reduce database hits)
- Better scalability (offload rendering to client)

#### 2. Writeup Display API
**Current**: Server-side rendering
**Target**: React component + JSON API

Similar optimization strategy to E2node display.

### Implementation Priority

**High Priority** (Phase 4):
1. E2node Display API + React Component
2. Writeup Display API + React Component
3. Document migration to React
4. Htmlpage migration to React

**Medium Priority** (Phase 6):
- Guest user S3 caching (biggest database win)
- Cache invalidation system
- WAF elimination

**Lower Priority** (Phase 9):
- Direct database optimization (connection pooling, query tuning)
- Read replicas
- Schema changes

---

## Summary and Quick Reference

### Completed Phases ✅
- **Phase 1**: Foundation - Testing infrastructure, mock-based tests, shared mocks

### Current Phase ⏳
- **Phase 2**: API Cleanup - Production-ready APIs with comprehensive testing

### Upcoming Phases 🔜
- **Phase 2.5**: Stylesheet Validation - Gate before shipping major features
- **Phase 3**: Revenue Optimization - Maximize AdSense, improve guest UX
- **Phase 4**: React Migration - Documents, htmlpages, writeups, e2nodes
- **Phase 5**: Container/Mason Consolidation - Eliminate legacy.js, thin routing layer
- **Phase 6**: Guest User Optimization - S3 caching, WAF elimination
- **Phase 7**: FastCGI/PSGI Migration - Modernize application server
- **Phase 8**: SEO Optimization - SEO-friendly URLs, canonical links
- **Phase 9**: Database Optimization - Address final bottleneck
- **Phase 10**: Social Login Integration - Google/Facebook/Apple login
- **Phase 11**: MySQL 8.4 Migration - Upgrade before RDS LTS sunset (priority increases near deadline)
- **Phase 12**: React 19 Migration - Upgrade to React 19 after React infrastructure complete

### Key Dependencies
```
Phase 1 (Done) → Phase 2 (Current) → Phase 2.5 (Gate)
                                          ↓
                                      Phase 3 (Revenue)
                                          ↓
                                      Phase 4 (React Migration)
                                          ↓
                                      Phase 5 (Container/Mason + legacy.js elimination)
                                          ↓
                                      Phase 6 (Guest Optimization - requires full React)
                                          ↓
                                      Phase 7 (FastCGI/PSGI)
                                          ↓
                                      Phase 8 (SEO)
                                          ↓
                                      Phase 9 (Database)

Phase 10 (Social Login) - Can be done after Phase 4 (React Migration)
Phase 11 (MySQL 8.4) - Independent, priority increases as LTS sunset approaches
Phase 12 (React 19) - After Phase 5 complete (requires stable React infrastructure)
```

### Critical Path Items
- **Phase 2**: Must complete before any new features ship
- **Phase 2.5**: Gate before Phase 3 (stylesheet validation)
- **Phase 3**: Optimize revenue before expensive migrations
- **Phase 5**: Must eliminate legacy.js before Phase 6 (guest caching requires no legacy.js)
- **Phase 6**: Must complete before WAF elimination (cost savings)
- **Phase 7**: Infrastructure cleanup before SEO work
- **Phase 8**: Consolidate S3 three-way indexing to single SEO slug (cost savings)

---

**Document Version**: 2.1
**Last Updated**: 2025-12-17
**Next Review**: 2026-01-17

**Recent Changes (v2.1)**:
- Added Phase 10: Social Login Integration
- Added Phase 11: MySQL 8.4 Migration (time-sensitive infrastructure upgrade)
- Added Phase 12: React 19 Migration (future frontend modernization)
- Updated TOC and dependencies diagram
- Removed obsolete documents: jquery-removal.md (covered by Phase 5), test-parallelization.md (completed work)
