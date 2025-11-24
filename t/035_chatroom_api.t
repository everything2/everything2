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
use Everything::API::chatroom;

# Suppress expected warnings throughout the test
$SIG{__WARN__} = sub {
	my $warning = shift;
	warn $warning unless $warning =~ /Could not open log/
	                  || $warning =~ /Use of uninitialized value/;
};

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

# Get or create test users
my $admin_user = $DB->getNode('root', 'user');
my $test_user = $DB->getNode('guest user', 'user');

ok($admin_user, 'Found admin user (root)');
ok($test_user, 'Found test user (guest user)');

# Helper: Create a mock request object
package MockRequest {
    sub new {
        my ($class, %args) = @_;
        return bless \%args, $class;
    }
    sub user { return $_[0]->{user} }
    sub is_guest { return $_[0]->{user}->is_guest }
    sub POSTDATA {
        my $self = shift;
        return undef unless $self->{_postdata};
        require JSON;
        return JSON->new->encode($self->{_postdata});
    }
    sub JSON_POSTDATA { return $_[0]->{_postdata} }
}

# Helper: Create a mock user object (Everything::Node::user-like)
# This blesses an existing node hashref and adds methods for the API
package MockUser {
    sub new {
        my ($class, %args) = @_;

        # If we have a real_node, bless it directly so DB operations work
        if ($args{real_node}) {
            my $self = $args{real_node};
            bless $self, $class;
            # Store override flags for testing
            $self->{_is_guest_override} = $args{is_guest_flag} if exists $args{is_guest_flag};
            $self->{_is_admin_override} = $args{is_admin_flag} if exists $args{is_admin_flag};
            $self->{_is_chanop_override} = $args{is_chanop_flag} if exists $args{is_chanop_flag};
            $self->{_level_override} = $args{level} if exists $args{level};
            return $self;
        }

        # For guest tests without real_node, create minimal mock
        my $self = {
            node_id => $args{node_id},
            title => $args{title},
            is_guest_flag => $args{is_guest_flag} // 0,
            is_admin_flag => $args{is_admin_flag} // 0,
            is_chanop_flag => $args{is_chanop_flag} // 0,
            level => $args{level} // 0,
        };
        return bless $self, $class;
    }
    sub node_id { return $_[0]->{node_id} }
    sub title { return $_[0]->{title} }
    sub is_guest { return exists $_[0]->{_is_guest_override} ? $_[0]->{_is_guest_override} : ($_[0]->{is_guest_flag} // 0) }
    sub is_admin { return exists $_[0]->{_is_admin_override} ? $_[0]->{_is_admin_override} : ($_[0]->{is_admin_flag} // 0) }
    sub is_chanop { return exists $_[0]->{_is_chanop_override} ? $_[0]->{_is_chanop_override} : ($_[0]->{is_chanop_flag} // 0) }
    sub level { return exists $_[0]->{_level_override} ? $_[0]->{_level_override} : ($_[0]->{level} // 0) }
    sub NODEDATA { return $_[0] }  # Return self as NODEDATA for blessed node
}

package main;

# Create a test room for testing
my $room_type = $DB->getType('room');
my $test_room_title = 'Test Room ' . time();
my $test_room_id = $DB->insertNode($test_room_title, $room_type, $admin_user, {
  roomlocked => 0,
  doctext => 'A test room for API testing'
}, 'skip maintenance');

ok($test_room_id, 'Created test room');

# Get the full node object
my $test_room = $DB->getNodeById($test_room_id);

# Add test room to e2 rooms group
my $rooms_group = $DB->getNode('e2 rooms', 'nodegroup');
if ($rooms_group) {
  push @{$rooms_group->{group}}, $test_room->{node_id};
  $DB->updateNode($rooms_group, -1);
}

# Create API instance
my $api = Everything::API::chatroom->new();
ok($api, 'Created chatroom API instance');

# Test 1: Change room - Unauthorized (guest)
subtest 'Change room - Unauthorized guest user' => sub {
  plan tests => 2;

  my $mock_user = MockUser->new(
    node_id => $test_user->{node_id},
    title => $test_user->{title},
    is_guest_flag => 1,
  );

  my $mock_request = MockRequest->new(
    user => $mock_user,
    _postdata => {
      room_id => $test_room->{node_id}
    }
  );

  my $result = $api->change_room($mock_request);

  is($result->[0], 401, 'Returns 401 Unauthorized');
  ok(!defined($result->[1]), 'Returns no data (handled by around modifier)');
};

# Test 2: Change room - Success
subtest 'Change room - Successful room change' => sub {
  plan tests => 5;

  # MockUser with real_node for DB operations
  my $mock_user = MockUser->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_admin_flag => 1,
    real_node => $admin_user,
  );

  my $mock_request = MockRequest->new(
    user => $mock_user,
    _postdata => {
      room_id => $test_room->{node_id}
    }
  );

  my $result = $api->change_room($mock_request);

  is($result->[0], 200, 'Returns 200 OK');
  ok($result->[1]{success}, 'Successfully changed rooms');
  is($result->[1]{room_id}, $test_room->{node_id}, 'Returned correct room ID');
  is($result->[1]{room_title}, $test_room->{title}, 'Returned correct room title');
  like($result->[1]{message}, qr/Changed to room/, 'Success message included');
};

# Test 3: Change room - Change to "outside" (room 0)
subtest 'Change room - Change to outside' => sub {
  plan tests => 4;

  my $mock_user = MockUser->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_admin_flag => 1,
    real_node => $admin_user,
  );

  my $mock_request = MockRequest->new(
    user => $mock_user,
    _postdata => {
      room_id => 0
    }
  );

  my $result = $api->change_room($mock_request);

  is($result->[0], 200, 'Returns 200 OK');
  ok($result->[1]{success}, 'Successfully changed to outside');
  is($result->[1]{room_id}, 0, 'Room ID is 0');
  is($result->[1]{room_title}, 'outside', 'Room title is outside');
};

# Test 4: Change room - Invalid room ID
subtest 'Change room - Invalid room ID' => sub {
  plan tests => 2;

  my $mock_user = MockUser->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_admin_flag => 1,
    real_node => $admin_user,
  );

  my $mock_request = MockRequest->new(
    user => $mock_user,
    _postdata => {
      room_id => 999999999
    }
  );

  my $result = $api->change_room($mock_request);

  is($result->[0], 404, 'Returns 404 Not Found');
  like($result->[1]{error}, qr/Room not found/, 'Returns appropriate error message');
};

# Test 5: Change room - Missing room_id parameter
subtest 'Change room - Missing room_id' => sub {
  plan tests => 2;

  my $mock_user = MockUser->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_admin_flag => 1,
    real_node => $admin_user,
  );

  my $mock_request = MockRequest->new(
    user => $mock_user,
    _postdata => {}
  );

  my $result = $api->change_room($mock_request);

  is($result->[0], 400, 'Returns 400 Bad Request');
  like($result->[1]{error}, qr/room_id is required/, 'Returns appropriate error message');
};

# Test 6: Set cloaked - Unauthorized (guest)
subtest 'Set cloaked - Unauthorized guest user' => sub {
  plan tests => 2;

  my $mock_user = MockUser->new(
    node_id => $test_user->{node_id},
    title => $test_user->{title},
    is_guest_flag => 1,
  );

  my $mock_request = MockRequest->new(
    user => $mock_user,
    _postdata => {
      cloaked => 1
    }
  );

  my $result = $api->set_cloaked($mock_request);

  is($result->[0], 401, 'Returns 401 Unauthorized');
  ok(!defined($result->[1]), 'Returns no data (handled by around modifier)');
};

# Test 7: Set cloaked - Success (cloak)
subtest 'Set cloaked - Successfully cloak' => sub {
  plan tests => 4;

  my $mock_user = MockUser->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_admin_flag => 1,
    real_node => $admin_user,
  );

  my $mock_request = MockRequest->new(
    user => $mock_user,
    _postdata => {
      cloaked => 1
    }
  );

  my $result = $api->set_cloaked($mock_request);

  is($result->[0], 200, 'Returns 200 OK');
  ok($result->[1]{success}, 'Successfully cloaked');
  is($result->[1]{cloaked}, 1, 'Cloaked status is 1');
  like($result->[1]{message}, qr/now cloaked/, 'Success message included');
};

# Test 8: Set cloaked - Success (uncloak)
subtest 'Set cloaked - Successfully uncloak' => sub {
  plan tests => 4;

  my $mock_user = MockUser->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_admin_flag => 1,
    real_node => $admin_user,
  );

  my $mock_request = MockRequest->new(
    user => $mock_user,
    _postdata => {
      cloaked => 0
    }
  );

  my $result = $api->set_cloaked($mock_request);

  is($result->[0], 200, 'Returns 200 OK');
  ok($result->[1]{success}, 'Successfully uncloaked');
  is($result->[1]{cloaked}, 0, 'Cloaked status is 0');
  like($result->[1]{message}, qr/now visible/, 'Success message included');
};

# Test 9: Set cloaked - Missing cloaked parameter
subtest 'Set cloaked - Missing cloaked parameter' => sub {
  plan tests => 2;

  my $mock_user = MockUser->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_admin_flag => 1,
    real_node => $admin_user,
  );

  my $mock_request = MockRequest->new(
    user => $mock_user,
    _postdata => {}
  );

  my $result = $api->set_cloaked($mock_request);

  is($result->[0], 400, 'Returns 400 Bad Request');
  like($result->[1]{error}, qr/cloaked parameter is required/, 'Returns appropriate error message');
};

# Test 10: Create room - Unauthorized (guest)
subtest 'Create room - Unauthorized guest user' => sub {
  plan tests => 2;

  my $mock_user = MockUser->new(
    node_id => $test_user->{node_id},
    title => $test_user->{title},
    is_guest_flag => 1,
  );

  my $mock_request = MockRequest->new(
    user => $mock_user,
    _postdata => {
      room_title => 'Guest Room',
      room_doctext => 'Should not be created'
    }
  );

  my $result = $api->create_room($mock_request);

  is($result->[0], 401, 'Returns 401 Unauthorized');
  ok(!defined($result->[1]), 'Returns no data (handled by around modifier)');
};

# Test 11: Create room - Success
subtest 'Create room - Successful creation' => sub {
  plan tests => 5;

  my $mock_user = MockUser->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_admin_flag => 1,
    level => 99,
    real_node => $admin_user,
  );

  my $unique_title = 'New Test Room ' . time();
  my $mock_request = MockRequest->new(
    user => $mock_user,
    _postdata => {
      room_title => $unique_title,
      room_doctext => 'A brand new test room'
    }
  );

  my $result = $api->create_room($mock_request);

  is($result->[0], 200, 'Returns 200 OK');
  ok($result->[1]{success}, 'Successfully created room');
  ok($result->[1]{room_id}, 'Room ID returned');
  is($result->[1]{room_title}, $unique_title, 'Correct room title returned');
  like($result->[1]{message}, qr/created successfully/, 'Success message included');

  # Clean up
  my $new_room = $DB->getNodeById($result->[1]{room_id});
  $DB->sqlDelete('node', "node_id=$new_room->{node_id}");
};

