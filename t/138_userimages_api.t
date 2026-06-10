#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::API::userimages;
use MockRequest;

# Everything::API::userimages -- editor moderation of homenode images (approve / remove).
# Tests the login + editor gates and userId validation. Stops before any DB mutation
# (the approve/remove happy paths delete from newuserimage and rewrite the user node).

initEverything('development-docker');

ok($DB,  'Database connection established');
ok($APP, 'Application object created');

my $api = Everything::API::userimages->new();
ok($api, 'Created userimages API instance');

is_deeply($api->routes, { 'approve' => 'approve', 'delete' => 'remove_image' },
    'routes: approve, delete -> remove_image');

my $guest  = MockRequest->new(is_guest_flag => 1);
my $normal = MockRequest->new(
    node_id => 2, title => 'normaluser1', is_guest_flag => 0, is_editor_flag => 0,
    nodedata => { node_id => 2, title => 'normaluser1' },
);
my $editor = MockRequest->new(
    node_id => 1, title => 'someeditor', is_guest_flag => 0, is_editor_flag => 1,
    nodedata => { node_id => 1, title => 'someeditor' },
    postdata => {},   # no userId
);

for my $method (qw(approve remove_image)) {
    my $r = $api->$method($guest);
    is($r->[1]{success}, 0, "$method: guest blocked");
    like($r->[1]{error}, qr/login required/i, "$method: login-required error");

    $r = $api->$method($normal);
    is($r->[1]{success}, 0, "$method: non-editor blocked");
    like($r->[1]{error}, qr/permission denied/i, "$method: permission-denied error");

    $r = $api->$method($editor);
    is($r->[1]{success}, 0, "$method: missing userId rejected");
    like($r->[1]{error}, qr/user id required/i, "$method: userId-required error");

    # Non-numeric userId is also rejected (regex guard).
    my $bad = MockRequest->new(
        node_id => 1, title => 'someeditor', is_guest_flag => 0, is_editor_flag => 1,
        nodedata => { node_id => 1, title => 'someeditor' },
        postdata => { userId => 'abc' },
    );
    $r = $api->$method($bad);
    like($r->[1]{error}, qr/user id required/i, "$method: non-numeric userId rejected");
}

done_testing();

=head1 NAME

t/138_userimages_api.t - Tests for Everything::API::userimages (moderation gates)

=cut
