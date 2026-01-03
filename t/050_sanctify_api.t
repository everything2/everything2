#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching RequireDotMatchAnything)
## no critic (ValuesAndExpressions ProhibitInterpolationOfLiterals ProhibitMagicNumbers)

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;
use Everything::Application;
use Everything::API::sanctify;

# Declare globals so MockUser can access them
our ($APP, $DB);

# Suppress expected warnings throughout the test
$SIG{__WARN__} = sub {
  my $warning = shift;
  warn $warning unless $warning =~ /Could not open log/
                    || $warning =~ /Use of uninitialized value/;
};

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");

#############################################################################
# Test Sanctify API functionality
#
# These tests verify:
# 1. GET /api/sanctify/status - Get user eligibility
# 2. POST /api/sanctify/give - Sanctify another user
# 3. Level requirements (Level 11+)
# 4. GP requirements (10 GP minimum)
# 5. GPoptout blocking
# 6. Eddie message sending
#############################################################################

# Helper: Create a mock request object
package MockRequest {
  sub new {
    my ($class, %args) = @_;
    return bless \%args, $class;
  }
  sub user { return $_[0]->{user} }
  sub request_method { return $_[0]->{method} // 'GET' }
  sub JSON_POSTDATA { return $_[0]->{postdata} // {} }
}

# Helper: Create a mock user object with VARS support
package MockUser {
  sub new {
    my ($class, %args) = @_;
    my $self = {
      node_id => $args{node_id} // 12345,
      user_id => $args{user_id} // $args{node_id} // 12345,
      title => $args{title} // 'TestUser',
      GP => $args{GP} // 100,
      sanctity => $args{sanctity} // 0,
      is_guest_flag => $args{is_guest_flag} // 0,
      real_user => $args{real_user},
      _vars => $args{vars} // {},
    };
    return bless $self, $class;
  }

  sub NODEDATA {
    my ($self) = @_;
    if ($self->{real_user}) {
      return $self->{real_user};
    }
    return $self;
  }

  sub VARS {
    my ($self) = @_;
    if ($self->{real_user}) {
      return $main::APP->getVars($self->{real_user});
    }
    return $self->{_vars};
  }

  sub set_vars {
    my ($self, $vars) = @_;
    if ($self->{real_user}) {
      my @pairs;
      foreach my $key (keys %$vars) {
        my $value = $vars->{$key};
        push @pairs, "$key=$value" if defined $value;
      }
      my $vars_string = join("\n", @pairs);
      $self->{real_user}->{vars} = $vars_string;
      $main::DB->updateNode($self->{real_user}, -1);
    } else {
      $self->{_vars} = $vars;
    }
  }
}

# Create API instance
my $api = Everything::API::sanctify->new();
ok($api, "Created sanctify API instance");

# Helper: Get normaluser1 and boost experience for level-gated tests
my $test_user = $DB->getNode("normaluser1", "user");
my $original_experience = $test_user->{experience};
my $original_gp = $test_user->{GP};

# Also need to set numwriteups in user vars for level calculation
my $original_vars = $APP->getVars($test_user);
my $original_numwriteups = $original_vars->{numwriteups};

# Helper to ensure test user is at the right level for tests
sub boost_test_user_level {
  my $vars = $APP->getVars($test_user);
  $vars->{numwriteups} = 100;
  delete $vars->{GPoptout};
  Everything::setVars($test_user, $vars);
  $DB->updateNode($test_user, -1);

  # Boost to level 12+ (experience ~50000, numwriteups >= 60)
  $DB->sqlUpdate("user", {experience => 50000}, "user_id = $test_user->{node_id}");

  # Clear cache so re-fetches see updated experience
  $DB->{cache}->removeNode($test_user) if $DB->{cache};
  $test_user = $DB->getNode($test_user->{node_id});
}

# Set up the test user level now
boost_test_user_level();

# Cleanup handler to restore state
END {
  if ($test_user && defined $original_experience && $DB) {
    $DB->sqlUpdate("user", {experience => $original_experience, GP => $original_gp}, "user_id = $test_user->{node_id}");
    my $vars = $APP->getVars($test_user);
    $vars->{numwriteups} = $original_numwriteups;
    delete $vars->{GPoptout};
    Everything::setVars($test_user, $vars);
    $DB->updateNode($test_user, -1);
    $DB->{cache}->removeNode($test_user) if $DB->{cache};
  }
}

#############################################################################
# Test 1: Status endpoint - guest user
#############################################################################
subtest "Status endpoint - guest user" => sub {
  plan tests => 3;

  my $guest = $DB->getNode('Guest User', 'user');

  my $guest_user = MockUser->new(
    node_id => $guest->{node_id},
    user_id => $guest->{user_id},
    title => $guest->{title},
    is_guest_flag => 1,
    GP => 0,
    real_user => $guest
  );

  my $request = MockRequest->new(user => $guest_user);
  my $result = $api->status($request);

  is($result->[0], 200, 'Returns HTTP 200');
  is($result->[1]->{success}, 0, 'Success is 0 for guest');
  like($result->[1]->{error}, qr/logged in/, 'Error mentions logging in');
};

#############################################################################
# Test 2: Status endpoint - logged in user with sufficient level and GP
#############################################################################
subtest "Status endpoint - eligible user" => sub {
  plan tests => 5;

  # Refresh test user and ensure level is set
  $DB->{cache}->removeNode($test_user) if $DB->{cache};
  $test_user = $DB->getNode($test_user->{node_id});
  boost_test_user_level();

  $test_user->{GP} = 100;
  $DB->updateNode($test_user, -1);

  my $user = MockUser->new(
    node_id => $test_user->{node_id},
    user_id => $test_user->{user_id},
    title => $test_user->{title},
    GP => 100,
    real_user => $test_user
  );

  my $request = MockRequest->new(user => $user);
  my $result = $api->status($request);

  is($result->[0], 200, 'Returns HTTP 200');
  is($result->[1]->{success}, 1, 'Success is 1');
  ok($result->[1]->{canSanctify}, 'canSanctify is true');
  is($result->[1]->{sanctifyAmount}, 10, 'sanctifyAmount is 10');
  is($result->[1]->{minLevel}, 11, 'minLevel is 11');
};

#############################################################################
# Test 3: Give - missing recipient
#############################################################################
subtest "Give - missing recipient" => sub {
  plan tests => 2;

  $DB->{cache}->removeNode($test_user) if $DB->{cache};
  $test_user = $DB->getNode($test_user->{node_id});
  boost_test_user_level();

  $test_user->{GP} = 100;
  $DB->updateNode($test_user, -1);

  my $user = MockUser->new(
    node_id => $test_user->{node_id},
    user_id => $test_user->{user_id},
    title => $test_user->{title},
    GP => 100,
    real_user => $test_user
  );

  my $request = MockRequest->new(
    user => $user,
    method => 'POST',
    postdata => {}
  );

  my $result = $api->give($request);

  is($result->[1]->{success}, 0, 'Cannot sanctify without recipient');
  like($result->[1]->{error}, qr/recipient/i, 'Error mentions recipient');
};

#############################################################################
# Test 4: Give - recipient not found
#############################################################################
subtest "Give - recipient not found" => sub {
  plan tests => 2;

  $DB->{cache}->removeNode($test_user) if $DB->{cache};
  $test_user = $DB->getNode($test_user->{node_id});
  boost_test_user_level();

  $test_user->{GP} = 100;
  $DB->updateNode($test_user, -1);

  my $user = MockUser->new(
    node_id => $test_user->{node_id},
    user_id => $test_user->{user_id},
    title => $test_user->{title},
    GP => 100,
    real_user => $test_user
  );

  my $request = MockRequest->new(
    user => $user,
    method => 'POST',
    postdata => { recipient => 'nonexistent_user_xyz123' }
  );

  my $result = $api->give($request);

  is($result->[1]->{success}, 0, 'Cannot sanctify nonexistent user');
  like($result->[1]->{error}, qr/not found/i, 'Error mentions user not found');
};

#############################################################################
# Test 5: Give - cannot sanctify yourself
#############################################################################
subtest "Give - cannot sanctify yourself" => sub {
  plan tests => 2;

  $DB->{cache}->removeNode($test_user) if $DB->{cache};
  $test_user = $DB->getNode($test_user->{node_id});
  boost_test_user_level();

  $test_user->{GP} = 100;
  $DB->updateNode($test_user, -1);

  my $user = MockUser->new(
    node_id => $test_user->{node_id},
    user_id => $test_user->{user_id},
    title => $test_user->{title},
    GP => 100,
    real_user => $test_user
  );

  my $request = MockRequest->new(
    user => $user,
    method => 'POST',
    postdata => { recipient => $test_user->{title} }
  );

  my $result = $api->give($request);

  is($result->[1]->{success}, 0, 'Cannot sanctify yourself');
  like($result->[1]->{error}, qr/yourself/i, 'Error mentions yourself');
};

#############################################################################
# Test 6: Give - insufficient GP
#############################################################################
subtest "Give - insufficient GP" => sub {
  plan tests => 2;

  $DB->{cache}->removeNode($test_user) if $DB->{cache};
  $test_user = $DB->getNode($test_user->{node_id});
  boost_test_user_level();

  $test_user->{GP} = 5;  # Less than 10
  $DB->updateNode($test_user, -1);

  my $user = MockUser->new(
    node_id => $test_user->{node_id},
    user_id => $test_user->{user_id},
    title => $test_user->{title},
    GP => 5,
    real_user => $test_user
  );

  my $request = MockRequest->new(
    user => $user,
    method => 'POST',
    postdata => { recipient => 'genericdev' }
  );

  my $result = $api->give($request);

  is($result->[1]->{success}, 0, 'Cannot sanctify with insufficient GP');
  like($result->[1]->{error}, qr/10 GP/i, 'Error mentions 10 GP requirement');
};

#############################################################################
# Test 7: GPoptout blocks sanctification
#############################################################################
subtest "GPoptout blocks sanctification" => sub {
  plan tests => 2;

  $DB->{cache}->removeNode($test_user) if $DB->{cache};
  $test_user = $DB->getNode($test_user->{node_id});
  boost_test_user_level();

  $test_user->{GP} = 100;
  $DB->updateNode($test_user, -1);

  # Set GPoptout
  my $vars = $APP->getVars($test_user);
  $vars->{GPoptout} = 1;
  Everything::setVars($test_user, $vars);
  $DB->updateNode($test_user, -1);

  my $user = MockUser->new(
    node_id => $test_user->{node_id},
    user_id => $test_user->{user_id},
    title => $test_user->{title},
    GP => 100,
    real_user => $test_user
  );

  my $request = MockRequest->new(
    user => $user,
    method => 'POST',
    postdata => { recipient => 'genericdev' }
  );

  my $result = $api->give($request);

  is($result->[1]->{success}, 0, 'GPoptout blocks sanctification');
  like($result->[1]->{error}, qr/opted out/i, 'Error mentions opted out');

  # Restore GPoptout setting
  delete $vars->{GPoptout};
  Everything::setVars($test_user, $vars);
  $DB->updateNode($test_user, -1);
};

#############################################################################
# Test 8: Successful sanctification
#############################################################################
subtest "Successful sanctification" => sub {
  plan tests => 7;

  $DB->{cache}->removeNode($test_user) if $DB->{cache};
  $test_user = $DB->getNode($test_user->{node_id});
  boost_test_user_level();

  $test_user->{GP} = 100;
  $DB->updateNode($test_user, -1);

  # Get recipient fresh from DB (clear cache to avoid stale data from other tests)
  my $recipient_node = $DB->getNode('genericdev', 'user');
  $DB->{cache}->removeNode($recipient_node) if $DB->{cache} && $recipient_node;
  my $recipient = $DB->getNode('genericdev', 'user');
  my $original_recipient_gp = $recipient->{GP};
  my $original_recipient_sanctity = $recipient->{sanctity} || 0;

  # Record the highest message_id before our action for filtering
  my $max_msg_before = $DB->sqlSelect('MAX(message_id)', 'message') || 0;

  my $user = MockUser->new(
    node_id => $test_user->{node_id},
    user_id => $test_user->{user_id},
    title => $test_user->{title},
    GP => 100,
    real_user => $test_user
  );

  my $request = MockRequest->new(
    user => $user,
    method => 'POST',
    postdata => { recipient => 'genericdev' }
  );

  my $result = $api->give($request);

  is($result->[1]->{success}, 1, 'Sanctification succeeded');
  is($result->[1]->{newGP}, 90, 'GP reduced by 10');
  is($result->[1]->{recipientSanctity}, $original_recipient_sanctity + 1, 'Recipient sanctity incremented');

  # Verify recipient got the GP
  $DB->{cache}->removeNode($recipient) if $DB->{cache};
  $recipient = $DB->getNode($recipient->{node_id});
  is($recipient->{GP}, $original_recipient_gp + 10, 'Recipient GP increased by 10');
  is($recipient->{sanctity}, $original_recipient_sanctity + 1, 'Recipient sanctity field updated');

  # Restore recipient's original values
  $recipient->{GP} = $original_recipient_gp;
  $recipient->{sanctity} = $original_recipient_sanctity;
  $DB->updateNode($recipient, -1);

  # Check for Eddie message created after our action
  my $eddie = $DB->getNode('Cool Man Eddie', 'user');
  my $msg = $DB->sqlSelectHashref('*', 'message',
    "author_user = $eddie->{user_id} AND for_user = $recipient->{user_id} AND message_id > $max_msg_before AND msgtext LIKE '%sanctified%'",
    'ORDER BY message_id DESC LIMIT 1'
  );
  ok($msg, 'Eddie message sent for sanctification');

  # Check for security log entry (logs to "Sanctify user" superdoc)
  # Look for entry that mentions both the sanctifier and the specific recipient (genericdev)
  my $sanctify_node = $DB->getNode('Sanctify user', 'superdoc');
  SKIP: {
    skip 'Sanctify user superdoc not found', 1 unless $sanctify_node;
    my $seclog = $DB->sqlSelectHashref('*', 'seclog',
      "seclog_node = $sanctify_node->{node_id} AND seclog_user = $test_user->{node_id} AND seclog_details LIKE '%genericdev%'",
      'ORDER BY seclog_id DESC LIMIT 1'
    );
    ok($seclog && $seclog->{seclog_details} =~ /sanctified.*genericdev/i, 'Security log entry created for sanctification');
  }

  # Clean up only our message
  $DB->sqlDelete('message', "author_user = $eddie->{user_id} AND for_user = $recipient->{user_id} AND message_id > $max_msg_before");
};

#############################################################################
# Test 9: Anonymous sanctification
#############################################################################
subtest "Anonymous sanctification" => sub {
  plan tests => 3;

  $DB->{cache}->removeNode($test_user) if $DB->{cache};
  $test_user = $DB->getNode($test_user->{node_id});
  boost_test_user_level();

  $test_user->{GP} = 100;
  $DB->updateNode($test_user, -1);

  # Get recipient fresh from DB (clear cache to avoid stale data from other tests)
  my $recipient_node = $DB->getNode('genericdev', 'user');
  $DB->{cache}->removeNode($recipient_node) if $DB->{cache} && $recipient_node;
  my $recipient = $DB->getNode('genericdev', 'user');
  my $original_recipient_gp = $recipient->{GP};
  my $original_recipient_sanctity = $recipient->{sanctity} || 0;

  # Get Eddie for message check
  my $eddie = $DB->getNode('Cool Man Eddie', 'user');

  # Record the highest message_id before our action for filtering
  my $max_msg_before = $DB->sqlSelect('MAX(message_id)', 'message') || 0;

  my $user = MockUser->new(
    node_id => $test_user->{node_id},
    user_id => $test_user->{user_id},
    title => $test_user->{title},
    GP => 100,
    real_user => $test_user
  );

  my $request = MockRequest->new(
    user => $user,
    method => 'POST',
    postdata => { recipient => 'genericdev', anonymous => 1 }
  );

  my $result = $api->give($request);

  is($result->[1]->{success}, 1, 'Anonymous sanctification succeeded');

  # Check Eddie message created after our action does not include sender name
  my $msg = $DB->sqlSelectHashref('*', 'message',
    "author_user = $eddie->{user_id} AND for_user = $recipient->{user_id} AND message_id > $max_msg_before",
    'ORDER BY message_id DESC LIMIT 1'
  );
  ok($msg && $msg->{msgtext} =~ /sanctified\]!$/, 'Anonymous message ends with sanctified]!');
  ok($msg && $msg->{msgtext} !~ /\[$test_user->{title}\]/, 'Anonymous message does not include sender name');

  # Restore recipient's original values
  $recipient->{GP} = $original_recipient_gp;
  $recipient->{sanctity} = $original_recipient_sanctity;
  $DB->updateNode($recipient, -1);

  # Clean up only our message
  $DB->sqlDelete('message', "author_user = $eddie->{user_id} AND for_user = $recipient->{user_id} AND message_id > $max_msg_before");
};

#############################################################################
# Test 10: Route dispatch
#############################################################################
subtest "Route dispatch" => sub {
  plan tests => 2;

  my $user = MockUser->new(
    node_id => $test_user->{node_id},
    user_id => $test_user->{user_id},
    title => $test_user->{title},
    real_user => $test_user
  );

  my $request = MockRequest->new(
    user => $user,
    method => 'GET'
  );

  # Test unknown route
  my $result = $api->route($request, 'unknown');
  is($result->[0], 404, 'Unknown route returns 404');

  # Test status route
  $result = $api->route($request, 'status');
  is($result->[0], 200, 'Status route returns 200');
};

done_testing();
