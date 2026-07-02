package Everything::Page::the_oracle_classic;

use Moose;
extends 'Everything::Page::the_oracle';

=head1 NAME

Everything::Page::the_oracle_classic - The Oracle in classic (raw, admin-only) mode

=head1 DESCRIPTION

The Oracle Classic is the same page as L<Everything::Page::the_oracle>, in its
"classic" mode: a raw, unformatted view of B<all> of a user's variables, restricted
to administrators. It is a distinct document/title only; all behaviour lives in the
parent, branched on C<classic_mode>, and it renders through the same C<TheOracle>
React component (with C<classic_mode = 1>). (#4298)

=cut

sub classic_mode { return 1 }

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page::the_oracle>

=cut
