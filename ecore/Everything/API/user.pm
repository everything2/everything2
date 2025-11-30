package Everything::API::user;

use Moose;
extends 'Everything::API';

sub route {
  my ($self, $REQUEST, $extra) = @_;
  my $method = lc($REQUEST->request_method());

  # GET /api/user/sanctity?username=<name>
  if ($extra eq 'sanctity' && $method eq 'get') {
    return $self->sanctity($REQUEST);
  }

  # GET /api/user/available/<username>
  if ($extra =~ m{^available/(.+)$} && $method eq 'get') {
    return $self->check_available($REQUEST, $1);
  }

  # Catchall for unmatched routes
  return $self->$method($REQUEST);
}

sub sanctity {
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;
  my $query = $REQUEST->Vars;
  my $APP = $self->APP;
  my $DB = $self->DB;

  # Admin-only endpoint
  unless ($APP->isAdmin($user)) {
    return [$self->HTTP_FORBIDDEN, {
      success => 0,
      error => 'Admin access required'
    }];
  }

  # Get username parameter
  my $username = $query->{username};
  unless ($username) {
    return [$self->HTTP_BAD_REQUEST, {
      success => 0,
      error => 'Username parameter required'
    }];
  }

  # Look up user
  my $target_user = $DB->getNode($username, 'user');
  unless ($target_user) {
    # Try with underscores converted to spaces
    $username =~ s/_/ /g;
    $target_user = $DB->getNode($username, 'user');
  }

  unless ($target_user) {
    return [$self->HTTP_NOT_FOUND, {
      success => 0,
      error => "User '$username' not found"
    }];
  }

  return [$self->HTTP_OK, {
    success => 1,
    username => $target_user->{title},
    sanctity => int($target_user->{sanctity} || 0)
  }];
}

=head2 GET /api/user/available/<username>

Check if a username is available for registration.

Response:
{
  "available": true|false,
  "username": "the_username"
}

=cut

sub check_available
{
  my ($self, $REQUEST, $username) = @_;

  my $APP = $self->APP;

  unless ($username) {
    return [$self->HTTP_BAD_REQUEST, {
      error => 'Username required'
    }];
  }

  # URL decode the username
  $username =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;

  # Check username format first
  my $invalidName = '^\W+$|[\[\]\<\>\&\{\}\|\/\\\]| .*_|_.* |\s\s|^\s|\s$';
  if ($username =~ /$invalidName/) {
    return [$self->HTTP_OK, {
      available => 0,
      username => $username,
      reason => 'invalid_format'
    }];
  }

  # Check if username is taken
  my $taken = $APP->is_username_taken($username);

  return [$self->HTTP_OK, {
    available => $taken ? 0 : 1,
    username => $username
  }];
}

1;
