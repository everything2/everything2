package Everything::Page;

use Moose;
use namespace::autoclean;
with 'Everything::Globals';
with 'Everything::HTTP';

with 'Everything::Security::Permissive';

has 'mimetype' => (is => 'ro', default => 'text/html');
has 'guest_allowed' => (is => 'ro', default => 1);
has 'template' => (is => 'ro', default => '');

sub display
{
  return {}
}

__PACKAGE__->meta->make_immutable();
1;
