package Everything::Page::the_oracle_classic;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::the_oracle_classic - Admin-only user variable viewer/editor

=head1 DESCRIPTION

The Oracle Classic is the original admin-only tool for viewing and editing
user variables. It shows all variables with minimal formatting.

Uses the same React component as The Oracle but with classic_mode=1.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB    = $self->DB;
    my $APP   = $self->APP;
    my $USER  = $REQUEST->user;
    my $query = $REQUEST->cgi;

    my $is_admin = $APP->isAdmin($USER->NODEDATA) ? 1 : 0;

    # Classic mode is admin-only
    unless ($is_admin) {
        return {
            type  => 'the_oracle',
            error => 'Access denied. The Oracle Classic is restricted to administrators.'
        };
    }

    # Build response data - mark as classic mode
    my $data = {
        type         => 'the_oracle',
        classic_mode => 1,
        is_admin     => 1,
        is_editor    => 0
    };

    # Handle variable update
    my $new_value = $query->param('new_value');
    my $new_user  = $query->param('new_user');
    my $new_var   = $query->param('new_var');

    if (defined $new_value && $new_user && $new_var) {
        my $target = $DB->getNode($new_user, 'user');
        if ($target) {
            my $vars = $APP->getVars($target);
            $vars->{$new_var} = $new_value;
            $APP->setVars($target, $vars);

            $data->{update_result} = {
                user    => $new_user,
                var     => $new_var,
                value   => $new_value,
                success => 1
            };
        }
    }

    # Handle edit mode
    my $var_edit  = $query->param('varEdit');
    my $user_edit = $query->param('userEdit');

    if ($var_edit && $user_edit) {
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

        # Skip only dangerous vars
        my %skip_vars = map { $_ => 1 } qw(noteletRaw noteletScreened);

        for my $key (sort keys %$vars) {
            next if $skip_vars{$key};

            my $value = $vars->{$key} // '';

            my $var_entry = {
                key   => $key,
                value => $value
            };

            # Add IP Hunter link for ipaddy
            if ($key eq 'ipaddy' && $value) {
                my $ip_hunter = $DB->getNode('IP Hunter', 'restricted_superdoc');
                $var_entry->{ip_hunter_id} = $ip_hunter->{node_id} if $ip_hunter;
            }

            push @var_list, $var_entry;
        }

        $data->{search_result} = {
            username => $target->{title},
            user_id  => int($target->{node_id}),
            vars     => \@var_list
        };
    }

    return $data;
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::Page::the_oracle>

=cut
