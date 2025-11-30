package Everything::API::teddybear;

use Moose;
extends 'Everything::API';

sub routes
{
  return {
    "hug" => "hug"
  }
}

=head1 Everything::API::teddybear

API for Giant Teddy Bear Suit - allows admins to hug users with GP grants.

Migrated from document.pm giant_teddy_bear_suit() delegation function.

=head2 hug

Grant GP to users via Giant Teddy Bear hug.

POST /api/teddybear/hug
{
  "usernames": ["user1", "user2", "user3"]
}

Returns:
{
  "success": true,
  "results": [
    {"username": "user1", "granted": 2, "message": "User user1 was given 2 GP"},
    {"username": "user2", "granted": 2, "message": "User user2 was given 2 GP"}
  ],
  "errors": []
}

=cut

sub hug
{
  my ($self, $REQUEST) = @_;

  my $USER = $REQUEST->user->NODEDATA;
  my $APP = $self->APP;
  my $DB = $self->DB;

  # Only admins can use the Giant Teddy Bear Suit
  unless ($APP->isAdmin($USER)) {
    return [$self->HTTP_FORBIDDEN, {
      error => 'Hands off the bear, bobo.',
      message => 'Only administrators can use the Giant Teddy Bear Suit'
    }];
  }

  my $data = $REQUEST->JSON_POSTDATA;
  my $usernames = $data->{usernames} || [];

  unless (@$usernames) {
    return [$self->HTTP_BAD_REQUEST, {
      error => 'No usernames provided',
      message => 'Please provide an array of usernames to hug'
    }];
  }

  # Giant Teddy Bear grants fixed 2 GP per hug
  my $gp_amount = 2;

  my @results;
  my @errors;

  # Get Giant Teddy Bear user for chatbox messages
  my $teddy_bear_user = $DB->getNode('Giant Teddy Bear', 'user');
  my $teddy_bear_id = $teddy_bear_user ? $teddy_bear_user->{node_id} : undef;

  foreach my $username (@$usernames) {
    next unless $username;  # Skip empty entries

    my $target_user = $DB->getNode($username, 'user');

    if (!$target_user) {
      push @errors, {
        username => $username,
        error => "User not found: $username"
      };
      next;
    }

    # Post hug message to public chatter
    if ($teddy_bear_id) {
      $DB->sqlInsert('message', {
        msgtext => '/me hugs ' . $target_user->{title},
        author_user => $teddy_bear_id,
        for_user => 0,  # 0 is public
        room => $USER->{in_room} || 0  # Default to outside
      });
    }

    # Grant GP
    $APP->adjustGP($target_user, $gp_amount);

    # Increase karma
    $target_user->{karma} += 1;
    $DB->updateNode($target_user, -1);

    # Security log
    $APP->securityLog(
      $DB->getNode('Superbless', 'superdoc'),
      $USER,
      "$USER->{title} hugged $target_user->{title} using the [Giant Teddy Bear suit] for $gp_amount GP."
    );

    # Check for karma achievements
    $APP->checkAchievementsByType('karma', $target_user->{user_id});

    push @results, {
      username => $target_user->{title},
      granted => $gp_amount,
      message => "User $target_user->{title} was given $gp_amount GP"
    };
  }

  return [$self->HTTP_OK, {
    success => 1,
    results => \@results,
    errors => \@errors
  }];
}

__PACKAGE__->meta->make_immutable;
1;