# Test 12: Create room - Missing title
subtest 'Create room - Missing title' => sub {
  plan tests => 2;

  my $mock_user = MockUser->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_admin_flag => 1,
    level => 99,
    real_node => $admin_user,
  );

  my $mock_request = MockRequest->new(
    user => $mock_user,
    _postdata => {
      room_doctext => 'No title provided'
    }
  );

  my $result = $api->create_room($mock_request);

  is($result->[0], 400, 'Returns 400 Bad Request');
  like($result->[1]{error}, qr/room_title is required/, 'Returns appropriate error message');
};

# Test 13: Create room - Empty title
subtest 'Create room - Empty title' => sub {
  plan tests => 2;

  my $mock_user = MockUser->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_admin_flag => 1,
    level => 99,
    real_node => $admin_user,
  );

  my $mock_request = MockRequest->new(
    user => $mock_user,
    _postdata => {
      room_title => '   ',
      room_doctext => 'Empty title'
    }
  );

  my $result = $api->create_room($mock_request);

  is($result->[0], 400, 'Returns 400 Bad Request');
  like($result->[1]{error}, qr/room_title is required/, 'Returns appropriate error message');
};

# Test 14: Create room - Title too long
subtest 'Create room - Title too long' => sub {
  plan tests => 2;

  my $mock_user = MockUser->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_admin_flag => 1,
    level => 99,
    real_node => $admin_user,
  );

  my $long_title = 'x' x 81; # 81 characters, max is 80
  my $mock_request = MockRequest->new(
    user => $mock_user,
    _postdata => {
      room_title => $long_title,
      room_doctext => 'Title is too long'
    }
  );

  my $result = $api->create_room($mock_request);

  is($result->[0], 400, 'Returns 400 Bad Request');
  like($result->[1]{error}, qr/80 characters or less/, 'Returns appropriate error message');
};

