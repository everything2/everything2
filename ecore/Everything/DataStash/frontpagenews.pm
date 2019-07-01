package Everything::DataStash::frontpagenews;

use Moose;
use namespace::autoclean;
extends 'Everything::DataStash';

has '+interval' => (default => 60);

sub generate
{
  my ($this) = @_;

  my $frontpage_superdoc = $this->DB->getNode("News", "usergroup");
  my $weblog_entries = $this->APP->fetch_weblog($frontpage_superdoc, 5);
  
  if(scalar(@$weblog_entries) == 0)
  {
    $frontpage_superdoc = $this->DB->getNode("News for noders. Stuff that matters.","superdoc");
    $weblog_entries = $this->APP->fetch_weblog($frontpage_superdoc, 5);
  }

  return $this->SUPER::generate($weblog_entries);
}


__PACKAGE__->meta->make_immutable;
1;
