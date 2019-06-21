package Everything::Page;

use Moose;
use namespace::autoclean;

with 'Everything::Globals';
with 'Everything::HTTP';

has 'mimetype' => (is => 'ro', default => 'text/html'); 
has 'guest_allowed' => (is => 'ro', default => 0);

__PACKAGE__->meta->make_immutable();
1;
