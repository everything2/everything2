package Everything::Controller::nodelet::nodelet_master_control;

use Moose;
extends 'Everything::Controller::nodelet';

sub nodelet
{
  my ($this, $request, $node, $properties) = @_;

#  has "admin_searchform" => (isa => "Maybe[Str]);
#  has "admin_toolset" => (isa => "Maybe[Str]);
#  has "nodenote" => (isa => "Maybe[Str]);
#  has "episectionadmin" => (isa => "Maybe[Str]");
#  has "episectionces" => (isa => "Maybe[Str]");

  $properties->{admin_searchform} = $this->emulate_htmlcode("admin_searchform",$request);
  $properties->{admin_toolset} = $this->emulate_htmlcode("admin_toolset", $request);
  $properties->{nodenote} = $this->emulate_htmlcode("nodenote", $request);
  $properties->{episectionadmin} = $this->emulate_htmlcode("nodeletsection", $request, 'epi', 'admins', 'Admin');
  $properties->{episectionces} = $this->emulate_htmlcode("nodeletsection", $request, 'epi', 'ces', 'CE');
  $properties->{template} = "nodelet/master_control";
  return $this->SUPER::nodelet($request,$node,$properties);
}


1;
