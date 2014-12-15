package Everything::DataStash::reviewdrafts;

use Moose;
extends 'Everything::DataStash';
use namespace::autoclean;

has '+interval' => (default => 60);

sub generate
{
  my ($this) = @_;

  my $review = $this->DB->getId($this->DB->getNode('review', 'publication_status'));
  my $cuss = $this->DB->sqlSelectMany(
    "node_id, title, author_user, request.timestamp AS publishtime, (Select CONCAT(timestamp, ': ', notetext) From nodenote As response
		Where response.nodenote_nodeid = request.nodenote_nodeid
			And response.timestamp > request.timestamp
			Order By response.timestamp Desc Limit 1) as latestnote,
		(Select count(*) From nodenote As response
		Where response.nodenote_nodeid = request.nodenote_nodeid
			And response.timestamp > request.timestamp) as notecount"
    , "draft JOIN node on node_id = draft_id
      JOIN nodenote AS request
      ON draft_id = nodenote_nodeid
      AND request.noter_user = 0
      LEFT JOIN nodenote AS newer
      ON request.nodenote_nodeid = newer.nodenote_nodeid
      AND newer.noter_user = 0
      AND request.timestamp < newer.timestamp"
      , "publication_status = $review AND newer.timestamp IS NULL"
      , "ORDER BY notecount > 0, request.timestamp");

  return $this->SUPER::generate($cuss->fetchall_arrayref({}));
}


__PACKAGE__->meta->make_immutable;
1;
