package Everything::Page::the_nodeshell_hopper;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::StaffOnly';

=head1 Everything::Page::the_nodeshell_hopper

Admin tool for bulk deletion of empty nodeshells.

Features:
- Accepts a list of nodeshell titles (one per line)
- Validates each is an e2node and is empty
- Checks for firmlinks before deletion
- Reports results for each nodeshell

Security: Requires editor permissions (oppressor_superdoc).

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;

    return {
        nodeshellHopper => {
            # Just need to return the type - form submission handled by API
        }
    };
}

__PACKAGE__->meta->make_immutable;

1;
