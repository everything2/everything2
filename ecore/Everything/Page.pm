package Everything::Page;

use Moose;
use namespace::autoclean;

with 'Everything::Globals';
with 'Everything::HTTP';

has 'mimetype' => (is => 'ro', default => 'text/html'); 

__PACKAGE__->meta->make_immutable();
1;
