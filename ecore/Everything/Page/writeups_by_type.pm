package Everything::Page::writeups_by_type;

use Moose;
extends 'Everything::Page';

# Writeups by Type - Browse writeups filtered by writeup type
# Migrated from Everything::Delegation::document::writeups_by_type
# Shows a filterable list of writeups with pagination

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $USER = $REQUEST->user->NODEDATA;
    my $VARS = $REQUEST->user->VARS;
    my $query = $REQUEST->cgi;

    # Get URL parameters
    my $wuType = abs(int($query->param('wutype') || 0));
    my $count = abs(int($query->param('count') || 50));
    my $page = abs(int($query->param('page') || 0));

    # Sanity check count
    $count = 50 if $count < 10 || $count > 500;

    # Get all writeup types for the filter dropdown
    my $writeuptype_type = $DB->getType('writeuptype');
    my @writeup_types = $DB->getNodeWhere({ type_nodetype => $writeuptype_type->{node_id} });

    my @type_options;
    push @type_options, { value => 0, label => 'All' };
    for my $wt (sort { $a->{title} cmp $b->{title} } @writeup_types) {
        push @type_options, {
            value => $wt->{node_id},
            label => $wt->{title}
        };
    }

    # Build WHERE clause
    my $where = '';
    $where = "wrtype_writeuptype = $wuType" if $wuType;

    # Get writeups with pagination
    my $offset = $page * $count;
    my $sth = $DB->sqlSelectMany(
        'node.node_id, writeup_id, parent_e2node, publishtime,
         node.author_user, node.title,
         type.title AS type_title',
        'writeup
         JOIN node ON writeup_id = node.node_id
         JOIN node type ON type.node_id = writeup.wrtype_writeuptype',
        $where,
        "ORDER BY publishtime DESC LIMIT $offset, $count"
    );

    my @writeups;
    while (my $row = $sth->fetchrow_hashref) {
        my $author = $DB->getNodeById($row->{author_user});
        my $parent = $row->{parent_e2node} ? $DB->getNodeById($row->{parent_e2node}) : undef;

        push @writeups, {
            node_id => $row->{node_id},
            title => $row->{title},
            writeup_type => $row->{type_title},
            publishtime => $row->{publishtime},
            author => $author ? {
                node_id => $author->{node_id},
                title => $author->{title}
            } : undef,
            parent => $parent ? {
                node_id => $parent->{node_id},
                title => $parent->{title}
            } : undef
        };
    }
    $sth->finish;

    # Get selected type name for display
    my $selected_type_name = 'All';
    if ($wuType) {
        my $type_node = $DB->getNodeById($wuType);
        $selected_type_name = $type_node->{title} if $type_node;
    }

    # Count options for dropdown
    my @count_options = (10, 25, 50, 75, 100, 150, 200, 250, 500);

    return {
        type => 'writeups_by_type',
        writeups => \@writeups,
        type_options => \@type_options,
        count_options => \@count_options,
        current_type => $wuType,
        current_type_name => $selected_type_name,
        current_count => $count,
        current_page => $page
    };
}

__PACKAGE__->meta->make_immutable;
1;
