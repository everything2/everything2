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

      # Add e2 data to controller output for template
      $controller_output->{e2} = $e2;
    }

    my $layout;
    if ($is_react_page) {
      # Use fullpage React template (no sidebar/header/footer)
      $layout = 'react_fullpage';
      # For React pages, render template directly without E2 layout wrapper
      $self->MASON->set_global('$REQUEST',$REQUEST);
      my $html = $self->MASON->run("/pages/$layout", {
        e2 => $controller_output->{e2},
        REQUEST => $REQUEST,
        node => $node
      })->output();
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
