package Everything::Page::simple_usergroup_editor;

use Moose;
extends 'Everything::Page';

use Everything qw(getNode getNodeById getId);

=head1 Everything::Page::simple_usergroup_editor

React page for Simple Usergroup Editor - allows editing usergroup membership.

=cut

sub buildReactData
{
    my ( $self, $REQUEST ) = @_;

    my $DB    = $self->DB;
    my $APP   = $self->APP;
    my $USER  = $REQUEST->user;
    my $query = $REQUEST->cgi;

    my $is_admin  = $APP->isAdmin( $USER->NODEDATA );
    my $is_editor = $APP->isEditor( $USER->NODEDATA );

    # Forbidden groups for editors (only admins can edit these)
    my $forbidden_for_editors = {
        'content editors' => 1,
        'gods'            => 1,
        'e2gods'          => 1
    };
    my $editor_only = $is_editor && !$is_admin;

    # Process form submission if this is a POST
    my $message = $self->_process_form( $REQUEST, $forbidden_for_editors, $editor_only );

    # Get list of usergroups the user can edit
    my @usergroups;

    if ($is_editor) {
        # Editors can see all usergroups
        my $usergroup_type = $DB->getType('usergroup');
        my $csr = $DB->sqlSelectMany(
            'node_id, title',
            'node',
            'type_nodetype=' . $usergroup_type->{node_id},
            'ORDER BY title'
        );
        while ( my $row = $csr->fetchrow_hashref ) {
            # Skip forbidden groups for non-admin editors
            next if $editor_only && exists $forbidden_for_editors->{ lc( $row->{title} ) };
            push @usergroups, {
                node_id => $row->{node_id},
                title   => $row->{title}
            };
        }
    } else {
        # Regular users can only edit usergroups they own
        my $csr = $DB->sqlSelectMany(
            'node.node_id, node.title',
            'nodeparam JOIN node on nodeparam.node_id=node.node_id',
            "paramkey='usergroup_owner' AND paramvalue='$USER->NODEDATA->{node_id}'",
            'ORDER BY node.title'
        );
        while ( my $row = $csr->fetchrow_hashref ) {
            push @usergroups, {
                node_id => $row->{node_id},
                title   => $row->{title}
            };
        }
    }

    # Get selected usergroup details if one is selected
    my $selected_usergroup;
    my @members;
    my @ignoring_users;

    my $for_usergroup_id = $query->param('for_usergroup');
    if ($for_usergroup_id) {
        my $usergroup = $DB->getNodeById($for_usergroup_id);

        # Verify user can edit this usergroup
        my $can_edit = 0;
        foreach my $ug (@usergroups) {
            if ( $ug->{node_id} == $for_usergroup_id ) {
                $can_edit = 1;
                last;
            }
        }

        if ( $usergroup && $can_edit ) {
            # Check forbidden groups again
            if ( $editor_only && exists $forbidden_for_editors->{ lc( $usergroup->{title} ) } ) {
                $can_edit = 0;
            }

            if ($can_edit) {
                $selected_usergroup = {
                    node_id => $usergroup->{node_id},
                    title   => $usergroup->{title}
                };

                # Get members
                my $group = $usergroup->{group} || [];
                foreach my $member_id (@$group) {
                    my $member = $DB->getNodeById($member_id);
                    next unless $member;
                    push @members, {
                        node_id  => $member->{node_id},
                        title    => $member->{title},
                        lasttime => $member->{lasttime}
                    };
                }

                # Get users ignoring this group
                my $ignore_csr = $DB->sqlSelectMany(
                    'messageignore_id',
                    'messageignore',
                    'ignore_node=' . $for_usergroup_id
                );
                while ( my $row = $ignore_csr->fetchrow_hashref ) {
                    my $ignorer = $DB->getNodeById( $row->{messageignore_id} );
                    next unless $ignorer;
                    push @ignoring_users, {
                        node_id => $ignorer->{node_id},
                        title   => $ignorer->{title}
                    };
                }
            }
        }
    }

    unless ( @usergroups || $selected_usergroup ) {
        return {
            type       => 'simple_usergroup_editor',
            no_access  => 1
        };
    }

    return {
        type              => 'simple_usergroup_editor',
        usergroups        => \@usergroups,
        selected_usergroup => $selected_usergroup,
        members           => \@members,
        ignoring_users    => \@ignoring_users,
        is_admin          => $is_admin ? 1 : 0,
        is_editor         => $is_editor ? 1 : 0,
        message           => $message
    };
}

sub _process_form
{
    my ( $self, $REQUEST, $forbidden_for_editors, $editor_only ) = @_;

    my $DB    = $self->DB;
    my $APP   = $self->APP;
    my $USER  = $REQUEST->user;
    my $query = $REQUEST->cgi;

    # Only process POST requests with submit button
    return unless $query->request_method eq 'POST';
    return unless $query->param('submit');

    my $for_usergroup_id = $query->param('for_usergroup');
    return unless $for_usergroup_id;

    # Get the usergroup as a blessed node object
    my $usergroup = $APP->node_by_id($for_usergroup_id);
    return "Usergroup not found." unless $usergroup;

    # Check forbidden groups for editors
    if ( $editor_only && exists $forbidden_for_editors->{ lc( $usergroup->title ) } ) {
        return "You don't have permission to edit this usergroup.";
    }

    my @added;
    my @removed;
    my @not_found;

    # Process removals - look for rem_* checkboxes
    my @to_remove;
    foreach my $param ( $query->param ) {
        if ( $param =~ /^rem_(\d+)$/ ) {
            push @to_remove, $1;
        }
    }

    if (@to_remove) {
        foreach my $member_id (@to_remove) {
            my $member = $DB->getNodeById($member_id);
            if ($member) {
                push @removed, $member->{title};
            }
        }
        $usergroup->group_remove( \@to_remove, $USER );
    }

    # Process additions
    my $addperson = $query->param('addperson') || '';
    if ($addperson) {
        my @names = split /[\r\n]+/, $addperson;
        my @to_add;

        foreach my $name (@names) {
            $name =~ s/^\s+|\s+$//g;    # trim whitespace
            next unless $name;

            my $person = $DB->getNode( $name, 'user' );
            if ($person) {
                push @to_add,  $person->{node_id};
                push @added, $person->{title};
            } else {
                push @not_found, $name;
            }
        }

        if (@to_add) {
            $usergroup->group_add( \@to_add, $USER );
        }
    }

    # Build message
    my @msg_parts;
    if (@added) {
        push @msg_parts, "Added: " . join( ", ", @added );
    }
    if (@removed) {
        push @msg_parts, "Removed: " . join( ", ", @removed );
    }
    if (@not_found) {
        push @msg_parts, "Not found: " . join( ", ", @not_found );
    }

    return @msg_parts ? join( ". ", @msg_parts ) . "." : "No changes made.";
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>

=cut
