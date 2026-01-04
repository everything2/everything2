package Everything::DataStash::coolnodes;

use Moose;
extends 'Everything::DataStash';
use namespace::autoclean;

has '+interval' => (default => 60);

sub generate
{
  my ($this) = @_;

  # Get 30 most recently cooled UNIQUE writeups. Use GROUP BY to deduplicate
  # writeups that have been C!'d by multiple users, showing only the most recent C!.
  # MAX(tstamp) ensures we order by the most recent cooling for each writeup.
  my $cuss = $this->DB->sqlSelectMany(
    "coolwriteups_id, MAX(tstamp) as latest_cool, " .
    "(select title from node where node_id=(select author_user from node where node_id=coolwriteups_id limit 1) limit 1) as wu_author, " .
    "(select parent_e2node from writeup where writeup_id=coolwriteups_id limit 1) as parentNode, " .
    "(select title from node where node_id=parentNode limit 1) as parentTitle, " .
    "(select cooled from writeup where writeup_id=coolwriteups_id limit 1) as writeupCooled",
    "coolwriteups",
    "",
    "group by coolwriteups_id order by latest_cool desc limit 30"
  );

  return $this->SUPER::generate($cuss->fetchall_arrayref({}));
}


__PACKAGE__->meta->make_immutable;
1;
