#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 17;
use JSON;

use lib '/var/libraries/lib/perl5';
use lib '/var/everything/ecore';

use Everything;
use Everything::API::spamcannon;

# Initialize E2 system
initEverything();

my $APP = $Everything::APP;
my $DB = $APP->{db};

# Get test users
my $root_user = $DB->getNode('root', 'user');
my $guest_user = $DB->getNode('guest user', 'user');

# Create mock request and user objects
{
  package MockUser;
  sub new {
    my ($class, %args) = @_;
    return bless {
      node_id => $args{node_id} // 0,
      title => $args{title} // 'test',
      is_editor_flag => $args{is_editor_flag} // 0,
      is_guest_flag => $args{is_guest_flag} // 0,
      _nodedata => $args{nodedata} // {},
    }, $class;
  }
  sub is_editor { return shift->{is_editor_flag}; }
  sub is_guest { return shift->{is_guest_flag}; }
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
}

# Create API instance
my $api = Everything::API::spamcannon->new();

# ============================================
# Test 1: Routes are configured correctly
# ============================================
{
  my $routes = $api->routes;
  is(ref($routes), 'HASH', 'routes() returns a hashref');
  ok(exists $routes->{'/'}, 'Root route exists');
  is($routes->{'/'}, 'send_bulk_message', 'Root route maps to send_bulk_message');
}

# ============================================
# Test 2: Guest cannot use spamcannon
# ============================================
{
  my $guest_request = MockRequest->new(
    node_id => $guest_user->{node_id},
    title => $guest_user->{title},
    nodedata => $guest_user,
    is_guest_flag => 1,
    is_editor_flag => 0,
    postdata => { recipients => ['root'], message => 'test' }
  );

  my $result = $api->send_bulk_message($guest_request);
  is($result->[0], $api->HTTP_OK, 'Guest gets HTTP_OK (per API convention)');
  is($result->[1]->{success}, 0, 'Guest request has success=0');
  like($result->[1]->{error}, qr/Not logged in/, 'Guest gets "Not logged in" error');
}

# ============================================
# Test 3: Non-editor cannot use spamcannon
# ============================================
{
  # Create a mock non-editor user
  my $non_editor_request = MockRequest->new(
    node_id => 12345,
    title => 'test_user',
    nodedata => { node_id => 12345, title => 'test_user' },
    is_guest_flag => 0,
    is_editor_flag => 0,
    postdata => { recipients => ['root'], message => 'test' }
  );

  my $result = $api->send_bulk_message($non_editor_request);
  is($result->[0], $api->HTTP_OK, 'Non-editor gets HTTP_OK (per API convention)');
  is($result->[1]->{success}, 0, 'Non-editor request has success=0');
  like($result->[1]->{error}, qr/Permission denied|Editor access required/, 'Non-editor gets permission error');
}

# ============================================
# Test 4: Missing recipients validation
# ============================================
{
  my $editor_request = MockRequest->new(
    node_id => $root_user->{node_id},
    title => $root_user->{title},
    nodedata => $root_user,
    is_guest_flag => 0,
    is_editor_flag => 1,
    postdata => { message => 'test' }  # No recipients
  );

  my $result = $api->send_bulk_message($editor_request);
  is($result->[1]->{success}, 0, 'Missing recipients has success=0');
  like($result->[1]->{error}, qr/No recipients/, 'Missing recipients error message');
}

# ============================================
# Test 5: Missing message validation
# ============================================
{
  my $editor_request = MockRequest->new(
    node_id => $root_user->{node_id},
    title => $root_user->{title},
    nodedata => $root_user,
    is_guest_flag => 0,
    is_editor_flag => 1,
    postdata => { recipients => ['root'] }  # No message
  );

  my $result = $api->send_bulk_message($editor_request);
  is($result->[1]->{success}, 0, 'Missing message has success=0');
  like($result->[1]->{error}, qr/No message/, 'Missing message error');
}

# ============================================
# Test 6: Too many recipients validation
# ============================================
{
  my @many_recipients = map { "user$_" } (1..25);
  my $editor_request = MockRequest->new(
    node_id => $root_user->{node_id},
    title => $root_user->{title},
    nodedata => $root_user,
    is_guest_flag => 0,
    is_editor_flag => 1,
    postdata => { recipients => \@many_recipients, message => 'test' }
  );

  my $result = $api->send_bulk_message($editor_request);
  is($result->[1]->{success}, 0, 'Too many recipients has success=0');
  like($result->[1]->{error}, qr/Too many recipients|Maximum/, 'Too many recipients error');
}

# ============================================
# Test 7: Invalid JSON body
# ============================================
{
  my $editor_request = MockRequest->new(
    node_id => $root_user->{node_id},
    title => $root_user->{title},
    nodedata => $root_user,
    is_guest_flag => 0,
    is_editor_flag => 1,
    postdata => undef  # No JSON body
  );

  my $result = $api->send_bulk_message($editor_request);
  is($result->[1]->{success}, 0, 'Invalid JSON body has success=0');
  like($result->[1]->{error}, qr/Invalid JSON/, 'Invalid JSON body error');
}

done_testing();
