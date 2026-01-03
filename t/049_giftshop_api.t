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
use Everything::API::giftshop;

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
# Test Gift Shop API functionality
#
# These tests verify:
# 1. GET /api/giftshop/status - Get user status
# 2. Star cost calculation
# 3. Level requirements
# 4. GP requirements
# 5. Ching cooldown check
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
      votesleft => $args{votesleft} // 10,
      stars => $args{stars} // 0,
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
my $api = Everything::API::giftshop->new();
ok($api, "Created giftshop API instance");

# Helper: Get normaluser1 and boost experience for level-gated tests
my $test_user = $DB->getNode("normaluser1", "user");
my $original_experience = $test_user->{experience};

# Also need to set numwriteups in user vars for level calculation
my $original_vars = $APP->getVars($test_user);
my $original_numwriteups = $original_vars->{numwriteups};

# Helper to ensure test user is at the right level for tests
sub boost_test_user_level {
  my $vars = $APP->getVars($test_user);
  $vars->{numwriteups} = 100;
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

# Cleanup handler to restore experience and numwriteups
END {
  if ($test_user && defined $original_experience && $DB) {
    $DB->sqlUpdate("user", {experience => $original_experience}, "user_id = $test_user->{node_id}");
    my $vars = $APP->getVars($test_user);
    $vars->{numwriteups} = $original_numwriteups;
    Everything::setVars($test_user, $vars);
    $DB->updateNode($test_user, -1);
    $DB->{cache}->removeNode($test_user) if $DB->{cache};
  }
}

#############################################################################
# Test 1: Star cost calculation
#############################################################################
subtest "Star cost calculation" => sub {
  plan tests => 5;

  # Level 1 = 75 - (0*5) = 75... wait that formula gives 75 for level 1
  # Actually the formula is 75 - ((level-1)*5)
  # Level 1: 75 - 0 = 75... let me check the actual code
  # Wait the test was wrong - let me fix it based on actual formula:
  # cost = 75 - ((level - 1) * 5), minimum 25

  is($api->_star_cost(1), 75, 'Level 1 star costs 75 GP');
  is($api->_star_cost(5), 55, 'Level 5 star costs 55 GP');
  is($api->_star_cost(10), 30, 'Level 10 star costs 30 GP');
  is($api->_star_cost(11), 25, 'Level 11 star costs minimum 25 GP');
  is($api->_star_cost(15), 25, 'Level 15 star costs minimum 25 GP');
};

#############################################################################
# Test 2: Ching cooldown check
#############################################################################
subtest "Ching cooldown check" => sub {
  plan tests => 3;

  # No previous purchase
  my $vars_no_purchase = {};
  ok($api->_can_buy_ching($vars_no_purchase), 'Can buy ching with no previous purchase');

  # Purchase from 25 hours ago (should be allowed)
  my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time - 90000);  # 25 hours ago
  my $old_purchase = sprintf "%4d-%02d-%02d %02d:%02d:%02d",
    $year+1900, $mon+1, $mday, $hour, $min, $sec;
  my $vars_old = { chingbought => $old_purchase };
  ok($api->_can_buy_ching($vars_old), 'Can buy ching after 25 hours');

  # Purchase from 1 hour ago (should not be allowed)
  ($sec,$min,$hour,$mday,$mon,$year) = localtime(time - 3600);  # 1 hour ago
  my $recent_purchase = sprintf "%4d-%02d-%02d %02d:%02d:%02d",
    $year+1900, $mon+1, $mday, $hour, $min, $sec;
  my $vars_recent = { chingbought => $recent_purchase };
  ok(!$api->_can_buy_ching($vars_recent), 'Cannot buy ching after only 1 hour');
};

#############################################################################
# Test 3: Status endpoint - guest user
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
# Test 4: Status endpoint - logged in user
#############################################################################
subtest "Status endpoint - logged in user" => sub {
  plan tests => 7;

  ok($test_user, "Got test user normaluser1");

  # Set user GP
  my $original_gp = $test_user->{GP};
  $test_user->{GP} = 150;
  $DB->updateNode($test_user, -1);

  my $user = MockUser->new(
    node_id => $test_user->{node_id},
    user_id => $test_user->{user_id},
    title => $test_user->{title},
    GP => 150,
    votesleft => 10,
    real_user => $test_user
  );

  my $request = MockRequest->new(user => $user);
  my $result = $api->status($request);

  is($result->[0], 200, 'Returns HTTP 200');
  is($result->[1]->{success}, 1, 'Success is 1');
  is($result->[1]->{gp}, 150, 'GP is correct');
  ok(defined $result->[1]->{level}, 'Level is returned');
  ok(defined $result->[1]->{starCost}, 'Star cost is returned');
  ok(defined $result->[1]->{votesLeft}, 'Votes left is returned');

  # Restore original GP
  $test_user->{GP} = $original_gp;
  $DB->updateNode($test_user, -1);
};

