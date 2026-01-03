package Everything::Page::quick_rename;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::StaffOnly';

=head1 Everything::Page::quick_rename

Bulk e2node rename tool for editors. Allows retitling multiple e2nodes at once.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    return {
        quickRename => {
            maxItems => 10,
        }
    };
}

__PACKAGE__->meta->make_immutable;

1;
