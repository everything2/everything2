package Everything::Page::your_insured_writeups;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::StaffOnly';

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  my $csr = $self->DB->sqlSelectMany('publish_id', 'publish', 'publisher='.$REQUEST->user->id);

  my $writeups = [];
  while(my $pubwu = $csr->fetchrow_hashref)
  {
    my $wu = $self->APP->node_by_id($pubwu->{publish_id});
    push @$writeups, $wu->json_reference if(defined($wu));
  }

  return { writeups => $writeups };
}

__PACKAGE__->meta->make_immutable;

1;
