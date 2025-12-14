package Everything::Page::the_node_crypt;

use Moose;
extends 'Everything::Page';
use Everything::Serialization qw(safe_deserialize_dumper);

=head1 NAME

Everything::Page::the_node_crypt - View deleted nodes in the tomb

=head1 DESCRIPTION

Admin tool for viewing nodes that have been deleted and stored in the tomb table.
Allows viewing details of deleted nodes and provides resurrection links.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP  = $self->APP;
    my $DB   = $self->DB;
    my $USER = $REQUEST->user;
    my $q    = $REQUEST->cgi;

    # Admin-only page
    unless ($APP->isAdmin($USER->NODEDATA)) {
        return {
            type  => 'the_node_crypt',
            error => 'This page is restricted to administrators.'
        };
    }

    my $node_id = $REQUEST->node->node_id;

    # Viewing a specific coffin (deleted node details)
    if (my $coffin_id = $q->param('opencoffin')) {
        return $self->_view_coffin($DB, $coffin_id, $node_id);
    }

    # List all nodes in the tomb
    return $self->_list_tomb($DB, $node_id);
}

sub _view_coffin {
    my ($self, $DB, $coffin_id, $page_node_id) = @_;

    my $dbh = $DB->getDatabaseHandle();
    my $N = $DB->sqlSelectHashref('*', 'tomb', 'node_id=' . $dbh->quote($coffin_id));

    unless ($N) {
        return {
            type      => 'the_node_crypt',
            error     => "Node $coffin_id not found in tomb",
            node_id   => $page_node_id
        };
    }

    # Deserialize the stored data
    my $DATA = safe_deserialize_dumper('my ' . $N->{data});

    unless ($DATA) {
        return {
            type      => 'the_node_crypt',
            error     => "Deserialization failed for node $coffin_id",
            node_id   => $page_node_id
        };
    }

    # Merge data into main hash
    @$N{keys %$DATA} = values %$DATA;
    delete $N->{data};

    # Check if already resurrected
    my $existing = $DB->getNodeById($coffin_id);
    my $is_resurrected = $existing ? 1 : 0;
    my $existing_title = $existing ? $existing->{title} : undef;

    # Get dr. nate's secret lab for resurrection link
    my $lab = $DB->getNode("dr. nate's secret lab", 'restricted_superdoc');
    my $lab_id = $lab ? int($lab->{node_id}) : undef;

    # Build fields list, resolving node IDs to titles where appropriate
    my @fields = ();
    foreach my $key (sort keys %$N) {
        my $value = $N->{$key};
        my $is_node_id = 0;
        my $resolved_title = undef;

        # Fields ending in _ that have numeric values might be node IDs
        if ($key =~ /_/ && defined($value) && $value =~ /^\d+$/ && $value != -1) {
            my $ref_node = $DB->getNodeById($value);
            if ($ref_node) {
                $is_node_id = 1;
                $resolved_title = $ref_node->{title};
            }
        }

        push @fields, {
            key            => $key,
            value          => defined($value) ? "$value" : '',
            is_node_id     => $is_node_id,
            resolved_title => $resolved_title
        };
    }

    return {
        type            => 'the_node_crypt',
        viewing_coffin  => 1,
        coffin_id       => int($coffin_id),
        node_id         => $page_node_id,
        is_resurrected  => $is_resurrected,
        existing_title  => $existing_title,
        lab_id          => $lab_id,
        fields          => \@fields,
        field_count     => scalar(@fields)
    };
}

sub _list_tomb {
    my ($self, $DB, $page_node_id) = @_;

    my $csr = $DB->sqlSelectMany('title, type_nodetype, author_user, killa_user, node_id', 'tomb');

    my @items = ();
    while (my $N = $csr->fetchrow_hashref()) {
        my $killa = $N->{killa_user};
        $killa = 0 if $killa == -1;

        my $author_id = $N->{author_user};
        my $author_title = undef;
        if ($author_id != -1) {
            my $author = $DB->getNodeById($author_id);
            $author_title = $author ? $author->{title} : undef;
        }

        my $type = $DB->getNodeById($N->{type_nodetype}, 'light');
        my $type_title = $type ? $type->{title} : 'unknown';

        my $killa_user = $killa ? $DB->getNodeById($killa) : undef;
        my $killa_title = $killa_user ? $killa_user->{title} : undef;

        push @items, {
            node_id       => int($N->{node_id}),
            title         => $N->{title},
            type_id       => int($N->{type_nodetype}),
            type_title    => $type_title,
            author_id     => $author_id == -1 ? undef : int($author_id),
            author_title  => $author_title,
            killa_id      => $killa ? int($killa) : undef,
            killa_title   => $killa_title
        };
    }
    $csr->finish;

    return {
        type      => 'the_node_crypt',
        items     => \@items,
        count     => scalar(@items),
        node_id   => $page_node_id
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
