package Everything::API::weblogmenu;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

sub routes {
    return {
        'update' => 'update_settings',
    };
}

sub update_settings {
    my ($self, $REQUEST) = @_;

    my $data = $REQUEST->JSON_POSTDATA;

    unless ($data && ref($data) eq 'HASH') {
        return [$self->HTTP_OK, {
            success => 0,
            error   => 'Invalid request data',
        }];
    }

    my $USER = $REQUEST->user;
    my $VARS = $USER->VARS;

    # Handle nameifyweblogs toggle
    if (exists $data->{nameifyWeblogs}) {
        if ($data->{nameifyWeblogs}) {
            $VARS->{nameifyweblogs} = 1;
        } else {
            delete $VARS->{nameifyweblogs};
        }
    }

    # Handle weblog visibility toggles
    if (exists $data->{weblogs} && ref($data->{weblogs}) eq 'HASH') {
        # Get user's can_weblog list to validate allowed weblogs
        my $can_weblog = $VARS->{can_weblog} || '';
        my %allowed_weblogs = map { $_ => 1 } split(',', $can_weblog);

        my $something_hidden = 0;

        foreach my $weblog_id (keys %{$data->{weblogs}}) {
            # Validate weblog_id is numeric and user has access
            next unless $weblog_id =~ /^\d+$/;
            next unless $allowed_weblogs{$weblog_id};

            my $var_key = 'hide_weblog_' . $weblog_id;

            if ($data->{weblogs}{$weblog_id}) {
                # Show this weblog (remove hide)
                delete $VARS->{$var_key};
            } else {
                # Hide this weblog
                $VARS->{$var_key} = 1;
                $something_hidden = 1;
            }
        }

        # Update the hidden_weblog flag
        if ($something_hidden) {
            $VARS->{hidden_weblog} = 1;
        } else {
            delete $VARS->{hidden_weblog};
        }
    }

    # Save the updated VARS
    $USER->set_vars($VARS);

    return [$self->HTTP_OK, {
        success => 1,
    }];
}

around 'update_settings' => \&Everything::API::unauthorized_if_guest;

__PACKAGE__->meta->make_immutable;

1;
