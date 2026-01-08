package Everything::Controller::dbtable;

use Moose;
extends 'Everything::Controller';
with 'Everything::Controller::Role::BasicEdit';

# Controller for dbtable nodes
# Migrated from Everything::Delegation::htmlpage::dbtable_display_page, dbtable_index_page

sub display {
    my ($self, $REQUEST, $node) = @_;

    my $user = $REQUEST->user;
    my $DB = $self->DB;
    my $APP = $self->APP;

    # Only gods can view dbtable details
    unless ($APP->isAdmin($user->NODEDATA)) {
        return $self->error_page($REQUEST, 'Access denied', 'dbtable display is restricted to administrators.');
    }

    my $table_name = $node->title;

    # Get table status (engine, row count estimate)
    my $table_status = {};
    my $qh = $DB->{dbh}->prepare("SHOW TABLE STATUS LIKE ?");
    $qh->execute($table_name);
    $table_status = $qh->fetchrow_hashref() || {};
    $qh->finish();

    my $engine = $table_status->{Engine} // 'Unknown';
    my $approx_rows = $table_status->{Rows} // 0;

    # Get field information
    my @fields = $DB->getFieldsHash($table_name);
    my @field_data;
    foreach my $field (@fields) {
        push @field_data, {
            name => $field->{Field},
            type => $field->{Type},
            null => $field->{Null},
            key => $field->{Key},
            default => $field->{Default},
            extra => $field->{Extra},
        };
    }

    # Get index information
    my @indexes;
    my $idx_sth = $DB->{dbh}->prepare("SHOW INDEX FROM $table_name");
    $idx_sth->execute();
    while (my $rec = $idx_sth->fetchrow_hashref()) {
        push @indexes, {
            key_name => $rec->{Key_name},
            seq_in_index => $rec->{Seq_in_index},
            column_name => $rec->{Column_name},
            collation => $rec->{Collation},
            cardinality => $rec->{Cardinality},
            sub_part => $rec->{Sub_part},
            packed => $rec->{Packed},
            comment => $rec->{Comment} // $rec->{Index_comment} // '',
        };
    }
    $idx_sth->finish();

    # Build user data
    my $user_data = {
        node_id  => $user->node_id,
        title    => $user->title,
        is_guest => $user->is_guest ? 1 : 0,
        is_admin => $user->is_admin ? 1 : 0,
    };

    # Build contentData for React
    my $content_data = {
        type => 'dbtable',
        table => {
            node_id => $node->node_id,
            name => $table_name,
            engine => $engine,
            approx_rows => int($approx_rows),
        },
        fields => \@field_data,
        indexes => \@indexes,
        user => $user_data,
    };

    # Set node on REQUEST for buildNodeInfoStructure
    $REQUEST->node($node);

    # Build e2 data structure
    my $e2 = $APP->buildNodeInfoStructure(
        $node->NODEDATA,
        $REQUEST->user->NODEDATA,
        $REQUEST->user->VARS,
        $REQUEST->cgi,
        $REQUEST
    );

    # Override contentData with our directly-built data
    $e2->{contentData} = $content_data;
    $e2->{reactPageMode} = \1;

    # Use react_page layout (includes sidebar/header/footer)
    my $html = $self->layout(
        '/pages/react_page',
        e2 => $e2,
        REQUEST => $REQUEST,
        node => $node
    );

    return [$self->HTTP_OK, $html];
}

__PACKAGE__->meta->make_immutable();
1;