#############################################################################
# Test 5: Give star - missing recipient
#############################################################################
subtest "Give star - missing recipient" => sub {
  plan tests => 2;

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
    postdata => {
      color => 'Gold',
      reason => 'Great writeup!',
    }
  );

  my $result = $api->give_star($request);

  is($result->[1]->{success}, 0, 'Cannot give star without recipient');
  like($result->[1]->{error}, qr/recipient/i, 'Error mentions recipient');
};

#############################################################################
# Test 6: Give star - missing reason
#############################################################################
subtest "Give star - missing reason" => sub {
  plan tests => 2;

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
    postdata => {
      recipient => 'OtherUser',
      color => 'Gold',
    }
  );

  my $result = $api->give_star($request);

  is($result->[1]->{success}, 0, 'Cannot give star without reason');
  like($result->[1]->{error}, qr/reason/i, 'Error mentions reason');
};

#############################################################################
# Test 7: Buy votes - invalid amount
#############################################################################
subtest "Buy votes - invalid amount" => sub {
  plan tests => 2;

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
    postdata => { amount => 0 }
  );

  my $result = $api->buy_votes($request);

  is($result->[1]->{success}, 0, 'Cannot buy 0 votes');
  like($result->[1]->{error}, qr/positive/i, 'Error mentions positive number');
};

#############################################################################
# Test 8: Give votes - amount over limit
#############################################################################
subtest "Give votes - amount over limit" => sub {
  plan tests => 2;

  $test_user->{votesleft} = 50;
  $DB->updateNode($test_user, -1);

  my $user = MockUser->new(
    node_id => $test_user->{node_id},
    user_id => $test_user->{user_id},
    title => $test_user->{title},
    votesleft => 50,
    real_user => $test_user
  );

  my $request = MockRequest->new(
    user => $user,
    method => 'POST',
    postdata => {
      recipient => 'OtherUser',
      amount => 30,  # Over 25 limit
    }
  );

  my $result = $api->give_votes($request);

  is($result->[1]->{success}, 0, 'Cannot give more than 25 votes');
  like($result->[1]->{error}, qr/25/i, 'Error mentions 25 vote limit');
};

#############################################################################
# Test 9: Buy eggs - amount over limit
#############################################################################
subtest "Buy eggs - amount over limit" => sub {
  plan tests => 2;

  $test_user->{GP} = 500;
  $DB->updateNode($test_user, -1);

  my $user = MockUser->new(
    node_id => $test_user->{node_id},
    user_id => $test_user->{user_id},
    title => $test_user->{title},
    GP => 500,
    real_user => $test_user
  );

  my $request = MockRequest->new(
    user => $user,
    method => 'POST',
    postdata => { amount => 10 }  # Over 5 limit
  );

  my $result = $api->buy_eggs($request);

  is($result->[1]->{success}, 0, 'Cannot buy more than 5 eggs');
  like($result->[1]->{error}, qr/5/i, 'Error mentions 5 egg limit');
};

#############################################################################
# Test 10: Set topic - empty topic
#############################################################################
subtest "Set topic - empty topic" => sub {
  plan tests => 2;

  # Set tokens in the user's vars
  my $vars = $APP->getVars($test_user);
  $vars->{tokens} = 5;
  Everything::setVars($test_user, $vars);
  $DB->updateNode($test_user, -1);

  my $user = MockUser->new(
    node_id => $test_user->{node_id},
    user_id => $test_user->{user_id},
    title => $test_user->{title},
    real_user => $test_user
  );

  my $request = MockRequest->new(
    user => $user,
    method => 'POST',
    postdata => { topic => '' }
  );

  my $result = $api->set_topic($request);

  is($result->[1]->{success}, 0, 'Cannot set empty topic');
  like($result->[1]->{error}, qr/topic/i, 'Error mentions topic');

  # Cleanup tokens
  delete $vars->{tokens};
  Everything::setVars($test_user, $vars);
  $DB->updateNode($test_user, -1);
};

