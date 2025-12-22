#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::Application;
use Everything::API::levels;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

my $api = Everything::API::levels->new();
ok($api, "Created levels API instance");

#############################################################################
# Test Setup: Get test users
#############################################################################

my $normal_user = $DB->getNode("normaluser1", "user");
ok($normal_user, "Got normal user for testing");

my $guest_user = $DB->getNode("guest user", "user");
ok($guest_user, "Got guest user for testing");

#############################################################################
# Test: Basic routes check
#############################################################################

my $routes = $api->routes();
ok($routes, "Routes defined");
is($routes->{get_levels}, 'get_levels', "get_levels route exists");

#############################################################################
# Test: Default level range (0-12)
#############################################################################

my $request = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    is_guest_flag => 0,
    nodedata => $normal_user
);

# Mock the param method for CGI params
{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return undef; # No params = use defaults
    };
}

my $result = $api->get_levels($request);
is($result->[0], $api->HTTP_OK, "Default range returns HTTP 200");
is($result->[1]{success}, 1, "Request was successful");
is($result->[1]{first_level}, 0, "First level defaults to 0");
is($result->[1]{second_level}, 12, "Second level defaults to 12");
ok(defined($result->[1]{levels}), "Levels array returned");
is(scalar(@{$result->[1]{levels}}), 13, "13 levels returned (0-12 inclusive)");

#############################################################################
# Test: Level data structure
#############################################################################

my $level_0 = $result->[1]{levels}[0];
ok(defined($level_0->{level}), "Level number present");
is($level_0->{level}, 0, "First level is 0");
ok(defined($level_0->{title}), "Level title present");
ok(defined($level_0->{xp}), "XP requirement present");
ok(defined($level_0->{writeups}), "Writeups requirement present");
ok(defined($level_0->{votes}), "Votes present");
ok(defined($level_0->{cools}), "Cools present");
ok(defined($level_0->{is_user_level}), "is_user_level flag present");

#############################################################################
# Test: User level indicator
#############################################################################

ok(defined($result->[1]{user_level}), "User level returned");
my $user_level = $result->[1]{user_level};

# Find the level marked as user's current level
my $found_user_level = 0;
foreach my $level (@{$result->[1]{levels}}) {
    if ($level->{is_user_level}) {
        $found_user_level = 1;
        is($level->{level}, $user_level, "is_user_level matches user_level");
        last;
    }
}
# User level may be outside 0-12 range, so this check is conditional
if ($user_level >= 0 && $user_level <= 12) {
    ok($found_user_level, "User's level is marked in the levels array");
}

#############################################################################
# Test: Custom level range
#############################################################################

{
    my %params = (first_level => 5, second_level => 10);
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return $params{$name};
    };
}

$result = $api->get_levels($request);
is($result->[0], $api->HTTP_OK, "Custom range returns HTTP 200");
is($result->[1]{first_level}, 5, "First level is 5");
is($result->[1]{second_level}, 10, "Second level is 10");
is(scalar(@{$result->[1]{levels}}), 6, "6 levels returned (5-10 inclusive)");
is($result->[1]{levels}[0]{level}, 5, "First returned level is 5");
is($result->[1]{levels}[5]{level}, 10, "Last returned level is 10");

#############################################################################
# Test: Negative levels (Arcanist levels)
#############################################################################

{
    my %params = (first_level => -3, second_level => 2);
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return $params{$name};
    };
}

$result = $api->get_levels($request);
is($result->[0], $api->HTTP_OK, "Negative range returns HTTP 200");
is($result->[1]{first_level}, -3, "First level is -3");
is(scalar(@{$result->[1]{levels}}), 6, "6 levels returned (-3 to 2)");

# Check negative level titles
my $level_minus3 = $result->[1]{levels}[0];
is($level_minus3->{level}, -3, "First level is -3");
is($level_minus3->{title}, 'Demon', "Level -3 is Demon");

my $level_minus2 = $result->[1]{levels}[1];
is($level_minus2->{level}, -2, "Second level is -2");
is($level_minus2->{title}, 'Master Arcanist', "Level -2 is Master Arcanist");

my $level_minus1 = $result->[1]{levels}[2];
is($level_minus1->{level}, -1, "Third level is -1");
is($level_minus1->{title}, 'Arcanist', "Level -1 is Arcanist");

#############################################################################
# Test: High levels (Transcendent)
#############################################################################

{
    my %params = (first_level => 99, second_level => 102);
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return $params{$name};
    };
}

$result = $api->get_levels($request);
is($result->[0], $api->HTTP_OK, "High level range returns HTTP 200");
is(scalar(@{$result->[1]{levels}}), 4, "4 levels returned (99-102)");

# Level 100+ should be Transcendent
my $level_100 = $result->[1]{levels}[1];
is($level_100->{level}, 100, "Level 100 present");
is($level_100->{title}, 'Transcendent', "Level 100 is Transcendent");

my $level_101 = $result->[1]{levels}[2];
is($level_101->{level}, 101, "Level 101 present");
is($level_101->{title}, 'Transcendent', "Level 101 is Transcendent");

#############################################################################
# Test: Too many levels requested
#############################################################################

{
    my %params = (first_level => 0, second_level => 200);
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return $params{$name};
    };
}

$result = $api->get_levels($request);
is($result->[0], $api->HTTP_OK, "Too many levels returns HTTP 200");
is($result->[1]{success}, 0, "Request fails when too many levels requested");
like($result->[1]{error}, qr/more than 100 levels/i, "Error message mentions 100 level limit");

#############################################################################
# Test: Guest user can also fetch levels
#############################################################################

my $guest_request = MockRequest->new(
    node_id => 0,
    title => 'Guest User',
    is_guest_flag => 1,
    nodedata => $guest_user
);

{
    my %params = (first_level => 0, second_level => 5);
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return $params{$name};
    };
}

$result = $api->get_levels($guest_request);
is($result->[0], $api->HTTP_OK, "Guest can fetch levels");
is($result->[1]{success}, 1, "Guest request succeeds");
is(scalar(@{$result->[1]{levels}}), 6, "Guest gets 6 levels (0-5)");

#############################################################################
# Test: Edge cases
#############################################################################

# Single level
{
    my %params = (first_level => 5, second_level => 5);
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return $params{$name};
    };
}

$result = $api->get_levels($request);
is($result->[0], $api->HTTP_OK, "Single level returns HTTP 200");
is(scalar(@{$result->[1]{levels}}), 1, "1 level returned");
is($result->[1]{levels}[0]{level}, 5, "Level 5 returned");

# Very low Archdemon level
{
    my %params = (first_level => -10, second_level => -4);
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return $params{$name};
    };
}

$result = $api->get_levels($request);
is($result->[0], $api->HTTP_OK, "Archdemon range returns HTTP 200");
my $archdemon_level = $result->[1]{levels}[0];
is($archdemon_level->{level}, -10, "Level -10 present");
is($archdemon_level->{title}, 'Archdemon', "Level -10 is Archdemon");
ok($archdemon_level->{xp} < 0, "Archdemon has negative XP requirement");

done_testing();

=head1 NAME

t/067_levels_api.t - Tests for Everything::API::levels

=head1 DESCRIPTION

Tests for the levels API covering:
- Default level range (0-12)
- Custom level ranges
- Negative levels (Arcanist, Demon, Archdemon)
- High levels (Transcendent)
- Level data structure validation
- User level indicator
- Request limits (max 100 levels)
- Guest user access

=head1 AUTHOR

Everything2 Development Team

=cut
