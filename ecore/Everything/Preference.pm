package Everything::Preference;

use Moose;
use namespace::autoclean;

has 'default_value' => (is => 'ro');

__PACKAGE__->meta->make_immutable;
1;
