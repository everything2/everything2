#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 12;
use JSON;

use lib '/var/libraries/lib/perl5';
use lib '/var/everything/ecore';

use Everything;
use Everything::API::admin;

# Initialize E2 system
initEverything();

my $APP = $Everything::APP;
my $DB = $APP->{db};

# Get test users
my $admin_user = $DB->getNode('root', 'user');
my $editor_user = $DB->getNode('e2e_editor', 'user');
my $regular_user = $DB->getNode('e2e_user', 'user');

# Get a maintenance node to test with
my $maintenance_node = $DB->getNode('writeup maintenance create', 'maintenance');

# Create mock request and user objects
{
  package MockUser;
  sub new {
    my ($class, %args) = @_;
    return bless {
      node_id => $args{node_id} // 0,
      title => $args{title} // 'test',
      is_admin_flag => $args{is_admin_flag} // 0,
      _nodedata => $args{nodedata} // {},
    }, $class;
  }
  sub is_admin { return shift->{is_admin_flag}; }
  sub node_id { shift->{node_id} }
  sub title { shift->{title} }
  sub NODEDATA { shift->{_nodedata} }
}

{
  package MockRequest;
  sub new {
    my ($class, %args) = @_;
    return bless {
      user => MockUser->new(%args),
      postdata => $args{postdata},
    }, $class;
  }
  sub user { shift->{user} }
  sub JSON_POSTDATA { shift->{postdata} }
  sub set_postdata {
    my ($self, $data) = @_;
    $self->{postdata} = $data;
  }
  sub is_guest { return 0 }
}

# Create API instance
my $api = Everything::API::admin->new();

# Test 1: Admin flag works in mock
my $admin_request = MockRequest->new(
  node_id => $admin_user->{node_id},
  title => $admin_user->{title},
  nodedata => $admin_user,
  is_admin_flag => 1
);
ok($admin_request->user->is_admin, 'Admin request has is_admin = true');

# Test 2: Non-admin flag works in mock
my $regular_request = MockRequest->new(
  node_id => $regular_user->{node_id},
  title => $regular_user->{title},
  nodedata => $regular_user,
  is_admin_flag => 0
);
ok(!$regular_request->user->is_admin, 'Regular request has is_admin = false');

# Test 3: Admin can GET node data
SKIP: {
  skip "No maintenance node in test database", 1 unless $maintenance_node;

  my $result = $api->get_node($admin_request, $maintenance_node->{node_id});
  is($result->[0], $api->HTTP_OK, 'Admin can GET system node data');
}

# Test 4: Non-admin cannot GET node data
SKIP: {
  skip "No maintenance node in test database", 1 unless $maintenance_node;

  my $result = $api->get_node($regular_request, $maintenance_node->{node_id});
  is($result->[0], $api->HTTP_FORBIDDEN, 'Non-admin cannot GET system node data');
}

# Test 5: Non-admin gets proper error message
SKIP: {
  skip "No maintenance node in test database", 1 unless $maintenance_node;

  my $result = $api->get_node($regular_request, $maintenance_node->{node_id});
  is($result->[1]->{error}, 'Admin access required', 'Non-admin gets admin access required error');
}

# Test 6: Admin cannot GET non-existent node
{
  my $result = $api->get_node($admin_request, 999999999);
  is($result->[0], $api->HTTP_NOT_FOUND, 'Admin gets 404 for non-existent node');
}

# Test 7: Admin cannot GET non-system node types (like user)
{
  my $result = $api->get_node($admin_request, $admin_user->{node_id});
  is($result->[0], $api->HTTP_FORBIDDEN, 'Admin cannot GET non-system node type (user)');
}

# Test 8: Admin can edit node
SKIP: {
  skip "No maintenance node in test database", 1 unless $maintenance_node;

  # Get original title
  my $original_title = $maintenance_node->{title};

  # Set up edit request
  $admin_request->set_postdata({ title => $original_title . ' TEST' });

  my $result = $api->edit_node($admin_request, $maintenance_node->{node_id});
  is($result->[0], $api->HTTP_OK, 'Admin can edit system node');

  # Restore original title
  $admin_request->set_postdata({ title => $original_title });
  $api->edit_node($admin_request, $maintenance_node->{node_id});
}

# Test 9: Non-admin cannot edit node
SKIP: {
  skip "No maintenance node in test database", 1 unless $maintenance_node;

  $regular_request->set_postdata({ title => 'HACKED TITLE' });
  my $result = $api->edit_node($regular_request, $maintenance_node->{node_id});
  is($result->[0], $api->HTTP_FORBIDDEN, 'Non-admin cannot edit system node');
}

# Test 10: Empty title is rejected
SKIP: {
  skip "No maintenance node in test database", 1 unless $maintenance_node;

  $admin_request->set_postdata({ title => '' });
  my $result = $api->edit_node($admin_request, $maintenance_node->{node_id});
  is($result->[0], $api->HTTP_BAD_REQUEST, 'Empty title is rejected');
}

# Test 11: Title too long is rejected
SKIP: {
  skip "No maintenance node in test database", 1 unless $maintenance_node;

  $admin_request->set_postdata({ title => 'x' x 300 });
  my $result = $api->edit_node($admin_request, $maintenance_node->{node_id});
  is($result->[0], $api->HTTP_BAD_REQUEST, 'Title over 240 chars is rejected');
}

# Test 12: Editor is not admin (editors can see Master Control but not use admin API)
my $editor_request = MockRequest->new(
  node_id => $editor_user->{node_id},
  title => $editor_user->{title},
  nodedata => $editor_user,
  is_admin_flag => 0  # Editors are not admins
);
ok(!$editor_request->user->is_admin, 'Editor is not admin (cannot use admin API)');

done_testing();
