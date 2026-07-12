package Everything::API::content_reports;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::content_reports - editor content-quality reports

=head1 DESCRIPTION

Serves the content-quality reports (cached datastash jobs that flag nodes needing repair). This
used to run inside C<Everything::Page::content_reports>'s buildReactData off the C<?driver> query
param; the param + the datastash work now live here (#4511), the Page is a pure gate, and React
(ContentReports) reads C<?driver> off the URL and calls this.

  GET /api/content_reports            -> list view: every driver with cached data + its failure count
  GET /api/content_reports/:driver    -> driver view: the driver's flagged nodes

Editor-only. The report labels/descriptions are React's concern (ContentReports REPORT_LABELS); this
ships only driver ids + backend-derived data (counts, resolved node refs).

=cut

# The valid report drivers. Just the enumeration/validity set -- the display labels live in React.
my @DRIVERS = qw(
    editing_invalid_authors
    editing_null_node_titles
    editing_writeups_bad_types
    editing_writeups_broken_titles
    editing_writeups_invalid_parents
    editing_writeups_under_20_characters
    editing_writeups_without_formatting
    editing_writeups_linkless
    editing_e2nodes_with_duplicate_titles
);
my %VALID_DRIVER = map { $_ => 1 } @DRIVERS;

sub routes {
    return {
        "/"       => "list",
        ":driver" => "driver(:driver)",
    };
}

# Editors only. Returns HTTP 200 with success=0 (never a 4xx -- mod_perl appends HTML to non-200s
# and breaks the JSON client).
sub _editors_only {
    my ($self, $REQUEST) = @_;
    return if $REQUEST->user->is_editor;   # allowed -> no denial response
    return [$self->HTTP_OK, { success => 0, error => 'Editors only' }];
}

=head2 list($REQUEST)

Every driver that has cached data, with its current failure count.

=cut

sub list {
    my ($self, $REQUEST) = @_;
    if (my $denied = $self->_editors_only($REQUEST)) { return $denied; }

    my $DB = $self->DB;
    my @reports;
    foreach my $driver (sort @DRIVERS) {
        my $datanode = $DB->getNode($driver, 'datastash');
        next unless $datanode;
        next unless $datanode->{vars};

        my $data = $DB->stashData($driver);
        $data = [] unless ref($data) eq 'ARRAY';

        push @reports, { driver => $driver, count => scalar(@$data) };
    }

    return [$self->HTTP_OK, { success => 1, view => 'list', reports => \@reports }];
}

=head2 driver($REQUEST, $driver)

The flagged nodes for a single driver (resolved to node_id/title/type).

=cut

sub driver {
    my ($self, $REQUEST, $driver) = @_;
    if (my $denied = $self->_editors_only($REQUEST)) { return $denied; }

    my $DB = $self->DB;
    my $datanode = $DB->getNode($driver, 'datastash');

    unless ($datanode && $VALID_DRIVER{$driver}) {
        # error copy ("Could not access driver: <id>") is React's; ship just the flag + id.
        return [$self->HTTP_OK, { success => 1, view => 'driver', driver => $driver, error => 1 }];
    }

    my $data = $DB->stashData($driver);
    $data = [] unless ref($data) eq 'ARRAY';

    my @nodes;
    foreach my $node_id (@$data) {
        my $N = $DB->getNodeById($node_id);
        if ($N) {
            push @nodes, {
                node_id => int($node_id),
                title   => $N->{title} || '',
                type    => $N->{type}{title},
            };
        } else {
            # node-ref failure is a flag; the "Could not assemble node reference" copy is React's.
            push @nodes, { node_id => int($node_id), title => '', type => '', error => 1 };
        }
    }

    return [$self->HTTP_OK, { success => 1, view => 'driver', driver => $driver, nodes => \@nodes }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGatePage>

=cut
