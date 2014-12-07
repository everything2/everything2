package Everything::DataStash::coolnodes;

use Moose;
extends 'Everything::DataStash';
use namespace::autoclean;

has '+interval' => (default => 60);

sub generate
{
  my ($this) = @_;

  my $cuss = $this->DB->sqlSelectMany("(select title from node where node_id=cooledby_user limit 1) as cooluser, coolwriteups_id, (select title from node where node_id=(select author_user from node where node_id=coolwriteups_id limit 1) limit 1) as wu_author, (select parent_e2node from writeup where writeup_id=coolwriteups_id limit 1) as parentNode, (select title from node where node_id=parentNode limit 1) as parentTitle, (select cooled from writeup where writeup_id=coolwriteups_id limit 1) as writeupCooled", "coolwriteups", "", "order by tstamp desc limit 30");


  return $this->SUPER::generate($cuss->fetchall_arrayref({}));
}


__PACKAGE__->meta->make_immutable;
1;
