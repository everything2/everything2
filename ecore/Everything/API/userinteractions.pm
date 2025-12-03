package Everything::API::userinteractions;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

## no critic (ProhibitBuiltinHomonyms)

=head1 NAME

Everything::API::userinteractions - Unified API for managing user social interactions

=head1 DESCRIPTION

Provides a unified interface for managing both:
- Unfavorite users (hide writeups from New Writeups) - stored in VARS
- Message blocking (block private messages/chat) - stored in messageignore table

=cut

sub routes
{
  return {
  "/:id/action/delete" => "delete(:id)",
  "create" => "create",
  "/" => "get_all",
  "/:id" => "get_single(:id)",
  "/:id/action/update" => "update(:id)"
  }
}

sub get_all
{
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;
  my $VARS = $user->VARS;

  # Get unfavorite users (writeup hiding)
  my %unfavorite_map;
  if($VARS->{unfavoriteusers})
  {
    my @unfavorites = split(/,/, $VARS->{unfavoriteusers});
    foreach my $uid (@unfavorites)
    {
      $uid =~ s/^\s+|\s+$//g;
      $unfavorite_map{$uid} = 1 if $uid =~ /^\d+$/;
    }
  }

  # Get message blocks
  my %message_block_map;
  my $csr = $self->DB->sqlSelectMany("ignore_node","messageignore","messageignore_id=".$user->node_id);
  while(my ($blocked_id) = $csr->fetchrow_array)
  {
    $message_block_map{$blocked_id} = 1;
  }

  # Combine both lists
  my %all_users = (%unfavorite_map, %message_block_map);
  my @results;

  foreach my $uid (keys %all_users)
  {
    my $blocked_user = $self->DB->getNodeById($uid);
    next unless $blocked_user;

    my $type = $blocked_user->{type}{title};

    push @results, {
      node_id => int($blocked_user->{node_id}),
      title => $blocked_user->{title},
      type => $type,
      hide_writeups => $unfavorite_map{$uid} ? 1 : 0,
      block_messages => $message_block_map{$uid} ? 1 : 0
    };
  }

  return [$self->HTTP_OK, { blocked_users => \@results }];
}

sub create
{
  my ($self, $REQUEST) = @_;

  my $data = $REQUEST->JSON_POSTDATA;
  my $user = $REQUEST->user;

  # Look up user by name or use provided node_id
  my $target_user;
  if($data->{username})
  {
    $target_user = $self->DB->getNode($data->{username},'usergroup') ||
      $self->DB->getNode($data->{username},'user');
  }
  elsif($data->{node_id})
  {
    $target_user = $self->DB->getNodeById($data->{node_id});
  }

  unless($target_user)
  {
    return [$self->HTTP_OK, {success => 0, error => 'User not found'}];
  }

  my $target_id = $target_user->{node_id};
  my $target_type = $target_user->{type}{title};
  my $hide_writeups = $data->{hide_writeups} ? 1 : 0;
  my $block_messages = $data->{block_messages} ? 1 : 0;

  # Capture title BEFORE any updates
  my $target_title = $target_user->{title};

  # Update unfavoriteusers VARS
  if($hide_writeups)
  {
    my $VARS = $user->VARS;
    my @current = $VARS->{unfavoriteusers} ? split(/,/, $VARS->{unfavoriteusers}) : ();

    # Add if not already present
    unless(grep { $_ eq $target_id } @current)
    {
      push @current, $target_id;
      $VARS->{unfavoriteusers} = join(',', @current);
      $user->set_vars($VARS);
    }
  }

  # Update messageignore table
  if($block_messages)
  {
    unless($self->DB->sqlSelect('*', 'messageignore', "messageignore_id=".$user->node_id." and ignore_node=$target_id"))
    {
      $self->DB->sqlInsert('messageignore', {
        messageignore_id => $user->node_id,
        ignore_node => $target_id
      });
    }
  }

  return [$self->HTTP_OK, {
    success => 1,
    node_id => int($target_id),
    title => $target_title,
    type => $target_type,
    hide_writeups => $hide_writeups,
    block_messages => $block_messages
  }];
}

