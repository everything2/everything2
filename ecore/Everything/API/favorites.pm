package Everything::API::favorites;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

=head1 NAME

Everything::API::favorites - API for managing favorite users (following)

=head1 DESCRIPTION

Provides endpoints for favoriting and unfavoriting users.
Favorites allow users to follow other users and see their writeups
in the Favorite Noders nodelet.

This is distinct from the "unfavorite" system (hiding writeups from
New Writeups) which is managed by the userinteractions API.

=cut

sub routes
{
  return {
    "/" => "get_all",
    "/:id" => "get_single(:id)",
    "/:id/action/favorite" => "favorite(:id)",
    "/:id/action/unfavorite" => "unfavorite(:id)"
  }
}

# Get all users the current user has favorited
sub get_all
{
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;
  my $linktype = $self->DB->getNode('favorite', 'linktype');

  return [$self->HTTP_OK, {success => 0, error => 'Linktype not found'}]
    unless $linktype;

  my $linktype_id = $linktype->{node_id};
  my $user_id = $user->node_id;

  # Get all favorited users
  my $csr = $self->DB->sqlSelectMany(
    'to_node',
    'links',
    "from_node = $user_id AND linktype = $linktype_id"
  );

  my @favorites;
  while (my ($fav_id) = $csr->fetchrow_array)
  {
    my $fav_user = $self->DB->getNodeById($fav_id);
    next unless $fav_user && $fav_user->{type}{title} eq 'user';

    push @favorites, {
      node_id => int($fav_user->{node_id}),
      title => $fav_user->{title}
    };
  }

  return [$self->HTTP_OK, {
    success => 1,
    favorites => \@favorites
  }];
}

# Get favorite status for a specific user
sub get_single
{
  my ($self, $REQUEST, $id) = @_;

  my $user = $REQUEST->user;
  my $target_id = int($id);

  # Verify target exists and is a user
  my $target = $self->DB->getNodeById($target_id);
  return [$self->HTTP_OK, {success => 0, error => 'User not found'}]
    unless $target && $target->{type}{title} eq 'user';

  my $linktype = $self->DB->getNode('favorite', 'linktype');
  return [$self->HTTP_OK, {success => 0, error => 'Linktype not found'}]
    unless $linktype;

  my $linktype_id = $linktype->{node_id};
  my $user_id = $user->node_id;

  # Check if favorited
  my $is_favorited = $self->DB->sqlSelect(
    '1',
    'links',
    "from_node = $user_id AND to_node = $target_id AND linktype = $linktype_id"
  ) ? 1 : 0;

  return [$self->HTTP_OK, {
    success => 1,
    node_id => $target_id,
    title => $target->{title},
    is_favorited => $is_favorited
  }];
}

# Favorite a user (follow)
sub favorite
{
  my ($self, $REQUEST, $id) = @_;

  my $user = $REQUEST->user;
  my $target_id = int($id);
  my $user_id = $user->node_id;

  # Can't favorite yourself
  return [$self->HTTP_OK, {success => 0, error => 'Cannot favorite yourself'}]
    if $target_id == $user_id;

  # Verify target exists and is a user
  my $target = $self->DB->getNodeById($target_id);
  return [$self->HTTP_OK, {success => 0, error => 'User not found'}]
    unless $target && $target->{type}{title} eq 'user';

  my $linktype = $self->DB->getNode('favorite', 'linktype');
  return [$self->HTTP_OK, {success => 0, error => 'Linktype not found'}]
    unless $linktype;

  my $linktype_id = $linktype->{node_id};

  # Check if already favorited
  my $already_favorited = $self->DB->sqlSelect(
    '1',
    'links',
    "from_node = $user_id AND to_node = $target_id AND linktype = $linktype_id"
  );

  if ($already_favorited)
  {
    return [$self->HTTP_OK, {
      success => 1,
      node_id => $target_id,
      title => $target->{title},
      is_favorited => 1,
      message => 'Already favorited'
    }];
  }

  # Insert the favorite link
  $self->DB->sqlInsert('links', {
    -from_node => $user_id,
    -to_node => $target_id,
    -linktype => $linktype_id
  });

  return [$self->HTTP_OK, {
    success => 1,
    node_id => $target_id,
    title => $target->{title},
    is_favorited => 1
  }];
}

# Unfavorite a user (unfollow)
sub unfavorite
{
  my ($self, $REQUEST, $id) = @_;

  my $user = $REQUEST->user;
  my $target_id = int($id);
  my $user_id = $user->node_id;

  # Verify target exists and is a user
  my $target = $self->DB->getNodeById($target_id);
  return [$self->HTTP_OK, {success => 0, error => 'User not found'}]
    unless $target && $target->{type}{title} eq 'user';

  my $linktype = $self->DB->getNode('favorite', 'linktype');
  return [$self->HTTP_OK, {success => 0, error => 'Linktype not found'}]
    unless $linktype;

  my $linktype_id = $linktype->{node_id};

  # Delete the favorite link
  $self->DB->sqlDelete('links',
    "from_node = $user_id AND to_node = $target_id AND linktype = $linktype_id"
  );

  return [$self->HTTP_OK, {
    success => 1,
    node_id => $target_id,
    title => $target->{title},
    is_favorited => 0
  }];
}

around ['get_all', 'get_single', 'favorite', 'unfavorite'] => \&Everything::API::unauthorized_if_guest;
__PACKAGE__->meta->make_immutable;
1;
