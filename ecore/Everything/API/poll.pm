package Everything::API::poll;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

## no critic (ProhibitBuiltinHomonyms)

sub routes
{
  return {
    "vote" => "submit_vote",
    "delete_vote" => "delete_vote",
  }
}

sub submit_vote
{
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;
  my $APP = $self->APP;
  my $DB = $self->DB;

  # Check if user is logged in
  if (!$user || $user->node_id <= 0) {
    return [$self->HTTP_FORBIDDEN, { error => "You must be logged in to vote" }];
  }

  # Get POST data
  my $data = $REQUEST->JSON_POSTDATA;
  if (!$data) {
    return [$self->HTTP_BAD_REQUEST, { error => "Missing request data" }];
  }

  my $poll_id = $data->{poll_id};
  my $choice = $data->{choice};

  # Validate required fields
  if (!defined $poll_id || !defined $choice) {
    return [$self->HTTP_BAD_REQUEST, { error => "Missing required fields: poll_id and choice" }];
  }

  # Validate choice is a number
  if ($choice !~ /^\d+$/) {
    return [$self->HTTP_BAD_REQUEST, { error => "Invalid choice: must be a number" }];
  }

  # Get the poll
  my $poll = $DB->getNodeById($poll_id);
  if (!$poll || $poll->{type}{title} ne 'e2poll') {
    return [$self->HTTP_NOT_FOUND, { error => "Poll not found" }];
  }

  # Check if poll is open for voting
  if ($poll->{poll_status} ne 'current' && $poll->{poll_status} ne 'open') {
    return [$self->HTTP_BAD_REQUEST, {
      error => "This poll is not open for voting",
      poll_status => $poll->{poll_status}
    }];
  }

  # Parse poll options to validate choice
  my @options = split /\s*\n\s*/, $poll->{doctext};
  if ($choice < 0 || $choice >= scalar(@options)) {
    return [$self->HTTP_BAD_REQUEST, {
      error => "Invalid choice: must be between 0 and " . (scalar(@options) - 1),
      num_options => scalar(@options)
    }];
  }

  # Check if user has already voted (unless multiple voting is allowed)
  unless ($poll->{multiple}) {
    my $where = "voter_user=" . $user->node_id . " AND pollvote_id=" . $poll->{node_id};
    my $vote_count = $DB->sqlSelect('COUNT(*)', 'pollvote', $where);

    if ($vote_count > 0) {
      my $existing_vote = $DB->sqlSelect('choice', 'pollvote', $where);
      return [$self->HTTP_BAD_REQUEST, {
        error => "You have already voted on this poll",
        previous_vote => $existing_vote
      }];
    }
  }

  # Insert the vote
  $DB->sqlInsert("pollvote", {
    pollvote_id => $poll->{node_id},
    voter_user => $user->node_id,
    choice => $choice,
    votetime => $APP->convertEpochToDate(time())
  });

  # Update vote counts
  my @results = split ',', $poll->{e2poll_results} || '';

  # Ensure results array is large enough
  while (scalar(@results) <= $choice) {
    push @results, 0;
  }

  $results[$choice]++;
  $poll->{e2poll_results} = join(',', @results);
  $poll->{totalvotes} = ($poll->{totalvotes} || 0) + 1;

  # Update poll node (this will invalidate cache)
  $DB->updateNode($poll, -1);

  # Refresh poll data
  $poll = $DB->getNodeById($poll_id);

  # Build response with updated poll data
  @results = split ',', $poll->{e2poll_results} || '';
  my $author = $DB->getNodeById($poll->{poll_author});
  my $author_name = $author ? $author->{title} : 'Unknown';

  return [$self->HTTP_OK, {
    success => 1,
    message => "Vote recorded successfully",
    poll => {
      node_id => $poll->{node_id},
      title => $poll->{title},
      poll_author => $poll->{poll_author},
      author_name => $author_name,
      question => $poll->{question},
      options => \@options,
      poll_status => $poll->{poll_status},
      e2poll_results => \@results,
      totalvotes => $poll->{totalvotes},
      userVote => int($choice)
    }
  }];
}

sub delete_vote
{
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;
  my $APP = $self->APP;
  my $DB = $self->DB;

  # Check if user is an admin/god
  unless ($user && $user->is_admin) {
    return [$self->HTTP_FORBIDDEN, { error => 'Admin access required' }];
  }

  # Get POST data
  my $data = $REQUEST->JSON_POSTDATA;
  if (!$data) {
    return [$self->HTTP_BAD_REQUEST, { error => 'Missing request data' }];
  }

  my $poll_id = $data->{poll_id};
  my $voter_user = $data->{voter_user};

  # Validate required field
  if (!defined $poll_id) {
    return [$self->HTTP_BAD_REQUEST, { error => 'Missing required field: poll_id' }];
  }

  # Get the poll
  my $poll = $DB->getNodeById($poll_id);
  if (!$poll || $poll->{type}{title} ne 'e2poll') {
    return [$self->HTTP_NOT_FOUND, { error => 'Poll not found' }];
  }

  # Delete votes
  my $deleted_count = 0;
  if (defined $voter_user) {
    # Delete vote for specific user
    my $where = 'voter_user=' . $voter_user . ' AND pollvote_id=' . $poll->{node_id};
    my $vote = $DB->sqlSelect('choice', 'pollvote', $where);

    if (defined $vote) {
      my $result = $DB->sqlDelete('pollvote', $where);
      $deleted_count = 1;
    }
  } else {
    # Delete all votes for this poll
    my $votes = $DB->sqlSelectMany('choice', 'pollvote',
      'pollvote_id=' . $poll->{node_id});

    while (my $row = $votes->fetchrow_hashref()) {
      $deleted_count++;
    }

    $DB->sqlDelete('pollvote', 'pollvote_id=' . $poll->{node_id});
  }

  # Recalculate vote counts
  my $votes = $DB->sqlSelectMany('choice', 'pollvote',
    'pollvote_id=' . $poll->{node_id});

  my @options = split /\s*\n\s*/, $poll->{doctext};
  my @results = (0) x scalar(@options);
  my $total_votes = 0;

  while (my $row = $votes->fetchrow_hashref()) {
    my $choice = $row->{choice};
    if ($choice >= 0 && $choice < scalar(@options)) {
      $results[$choice]++;
      $total_votes++;
    }
  }

  # Update poll with new counts
  $poll->{e2poll_results} = join(',', @results);
  $poll->{totalvotes} = $total_votes;
  $DB->updateNode($poll, -1);

  return [$self->HTTP_OK, {
    success => 1,
    message => "Deleted $deleted_count vote(s)",
    deleted_count => $deleted_count,
    poll_id => $poll->{node_id},
    new_total => $total_votes
  }];
}

1;
