package Everything::Controller::superdoc;

use Moose;
extends 'Everything::Controller::page';

sub display
{
  my ($self, $REQUEST, $node) = @_;

  # Get page class instance ONCE and reuse for all calls
  # This is critical for pages like Sign Up that cache state between display() and buildReactData()
  my $page_class = $self->page_class($node);
  my $permission_result = $page_class->check_permission($REQUEST, $node);

  if($permission_result->allowed)
  {
    my $controller_output = $page_class->display($REQUEST, $node);

    # Check if this page uses React (has buildReactData method)
    my $is_react_page = $page_class && $page_class->can('buildReactData');

    # Phase 4a: For React pages, build window.e2 data structure
    if ($is_react_page) {
      # Set node on REQUEST for buildReactData access
      $REQUEST->node($node);

      # Store page_class instance on REQUEST so buildNodeInfoStructure can reuse it
      # This is critical for pages like Sign Up that cache state between display() and buildReactData()
      $REQUEST->page_class_instance($page_class);

      # Build e2 data structure (includes reactPageMode and contentData)
      my $e2 = $self->APP->buildNodeInfoStructure(
        $node->NODEDATA,
        $REQUEST->user->NODEDATA,
        $REQUEST->user->VARS,
        $REQUEST->cgi,
        $REQUEST  # Pass full REQUEST object for buildReactData
      );

      # Add e2 data to controller output for template
      $controller_output->{e2} = $e2;
    }

    my $layout;
    if ($is_react_page) {
      # Use generic React container template for React pages
      $layout = 'react_page';
    } else {
      # Use page-specific Mason template for traditional pages
      $layout = $page_class->template || $self->title_to_page($node->title);
    }

    my $html = $self->layout("/pages/$layout", %$controller_output, REQUEST => $REQUEST, node => $node);
    return [$self->HTTP_OK,$html];
  } else {
    $self->devLog("Page permission not allowed");
    return [$self->HTTP_FOUND, '', {'Location' => $permission_result->redirect}];
  }
}

__PACKAGE__->meta->make_immutable();
1;
