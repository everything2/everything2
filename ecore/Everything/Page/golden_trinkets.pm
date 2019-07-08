package Everything::Page::golden_trinkets;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::NoGuest';

sub display
{
  my ($self, $REQUEST, $node) = @_;

  if($REQUEST->user->is_admin)
  {
    my $error = "";
    my $gtuser = undef;
    my $gtusername = $REQUEST->param("gtuser");

    if(defined($gtusername))
    {
      $gtuser = $self->APP->node_by_name($REQUEST->param("gtuser"),"user");
      if(not defined($gtuser))
      {
        $error = "User '".$REQUEST->param("gtuser")."' does not exit";
      }
    }

    return {"error" => $error, "other_user" => $gtuser};
  }else{
    return {};
  }
}


__PACKAGE__->meta->make_immutable;
1;
