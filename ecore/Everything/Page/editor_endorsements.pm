package Everything::Page::editor_endorsements;

use Moose;
extends 'Everything::Page';

sub buildReactData {
    my ($self, $REQUEST) = @_;
    my $DB = $self->DB;
    my $APP = $self->APP;
    my $query = $REQUEST->cgi;

    # Get all editors from gods, Content Editors, and exeds groups
    my @editor_ids;

    my $gods = $DB->getNode("gods", "usergroup");
    push @editor_ids, @{$gods->{group} || []} if $gods;

    my $content_editors = $DB->getNode("Content Editors", "usergroup");
    push @editor_ids, @{$content_editors->{group} || []} if $content_editors;

    my $exeds = $DB->getNode("exeds", "nodegroup");
    push @editor_ids, @{$exeds->{group} || []} if $exeds;

    # Filter out excluded users and non-users
    my %excluded = map {
        my $u = $DB->getNode($_, "user");
        $u ? ($u->{node_id} => 1) : ()
    } ("Cool Man Eddie", "EDB", "Webster 1913", "Klaproth");

    # Build editor list with unique IDs
    my %seen;
    my @editors;
    foreach my $id (@editor_ids) {
        next if $seen{$id};
        $seen{$id} = 1;
        next if $excluded{$id};

        my $user = $DB->getNodeById($id);
        next unless $user && $user->{type}{title} eq 'user';

        push @editors, {
            node_id => $user->{node_id},
            title => $user->{title}
        };
    }

    # Sort by title (case-insensitive)
    @editors = sort { lc($a->{title}) cmp lc($b->{title}) } @editors;

    # Get selected editor's endorsements if requested
    my $editor_id = $query->param('editor');
    $editor_id =~ s/[^\d]//g if $editor_id;

    my $selected_editor = undef;
    my @endorsements = ();

    if ($editor_id) {
        my $editor_node = $DB->getNodeById($editor_id);
        if ($editor_node && $editor_node->{type}{title} eq 'user') {
            $selected_editor = {
                node_id => $editor_node->{node_id},
                title => $editor_node->{title}
            };

            # Get coollinks to this editor
            my $coollink_id = $DB->getId($DB->getNode('coollink', 'linktype'));

            my $csr = $DB->sqlSelectMany(
                'node_id',
                'links LEFT JOIN node ON links.from_node = node.node_id',
                "linktype = $coollink_id AND to_node = $editor_id ORDER BY title"
            );

            while (my $row = $csr->fetchrow_hashref) {
                my $node = $DB->getNodeById($row->{node_id});
                next unless $node;

                my $endorsement = {
                    node_id => $node->{node_id},
                    title => $node->{title},
                    type => $node->{type}{title}
                };

                # For e2nodes, get writeup count
                if ($node->{type}{title} eq 'e2node') {
                    $node->{group} ||= [];
                    $endorsement->{writeup_count} = scalar(@{$node->{group}});
                }

                push @endorsements, $endorsement;
            }
        }
    }

    return {
        type => 'editor_endorsements',
        editors => \@editors,
        selected_editor => $selected_editor,
        endorsements => \@endorsements
    };
}

__PACKAGE__->meta->make_immutable;
1;
