package Everything::Page::oblique_strategies_garden;

use Moose;
extends 'Everything::Page';

# Mason2 template removed - page now uses React via buildReactData()
# Content-only optimization: All strategies data moved to React component
# - 139 Oblique Strategies moved from Perl to React
# - Grid generation happens client-side (was server-side random)
# - Eliminates server processing
# - Reduces Perl library size
# - Better for CDN caching (static React bundles)
#
# Note: Oblique Strategies by Brian Eno and Peter Schmidt
# Original card deck for creative problem-solving
sub buildReactData
{
  my ($self, $REQUEST) = @_;

  # Content-only page - no server-side data needed
  # All strategies and grid logic lives in React component
  # Controller wraps this in contentData => {...}
  return {
    type => 'oblique_strategies_garden'
  };
}

__PACKAGE__->meta->make_immutable;

1;