# Test 15: Create room - Reserved name "outside"
subtest 'Create room - Reserved name "outside"' => sub {
  plan tests => 2;

  my $mock_user = MockUser->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_admin_flag => 1,
    level => 99,
    real_node => $admin_user,
  );

  my $mock_request = MockRequest->new(
    user => $mock_user,
    _postdata => {
      room_title => 'outside',
      room_doctext => 'Should not be created'
    }
  );

  my $result = $api->create_room($mock_request);

  is($result->[0], 400, 'Returns 400 Bad Request');
  like($result->[1]{error}, qr/reserved/, 'Returns appropriate error message');
};

# Test 16: Create room - Reserved name "OUTSIDE" (case insensitive)
subtest 'Create room - Reserved name "OUTSIDE" (case insensitive)' => sub {
  plan tests => 2;

  my $mock_user = MockUser->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_admin_flag => 1,
    level => 99,
    real_node => $admin_user,
  );

  my $mock_request = MockRequest->new(
    user => $mock_user,
    _postdata => {
      room_title => 'OUTSIDE',
      room_doctext => 'Should not be created'
    }
  );

  my $result = $api->create_room($mock_request);

  is($result->[0], 400, 'Returns 400 Bad Request');
  like($result->[1]{error}, qr/reserved/, 'Returns appropriate error message');
};

