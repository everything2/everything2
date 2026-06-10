#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::API::nodeshells;
use MockRequest;

# Everything::API::nodeshells -- editor-only bulk nodeshell deletion. Tests the custom
# route() dispatcher, the editor gate, and body validation. Does NOT delete anything:
# the non-editor/bad-body branches return early, and the editor happy-path is exercised
# only with an EMPTY list (no nodeshell is touched).

initEverything('development-docker');

ok($DB,  'Database connection established');
ok($APP, 'Application object created');

my $api = Everything::API::nodeshells->new();
ok($api, 'Created nodeshells API instance');

#############################################################################
# route() dispatcher
#############################################################################

my $editor = MockRequest->new(
    node_id        => 1,
    title          => 'someeditor',
    is_guest_flag  => 0,
    is_editor_flag => 1,
    nodedata       => { node_id => 1, title => 'someeditor' },
    postdata       => { nodeshells => [] },
);

my $r = $api->route($editor, 'no_such_route');
is($r->[0], $api->HTTP_NOT_FOUND, 'unknown route -> 404');
like($r->[1]{error}, qr/unknown route/i, 'unknown-route error message');

#############################################################################
# Editor gate
#############################################################################

my $normal = MockRequest->new(
    node_id        => 2,
    title          => 'normaluser1',
    is_guest_flag  => 0,
    is_editor_flag => 0,
    nodedata       => { node_id => 2, title => 'normaluser1' },
    postdata       => { nodeshells => ['whatever'] },
);
$r = $api->delete_nodeshells($normal);
is($r->[0], $api->HTTP_OK, 'non-editor returns 200');
is($r->[1]{success}, 0, 'non-editor cannot delete');
like($r->[1]{error}, qr/permission denied/i, 'permission-denied error');

#############################################################################
# Body validation (editor, but no nodeshells list)
#############################################################################

my $editor_nobody = MockRequest->new(
    node_id        => 1,
    title          => 'someeditor',
    is_guest_flag  => 0,
    is_editor_flag => 1,
    nodedata       => { node_id => 1, title => 'someeditor' },
    postdata       => {},
);
$r = $api->delete_nodeshells($editor_nobody);
is($r->[1]{success}, 0, 'editor with no body fails');
like($r->[1]{error}, qr/invalid request body/i, 'invalid-body error');

#############################################################################
# Editor happy path with an EMPTY list -> success, nothing deleted
#############################################################################

$r = $api->route($editor, 'delete');
is($r->[0], $api->HTTP_OK, 'editor delete (empty list) returns 200');
is($r->[1]{success}, 1, 'empty list succeeds');
is_deeply($r->[1]{results}, [], 'no results for an empty list');

done_testing();

=head1 NAME

t/137_nodeshells_api.t - Tests for Everything::API::nodeshells (editor gate + dispatch)

=cut
