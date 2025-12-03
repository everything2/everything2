package Everything::Page::pit_of_abomination;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::NoGuest';

=head1 NAME

Everything::Page::pit_of_abomination - Modern React-based user blocking interface

=head1 DESCRIPTION

Modern replacement for the legacy Perl "Pit of Abomination" page.
Uses the unified UserInteractionsManager component to manage both
writeup hiding and message blocking.

=cut

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;
  my $VARS = $user->VARS;
  my $DB = $self->DB;

  # Get blocked users using unified user interactions (both unfavorite + message blocking)
  my @blocked_users;

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
  my $csr = $DB->sqlSelectMany("ignore_node","messageignore","messageignore_id=".$user->node_id);
  while(my ($blocked_id) = $csr->fetchrow_array)
  {
    $message_block_map{$blocked_id} = 1;
  }

  # Combine both lists
  my %all_users = (%unfavorite_map, %message_block_map);

  foreach my $uid (keys %all_users)
  {
    my $blocked_user = $DB->getNodeById($uid);
    next unless $blocked_user;

    my $type = $blocked_user->{type}{title};

    push @blocked_users, {
      node_id => int($blocked_user->{node_id}),
      title => $blocked_user->{title},
      type => $type,
      hide_writeups => $unfavorite_map{$uid} ? 1 : 0,
      block_messages => $message_block_map{$uid} ? 1 : 0
    };
  }

  return {
    type => 'pit_of_abomination',
    blockedUsers => \@blocked_users,
    currentUser => {
      node_id => $user->node_id,
      title => $user->title
    }
  };
}

__PACKAGE__->meta->make_immutable;
1;