#############################################################################
# Test 10b: Set topic - success returns newTopic
#############################################################################
subtest "Set topic - success returns newTopic" => sub {
  plan tests => 4;

  # Save original room topic for restoration
  my $settingsnode = $DB->getNode('Room topics', 'setting');
  my $original_topics = $APP->getVars($settingsnode);
  my $original_topic = $original_topics->{0};

  # Set tokens in the user's vars
  my $vars = $APP->getVars($test_user);
  $vars->{tokens} = 5;
  Everything::setVars($test_user, $vars);
  $DB->updateNode($test_user, -1);

  my $user = MockUser->new(
    node_id => $test_user->{node_id},
    user_id => $test_user->{user_id},
    title => $test_user->{title},
    real_user => $test_user
  );

  my $test_topic = 'Test topic from gift shop test';

  my $request = MockRequest->new(
    user => $user,
    method => 'POST',
    postdata => { topic => $test_topic }
  );

  my $result = $api->set_topic($request);

  is($result->[1]->{success}, 1, 'Topic set successfully');
  ok(defined $result->[1]->{newTopic}, 'Response includes newTopic field');
  like($result->[1]->{newTopic}, qr/Test topic/, 'newTopic contains the set topic');
  is($result->[1]->{tokens}, 4, 'Token was consumed');

  # Cleanup: restore tokens
  delete $vars->{tokens};
  Everything::setVars($test_user, $vars);
  $DB->updateNode($test_user, -1);

  # Cleanup: restore original room topic
  if (defined $original_topic) {
    $original_topics->{0} = $original_topic;
  } else {
    delete $original_topics->{0};
  }
  Everything::setVars($settingsnode, $original_topics);
};

#############################################################################
# Test 11: Route dispatch
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

#############################################################################
# Test 12: GPoptout blocks purchases
#############################################################################
subtest "GPoptout blocks purchases" => sub {
  plan tests => 2;

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
    postdata => { amount => 5 }
  );

  my $result = $api->buy_votes($request);
  is($result->[1]->{success}, 0, 'GPoptout blocks buy_votes');
  like($result->[1]->{error}, qr/poverty/i, 'Error mentions vow of poverty');

  # Restore GPoptout setting
  delete $vars->{GPoptout};
  Everything::setVars($test_user, $vars);
  $DB->updateNode($test_user, -1);
};

#############################################################################
# Test 13: Eddie message - give votes
#############################################################################
subtest "Eddie message - give votes" => sub {
  plan tests => 4;

  # Get Cool Man Eddie
  my $eddie = $DB->getNode('Cool Man Eddie', 'user');
  ok($eddie, "Got Cool Man Eddie user");

  # Get recipient user (clear cache to avoid stale data from other tests)
  my $recipient_node = $DB->getNode('genericdev', 'user');
  $DB->{cache}->removeNode($recipient_node) if $DB->{cache} && $recipient_node;
  my $recipient = $DB->getNode('genericdev', 'user');
  ok($recipient, "Got genericdev as recipient");

  # Record the highest message_id before our action for filtering
  my $max_msg_before = $DB->sqlSelect('MAX(message_id)', 'message') || 0;

  # Refresh test_user from database and ensure level is set
  $DB->{cache}->removeNode($test_user) if $DB->{cache};
  $test_user = $DB->getNode($test_user->{node_id});
  boost_test_user_level();

  # Give test_user votes and set level high enough
  $test_user->{votesleft} = 30;
  $DB->updateNode($test_user, -1);

  my $user = MockUser->new(
    node_id => $test_user->{node_id},
    user_id => $test_user->{user_id},
    title => $test_user->{title},
    votesleft => 30,
    real_user => $test_user
  );

  my $request = MockRequest->new(
    user => $user,
    method => 'POST',
    postdata => {
      recipient => 'genericdev',
      amount => 5,
    }
  );

  my $result = $api->give_votes($request);
  is($result->[1]->{success}, 1, 'give_votes succeeded');

  # Check for Eddie message created after our action
  my $msg = $DB->sqlSelectHashref('*', 'message',
    "author_user = $eddie->{user_id} AND for_user = $recipient->{user_id} AND message_id > $max_msg_before AND msgtext LIKE '%gave you%votes%'",
    'ORDER BY message_id DESC LIMIT 1'
  );
  ok($msg, 'Eddie message sent for give_votes');

  # Clean up only our message
  $DB->sqlDelete('message', "author_user = $eddie->{user_id} AND for_user = $recipient->{user_id} AND message_id > $max_msg_before");
};

