package Everything::Node::helper::delegated;

use Moose::Role;

sub code_text
{
  my ($self) = @_;
  my $code = "Error: could not find code in delegated ".$self->type->title." (".$self->maintenance_sub.")";
  my $file="/var/everything/ecore/Everything/Delegation/".$self->type->title.".pm";

  my $filedata = undef;
  my $fileh = undef;

  open $fileh,$file;
  {
    local $/ = undef;
    $filedata = <$fileh>;
  }

  close $fileh;

  my $name = $self->maintenance_sub;
  $name =~ s/[\s\-]/_/g;
  if($filedata =~ /^(sub $name\s.*?^})/ims)
  {
    $code = $1;
  }

  return $code;
}

1;
