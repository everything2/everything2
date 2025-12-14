package Everything::Page::the_oracle;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::the_oracle - User variable viewer/editor

=head1 DESCRIPTION

The Oracle allows admins to view and edit all user variables,
and Content Editors to view a limited subset of user variables.

This is the "modern" Oracle with enhanced formatting and CE access.
The Oracle Classic reuses this same Page class with classic_mode=1.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB    = $self->DB;
    my $APP   = $self->APP;
    my $USER  = $REQUEST->user;
    my $query = $REQUEST->cgi;

    my $is_admin  = $APP->isAdmin($USER->NODEDATA) ? 1 : 0;
    my $is_editor = $APP->isEditor($USER->NODEDATA) ? 1 : 0;

    # Classic mode is set by the_oracle_classic.pm
    my $classic_mode = 0;

    # Access control - editors and admins for regular, admins only for classic
    unless ($is_editor || $is_admin) {
        return {
            type  => 'the_oracle',
            error => 'Access denied. This tool is restricted to Content Editors and administrators.'
        };
    }

    # Build response data
    my $data = {
        type         => 'the_oracle',
        classic_mode => $classic_mode,
        is_admin     => $is_admin,
        is_editor    => $is_editor
    };

    # Handle variable update (admin only)
    my $new_value = $query->param('new_value');
    my $new_user  = $query->param('new_user');
    my $new_var   = $query->param('new_var');

    if (defined $new_value && $new_user && $new_var && $is_admin) {
        my $target = $DB->getNode($new_user, 'user');
        if ($target) {
            my $vars = $APP->getVars($target);
            $vars->{$new_var} = $new_value;
            Everything::setVars($target, $vars);

            $data->{update_result} = {
                user    => $new_user,
                var     => $new_var,
                value   => $new_value,
                success => 1
            };
        }
    }

    # Handle edit mode (show edit form for a specific variable)
    my $var_edit  = $query->param('varEdit');
    my $user_edit = $query->param('userEdit');

    if ($var_edit && $user_edit && $is_admin) {
        my $target = $DB->getNode($user_edit, 'user');
        if ($target) {
            my $vars = $APP->getVars($target);
            $data->{edit_mode} = {
                username  => $user_edit,
                var_name  => $var_edit,
                old_value => $vars->{$var_edit} // ''
            };
            return $data;
        }
    }

    # Handle user search
    my $search_user = $query->param('the_oracle_subject') || '';

    if ($search_user) {
        my $target = $DB->getNode($search_user, 'user');

        unless ($target) {
            $data->{error} = "User not found: $search_user";
            return $data;
        }

        my $vars = $APP->getVars($target);
        my @var_list = ();

        # Variables that CEs can see (limited subset)
        my %ce_allowed = map { $_ => 1 } qw(
            settings_useTinyMCE easter_eggs nodelets userstyle wuhead browser
        );

        # Variables to skip entirely
        my %skip_vars = map { $_ => 1 } qw(noteletRaw noteletScreened);

        for my $key (sort keys %$vars) {
            next if $skip_vars{$key};

            # CEs can only see certain vars (unless they're also admin)
            if ($is_editor && !$is_admin) {
                next unless $ce_allowed{$key};
            }

            my $value = $vars->{$key} // '';

            # Build var entry
            my $var_entry = {
                key   => $key,
                value => $value
            };

            # Resolve node_id references to titles
            if ($key =~ /^(userstyle|lastnoded|current_nodelet|group)$/ && $value =~ /^\d+$/) {
                my $ref_node = $DB->getNodeById($value, 'light');
                if ($ref_node) {
                    $var_entry->{resolved_title} = $ref_node->{title};
                    $var_entry->{resolved_id}    = int($value);
                }
            }

            # Resolve CSV lists of node_ids
            if ($key =~ /^(nodelets|bookbucket|favorite_noders|emailSubscribedusers|nodetrail|nodebucket|can_weblog)$/) {
                my @ids = split(/,/, $value);
                my @resolved = ();
                for my $id (@ids) {
                    next unless $id =~ /^\d+$/;
                    my $ref_node = $DB->getNodeById($id, 'light');
                    if ($ref_node) {
                        push @resolved, {
                            node_id => int($id),
                            title   => $ref_node->{title}
                        };
                    } else {
                        push @resolved, {
                            node_id => int($id),
                            title   => '[deleted]',
                            missing => 1
                        };
                    }
                }
                $var_entry->{resolved_list} = \@resolved if @resolved;
            }

            # Add IP Hunter link for ipaddy
            if ($key eq 'ipaddy' && $value) {
                my $ip_hunter = $DB->getNode('IP Hunter', 'restricted_superdoc');
                $var_entry->{ip_hunter_id} = $ip_hunter->{node_id} if $ip_hunter;
            }

            # Special formatting hints
            $var_entry->{is_code}         = 1 if $key eq 'customstyle';
            $var_entry->{is_nodelet_list} = 1 if $key eq 'personal_nodelet';

            push @var_list, $var_entry;
        }

        $data->{search_result} = {
            username => $target->{title},
            user_id  => int($target->{node_id}),
            vars     => \@var_list
        };
    }

    # CE help text
    if ($is_editor && !$is_admin) {
        $data->{ce_help} = [
            { var => 'browser',           desc => 'the web browser and operating system the noder is using' },
            { var => 'easter_eggs',       desc => 'how many easter eggs the noder has' },
            { var => 'nodelets',          desc => 'list of nodelets the noder has turned on, node_id and name' },
            { var => 'settings_useTinyMCE', desc => 'whether or not the noder has tinyMCE turned on' },
            { var => 'userstyle',         desc => 'the Zen stylesheet the noder has active' },
            { var => 'wuhead',            desc => 'the code for displaying the writeupheader' }
        ];
    }

    return $data;
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::Page::the_oracle_classic>

=cut
