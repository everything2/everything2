package Everything::Page::your_gravatar;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::NoGuest';

__PACKAGE__->meta->make_immutable;

1;
