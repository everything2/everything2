package Everything::API::ilikeit;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

=head1 NAME

Everything::API::ilikeit - API for guest users to send "I like it!" messages

=head1 DESCRIPTION

Allows guest (anonymous) users to send appreciation messages to writeup authors.
When a guest clicks "I like it!" on a writeup, a Cool Man Eddie message is sent
to the author letting them know someone appreciated their work.

This is tracked by IP address to prevent spam - each IP can only "like" a
specific writeup once.

=cut

sub routes
{
  return {
    "writeup/:id" => "like_writeup(:id)",
    "status/:id" => "get_status(:id)"
  };
}

sub like_writeup
{
  my ($self, $REQUEST, $writeup_id) = @_;

  my $APP = $self->APP;
  my $DB = $self->DB;
  my $user = $REQUEST->user;

  # This is for guests only - logged-in users can vote/cool instead
  unless ($user->is_guest) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'This feature is for guests only. As a logged-in user, you can vote or C! instead.'
    }];
  }

  # Block spiders/bots
  if ($APP->isSpider()) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Request blocked'
    }];
  }

  # Validate writeup_id
  $writeup_id = int($writeup_id || 0);
  unless ($writeup_id) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Missing writeup_id'
    }];
  }

  # Get the writeup
  my $writeup = $APP->node_by_id($writeup_id);
  unless ($writeup && $writeup->type->title eq 'writeup') {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Writeup not found'
    }];
  }

  # Get client IP address
  my $addr = $ENV{HTTP_X_FORWARDED_FOR} || $ENV{REMOTE_ADDR};
  unless ($addr) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Unable to determine client address'
    }];
  }

  # Check if this IP has already liked this writeup
  my $already_liked = $DB->sqlSelect(
    "count(*)",
    "likedit",
    "likedit_ip = " . $DB->quote($addr) . " AND likedit_node = $writeup_id"
  );

  if ($already_liked) {
    return [$self->HTTP_OK, {
      success => 0,
      already_liked => 1,
      error => 'You have already liked this writeup'
    }];
  }

  # Get the ilikeit linktype for tracking
  my $ilikeit_linktype = $DB->getNode('ilikeit', 'linktype');
  my $guest_user_id = $Everything::CONF->guest_user;

  if ($ilikeit_linktype && $guest_user_id) {
    my $linktype_id = $ilikeit_linktype->{node_id};

    # Check if link exists and update hits, otherwise create it
    my $link_exists = $DB->sqlSelect(
      "count(*)",
      "links",
      "from_node = $guest_user_id AND to_node = $writeup_id AND linktype = $linktype_id"
    );

    if ($link_exists) {
      $DB->sqlUpdate(
        "links",
        { -hits => 'hits + 1' },
        "from_node = $guest_user_id AND to_node = $writeup_id AND linktype = $linktype_id"
      );
    } else {
      $DB->sqlInsert("links", {
        from_node => $guest_user_id,
        to_node => $writeup_id,
        linktype => $linktype_id,
        hits => 1,
        food => 0
      });
    }
  }

  # Log the like (for analytics) - uses user_agent as key
  my $log_query = qq|
    INSERT INTO likeitlog
    (user_agent, liked_node_id, hits)
    VALUES (?, ?, ?)
    ON DUPLICATE KEY UPDATE hits = hits + 1
  |;
  $DB->getDatabaseHandle()->do($log_query, undef, $ENV{HTTP_USER_AGENT} || '', $writeup_id, 1);

  # Record in likedit table (prevents duplicate likes from same IP)
  $DB->sqlInsert('likedit', {
    likedit_ip => $addr,
    likedit_node => $writeup_id
  });

  # Send Cool Man Eddie message to the author (with conditions)
  $self->_send_like_notification($writeup);

  return [$self->HTTP_OK, {
    success => 1,
    message => 'Thanks! Your appreciation has been sent to the author.',
    writeup_id => $writeup_id
  }];
}

sub get_status
{
  my ($self, $REQUEST, $writeup_id) = @_;

  my $APP = $self->APP;
  my $DB = $self->DB;
  my $user = $REQUEST->user;

  # This feature is only relevant to guests
  unless ($user->is_guest) {
    return [$self->HTTP_OK, {
      success => 1,
      available => 0,
      reason => 'logged_in'
    }];
  }

  # Block spiders
  if ($APP->isSpider()) {
    return [$self->HTTP_OK, {
      success => 1,
      available => 0,
      reason => 'spider'
    }];
  }

  # Validate writeup_id
  $writeup_id = int($writeup_id || 0);
  unless ($writeup_id) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Missing writeup_id'
    }];
  }

  # Get the writeup
  my $writeup = $APP->node_by_id($writeup_id);
  unless ($writeup && $writeup->type->title eq 'writeup') {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Writeup not found'
    }];
  }

  # Get client IP
  my $addr = $ENV{HTTP_X_FORWARDED_FOR} || $ENV{REMOTE_ADDR};
  unless ($addr) {
    return [$self->HTTP_OK, {
      success => 1,
      available => 0,
      reason => 'no_ip'
    }];
  }

  # Check if already liked
  my $already_liked = $DB->sqlSelect(
    "count(*)",
    "likedit",
    "likedit_ip = " . $DB->quote($addr) . " AND likedit_node = $writeup_id"
  );

  if ($already_liked) {
    return [$self->HTTP_OK, {
      success => 1,
      available => 0,
      already_liked => 1
    }];
  }

  return [$self->HTTP_OK, {
    success => 1,
    available => 1,
    writeup_id => $writeup_id
  }];
}

sub _send_like_notification
{
  my ($self, $writeup) = @_;

  my $APP = $self->APP;
  my $DB = $self->DB;

  # Don't notify for Webster 1913 writeups
  my $webster = $DB->getNode('Webster 1913', 'user');
  if ($webster && $writeup->author_user == $webster->{node_id}) {
    return;
  }

  # Get the author
  my $author = $APP->node_by_id($writeup->author_user);
  return unless $author;

  # Check if author was active in the last 30 days
  my ($sec, $min, $hour, $mday, $mon, $year) = localtime(time - 86400 * 30);
  $year += 1900;
  $mon++;
  my $check_date = sprintf('%04d-%02d-%02d', $year, $mon, $mday);

  my $author_data = $author->NODEDATA;
  my $is_recent = ($author_data->{lasttime} && $author_data->{lasttime} ge $check_date);
  return unless $is_recent;

  # Check if author has disabled like notifications
  my $author_vars = $author->VARS;
  if ($author_vars->{no_likeitnotification}) {
    return;
  }

  # Get parent e2node title for the message
  my $parent = $writeup->parent;
  return unless $parent;

  # Send Cool Man Eddie message
  my $eddie = $DB->getNode('Cool Man Eddie', 'user');
  return unless $eddie;

  my $msg_text = 'Hey, sweet! Someone likes your writeup titled "[' . $parent->title . ']!"';

  $DB->sqlInsert('message', {
    'msgtext' => $msg_text,
    'author_user' => $eddie->{node_id},
    'for_user' => $writeup->author_user,
    'for_usergroup' => 0,
    'archive' => 0
  });

  return;
}

__PACKAGE__->meta->make_immutable;
1;
