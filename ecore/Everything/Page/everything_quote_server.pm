package Everything::Page::everything_quote_server;

use Moose;
extends 'Everything::Page';

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  # No page-specific data needed - component is self-contained
  return {
    type => 'everything_quote_server'
  };
}

__PACKAGE__->meta->make_immutable;

1;
