package Everything::Page::e2_sperm_counter;

use Moose;
extends 'Everything::Page';
use POSIX qw(ceil);

=head1 NAME

Everything::Page::e2_sperm_counter - E2 Sperm Counter

=head1 DESCRIPTION

A humorous calculator showing the "total sperm count" of E2 users worldwide
and currently online, based on user statistics.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns React data structure with calculated sperm counts.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;

    # Get the number of users on the system
    my $total_users = $DB->sqlSelect("count(*)", "user");
    my $users_online = $DB->sqlSelect("count(*)", "room");

    # 85% of our users are male
    my $male_users = $total_users * 0.85;
    my $male_online = $users_online * 0.85;

    # At any particular point, one could have between 1.2 and 1.4 billion sperm
    # Generate random values in that range
    my $rand1 = rand(200000000) + 1200000000;
    my $rand2 = rand(200000000) + 1200000000;

    # Calculate totals
    my $total_sperm = ceil($male_users * $rand1);
    my $online_sperm = ceil($male_online * $rand2);

    # Format with commas
    $total_sperm = $self->_format_number($total_sperm);
    $online_sperm = $self->_format_number($online_sperm);

    return {
        type => 'e2_sperm_counter',
        total_sperm => $total_sperm,
        online_sperm => $online_sperm
    };
}

sub _format_number {
    my ($self, $num) = @_;

    # Reverse for easier regex
    my $rev = reverse("$num");

    # Add commas every 3 digits
    $rev =~ s/(\d\d\d)/$1,/g;

    # Remove trailing comma if present
    my $c = chop($rev);
    $rev .= $c unless $c eq ',';

    # Reverse back
    return reverse($rev);
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
