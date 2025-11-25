<%flags>
  extends => '/zen.mc'
</%flags>
<%doc>
Generic React Page Container (Phase 4a)

This template is used for all pages that have buildReactData() method.
It provides the container div where React's PageLayout component will render.

React will:
1. Check window.e2.reactPageMode === true
2. Mount into #e2-react-page-root
3. Render PageLayout with page content (not full page structure)
4. Use window.e2.contentData for page-specific data

This template extends zen.mc which provides:
- Full page HTML structure (header, sidebar, footer)
- window.e2 JavaScript setup
- CSS and JavaScript includes

No page-specific logic should go here - this is a generic container.
</%doc>

<div id="e2-react-page-root">
  <!-- React PageLayout component renders here -->
  <!-- Powered by window.e2.reactPageMode and window.e2.contentData -->
</div>
