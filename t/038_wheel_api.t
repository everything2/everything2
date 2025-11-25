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
use Everything::API::wheel;

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
# Test Wheel of Surprise API functionality
#
# These tests verify:
# 1. POST /api/wheel/spin - Spin the wheel
# 2. Authorization checks (guest users blocked)
# 3. GP opt-out check
# 4. Minimum GP requirement (5 GP)
# 5. Prize distribution and user updates
#############################################################################

# Get test user
my $test_user = $DB->getNode("normaluser1", "user");
ok($test_user, "Got test user normaluser1");

# Helper: Create a mock request object
package MockRequest {
    sub new {
        my ($class, %args) = @_;
        return bless \%args, $class;
    }
    sub user { return $_[0]->{user} }
}

# Helper: Create a mock user object with VARS support
package MockUser {
    sub new {
        my ($class, %args) = @_;
        my $self = {
            node_id => $args{node_id},
            user_id => $args{user_id},
            title => $args{title},
            GP => $args{GP} // 0,
            is_guest_flag => $args{is_guest_flag} // 0,
            real_user => $args{real_user},  # Reference to real user object
        };
        return bless $self, $class;
    }

    sub NODEDATA {
        my ($self) = @_;
        # Return the actual hashref from the real user if available
        # This allows the API to modify GP and other fields directly
        if ($self->{real_user}) {
            return $self->{real_user};
        }
        # Fallback: return the blessed object itself (acts like hashref)
        return $self;
    }

    sub VARS {
        my ($self) = @_;
        # Get VARS from the real user object if available
        if ($self->{real_user}) {
            return $main::APP->getVars($self->{real_user});
        }
        return {};
    }

    sub set_vars {
        my ($self, $vars) = @_;
        # Save VARS to the real user object if available
        if ($self->{real_user}) {
            # Need to convert hashref to vars string format and save
            # For now, manually update the real user's vars field
            my @pairs;
            foreach my $key (keys %$vars) {
                my $value = $vars->{$key};
                push @pairs, "$key=$value" if defined $value;
            }
            my $vars_string = join("\n", @pairs);
            $self->{real_user}->{vars} = $vars_string;
            $main::DB->updateNode($self->{real_user}, -1);
        }
    }
}

# Create API instance
my $api = Everything::API::wheel->new();
ok($api, "Created wheel API instance");

#############################################################################
# Test 1: Guest user cannot spin
#############################################################################
subtest "Guest user blocked" => sub {
    plan tests => 2;

    # Get the actual guest user from database
    my $guest = $DB->getNode('Guest User', 'user');

    my $guest_user = MockUser->new(
        node_id => $guest->{node_id},
        user_id => $guest->{user_id},
        title => $guest->{title},
        is_guest_flag => 1,
        GP => 100,
        real_user => $guest
    );

    my $request = MockRequest->new(user => $guest_user);
    my $response = $api->spin($request);

    is($response->[0], 403, "Returns 403 Forbidden");
    ok($response->[1]->{error} =~ /logged in/, "Error message mentions login requirement");
};

#############################################################################
# Test 2: User with GP opt-out cannot spin
#############################################################################
subtest "GP opt-out user blocked" => sub {
    plan tests => 3;

    # Set test user GP to sufficient amount and enable GP opt-out
    my $original_gp = $test_user->{GP};
    $test_user->{GP} = 100;
    $DB->updateNode($test_user, -1);

    # Set GP opt-out in VARS
    my $vars = $APP->getVars($test_user);
    my $original_optout = $vars->{GPoptout};
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

    my $request = MockRequest->new(user => $user);
    my $response = $api->spin($request);

    is($response->[0], 403, "Returns 403 Forbidden");
    ok($response->[1]->{error} =~ /vow of poverty/, "Error mentions vow of poverty");
    is($response->[1]->{success}, 0, "Success is false");

    # Restore original opt-out setting and GP
    $vars->{GPoptout} = $original_optout;
    Everything::setVars($test_user, $vars);
    $test_user->{GP} = $original_gp;
    $DB->updateNode($test_user, -1);
};

#############################################################################
# Test 3: User with insufficient GP cannot spin
#############################################################################
subtest "Insufficient GP blocked" => sub {
    plan tests => 3;

    # Set test user GP to insufficient amount
    my $original_gp = $test_user->{GP};
    $test_user->{GP} = 3;  # Less than required 5 GP
    $DB->updateNode($test_user, -1);

    my $user = MockUser->new(
        node_id => $test_user->{node_id},
        user_id => $test_user->{user_id},
        title => $test_user->{title},
        GP => 3,
        real_user => $test_user
    );

    my $request = MockRequest->new(user => $user);
    my $response = $api->spin($request);

    is($response->[0], 403, "Returns 403 Forbidden");
    ok($response->[1]->{error} =~ /at least 5 GP/, "Error mentions 5 GP requirement");
    is($response->[1]->{success}, 0, "Success is false");

    # Restore original GP
    $test_user->{GP} = $original_gp;
    $DB->updateNode($test_user, -1);
};

#############################################################################
# Test 4: Successful spin
#############################################################################
subtest "Successful spin" => sub {
    plan tests => 8;

    # Give test user sufficient GP
    my $original_gp = $test_user->{GP};
    $test_user->{GP} = 100;
    $DB->updateNode($test_user, -1);

    # Clear any GP opt-out
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

    my $request = MockRequest->new(user => $user);
    my $response = $api->spin($request);

    is($response->[0], 200, "Returns 200 OK");
    is($response->[1]->{success}, 1, "Success is true");
    ok($response->[1]->{message}, "Has result message");
    ok($response->[1]->{prizeType}, "Has prize type");
    ok(defined $response->[1]->{user}->{GP}, "Returns updated GP");
    ok(defined $response->[1]->{user}->{spinCount}, "Returns spin count");
    ok(defined $response->[1]->{vars}, "Returns VARS data");

    # Verify GP is in reasonable range after spin
    # Spin costs 5 GP, but can win up to 500 GP, so GP could be anywhere from 95-600
    # Note: Can also win exactly 5 GP back (refund), resulting in same GP as before
    ok($response->[1]->{user}->{GP} >= 95 && $response->[1]->{user}->{GP} <= 600,
       "GP is in valid range (95-600) after spin");

    # Restore original GP
    $test_user->{GP} = $original_gp;
    $DB->updateNode($test_user, -1);
};

#############################################################################
# Test 5: Spin counter increments
#############################################################################
subtest "Spin counter increments" => sub {
    plan tests => 2;

    # Give test user sufficient GP
    $test_user->{GP} = 100;
    $DB->updateNode($test_user, -1);

    my $vars = $APP->getVars($test_user);
    my $original_spin_count = $vars->{spin_wheel} || 0;

    my $user = MockUser->new(
        node_id => $test_user->{node_id},
        user_id => $test_user->{user_id},
        title => $test_user->{title},
        GP => 100,
        real_user => $test_user
    );

    my $request = MockRequest->new(user => $user);
    my $response = $api->spin($request);

    is($response->[0], 200, "Spin successful");
    is($response->[1]->{user}->{spinCount}, $original_spin_count + 1, "Spin counter incremented");
};

done_testing();
