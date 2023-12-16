package Everything::Node::draft;
use Moose;
use POSIX;
extends 'Everything::Node::writeup';

sub canonical_url
{
  my ($self) = @_;
  return "/user/".$self->author->uri_safe_title."/writeups/".$self->uri_safe_title;
}

sub neglected_drafts_reference
{
  my ($self) = @_;

  my $outdata = {};
  foreach my $key (qw|author parent|)
  {
    unless(UNIVERSAL::isa($self->$key, "Everything::Node::null"))
    {
      $outdata->{"draft_$key"} = $self->$key->json_reference;
    }
  }

  foreach my $key (qw|author_user title node_id|)
  {
    $outdata->{$key} = $self->{NODEDATA}->{$key};
  }

  if(defined($self->notes->[0]))
  {
    $outdata->{nodenote_id} = $self->notes->[0]->{nodenote_id};
    $outdata->{days} = POSIX::floor((time()-$self->APP->convertDateToEpoch($self->notes->[0]->{timestamp}))/86400);
  }

  return $outdata;
}

__PACKAGE__->meta->make_immutable;
1;
