package Everything::Page::content_reports;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::content_reports - Content quality reports for editors

=head1 DESCRIPTION

Displays various automated content quality reports that identify nodes needing repair.
These jobs run on a 24-hour basis and cache results in datastash nodes.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns report data or individual driver results.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $query = $REQUEST->cgi;

    # Define available report drivers
    my $drivers = {
        'editing_invalid_authors' => {
            'title'          => 'Invalid Authors on nodes',
            'extended_title' => 'These nodes do not have authors. Either the users were deleted or the records were damaged. Includes all types'
        },
        'editing_null_node_titles' => {
            'title'          => 'Null titles on nodes',
            'extended_title' => 'These nodes have null or empty-string titles. Not necessarily writeups.'
        },
        'editing_writeups_bad_types' => {
            'title'          => 'Writeup types that are invalid',
            'extended_title' => 'These are writeup types, such as (thing), (idea), (definition), etc that are not valid'
        },
        'editing_writeups_broken_titles' => {
            'title'          => q|Writeup titles that aren't the right pattern|,
            'extended_title' =>
q|These are writeup titles that don't have a left parenthesis in them, which means that it doesn't follow the 'parent_title (type)' pattern.|
        },
        'editing_writeups_invalid_parents' => {
            'title'          => q|Writeups that don't have valid e2node parents|,
            'extended_title' => q|These nodes need to be reparented|
        },
        'editing_writeups_under_20_characters' => {
            'title'          => 'Writeups under 20 characters',
            'extended_title' => 'Writeups that are under 20 characters'
        },
        'editing_writeups_without_formatting' => {
            'title'          => 'Writeups without any HTML tags',
            'extended_title' => q|Writeups that don't have any HTML tags in them, limited to 200, ignores E1 writeups.|
        },
        'editing_writeups_linkless' => {
            'title'          => 'Writeups without links',
            'extended_title' => q|Writeups post-2001 that don't have any links in them|
        },
        'editing_e2nodes_with_duplicate_titles' => {
            'title'          => 'Writeups with titles that only differ by case',
            'extended_title' => 'Writeups that only differ by case'
        },
    };

    my $driver_param = $query->param('driver');

    # If viewing a specific driver
    if ($driver_param) {
        my $datanode = $DB->getNode($driver_param, 'datastash');

        if ($datanode && exists $drivers->{$driver_param}) {
            my $data = $DB->stashData($driver_param);
            $data = [] unless (ref($data) eq 'ARRAY');

            my @nodes = ();
            foreach my $node_id (@$data) {
                my $N = $DB->getNodeById($node_id);
                if ($N) {
                    push @nodes, {
                        node_id => $node_id,
                        title => $N->{title} || '',
                        type => $N->{type}{title}
                    };
                } else {
                    push @nodes, {
                        node_id => $node_id,
                        title => '',
                        type => '',
                        error => 'Could not assemble node reference'
                    };
                }
            }

            return {
                type => 'content_reports',
                view => 'driver',
                driver => $driver_param,
                driver_title => $drivers->{$driver_param}{title},
                driver_description => $drivers->{$driver_param}{extended_title},
                nodes => \@nodes
            };
        } else {
            return {
                type => 'content_reports',
                view => 'driver',
                driver => $driver_param,
                error => "Could not access driver: $driver_param"
            };
        }
    }

    # Otherwise show report list
    my @reports = ();
    foreach my $driver (sort { $a cmp $b } keys %$drivers) {
        my $datanode = $DB->getNode($driver, 'datastash');
        next unless $datanode;
        next unless $datanode->{vars};

        my $data = $DB->stashData($driver);
        $data = [] unless (ref($data) eq 'ARRAY');

        push @reports, {
            driver => $driver,
            title => $drivers->{$driver}{title},
            count => scalar(@$data)
        };
    }

    return {
        type => 'content_reports',
        view => 'list',
        description => 'These jobs are run on a 24 hour basis and cached in the database. They show user-submitted content that is in need of repair.',
        reports => \@reports
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
