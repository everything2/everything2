package Everything::API::users;

use Moose;
extends 'Everything::API::nodes';

has 'UPDATE_ALLOWED' => (is => 'ro', isa => 'Int', default => 1);

around 'routes' => sub {
  my ($orig, $self) = @_;

  my $routes = $self->$orig;
  $routes->{'lookup'} = 'lookup';

  return $routes;
};

# Look up a user by username
# GET /api/users/lookup?username=foo
sub lookup
{
  my ($self, $REQUEST) = @_;

  my $username = $REQUEST->cgi->param('username') || '';
  $username =~ s/^\s+|\s+$//g;

  unless ($username) {
    return [$self->HTTP_OK, { success => 0, error => 'Missing username parameter' }];
  }

  # Look up the user by exact title match
  my $user = $self->DB->getNode($username, 'user');
  unless ($user) {
    return [$self->HTTP_OK, { success => 0, error => "User '$username' not found" }];
  }

  return [$self->HTTP_OK, {
    success => 1,
    user_id => int($user->{node_id}),
    username => $user->{title}
  }];
}

__PACKAGE__->meta->make_immutable;
1;
