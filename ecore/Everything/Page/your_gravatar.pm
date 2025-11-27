package Everything::Page::your_gravatar;

use Moose;
extends 'Everything::Page';

# Mason2 template removed - page now uses React via buildReactData()
# Content-only optimization: Gravatar URLs pre-computed server-side
# - All static gravatar URLs computed once
# - React component receives ready-to-display data
# - Eliminates client-side URL computation
# - Simple, fast rendering
sub buildReactData
{
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;

  # Pre-compute gravatar URLs for all sizes and styles
  # Sizes: 16, 32, 64, 128 pixels
  # Styles: default, identicon, monsterid, wavatar
  my @gravatar_data;

  foreach my $size (16, 32, 64, 128) {
    my @urls;
    foreach my $style (undef, 'identicon', 'monsterid', 'wavatar') {
      my $url = $user->gravatar_img_url($style, $size);
      my $style_label = $style || 'default';
      push @urls, {
        url => $url,
        style => $style_label
      };
    }

    push @gravatar_data, {
      size => $size,
      urls => \@urls
    };
  }

  # Content-only page - gravatar data pre-computed
  # Controller wraps this in contentData => {...}
  return {
    type => 'your_gravatar',
    gravatars => \@gravatar_data,
    userEmail => $user->email  # For display purposes only
  };
}

__PACKAGE__->meta->make_immutable;

1;