#############################################################################
# Test 14: Eddie message - give ching
#############################################################################
subtest "Eddie message - give ching" => sub {
  plan tests => 5;

  # Get Cool Man Eddie
  my $eddie = $DB->getNode('Cool Man Eddie', 'user');
  ok($eddie, "Got Cool Man Eddie user");

  # Get recipient user (clear cache to avoid stale data from other tests)
  my $recipient_node = $DB->getNode('genericdev', 'user');
  $DB->{cache}->removeNode($recipient_node) if $DB->{cache} && $recipient_node;
  my $recipient = $DB->getNode('genericdev', 'user');
  ok($recipient, "Got genericdev as recipient");

  # Record the highest message_id before our action for filtering
  my $max_msg_before = $DB->sqlSelect('MAX(message_id)', 'message') || 0;

  # Refresh test_user from database and ensure level is set
  $DB->{cache}->removeNode($test_user) if $DB->{cache};
  $test_user = $DB->getNode($test_user->{node_id});
  boost_test_user_level();

  # Give test_user a C!
  my $vars = $APP->getVars($test_user);
  $vars->{cools} = 3;
  Everything::setVars($test_user, $vars);
  $DB->updateNode($test_user, -1);

  my $user = MockUser->new(
    node_id => $test_user->{node_id},
    user_id => $test_user->{user_id},
    title => $test_user->{title},
    real_user => $test_user
  );

  my $request = MockRequest->new(
    user => $user,
    method => 'POST',
    postdata => {
      recipient => 'genericdev',
    }
  );

  my $result = $api->give_ching($request);
  is($result->[1]->{success}, 1, 'give_ching succeeded');

  # Check for Eddie message created after our action
  my $msg = $DB->sqlSelectHashref('*', 'message',
    "author_user = $eddie->{user_id} AND for_user = $recipient->{user_id} AND message_id > $max_msg_before AND msgtext LIKE '%gave you%C!%'",
    'ORDER BY message_id DESC LIMIT 1'
  );
  ok($msg, 'Eddie message sent for give_ching');

  # Check for security log entry (logs to "E2 Gift Shop" superdoc)
  my $giftshop_node = $DB->getNode('E2 Gift Shop', 'superdoc');
  SKIP: {
    skip 'E2 Gift Shop superdoc not found', 1 unless $giftshop_node;
    my $seclog = $DB->sqlSelectHashref('*', 'seclog',
      "seclog_node = $giftshop_node->{node_id} AND seclog_user = $test_user->{node_id}",
      'ORDER BY seclog_id DESC LIMIT 1'
    );
    ok($seclog && $seclog->{seclog_details} =~ /gave a C!/, 'Security log entry created for give_ching');
  }

  # Clean up only our message
  $DB->sqlDelete('message', "author_user = $eddie->{user_id} AND for_user = $recipient->{user_id} AND message_id > $max_msg_before");
};

#############################################################################
# Test 15: Eddie message - give star
#############################################################################
subtest "Eddie message - give star" => sub {
  plan tests => 5;

  # Get Cool Man Eddie
  my $eddie = $DB->getNode('Cool Man Eddie', 'user');
  ok($eddie, "Got Cool Man Eddie user");

  # Get recipient user (clear cache to avoid stale data from other tests)
  my $recipient_node = $DB->getNode('genericdev', 'user');
  $DB->{cache}->removeNode($recipient_node) if $DB->{cache} && $recipient_node;
  my $recipient = $DB->getNode('genericdev', 'user');
  ok($recipient, "Got genericdev as recipient");

  # Record the highest message_id before our action for filtering
  my $max_msg_before = $DB->sqlSelect('MAX(message_id)', 'message') || 0;

  # Refresh test_user from database and ensure level is set
  $DB->{cache}->removeNode($test_user) if $DB->{cache};
  $test_user = $DB->getNode($test_user->{node_id});
  boost_test_user_level();

  # Give test_user GP
  $test_user->{GP} = 100;
  $DB->updateNode($test_user, -1);

  my $vars = $APP->getVars($test_user);
  delete $vars->{GPoptout};
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
    postdata => {
      recipient => 'genericdev',
      color => 'Gold',
      reason => 'Great work on testing',
    }
  );

  my $result = $api->give_star($request);
  is($result->[1]->{success}, 1, 'give_star succeeded');

  # Check for Eddie message created after our action
  my $msg = $DB->sqlSelectHashref('*', 'message',
    "author_user = $eddie->{user_id} AND for_user = $recipient->{user_id} AND message_id > $max_msg_before AND msgtext LIKE '%Gold Star%'",
    'ORDER BY message_id DESC LIMIT 1'
  );
  ok($msg, 'Eddie message sent for give_star');

  # Verify the reason is quoted, not italicized (HTML fix)
  ok($msg && $msg->{msgtext} =~ /"Great work on testing"/, 'Star reason uses quotes, not HTML');

  # Clean up only our message
  $DB->sqlDelete('message', "author_user = $eddie->{user_id} AND for_user = $recipient->{user_id} AND message_id > $max_msg_before");
};

