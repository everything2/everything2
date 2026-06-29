package Everything::Page::recent_node_notes;

use Moose;
use Everything::Timestamp;
extends 'Everything::Page';
with 'Everything::Security::StaffOnly';

sub buildReactData
{
  my ($self, $REQUEST, $node) = @_;

  my $onlymynotes = (defined($REQUEST->param('onlymynotes')) and scalar($REQUEST->param('onlymynotes')))?(1):(0);
  # "Hide automated notes" defaults ON so the page leads with editorial
  # feedback; an explicit hidesystemnotes=0 (sent by the React toggle when
  # unchecked) turns it off. Absent param => first visit => default on.
  my $hidesystemnotes = defined($REQUEST->param('hidesystemnotes'))
    ? (scalar($REQUEST->param('hidesystemnotes')) ? 1 : 0)
    : 1;
  my $page = defined($REQUEST->param('page'))?(int($REQUEST->param('page'))):(0);
  my $where = "1=1 ";

  if($onlymynotes)
  {
    $where = "(noter_user=".$REQUEST->user->node_id." OR notetext like ".$self->DB->quote("[".$REQUEST->user->title."]%").")";
  }elsif($hidesystemnotes)
  {
    # Drop both true system notes (noter_user = 0) and the lifecycle
    # breadcrumbs (publish/remove/...) that are attributed to the acting user,
    # leaving genuine editorial feedback.
    $where = "noter_user != 0 AND ".$self->APP->nodenote_editorial_sql;
  }

  # Inner-join to node so the count AND the page reflect only notes whose node
  # still exists -- deleted/nuked nodes are excluded in the query, not skipped
  # after fetching. That keeps "showing N of TOTAL" honest and gives a full
  # page of currently-good notes instead of filtering a page of 50 down to a
  # handful (#4389).
  my $from = "nodenote JOIN node ON node.node_id = nodenote.nodenote_nodeid";
  my $totalnotes = $self->DB->sqlSelect("count(*)", $from, $where);
  my $limit = 50;
  my $startat = $page * 50;
  my $notes = [];

  $self->devLog("recent_node_notes: $where");
  my $csr = $self->DB->sqlSelectMany("nodenote.*, node.title", $from,
    $where . " ORDER by nodenote.timestamp DESC LIMIT $startat,$limit");

  while(my $row = $csr->fetchrow_hashref)
  {
    # Restore noter attribution (the page used to drop it -- #4389). Mirror
    # getNodeNotes: noter_user 0 = system note, 1 = legacy (name embedded in
    # notetext), otherwise look up the username.
    my $noter_user = $row->{noter_user} // 0;
    my $noter;
    if ($noter_user > 1)
    {
      my $nu = $self->DB->getNodeById($noter_user);
      $noter = $nu->{title} if $nu;
    }

    # Flag auto-generated breadcrumbs so the view can badge them; combined with
    # noter_user==0 this is "not editorial feedback".
    my $is_auto = ($noter_user == 0)
      || $self->APP->nodenote_is_lifecycle($row->{notetext});

    # node.title comes from the JOIN, so the node is guaranteed to exist.
    push @$notes, {
      node => {
        node_id => $row->{nodenote_nodeid},
        title   => $row->{title}
      },
      timestamp => $row->{timestamp},
      note => $row->{notetext},
      noter => $noter,
      kind => $is_auto ? 'auto' : 'editorial'
    };
  }

  return {
    onlymynotes => $onlymynotes,
    hidesystemnotes => $hidesystemnotes,
    total => $totalnotes,
    page => $page,
    perpage => $limit,
    notes => $notes,
    node => $node
  };
}

__PACKAGE__->meta->make_immutable;

1;
