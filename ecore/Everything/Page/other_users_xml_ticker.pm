package Everything::Page::other_users_xml_ticker;

use Moose;
extends 'Everything::Page';

has 'mimetype' => (default => 'application/xml', 'is' => 'ro');

use XML::Generator;

#TODO: Remove me
use Everything::HTML;

sub display
{
  my ($self, $REQUEST, $node) = @_;

  my $str = "";
  my $XG = XML::Generator->new;
  my $time=180;

  my $curUserID = $REQUEST->user->node_id;
  my $userID;

  my $wherestr = "";

  unless ($REQUEST->user->infravision)
  {
    $wherestr.=' and ' if $wherestr;
    $wherestr.='visible=0';
  }

  my $csr = $self->DB->sqlSelectMany('*', 'room', $wherestr, 'order by experience DESC');
  my @users = ();
  while (my $N = $csr->fetchrow_hashref)
  {
    push @users, $N;
  }

  $str.=$XG->INFO({site => $self->CONF->site_url, sitename => $self->CONF->site_name,  servertime => scalar(localtime(time))}, 'Rendered by the Other Users XML Ticker');

  my %rooms;
  $rooms{0} = 'outside';
  foreach my $N (@users)
  {
    $userID = $$N{member_user};
    if (not $rooms{$$N{room_id}})
    {
      my $ROOM = $self->APP->node_by_id($N->{room_id});
      next unless $ROOM;
      $rooms{$N->{room_id}} = $ROOM->title;
    }

    $str.="\n\t".$XG->user({room =>$rooms{$$N{room_id}}, user_id => $$N{member_user},username=>$self->APP->xml_escape($$N{nick})},"\n");

  }

  return [$self->HTTP_OK, qq{<?xml version="1.0"?>\n} . $XG->OTHER_USERS($str), {"type" => $self->mimetype}];

}

1;
