package Everything::Page::e2_staff;

use Moose;
extends 'Everything::Page';

sub display
{
  my ($self, $REQUEST, $node) = @_;

  my $ces = [grep {$_->type->title eq "user"} @{$self->APP->node_by_name('Content Editors','usergroup')->group}];
  my $inactive = [];
  my $e2gods = $self->APP->node_by_name("e2gods","usergroup");
  my $gods = $self->APP->node_by_name("gods","usergroup");
  my $sigtitle = $self->APP->node_by_name("sigtitle","usergroup");
  my $chanops = $self->APP->node_by_name("chanops","usergroup");

  foreach my $n (@{$self->APP->node_by_name("gods","usergroup")->group})
  {
    next unless $n->type->title eq "user";
    push @$inactive, $n unless(grep {$n->id == $_->id} @{$e2gods->group});
  }

  return {"editors" => $ces, "gods" => $e2gods->group, "inactive" => $inactive, "sigtitle" => $sigtitle->group, "chanops" => $chanops->group};
}

__PACKAGE__->meta->make_immutable;

1;
