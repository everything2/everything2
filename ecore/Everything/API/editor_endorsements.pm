package Everything::API::editor_endorsements;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::editor_endorsements - the nodes an editor has C!'d (endorsed)

=head1 DESCRIPTION

Lists the site's editors and, for a selected editor, the nodes they have cooled (coollinks pointing
at them). Moved out of C<Everything::Page::editor_endorsements>'s buildReactData (#4528): the Page is
a pure gate, React reads the selected C<editor> id off the URL and calls this.

  GET /api/editor_endorsements?editor=<user_node_id>

Public. Ships data only.

=cut

sub routes { return { "/" => "list" }; }

sub list {
    my ($self, $REQUEST) = @_;
    my $DB = $self->DB;

    # Editors = gods + Content Editors + exeds, minus a few bots, unique, sorted by title.
    my @editor_ids;
    for my $spec (['gods', 'usergroup'], ['Content Editors', 'usergroup'], ['exeds', 'nodegroup']) {
        my $grp = $DB->getNode(@$spec);
        push @editor_ids, @{ $grp->{group} || [] } if $grp;
    }

    my %excluded = map {
        my $u = $DB->getNode($_, 'user'); $u ? ($u->{node_id} => 1) : ()
    } ('Cool Man Eddie', 'EDB', 'Webster 1913', 'Klaproth');

    my (%seen, @editors);
    for my $id (@editor_ids) {
        next if $seen{$id}++;
        next if $excluded{$id};
        my $user = $DB->getNodeById($id);
        next unless $user && $user->{type}{title} eq 'user';
        push @editors, { node_id => int($user->{node_id}), title => $user->{title} };
    }
    @editors = sort { lc($a->{title}) cmp lc($b->{title}) } @editors;

    my $editor_id = $REQUEST->param('editor');
    $editor_id =~ s/[^\d]//g if defined $editor_id;

    my $selected_editor = undef;
    my @endorsements;

    if ($editor_id) {
        my $editor_node = $DB->getNodeById(int($editor_id));
        if ($editor_node && $editor_node->{type}{title} eq 'user') {
            $selected_editor = { node_id => int($editor_node->{node_id}), title => $editor_node->{title} };

            my $coollink_id = $DB->getId($DB->getNode('coollink', 'linktype'));
            my $to = int($editor_id);   # digits-only above -> injection-safe
            my $csr = $DB->sqlSelectMany(
                'node_id',
                'links LEFT JOIN node ON links.from_node = node.node_id',
                "linktype = $coollink_id AND to_node = $to ORDER BY title"
            );

            while (my $row = $csr->fetchrow_hashref) {
                my $node = $DB->getNodeById($row->{node_id});
                next unless $node;
                my $endorsement = {
                    node_id => int($node->{node_id}),
                    title   => $node->{title},
                    type    => $node->{type}{title},
                };
                if ($node->{type}{title} eq 'e2node') {
                    $node->{group} ||= [];
                    $endorsement->{writeup_count} = scalar(@{ $node->{group} });
                }
                push @endorsements, $endorsement;
            }
        }
    }

    return [$self->HTTP_OK, {
        success         => 1,
        editors         => \@editors,
        selected_editor => $selected_editor,
        endorsements    => \@endorsements,
    }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut
