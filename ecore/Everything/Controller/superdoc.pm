package Everything::Controller::superdoc;

use Moose;
extends 'Everything::Controller::page';

sub display
{
  my ($self, $REQUEST, $node) = @_;

  if($self->page_class($node)->guest_allowed and $REQUEST->user->is_guest)
  {
    return [$self->HTTP_FOUND,'', {location => $self->login_link}]
  }else{
    my $html = $self->layout('/pages/'.$self->title_to_page($node->title), REQUEST => $REQUEST, node => $node);
    return [$self->HTTP_OK,$html];
  }
}

__PACKAGE__->meta->make_immutable();
1;
