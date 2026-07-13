package Everything::API::writeups_by_type;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::writeups_by_type - paginated writeups filtered by writeup type

=head1 DESCRIPTION

Public browse: a page of writeups, optionally filtered by writeup type, newest first. This used to
run inside C<Everything::Page::writeups_by_type>'s buildReactData off the ?wutype/count/page query
params; the params + the query now live here (#4524), the Page is a pure gate, and React
(WriteupsByType) reads the filters off the URL and calls this.

  GET /api/writeups_by_type?wutype=<id>&count=<n>&page=<n>

Ships data only (writeups + the type-filter options + the validated filter state); the static
per-page count choices and the empty-state copy are React's concern.

=cut

sub routes { return { "/" => "list" }; }

sub list {
    my ($self, $REQUEST) = @_;
    my $DB = $self->DB;

    my $wuType = abs(int($REQUEST->param('wutype') || 0));
    my $count  = abs(int($REQUEST->param('count')  || 50));
    my $page   = abs(int($REQUEST->param('page')   || 0));
    $count = 50 if $count < 10 || $count > 500;   # sanity clamp (bounds the LIMIT)

    # Writeup types for the filter dropdown.
    my $writeuptype_type = $DB->getType('writeuptype');
    my @writeup_types = $DB->getNodeWhere({ type_nodetype => $writeuptype_type->{node_id} });
    my @type_options = ({ value => 0, label => 'All' });
    for my $wt (sort { $a->{title} cmp $b->{title} } @writeup_types) {
        push @type_options, { value => int($wt->{node_id}), label => $wt->{title} };
    }

    # $wuType/$offset/$count are abs(int(...)) -> injection-safe to interpolate into the LIMIT/WHERE.
    my $where  = $wuType ? "wrtype_writeuptype = $wuType" : '';
    my $offset = $page * $count;
    my $sth = $DB->sqlSelectMany(
        'node.node_id, writeup_id, parent_e2node, publishtime, node.author_user, node.title, type.title AS type_title',
        'writeup JOIN node ON writeup_id = node.node_id JOIN node type ON type.node_id = writeup.wrtype_writeuptype',
        $where,
        "ORDER BY publishtime DESC LIMIT $offset, $count"
    );

    my @writeups;
    while (my $row = $sth->fetchrow_hashref) {
        my $author = $DB->getNodeById($row->{author_user});
        my $parent = $row->{parent_e2node} ? $DB->getNodeById($row->{parent_e2node}) : undef;
        push @writeups, {
            node_id      => int($row->{node_id}),
            title        => $row->{title},
            writeup_type => $row->{type_title},
            publishtime  => $row->{publishtime},
            author => $author ? { node_id => int($author->{node_id}), title => $author->{title} } : undef,
            parent => $parent ? { node_id => int($parent->{node_id}), title => $parent->{title} } : undef,
        };
    }
    $sth->finish;

    my $selected_type_name = 'All';
    if ($wuType) {
        my $type_node = $DB->getNodeById($wuType);
        $selected_type_name = $type_node->{title} if $type_node;
    }

    return [$self->HTTP_OK, {
        success           => 1,
        writeups          => \@writeups,
        type_options      => \@type_options,
        current_type      => $wuType + 0,
        current_type_name => $selected_type_name,
        current_count     => $count + 0,
        current_page      => $page + 0,
    }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut
