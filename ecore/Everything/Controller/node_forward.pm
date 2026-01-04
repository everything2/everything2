package Everything::Controller::node_forward;

use Moose;
extends 'Everything::Controller';

# Controller for node_forward nodes
# Handles HTTP redirects properly (headers before body)
# Migrated from Everything::Delegation::htmlpage

sub display {
    my ($self, $REQUEST, $node) = @_;

    my $APP = $self->APP;
    my $DB = $self->DB;
    my $CONF = $self->CONF;
    my $query = $REQUEST->cgi;
    my $USER = $REQUEST->user->NODEDATA;

    my $origTitle = $query->param("originalTitle") // '';
    my $circularLink = ($origTitle eq $node->title);

    my $targetNodeId = $node->NODEDATA->{doctext};
    my $targetNode = undef;

    if ($targetNodeId && $targetNodeId ne '') {
        $targetNode = $DB->getNodeById($targetNodeId, 'light');
    }

    my $badLink = ($circularLink || !$targetNode);
    $origTitle ||= $node->title;

    my $urlParams = {};

    unless ($APP->isAdmin($USER) && $badLink) {
        if (!$badLink) {
            # For good links, forward all users
            $urlParams = { 'originalTitle' => $origTitle };
        } else {
            # For circular or non-functional links, send non-gods to the search page
            $urlParams = {
                'node' => $node->title,
                'match_all' => 1
            };
        }

        $urlParams->{'lastnode_id'} = $query->param('lastnode_id')
            if defined $query->param('lastnode_id');
    } else {
        # For circular or non-functional links, send gods directly to the edit page
        $targetNode = $node->NODEDATA;
        $urlParams = {
            'displaytype' => 'edit',
            'circularLink' => $circularLink
        };
    }

    # Generate redirect URL
    my $redirect_url = $APP->urlGen($urlParams, 'no escape', $targetNode);

    # Build full URL for Location header
    my $protocol = ($CONF->environment eq "development") ? 'http://' : 'https://';
    my $full_url = $protocol . $ENV{HTTP_HOST} . $redirect_url;

    # Return proper HTTP 303 redirect
    # Controllers return [status, body, headers] - headers are sent BEFORE body
    return [$self->HTTP_SEE_OTHER, '', { 'Location' => $full_url }];
}

# Edit uses basicedit for raw field editing
sub edit {
    my ($self, $REQUEST, $node) = @_;
    return $self->basicedit($REQUEST, $node);
}

__PACKAGE__->meta->make_immutable;
1;
