package Everything::DataStash::altfrontpagecontent;

use Moose;
extends 'Everything::DataStash';
use namespace::autoclean;

has '+interval' => (default => 300);

# Credit for this goes to [merlyn] on perlmonks
sub fisher_yates_shuffle
{
  my ($this, $nodelist) = @_;  # $deck is a reference to an array
  my $i = @$nodelist;
  while ($i--)
  {
    my $j = int rand ($i+1);
    @$nodelist[$i,$j] = @$nodelist[$j,$i];
  }
  return;
}


sub generate
{
  my ($this) = @_;

  my $repthreshholdlo = 3;
  my $maxage = "1 WEEK";
  my $pulllimit = 24;
  my $limit = 3;

  my $csr = $this->DB->sqlSelectMany(
    'writeup_id, parent_e2node,
    (select title from node where node_id=writeup.wrtype_writeuptype limit 1) as type_title,author_user,
    (select doctext from document where document_id=writeup.writeup_id limit 1) as doctext' ,
    'writeup LEFT JOIN node ON node_id=writeup_id' ,

    "reputation > 0
    AND publishtime > DATE_SUB(CURDATE(), INTERVAL $maxage)" ,
    "ORDER BY reputation DESC LIMIT $pulllimit");

  my $content = [];
  my $used = {};
  while (my $row = $csr->fetchrow_hashref()) {
    next if exists $used->{$$row{type_title}};
    $used->{$$row{type_title}}=1;
    push(@$content, $$row{writeup_id});
  }

  $this->fisher_yates_shuffle($content);

  return $this->SUPER::generate([@$content[0..($limit-1)]]);
}


__PACKAGE__->meta->make_immutable;
1;
