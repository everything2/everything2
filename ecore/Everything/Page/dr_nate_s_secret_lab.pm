package Everything::Page::dr_nate_s_secret_lab;

use Moose;
extends 'Everything::Page';

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP  = $self->APP;
    my $USER = $REQUEST->user;

    # Admin-only page
    unless ($APP->isAdmin($USER->NODEDATA)) {
        return {
            type  => 'dr_nate_s_secret_lab',
            error => 'This page is restricted to administrators.',
        };
    }

    my $q = $REQUEST->cgi;

    # Get the pre-filled node ID if provided via query params
    my $prefill_node_id = $q->param('olde2nodeid') || '';
    my $prefill_source  = $q->param('heaven') ? 'heaven' : 'tomb';

    return {
        type            => 'dr_nate_s_secret_lab',
        prefillNodeId   => $prefill_node_id,
        prefillSource   => $prefill_source,
    };
}

__PACKAGE__->meta->make_immutable;

1;
