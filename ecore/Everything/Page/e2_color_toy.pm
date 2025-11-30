package Everything::Page::e2_color_toy;

use Moose;
extends 'Everything::Page';

# E2 Color Toy - Interactive color manipulation tool
#
# Features:
# - HSB to RGB conversion and vice versa
# - Named HTML color support (~130 colors + E2 "fake" colors)
# - Hex/named color parsing
# - 16-step gradient generator
#
# The React component (E2ColorToy.js) handles all color logic client-side.
# This Page class exists to route the superdocnolinks node to React.

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  return {
    type => 'e2_color_toy'
  };
}

__PACKAGE__->meta->make_immutable;
1;
