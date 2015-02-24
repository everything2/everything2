package Everything::Controller::nodelet::nodelet_node_statistics;

use Moose;
use namespace::autoclean;

extends 'Everything::Controller::nodelet';

sub nodelet
{
  my ($this, $request, $node, $properties) = @_;
#  has 'nodeid' => (isa => "Maybe[Int]");
#  has 'createtime' => (isa => "Maybe[Str]");
#  has 'hits' => (isa => "Maybe[Int]");
#  has 'nodetype' => (isa => "Maybe[Int]");

  $properties->{nodeid} = $request->NODE->{node_id};
  $properties->{createtime} = $request->NODE->{createtime};
  $properties->{hits} = $request->NODE->{hits};
  $properties->{nodetype} = $request->NODE->{type_nodetype};

  $properties->{template} = "nodelet/node_statistics";
  return $this->SUPER::nodelet($request,$node,$properties);
}

__PACKAGE__->meta->make_immutable;
1;
