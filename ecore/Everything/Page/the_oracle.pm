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

# classic_mode: 0 for The Oracle (friendly view, editors + admins); overridden to 1 by
# Everything::Page::the_oracle_classic (raw all-vars view, admins only). Both documents
# share this one implementation + the TheOracle React component -- they differ only by
# this flag and their title. (#4298)
sub classic_mode { return 0 }

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB    = $self->DB;
    my $APP   = $self->APP;
    my $USER  = $REQUEST->user;
    my $query = $REQUEST->cgi;

    my $classic   = $self->classic_mode;
    my $is_admin  = $APP->isAdmin($USER->NODEDATA) ? 1 : 0;
    my $is_editor = $APP->isEditor($USER->NODEDATA) ? 1 : 0;

    # Access control: classic is admin-only; the friendly Oracle allows editors + admins.
    my $allowed = $classic ? $is_admin : ( $is_editor || $is_admin );
    unless ($allowed) {
        return {
            type  => 'the_oracle',
            error => $classic
                ? 'Access denied. The Oracle Classic is restricted to administrators.'
                : 'Access denied. This tool is restricted to Content Editors and administrators.'
        };
    }

    # Build response data
    # Viewer role flags (is_admin/is_editor) intentionally NOT emitted here:
    # React reads them from the global e2.user prop (user.admin / user.editor). (#4390)
    my $data = {
        type         => 'the_oracle',
        classic_mode => $classic
    };

    # The variable WRITE moved to POST /api/oracle/setvar (Everything::API::oracle)
    # so rendering this page no longer mutates another user's vars off query
    # params (#4405). buildReactData is now pure-render -- the edit-form display
    # and the search below are reads only.

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
            easter_eggs nodelets userstyle wuhead browser
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

            # Friendly view only (classic shows raw values): resolve node_id refs to titles
            if (!$classic && $key =~ /^(userstyle|lastnoded|current_nodelet|group)$/ && $value =~ /^\d+$/) {
                my $ref_node = $DB->getNodeById($value, 'light');
                if ($ref_node) {
                    $var_entry->{resolved_title} = $ref_node->{title};
                    $var_entry->{resolved_id}    = int($value);
                }
            }

            # Resolve CSV lists of node_ids (friendly view only)
            if (!$classic && $key =~ /^(nodelets|bookbucket|favorite_noders|emailSubscribedusers|nodetrail|nodebucket|can_weblog)$/) {
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

            # Special formatting hints (friendly view only)
            unless ($classic) {
                $var_entry->{is_code}         = 1 if $key eq 'customstyle';
                $var_entry->{is_nodelet_list} = 1 if $key eq 'personal_nodelet';
            }

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
            { var => 'userstyle',         desc => 'the Zen stylesheet the noder has active' },
            { var => 'wuhead',            desc => 'the code for displaying the writeupheader' }
        ];
        $data->{deprecated_vars} = [
            { var => 'settings_useTinyMCE', desc => 'DEPRECATED - TinyMCE editor removed, replaced by TipTap editor' }
        ];
    }

    return $data;
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::Page::the_oracle_classic>

=cut