sub get_single
{
  my ($self, $REQUEST, $id) = @_;

  my $user = $REQUEST->user;
  my $VARS = $user->VARS;
  my $target_id = int($id);

  # Check unfavoriteusers
  my $hide_writeups = 0;
  if($VARS->{unfavoriteusers} && $VARS->{unfavoriteusers} =~ /\b$target_id\b/)
  {
    $hide_writeups = 1;
  }

  # Check messageignore
  my $block_messages = 0;
  if($self->DB->sqlSelect('*', 'messageignore', "messageignore_id=".$user->node_id." and ignore_node=$target_id"))
  {
    $block_messages = 1;
  }

  if($hide_writeups || $block_messages)
  {
    my $target_user = $self->DB->getNodeById($target_id);
    unless($target_user)
    {
      return [$self->HTTP_OK, {success => 0, error => 'User not found'}];
    }

    return [$self->HTTP_OK, {
      success => 1,
      node_id => $target_id,
      title => $target_user->{title},
      type => $target_user->{type}{title},
      hide_writeups => $hide_writeups,
      block_messages => $block_messages
    }];
  }

  return [$self->HTTP_OK, {success => 0, error => 'Not found'}];
}

sub update
{
  my ($self, $REQUEST, $id) = @_;

  my $data = $REQUEST->JSON_POSTDATA;
  my $user = $REQUEST->user;
  my $target_id = int($id);

  my $hide_writeups = $data->{hide_writeups} ? 1 : 0;
  my $block_messages = $data->{block_messages} ? 1 : 0;

  my $VARS = $user->VARS;

  # Update unfavoriteusers
  my @current = $VARS->{unfavoriteusers} ? split(/,/, $VARS->{unfavoriteusers}) : ();
  my @filtered = grep { $_ ne $target_id } @current;

  if($hide_writeups)
  {
    push @filtered, $target_id unless grep { $_ eq $target_id } @filtered;
  }

  $VARS->{unfavoriteusers} = join(',', @filtered);
  $user->set_vars($VARS);

  # Update messageignore
  if($block_messages)
  {
    unless($self->DB->sqlSelect('*', 'messageignore', "messageignore_id=".$user->node_id." and ignore_node=$target_id"))
    {
      $self->DB->sqlInsert('messageignore', {
        messageignore_id => $user->node_id,
        ignore_node => $target_id
      });
    }
  }
  else
  {
    $self->DB->sqlDelete('messageignore', "messageignore_id=".$user->node_id." and ignore_node=$target_id");
  }

  my $target_user = $self->DB->getNodeById($target_id);
  unless($target_user)
  {
    return [$self->HTTP_OK, {success => 0, error => 'User not found'}];
  }

  return [$self->HTTP_OK, {
    success => 1,
    node_id => $target_id,
    title => $target_user->{title},
    type => $target_user->{type}{title},
    hide_writeups => $hide_writeups,
    block_messages => $block_messages
  }];
}

sub delete
{
  my ($self, $REQUEST, $id) = @_;

  my $user = $REQUEST->user;
  my $target_id = int($id);

  # Remove from unfavoriteusers
  my $VARS = $user->VARS;
  if($VARS->{unfavoriteusers})
  {
    my @current = split(/,/, $VARS->{unfavoriteusers});
    my @filtered = grep { $_ ne $target_id } @current;
    $VARS->{unfavoriteusers} = join(',', @filtered);
    $user->set_vars($VARS);
  }

  # Remove from messageignore
  $self->DB->sqlDelete('messageignore', "messageignore_id=".$user->node_id." and ignore_node=$target_id");

  return [$self->HTTP_OK, {success => 1, message => "User interaction removed"}];
}

around ['get_all','create','get_single','update','delete'] => \&Everything::API::unauthorized_if_guest;
__PACKAGE__->meta->make_immutable;
1;