# Test 17: Create room - Reserved name "go outside"
subtest 'Create room - Reserved name "go outside"' => sub {
  plan tests => 2;

  my $mock_user = MockUser->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_admin_flag => 1,
    level => 99,
    real_node => $admin_user,
  );

  my $mock_request = MockRequest->new(
    user => $mock_user,
    _postdata => {
      room_title => 'Go Outside',
      room_doctext => 'Should not be created'
    }
  );

  my $result = $api->create_room($mock_request);

  is($result->[0], 400, 'Returns 400 Bad Request');
  like($result->[1]{error}, qr/reserved/, 'Returns appropriate error message');
};

# Test 18: Create room - Duplicate title
subtest 'Create room - Duplicate title' => sub {
  plan tests => 2;

  my $mock_user = MockUser->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_admin_flag => 1,
    level => 99,
    real_node => $admin_user,
  );

  my $mock_request = MockRequest->new(
    user => $mock_user,
    _postdata => {
      room_title => $test_room->{title},
      room_doctext => 'Duplicate room'
    }
  );

  my $result = $api->create_room($mock_request);

  is($result->[0], 200, 'Returns 200 OK');
  like($result->[1]{error}, qr/already exists/, 'Returns appropriate error message');
};

# Test 19: Create room - Already in room with same title
subtest 'Create room - Already in room with same title' => sub {
  plan tests => 2;

  # First, move user into the test room
  my $mock_user = MockUser->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_admin_flag => 1,
    level => 99,
    real_node => $admin_user,
  );

  $admin_user->{in_room} = $test_room->{node_id};

  my $mock_request = MockRequest->new(
    user => $mock_user,
    _postdata => {
      room_title => $test_room->{title},
      room_doctext => 'Trying to create room I am already in'
    }
  );

  my $result = $api->create_room($mock_request);

  is($result->[0], 200, 'Returns 200 OK');
  like($result->[1]{error}, qr/already in this room/, 'Returns specific error message for already in room');
};

# Clean up test data
$DB->sqlDelete('node', "node_id=$test_room->{node_id}");

done_testing();
