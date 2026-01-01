package Everything::API::nodeshells;

use Moose;
extends 'Everything::API';

=head1 Everything::API::nodeshells

API for nodeshell management - primarily bulk deletion of empty nodeshells.

This is an admin-only API (requires editor permissions).

=cut

sub route {
    my ($self, $REQUEST, $extra) = @_;

    my %routes = (
        'delete' => 'delete_nodeshells',
    );

    if (exists $routes{$extra}) {
        my $handler = $routes{$extra};
        return $self->$handler($REQUEST);
    }

    return [$self->HTTP_NOT_FOUND, { error => 'Unknown route' }];
}

=head2 delete_nodeshells

POST /api/nodeshells/delete

Accepts a list of nodeshell titles and attempts to delete each one.

Request body:
    {
        "nodeshells": ["title1", "title2", ...]
    }

Returns results for each nodeshell processed.

=cut

sub delete_nodeshells {
    my ($self, $REQUEST) = @_;

    my $APP = $self->APP;
    my $DB = $self->DB;
    my $user = $REQUEST->user;
    my $USER = $user->NODEDATA;

    # Editor-only operation
    unless ($user->is_editor) {
        return [$self->HTTP_OK, { success => 0, error => 'Permission denied' }];
    }

    # Parse request body
    my $data = $REQUEST->JSON_POSTDATA;

    unless ($data && ref($data) eq 'HASH' && $data->{nodeshells}) {
        return [$self->HTTP_OK, { success => 0, error => 'Invalid request body' }];
    }

    my @nodeshell_titles = @{$data->{nodeshells}};
    my @results = ();

    # Get firmlink linktype ID
    my $firmlink_type = $DB->getNode('firmlink', 'linktype');
    my $firmlink_id = $firmlink_type ? $firmlink_type->{node_id} : 0;

    foreach my $title (@nodeshell_titles) {
        # Clean up title
        $title =~ s/^\s+|\s+$//g;  # trim
        $title =~ s/\[|\]//g;       # remove brackets if copy-pasted from links
        next unless length($title);

        my $result = {
            title => $title,
            status => 'unknown',
            message => '',
        };

        # Look up the nodeshell
        my $nodeshell = $DB->getNode($title, 'e2node');

        if (!$nodeshell) {
            $result->{status} = 'not_found';
            $result->{message} = "Doesn't exist as an e2node";
            push @results, $result;
            next;
        }

        $result->{node_id} = $nodeshell->{node_id};

        # Check if it has writeups (not empty)
        my $has_writeups = 0;
        if (defined($nodeshell->{group}) && ref($nodeshell->{group}) eq 'ARRAY') {
            $has_writeups = scalar(@{$nodeshell->{group}}) > 0;
        }

        if ($has_writeups) {
            $result->{status} = 'not_empty';
            $result->{message} = 'Has writeups - cannot delete';
            push @results, $result;
            next;
        }

        # Check for firmlinks
        if ($firmlink_id) {
            my $has_firmlink = $DB->sqlSelect(
                'to_node', 'links',
                "linktype = $firmlink_id AND from_node = $nodeshell->{node_id}"
            );

            if ($has_firmlink) {
                $result->{status} = 'has_firmlink';
                $result->{message} = 'Part of a firmlink - cannot delete';
                push @results, $result;
                next;
            }
        }

        # All checks passed - delete the nodeshell
        my $deleted = $DB->nukeNode($nodeshell, $USER);

        if ($deleted) {
            $result->{status} = 'deleted';
            $result->{message} = 'Deleted successfully';
        } else {
            $result->{status} = 'error';
            $result->{message} = 'Failed to delete';
        }

        push @results, $result;
    }

    # Count results by status
    my %counts = ();
    foreach my $r (@results) {
        $counts{$r->{status}}++;
    }

    return [$self->HTTP_OK, {
        success => 1,
        results => \@results,
        counts => \%counts,
    }];
}

__PACKAGE__->meta->make_immutable;

1;
