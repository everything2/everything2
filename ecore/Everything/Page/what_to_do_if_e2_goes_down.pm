package Everything::Page::what_to_do_if_e2_goes_down;

use Moose;
extends 'Everything::Page';

# Mason2 template removed - page now uses React via buildReactData()
# Content-only optimization: Suggestions array moved to React component
# - Reduces Perl library size (no 93-element data array)
# - Eliminates server processing (random selection happens client-side)
# - Better for CDN caching (static React bundles)
# - Simpler architecture (pure client-side rendering)
sub buildReactData
{
  my ($self, $REQUEST) = @_;

  # Content-only page - no server-side data needed
  # All content and logic lives in React component
  # Controller wraps this in contentData => {...}
  return { type => 'what_to_do_if_e2_goes_down' };
}

__PACKAGE__->meta->make_immutable;

1;
