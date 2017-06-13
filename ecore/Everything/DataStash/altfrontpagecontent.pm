package Everything::DataStash::altfrontpagecontent;

use Moose;
extends 'Everything::DataStash';
use namespace::autoclean;

has '+interval' => (default => 60);

sub generate
{
  my ($this) = @_;

  my $repthreshholdlo = 12 ;
  my $maxage = "1 WEEK";
  my $pulllimit = 24;
  my $limit = 3;
  my $length = '1024-512';

  my $csr = $this->DB->sqlSelectMany(
    'writeup_id, parent_e2node,
    (select title from node where node_id=writeup.wrtype_writeuptype limit 1) as type_title,author_user,
    (select doctext from document where document_id=writeup.writeup_id limit 1) as doctext' ,
    'writeup LEFT JOIN node ON node_id=writeup_id' ,

    "reputation > $repthreshholdlo
    AND publishtime > DATE_SUB(CURDATE(), INTERVAL $maxage) 
    AND cooled != 0" ,
    "ORDER BY reputation DESC LIMIT $pulllimit");

  my $content = [];
  my $used = {};
  while (my $row = $csr->fetchrow_hashref()) {
    next if exists $used->{$$row{type_title}};
    last if scalar(@$content)>=$limit;
    $used->{$$row{type_title}}=1;
    push(@$content, $$row{writeup_id});
  }

  return $this->SUPER::generate($content);
}


__PACKAGE__->meta->make_immutable;
1;
