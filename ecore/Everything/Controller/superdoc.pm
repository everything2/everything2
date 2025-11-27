package Everything::Controller::superdoc;

use Moose;
extends 'Everything::Controller::page';

sub display
{
  my ($self, $REQUEST, $node) = @_;

  my $permission_result = $self->page_class($node)->check_permission($REQUEST, $node);

  if($permission_result->allowed)
  {
    $self->devLog("Page permission allowed: ".(ref $permission_result));
    my $controller_output = $self->page_class($node)->display($REQUEST, $node);

    # Check if this page uses React (has buildReactData method)
    my $page_class = $self->page_class($node);
    my $is_react_page = $page_class->can('buildReactData');

    # Phase 4a: For React pages, build window.e2 data structure
    if ($is_react_page) {
      # Build e2 data structure (includes reactPageMode and contentData)
      my $e2 = $self->APP->buildNodeInfoStructure(
        $node->NODEDATA,
        $REQUEST->user->NODEDATA,
        $REQUEST->user->VARS,
        $REQUEST->cgi
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