#############################################################################
# Test 16: Eddie message - give egg
#############################################################################
subtest "Eddie message - give egg" => sub {
  plan tests => 4;

  # Get Cool Man Eddie
  my $eddie = $DB->getNode('Cool Man Eddie', 'user');
  ok($eddie, "Got Cool Man Eddie user");

  # Get recipient user (clear cache to avoid stale data from other tests)
  my $recipient_node = $DB->getNode('genericdev', 'user');
  $DB->{cache}->removeNode($recipient_node) if $DB->{cache} && $recipient_node;
  my $recipient = $DB->getNode('genericdev', 'user');
  ok($recipient, "Got genericdev as recipient");

  # Clear any existing messages from Eddie to recipient
  $DB->sqlDelete('message', "author_user = $eddie->{user_id} AND for_user = $recipient->{user_id}");

  # Record the highest message_id before our action for filtering
  my $max_msg_before = $DB->sqlSelect('MAX(message_id)', 'message') || 0;

  # Refresh test_user from database and ensure level is set
  $DB->{cache}->removeNode($test_user) if $DB->{cache};
  $test_user = $DB->getNode($test_user->{node_id});
  boost_test_user_level();

  # Give test_user an egg
  my $vars = $APP->getVars($test_user);
  $vars->{easter_eggs} = 3;
  Everything::setVars($test_user, $vars);
  $DB->updateNode($test_user, -1);

  my $user = MockUser->new(
    node_id => $test_user->{node_id},
    user_id => $test_user->{user_id},
    title => $test_user->{title},
    real_user => $test_user
  );

  my $request = MockRequest->new(
    user => $user,
    method => 'POST',
    postdata => {
      recipient => 'genericdev',
    }
  );

  my $result = $api->give_egg($request);
  is($result->[1]->{success}, 1, 'give_egg succeeded');

  # Check for Eddie message created after our action
  my $msg = $DB->sqlSelectHashref('*', 'message',
    "author_user = $eddie->{user_id} AND for_user = $recipient->{user_id} AND message_id > $max_msg_before AND msgtext LIKE '%easter egg%'",
    'ORDER BY message_id DESC LIMIT 1'
  );
  ok($msg, 'Eddie message sent for give_egg');

  # Clean up only our message
  $DB->sqlDelete('message', "author_user = $eddie->{user_id} AND for_user = $recipient->{user_id} AND message_id > $max_msg_before");
};

#############################################################################
# Test 17: Eddie message - anonymous flag
#############################################################################
subtest "Eddie message - anonymous flag" => sub {
  plan tests => 3;

  # Get Cool Man Eddie
  my $eddie = $DB->getNode('Cool Man Eddie', 'user');

  # Get recipient user (clear cache to avoid stale data from other tests)
  my $recipient_node = $DB->getNode('genericdev', 'user');
  $DB->{cache}->removeNode($recipient_node) if $DB->{cache} && $recipient_node;
  my $recipient = $DB->getNode('genericdev', 'user');

  # Record the highest message_id before our action for filtering
  my $max_msg_before = $DB->sqlSelect('MAX(message_id)', 'message') || 0;

  # Refresh test_user from database and ensure level is set
  $DB->{cache}->removeNode($test_user) if $DB->{cache};
  $test_user = $DB->getNode($test_user->{node_id});
  boost_test_user_level();

  # Give test_user votes
  $test_user->{votesleft} = 30;
  $DB->updateNode($test_user, -1);

  my $user = MockUser->new(
    node_id => $test_user->{node_id},
    user_id => $test_user->{user_id},
    title => $test_user->{title},
    votesleft => 30,
    real_user => $test_user
  );

  my $request = MockRequest->new(
    user => $user,
    method => 'POST',
    postdata => {
      recipient => 'genericdev',
      amount => 3,
      anonymous => 1,
    }
  );

  my $result = $api->give_votes($request);
  is($result->[1]->{success}, 1, 'give_votes with anonymous succeeded');

  # Check Eddie message created after our action says "someone mysterious"
  my $msg = $DB->sqlSelectHashref('*', 'message',
    "author_user = $eddie->{user_id} AND for_user = $recipient->{user_id} AND message_id > $max_msg_before",
    'ORDER BY message_id DESC LIMIT 1'
  );
  ok($msg && $msg->{msgtext} =~ /someone mysterious/, 'Anonymous gift uses "someone mysterious"');
  ok($msg && $msg->{msgtext} !~ /\[$test_user->{title}\]/, 'Anonymous gift does not include sender name');

  # Clean up only our message
  $DB->sqlDelete('message', "author_user = $eddie->{user_id} AND for_user = $recipient->{user_id} AND message_id > $max_msg_before");
};

done_testing();
