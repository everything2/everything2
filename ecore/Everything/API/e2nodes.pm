package Everything::API::e2nodes;

use Moose;
extends 'Everything::API::nodes';

has 'CREATE_ALLOWED' => (is => 'ro', isa => 'Int', default => 1);

around 'routes' => sub {
    my ($orig, $self) = @_;
    my $parent_routes = $self->$orig();
    return {
        %{$parent_routes},
        'bulk-rename' => 'bulk_rename',
    };
};

=head2 bulk_rename

POST /api/e2nodes/bulk-rename

Bulk rename e2nodes. Editor-only operation.

Request body:
    {
        "renames": [
            { "from": "old title", "to": "new title" },
            ...
        ]
    }

=cut

sub bulk_rename {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $user = $REQUEST->user;

    # Editor-only operation
    unless ($user->is_editor) {
        return [$self->HTTP_OK, { success => 0, error => 'Permission denied' }];
    }

    # Parse request body
    my $data = $REQUEST->JSON_POSTDATA;

    unless ($data && ref($data) eq 'HASH' && $data->{renames}) {
        return [$self->HTTP_OK, { success => 0, error => 'Invalid request body' }];
    }

    my @renames = @{$data->{renames}};
    my @results = ();

    foreach my $rename (@renames) {
        my $from = $rename->{from} // '';
        my $to = $rename->{to} // '';

        # Trim whitespace
        $from =~ s/^\s+|\s+$//g;
        $to =~ s/^\s+|\s+$//g;

        next unless length($from) && length($to);

        my $result = {
            from   => $from,
            to     => $to,
            status => 'unknown',
        };

        # Look up source e2node by title, then get full node by ID
        # Using getNodeById ensures proper table joins for updateNode
        my $lookup = $DB->getNode($from, 'e2node');

        if (!$lookup) {
            $result->{status} = 'not_found';
            $result->{message} = "No such e2node: $from";
            push @results, $result;
            next;
        }

        my $from_node = $DB->getNodeById($lookup->{node_id});
        my $real_from = $from_node->{title};
        my $change_caps_only = ($real_from ne $to && lc($real_from) eq lc($to));

        # Check if same title
        if ($real_from eq $to) {
            $result->{status} = 'no_change';
            $result->{message} = 'Titles are identical';
            push @results, $result;
            next;
        }

        # Check if target already exists (unless just changing capitalization)
        if (!$change_caps_only) {
            my $to_node = $DB->getNode($to, 'e2node');
            if ($to_node) {
                $result->{status} = 'target_exists';
                $result->{message} = "Target e2node already exists: $to";
                $result->{targetNodeId} = $to_node->{node_id};
                push @results, $result;
                next;
            }
        }

        # Perform the rename
        $result->{nodeId} = $from_node->{node_id};
        $from_node->{title} = $to;
        $DB->updateNode($from_node, -1);

        # Repair the e2node (update writeup titles to match new e2node title)
        $self->APP->repairE2Node($from_node);

        $result->{status} = 'renamed';
        $result->{message} = 'Renamed and repaired';

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
        counts  => \%counts,
    }];
}

__PACKAGE__->meta->make_immutable;
1;
