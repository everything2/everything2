package Everything::Controller::nodelet::nodelet_epicenter;

use Moose;
use namespace::autoclean;
extends "Everything::Controller::nodelet";

sub nodelet
{
  my ($this, $request, $node, $properties) = @_;
  $properties->{template} = "nodelet/epicenter";
  $properties->{borgcheck} = $this->emulate_htmlcode("borgcheck",$request); 
  $properties->{usersettings} = $this->getNodeById($this->CONF->system->{user_settings});
  $properties->{drafts} = $this->getNode("Drafts","superdoc");
  $properties->{expearned} = $this->emulate_htmlcode('shownewexp',$request, 'TRUE');

  $properties->{votinginfodoc} = $this->getNode('The Everything2 Voting/Experience System','superdoc');
  $properties->{randomnode} = $this->emulate_htmlcode('randomnode',$request,'Random Node');
  $properties->{helplink} = $this->getNode(($this->APP->getLevel($request->USER) < 2 ? 'E2 Quick Start' : 'Everything2 Help'),'e2node');

  unless($request->VARS->{GPoptout}) {
    $properties->{gpearned} = $this->emulate_htmlcode('showNewGP',$request, 'TRUE');
  }

  return $this->SUPER::nodelet($request,$node,$properties);
}

__PACKAGE__->meta->make_immutable;
1;
