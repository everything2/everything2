package Everything::Page::page_of_cool;

use Moose;
extends 'Everything::Page';

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;

    # Get list of editors (gods, Content Editors, exeds)
    my @editor_ids;
    my %seen;

    # Gods
    my $gods = $DB->getNode('gods', 'usergroup');
    push @editor_ids, @{$gods->{group}} if $gods && $gods->{group};

    # Content Editors
    my $content_eds = $DB->getNode('Content Editors', 'usergroup');
    push @editor_ids, @{$content_eds->{group}} if $content_eds && $content_eds->{group};

    # Ex-editors (exeds nodegroup)
    my $exeds = $DB->getNode('exeds', 'nodegroup');
    push @editor_ids, @{$exeds->{group}} if $exeds && $exeds->{group};

    # Exclude certain users
    my %exclude;
    for my $name ('Cool Man Eddie', 'EDB', 'Webster 1913', 'Klaproth', 'PadLock') {
        my $u = $DB->getNode($name, 'user');
        $exclude{$u->{node_id}} = 1 if $u;
    }

    # Build editor list, removing duplicates and excluded users
    my @editors;
    for my $id (@editor_ids) {
        next if $seen{$id} || $exclude{$id};
        my $user = $DB->getNodeById($id);
        next unless $user && $user->{type}{title} eq 'user';

        push @editors, {
            node_id => $user->{node_id},
            title => $user->{title}
        };
        $seen{$id} = 1;
    }

    # Sort editors alphabetically by title
    @editors = sort { lc($a->{title}) cmp lc($b->{title}) } @editors;

    # Get initial coolnodes (first 50)
    my $coolnodes_group = $DB->getNode('coolnodes', 'nodegroup');
    my @initial_coolnodes;
    my $total_coolnodes = 0;

    if ($coolnodes_group && $coolnodes_group->{group}) {
        my $node_ids = $coolnodes_group->{group};
        $total_coolnodes = scalar(@$node_ids);

        # Get coollink linktype for finding who cooled each node
        my $coollink = $DB->getNode('coollink', 'linktype');
        my $coollink_id = $coollink ? $coollink->{node_id} : 0;

        # Get first 50 in reverse order (most recent first)
        my @reversed = reverse @$node_ids;
        my @first_50 = splice(@reversed, 0, 50);

        for my $node_id (@first_50) {
            my $node = $DB->getNodeById($node_id);
            next unless $node;

            # Find who cooled this node
            my $cooled_by_name = undef;
            if ($coollink_id) {
                my $link_row = $DB->{dbh}->selectrow_hashref(
                    'SELECT to_node FROM links WHERE from_node = ? AND linktype = ?',
                    {}, $node_id, $coollink_id
                );
                if ($link_row && $link_row->{to_node}) {
                    my $cooler = $DB->getNodeById($link_row->{to_node});
                    $cooled_by_name = $cooler->{title} if $cooler;
                }
            }

            push @initial_coolnodes, {
                node_id => $node->{node_id},
                title => $node->{title},
                cooled_by_name => $cooled_by_name
            };
        }
    }

    return {
        type => 'page_of_cool',
        editors => \@editors,
        initial_coolnodes => \@initial_coolnodes,
        pagination => {
            offset => 0,
            limit => 50,
            total => $total_coolnodes
        }
    };
}

__PACKAGE__->meta->make_immutable;

1;
