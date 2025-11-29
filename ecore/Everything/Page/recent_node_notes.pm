package Everything::Page::recent_node_notes;

use Moose;
use Everything::Timestamp;
extends 'Everything::Page';
with 'Everything::Security::StaffOnly';

sub buildReactData
{
  my ($self, $REQUEST, $node) = @_;

  my $onlymynotes = (defined($REQUEST->param('onlymynotes')) and scalar($REQUEST->param('onlymynotes')))?(1):(0);
  my $hidesystemnotes = (defined($REQUEST->param('hidesystemnotes')) and scalar($REQUEST->param('hidesystemnotes')))?(1):(0);
  my $page = defined($REQUEST->param('page'))?(int($REQUEST->param('page'))):(0);
  my $where = "1=1 ";

  if($onlymynotes)
  {
    $where = "(noter_user=".$REQUEST->user->node_id." OR notetext like ".$self->DB->quote("[".$REQUEST->user->title."]%").")";
  }elsif($hidesystemnotes)
  {
    $where = "noter_user != 0";
  }

  my $totalnotes = $self->DB->sqlSelect("count(*)","nodenote", $where);
  my $limit = 50;
  my $startat = $page * 50;
  my $notes = [];

  $where .= " ORDER by timestamp DESC LIMIT $startat,$limit";

  $self->devLog("recent_node_notes: $where");
  my $csr = $self->DB->sqlSelectMany("*","nodenote",$where);

  while(my $row = $csr->fetchrow_hashref)
  {
    my $notenode = $self->APP->node_by_id($row->{nodenote_nodeid});
    next unless defined($notenode);
    push @$notes, {
      node => {
        node_id => $notenode->id,
        title => $notenode->title
      },
      timestamp => $row->{timestamp},
      note => $row->{notetext}
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
