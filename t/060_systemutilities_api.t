#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "$FindBin::Bin/lib";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;
use Everything::Application;
use Everything::API::systemutilities;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

#############################################################################
# Test System Utilities API - Room Purge
#
# This test verifies:
# - Guest users cannot purge rooms (403 Forbidden)
# - Normal users cannot purge rooms (403 Forbidden)
# - Admin users can purge rooms (200 OK)
# - Room purge returns count of purged records
#
# Replaces legacy t/007_systemutilities.t that used Everything::APIClient
#############################################################################

# Get test users
my $normaluser1 = $DB->getNode("e2e_user", "user");
my $root = $DB->getNode("root", "user");

ok($normaluser1, "Got normaluser1");
ok($root, "Got root user");

# Create API instance
my $api = Everything::API::systemutilities->new();
ok($api, "Created systemutilities API instance");

#############################################################################
# Test 1: Guest User - Cannot Purge Rooms (403 Forbidden)
#############################################################################

my $guest_request = MockRequest->new(
  node_id => 0,
  title => 'Guest User',
  is_guest_flag => 1,
  is_admin_flag => 0
);

my $result = $api->roompurge($guest_request);
is($result->[0], $api->HTTP_FORBIDDEN, "Guest roompurge returns 403 Forbidden");

#############################################################################
# Test 2: Normal User - Cannot Purge Rooms (403 Forbidden)
#############################################################################

my $normal_request = MockRequest->new(
  node_id => $normaluser1->{node_id},
  title => $normaluser1->{title},
  nodedata => $normaluser1,
  is_guest_flag => 0,
  is_admin_flag => 0
);

$result = $api->roompurge($normal_request);
is($result->[0], $api->HTTP_FORBIDDEN, "Normal user roompurge returns 403 Forbidden");

#############################################################################
# Test 3: Admin User - Can Purge Rooms (200 OK)
#############################################################################

my $admin_request = MockRequest->new(
  node_id => $root->{node_id},
  title => $root->{title},
  nodedata => $root,
  is_guest_flag => 0,
  is_admin_flag => 1
);

$result = $api->roompurge($admin_request);
is($result->[0], $api->HTTP_OK, "Admin roompurge returns 200 OK");
ok(defined($result->[1]->{purged}), "Purge result includes purged count");

#############################################################################
# Test 4: Seed Rooms and Purge Again
#############################################################################

# Get the chatroom node (assuming it exists in test data)
my $chatroom = $DB->getNode("chatterbox", "room");
unless ($chatroom) {
  # Try finding any room
  my @rooms = $DB->getNodeWhere({type_nodetype => $DB->getType('room')->{node_id}});
  $chatroom = $rooms[0] if @rooms;
}

# Seed the rooms table by inserting some test data
if ($chatroom) {
  foreach my $user_name ('e2e_user', 'e2e_editor', 'e2e_admin', 'root')
  {
    my $user = $DB->getNode($user_name, 'user');
    if ($user) {
      # Check if this room/user combo already exists
      my $existing = $DB->sqlSelect('COUNT(*)', 'room',
        'room_id=' . $chatroom->{node_id} . ' AND member_user=' . $user->{node_id});

      unless ($existing) {
        # Insert a room entry for this user in the chatroom
        # room table has composite key: (room_id, member_user)
        $DB->sqlInsert('room', {
          room_id => $chatroom->{node_id},
          member_user => $user->{node_id},
          nick => $user->{title},
          op => 0,
          visible => 1,
          borgd => 0,
          experience => 0,
          unixcreatetime => time()
        });
      }
    }
  }
}

# Purge as admin
$result = $api->roompurge($admin_request);
is($result->[0], $api->HTTP_OK, "Admin roompurge returns 200 OK after seeding");
ok(defined($result->[1]->{purged}), "Purge result includes count");

done_testing();
