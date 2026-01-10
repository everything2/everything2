package Everything::Controller::fullpage;

use Moose;
extends 'Everything::Controller::page';

# TODO: Wind this type down - migrate fullpage nodes to superdoc

sub display
{
  my ($self, $REQUEST, $node) = @_;

  my $permission_result = $self->page_class($node)->check_permission($REQUEST, $node);

  if($permission_result->allowed)
  {
    my $controller_output = $self->page_class($node)->display($REQUEST, $node);

    # Check if Page class returned an HTTP response array (e.g., redirect, XML)
    # instead of a controller hashref
    if (ref($controller_output) eq 'ARRAY') {
      # Page class returned HTTP response directly - pass it through
      return $controller_output;
    }

    # Check if this page uses React (has buildReactData method)
    my $page_class = $self->page_class($node);
    my $is_react_page = $page_class->can('buildReactData');

    # Phase 4a: For React pages, build window.e2 data structure
    if ($is_react_page) {
      # Set node on REQUEST for buildReactData access
      $REQUEST->node($node);

      # Build e2 data structure (includes reactPageMode and contentData)
      my $e2 = $self->APP->buildNodeInfoStructure(
        $node->NODEDATA,
        $REQUEST->user->NODEDATA,
        $REQUEST->user->VARS,
        $REQUEST->cgi,
        $REQUEST  # Pass full REQUEST object for buildReactData
      );

      # Build nodeletorder for React sidebar (like Controller.pm layout does)
      my $user_nodelets;
      if ($REQUEST->user->is_guest) {
        # Load guest nodelets from config
        my $guest_nodelet_ids = $self->CONF->guest_nodelets || [];
        $user_nodelets = [];
        foreach my $nid (@$guest_nodelet_ids) {
          my $nodelet = $self->APP->node_by_id($nid);
          push @$user_nodelets, $nodelet if $nodelet;
        }
      } else {
        $user_nodelets = $REQUEST->user->nodelets || [];
      }

      my @nodeletorder = ();
      foreach my $nodelet (@$user_nodelets) {
        my $title = lc($nodelet->title);
        $title =~ s/ /_/g;
        push @nodeletorder, $title;
      }
      $e2->{nodeletorder} = \@nodeletorder;

      # Add e2 data to controller output for template
      $controller_output->{e2} = $e2;
    }

    my $layout;
    if ($is_react_page) {
      # Check if Page class specifies a custom template, otherwise use generic react_page
      $layout = $page_class->template || 'react_page';
      # Use layout() which sets up HTMLShell parameters for the React page
      my $html = $self->layout("/pages/$layout", %{$controller_output}, e2 => $controller_output->{e2}, REQUEST => $REQUEST, node => $node);
      return [$self->HTTP_OK,$html];
    } else {
      # Use page-specific template for traditional pages
      $layout = $page_class->template || $self->title_to_page($node->title);
      my $html = $self->layout("/pages/$layout", %{$controller_output}, REQUEST => $REQUEST, node => $node);
      return [$self->HTTP_OK,$html];
    }
  } else {
    return [$self->HTTP_FOUND, '', {'Location' => $permission_result->redirect}];
  }
}

__PACKAGE__->meta->make_immutable();
1;
