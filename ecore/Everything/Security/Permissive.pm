package Everything::Security::Permissive;

use Moose::Role;

use Everything::PermissionResult::OK;

sub check_permission
{
  my ($self, $REQUEST, $node) = @_;
  return Everything::PermissionResult::OK->new;
}

1;
