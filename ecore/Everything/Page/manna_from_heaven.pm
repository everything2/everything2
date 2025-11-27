
package Everything::Page::manna_from_heaven;

use Moose;
use Everything::Timestamp;
extends 'Everything::Page';
with 'Everything::Security::StaffOnly';

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  my $numdays = int($REQUEST->param("days")) || 30;
  $numdays = 365 if($numdays > 365);

  my @writeups;

  foreach my $title ("Content Editors","e2gods")
  {
    my $grp = $self->APP->node_by_name($title,"usergroup");
    foreach my $user (@{$grp->group})
    {
      next unless $user->type->title eq "user";
      my $count = $self->DB->sqlSelect("count(*)", "node", "type_nodetype=117 and author_user=".$user->node_id." and TO_DAYS(NOW())-TO_DAYS(createtime) <=$numdays");

      push @writeups, {
        username => $user->title,
        user_id => $user->node_id,
        count => int($count)
      };
    }
  }

  # Sort by username
  @writeups = sort { $a->{username} cmp $b->{username} } @writeups;

  return {
    type => 'manna_from_heaven',
    writeups => \@writeups,
    numdays => $numdays
  };
}

__PACKAGE__->meta->make_immutable;

1;
