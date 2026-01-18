package Everything::Node::category;
use Moose;
extends 'Everything::Node::document';

# Custom meta description for category pages
sub metadescription {
    my ($self) = @_;

    my $title = $self->title;
    my $member_count = $self->_get_member_count();

    # Build description based on category content
    my $desc;
    if ($member_count > 0) {
        $desc = "\"$title\" - A curated collection of $member_count ";
        $desc .= $member_count == 1 ? "item" : "items";
        $desc .= " on Everything2. Browse related writings, discussions, and creative works organized by topic.";
    } else {
        $desc = "\"$title\" - A category on Everything2. Everything2 is a community for fiction, nonfiction, poetry, reviews, and more.";
    }

    return $desc;
}

# Get the number of members in this category
sub _get_member_count {
    my ($self) = @_;

    my $category_linktype = $self->DB->getNode('category', 'linktype');
    return 0 unless $category_linktype;

    my $count = $self->DB->sqlSelect(
        'COUNT(*)',
        'links',
        'from_node = ' . $self->node_id . ' AND linktype = ' . $category_linktype->{node_id}
    );

    return $count || 0;
}

__PACKAGE__->meta->make_immutable;
1;
