package Everything::DataStash::neglecteddrafts;

use Moose;
extends 'Everything::DataStash';
use namespace::autoclean;

has '+interval' => (default => 60);

sub generate
{
  my ($this) = @_;

  my $eLimit = 2; # no node note after this many days = editor neglected
  my $aLimit = 10; # still up for review this many days after last note = author neglected
  my $aBoot = 25; # still up for review this long after last note = revert status
  my $reminderBot = 'Virgil';
  my $last_nudge = $this->current_data->{last_nudge} || time();
  my $notification = $this->DB->getId($this->DB->getNode('draft for review', 'notification'));
  my $review = $this->DB->getId($this->DB->getNode('review', 'publication_status'));

  my $do_nudge = 0;
  if(time() - $last_nudge >= 60*60*24)
  {
    $do_nudge = 1;
  }

  my $eNudge = sub{
    # repeat notification on editor neglect (but not too often)
    my $N = shift;

    if ($$N{days} >= $eLimit && $do_nudge)
    {
      print STDERR "Sending notification for editor neglect\n";
      $this->APP->add_notification($notification, $notification, {draft_id => $$N{node_id}, nodenote_id => $$N{nodenote_id}, neglected => 1});
    }
  };

  my $aNudge = sub{
    # send reminder message on author neglect (but only once)
    # push back to 'findable' status after more neglect
    my $N = shift;
    my $message;

    if ($$N{days} >= $aLimit && $do_nudge)
    {
      if ($$N{days} > $aBoot)
      {
        print STDERR "Reverting draft to findable\n";
	my $to_revert = $this->DB->getNodeById($N->{node_id});
        $to_revert->{publication_status} = $this->DB->getId($this->DB->getNode('findable', 'publication_status'));
        $this->DB->updateNode($to_revert, -1);
        $message = 'too long. Its status has been changed to "findable"';
      }
      my $author = $this->DB->getNodeById($N->{author_user});
      $message ||= 'some time. Please consider publishing it or changing its status';

      print STDERR "Sending message to author ($$N{author_user}, $$N{title}, $$author{title}, $message)\n";
      $this->APP->send_message({ "from" => $this->DB->getId($this->DB->getNode($reminderBot, 'user')), "to" => $$N{author_user} , "message" => "Your draft [$$N{title}\[by $$author{title}]] has been up for review for $message." }) if $message;

    }
  };

  my $parameters = [
    {
    "who" => 'Editor',
    "neglect" => $eLimit,
    "noter_user" => '= 0',
    "nudge" => $eNudge
    },
    {
    "who" => 'Author',
    "neglect" => $aLimit,
    "noter_user" => '!= 0',
    "nudge" => $aNudge
    }
  ];


  my $output = {};

  foreach my $params (@$parameters)
  {
    my $cuss = $this->DB->sqlSelectMany(
      "node_id, title, author_user, basenote.nodenote_id, DATEDIFF(NOW(), basenote.timestamp) AS days",
      "draft JOIN node on node_id = draft_id JOIN nodenote AS basenote ON draft_id = nodenote_nodeid AND basenote.noter_user $$params{noter_user}
        LEFT JOIN nodenote AS newer ON basenote.nodenote_nodeid = newer.nodenote_nodeid AND basenote.timestamp < newer.timestamp",
      "publication_status = $review AND basenote.timestamp < NOW()- INTERVAL $$params{neglect} DAY AND newer.timestamp IS NULL",
      "ORDER BY basenote.timestamp");
    $output->{lc($params->{who})} = $cuss->fetchall_arrayref({});

    foreach my $N(@{$output->{lc($params->{who})}})
    {
      $params->{nudge}->($N);
    }
  }

  if($do_nudge)
  {
    $output->{last_nudge} = time();
  }else{
    $output->{last_nudge} = $last_nudge;
  }

  return $this->SUPER::generate($output);
}


__PACKAGE__->meta->make_immutable;
1;
