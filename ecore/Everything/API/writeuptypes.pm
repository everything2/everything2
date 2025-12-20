package Everything::API::writeuptypes;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 Everything::API::writeuptypes

API for retrieving available writeup types.

=cut

sub routes {
    return {
        "/" => "list"
    };
}

=head2 list

Get all available writeup types.

GET /api/writeuptypes

Returns array of writeuptypes with node_id and title.

=cut

sub list {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;

    my $writeuptype_nodetype = $DB->getType('writeuptype');
    return [$self->HTTP_OK, { success => 0, error => 'writeuptype nodetype not found' }]
        unless $writeuptype_nodetype;

    my $rows = $DB->{dbh}->selectall_arrayref(
        q|SELECT node_id, title FROM node
          WHERE type_nodetype = ?
          ORDER BY title|,
        { Slice => {} },
        $writeuptype_nodetype->{node_id}
    );

    my @writeuptypes = map {
        { node_id => $_->{node_id}, title => $_->{title} }
    } @{$rows || []};

    return [$self->HTTP_OK, {
        success => 1,
        writeuptypes => \@writeuptypes
    }];
}

__PACKAGE__->meta->make_immutable;

1;
