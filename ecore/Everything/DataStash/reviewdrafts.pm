package Everything::DataStash::reviewdrafts;

use Moose;
extends 'Everything::DataStash';
use namespace::autoclean;

has '+interval' => (default => 60);

# Number of drafts to expose to the For Review nodelet. The nodelet renders a
# compact table in the sidebar; older drafts are still reachable via the full
# Drafts For Review document for editors who want the unbounded list.
use constant REVIEW_DRAFTS_NODELET_LIMIT => 20;

sub generate
{
  my ($this) = @_;

  my $review = $this->DB->getId($this->DB->getNode('review', 'publication_status'));
  my $limit = REVIEW_DRAFTS_NODELET_LIMIT;

  # Order: drafts the editor has NOT yet noted on first (notecount=0 wins via
  # `notecount > 0` ascending → 0 sorts before 1), then most-recently submitted
  # first within each group. The DESC on request.timestamp is the user-visible
  # change here; the nodelet previously surfaced the oldest review requests at
  # the top of the list, which is exactly backwards when the goal is to
  # service freshly-submitted reviews.
  # Also pull the author's title (author.title AS author_title) so the React
  # nodelet can render "by <username>" without a second round trip — the prior
  # query returned only author_user (the integer node_id), leaving the React
  # LinkNode with no text to display.
  my $cuss = $this->DB->sqlSelectMany(
    "node.node_id, node.title, node.author_user,
		author.title AS author_title,
		request.timestamp AS publishtime,
		(Select CONCAT(timestamp, ': ', notetext) From nodenote As response
		Where response.nodenote_nodeid = request.nodenote_nodeid
			And response.timestamp > request.timestamp
			Order By response.timestamp Desc Limit 1) as latestnote,
		(Select count(*) From nodenote As response
		Where response.nodenote_nodeid = request.nodenote_nodeid
			And response.timestamp > request.timestamp) as notecount"
    , "draft JOIN node on node.node_id = draft.draft_id
      LEFT JOIN node AS author ON author.node_id = node.author_user
      JOIN nodenote AS request
      ON draft.draft_id = request.nodenote_nodeid
      AND request.noter_user = 0
      LEFT JOIN nodenote AS newer
      ON request.nodenote_nodeid = newer.nodenote_nodeid
      AND newer.noter_user = 0
      AND request.timestamp < newer.timestamp"
      , "draft.publication_status = $review AND newer.timestamp IS NULL"
      , "ORDER BY notecount > 0, request.timestamp DESC LIMIT $limit");

  return $this->SUPER::generate($cuss->fetchall_arrayref({}));
}


__PACKAGE__->meta->make_immutable;
1;
