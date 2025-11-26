package Everything::Page::e2_staff;

use Moose;
extends 'Everything::Page';

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  my $ces = [grep {$_->type->title eq 'user'} @{$self->APP->node_by_name('Content Editors', 'usergroup')->group}];
  my $inactive = [];
  my $e2gods = $self->APP->node_by_name('e2gods', 'usergroup');
  my $gods = $self->APP->node_by_name('gods', 'usergroup');
  my $sigtitle = $self->APP->node_by_name('sigtitle', 'usergroup');
  my $chanops = $self->APP->node_by_name('chanops', 'usergroup');

  my $gods_group = $self->APP->node_by_name('gods', 'usergroup')->group;
  foreach my $n (@{$gods_group})
  {
    next unless $n->type->title eq 'user';
    push @{$inactive}, $n unless(scalar grep {$n->id == $_->id} @{$e2gods->group});
  }

  # Convert user nodes to simple data structures
  my $convert_users = sub {
    my ($users) = @_;
    return [map { { title => $_->title, node_id => $_->id, type => 'user' } } @{$users}];
  };

  return {
    editors => $convert_users->($ces),
    gods => $convert_users->($e2gods->group),
    inactive => $convert_users->($inactive),
    sigtitle => $convert_users->($sigtitle->group),
    chanops => $convert_users->($chanops->group),
  };
}

__PACKAGE__->meta->make_immutable;

1;
