package Everything::Page::wharfinger_s_linebreaker;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::NoGuest';

__PACKAGE__->meta->make_immutable;

1;
