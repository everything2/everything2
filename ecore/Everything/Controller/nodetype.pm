package Everything::Controller::nodetype;

use Moose;
extends 'Everything::Controller';

# Controller for nodetype nodes
# Migrated from Everything::Delegation::htmlpage::nodetype_display_page

sub display {
    my ( $self, $REQUEST, $node ) = @_;

    my $user      = $REQUEST->user;
    my $node_data = $node->NODEDATA;

    # Get nodetype data
    my $nodetype_data = $node->json_display($user);

    # Get SQL tables
    my $sql_tables = [];
    if ( $node_data->{sqltable} ) {
        my @table_names = split /,/, $node_data->{sqltable};
        foreach my $table_name (@table_names) {
            my $table_node = $self->DB->getNode( $table_name, 'dbtable' );
            if ($table_node) {
                push @$sql_tables,
                  {
                    node_id => $table_node->{node_id},
                    title   => $table_node->{title}
                  };
            }
        }
    }

    # Get extends nodetype
    my $extends_nodetype;
    if ( $node_data->{extends_nodetype} ) {
        my $extends_node =
          $self->APP->node_by_id( $node_data->{extends_nodetype} );
        if ($extends_node) {
            $extends_nodetype = $extends_node->json_reference;
        }
    }

    # Get relevant pages
    my @pages      = Everything::HTML::getPages($node_data);
    my $pages_data = [];
    foreach my $page_node (@pages) {
        push @$pages_data,
          {
            node_id => $page_node->{node_id},
            title   => $page_node->{title}
          };
    }

    # Get active maintenances
    my @maintenance_nodes = $self->DB->getNodeWhere(
        { maintain_nodetype => $node->node_id },
        $self->DB->getType('maintenance')
    );
    my $maintenances = [];
    foreach my $maint (@maintenance_nodes) {
        push @$maintenances,
          {
            node_id => $maint->{node_id},
            title   => $maint->{title}
          };
    }

    # Get group lists for readers, writers, deleters
    my $readers  = $self->_getGroupMembers( $node_data, 'readers_user' );
    my $writers  = $self->_getGroupMembers( $node_data, 'writers_user' );
    my $deleters = $self->_getGroupMembers( $node_data, 'deleters_user' );

    # Build user data
    my $user_data = {
        node_id   => $user->node_id,
        title     => $user->title,
        is_guest  => $user->is_guest  ? 1 : 0,
        is_editor => $user->is_editor ? 1 : 0
    };

    # Build source map for nodetype (shows Everything::Node::$nodetype class)
    my $nodetype_name = $node->title;
    my $source_map    = {
        githubRepo => 'https://github.com/everything2/everything2',
        branch     => 'master',
        commitHash => $self->APP->{conf}->last_commit || 'master',
        components => [
            {
                type        => 'node_class',
                name        => "Everything::Node::$nodetype_name",
                path        => "ecore/Everything/Node/$nodetype_name.pm",
                description => 'Node class implementation'
            },
            {
                type        => 'controller',
                name        => 'Everything::Controller::nodetype',
                path        => 'ecore/Everything/Controller/nodetype.pm',
                description => 'Controller for nodetype display'
            },
            {
                type        => 'react_component',
                name        => 'Nodetype',
                path        => 'react/components/Documents/Nodetype.js',
                description => 'React component for nodetype display'
            }
        ]
    };

    # Add SQL tables to source map if they exist
    if ( $node_data->{sqltable} ) {
        my @table_names = split /,/, $node_data->{sqltable};
        foreach my $table_name (@table_names) {
            push @{ $source_map->{components} },
              {
                type        => 'database_table',
                name        => $table_name,
                path        => "nodepack/dbtable/$table_name.xml",
                description => "Node type table: $table_name"
              };
        }
    }

    # Build contentData for React
    my $content_data = {
        type     => 'nodetype',
        nodetype => {
            %$nodetype_data,
            sql_tables       => $sql_tables,
            extends_nodetype => $extends_nodetype,
            pages            => $pages_data,
            maintenances     => $maintenances,
            readers          => $readers,
            writers          => $writers,
            deleters         => $deleters,
            restrictdupes    => $node_data->{restrictdupes} || 0,
            verify_edits     => $node_data->{verify_edits}  || 0
        },
        user      => $user_data,
        sourceMap => $source_map
    };

    # Set node on REQUEST for buildNodeInfoStructure
    $REQUEST->node($node);

    # Build e2 data structure
    my $e2 =
      $self->APP->buildNodeInfoStructure( $node_data, $REQUEST->user->NODEDATA,
        $REQUEST->user->VARS, $REQUEST->cgi, $REQUEST );

    # Override contentData with our directly-built data
    $e2->{contentData}   = $content_data;
    $e2->{reactPageMode} = \1;

    # Use react_page layout (includes sidebar/header/footer)
    my $html = $self->layout(
        '/pages/react_page',
        e2      => $e2,
        REQUEST => $REQUEST,
        node    => $node
    );
    return [ $self->HTTP_OK, $html ];
}

# Helper to get group members
sub _getGroupMembers {
    my ( $self, $node, $field_name ) = @_;

    return [] unless $node->{$field_name};

    my $group_node = $self->APP->node_by_id( $node->{$field_name} );
    return [] unless $group_node;

    my $members = [];
    if ( $group_node->{group} ) {
        foreach my $member_id ( @{ $group_node->{group} } ) {
            my $member = $self->APP->node_by_id($member_id);
            if ($member) {
                push @$members,
                  {
                    node_id => $member->node_id,
                    title   => $member->title
                  };
            }
        }
    }

    return $members;
}

__PACKAGE__->meta->make_immutable();
1;
