#!/usr/bin/perl -w
# Everything::API::notelet -- POST /api/notelet/{save,castrate} (#4479, Refs #4298).
#
# The notelet save/castrate writes used to run in Everything::Page::notelet_editor's
# buildReactData off the ?makethechange / ?YesReallyCastrate query params. They now live here,
# sharing the level-based cap + payload + write logic with the pure-render page via
# Everything::Roles::Notelet. MockUser->set_vars is in-memory, so these exercise the API/role
# logic without persisting to the real user.
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::API::notelet;
use MockRequest;

initEverything('development-docker');
ok($DB, 'Database connection established');

my $api = Everything::API::notelet->new();
ok($api, 'Created notelet API instance');
is_deeply($api->routes, {save => 'save', castrate => 'castrate'}, 'routes: save + castrate');

#############################################################################
# Gate: guest -> refused (200 + success=0) on both endpoints
#############################################################################
for my $action (qw(save castrate)) {
    my $r = $api->$action(MockRequest->new(is_guest_flag => 1, vars => {}));
    is($r->[0], $api->HTTP_OK, "$action returns 200 for guest");
    is($r->[1]{success}, 0, "$action refuses guest");
    like($r->[1]{error}, qr/logged in/i, "$action guest error mentions login");
}

#############################################################################
# Logged-in save: stores the raw source + returns the fresh payload
#############################################################################
SKIP: {
    my $target = $DB->getNode('normaluser1', 'user');
    skip 'normaluser1 not present', 10 unless $target;

    my $req = MockRequest->new(
        is_guest_flag => 0,
        nodedata      => $target,
        vars          => {},
        postdata      => {notelet_source => 'hello world', keep_comments => 0},
    );
    my $r = $api->save($req);
    is($r->[0], $api->HTTP_OK, 'save returns 200');
    is($r->[1]{success}, 1, 'save succeeds');
    is($r->[1]{notelet_raw}, 'hello world', 'raw source stored');
    ok(exists $r->[1]{max_length}, 'payload carries max_length');
    ok(exists $r->[1]{char_count}, 'payload carries char_count');
    like($r->[1]{message}, qr/saved/i, 'success message present');

    # Castrate: comments out every line of JS.
    my $cr = $api->castrate(MockRequest->new(
        is_guest_flag => 0, nodedata => $target,
        vars => {noteletRaw => "alert(1)\nfoo()", noteletScreened => 'x'},
    ));
    is($cr->[1]{success}, 1, 'castrate succeeds');
    is($cr->[1]{notelet_raw}, "// alert(1)\n// foo()", 'castrate comments every line');

    # #4479: an empty notelet stays empty (was: became '// ' and grew on each castrate).
    my $empty = $api->castrate(MockRequest->new(
        is_guest_flag => 0, nodedata => $target,
        vars => {noteletRaw => '', noteletScreened => ''},
    ));
    is($empty->[1]{notelet_raw}, '', 'castrating an empty notelet stays empty');

    # #4479: idempotent -- re-castrating already-commented text does not re-add markers.
    my $again = $api->castrate(MockRequest->new(
        is_guest_flag => 0, nodedata => $target,
        vars => {noteletRaw => "// alert(1)\n// foo()", noteletScreened => ''},
    ));
    is($again->[1]{notelet_raw}, "// alert(1)\n// foo()", 're-castrate is idempotent');
}

#############################################################################
# Keep-comments option: saved under the key the screening reads (#4662)
#############################################################################
SKIP: {
    my $target = $DB->getNode('normaluser1', 'user');
    skip 'normaluser1 not present', 9 unless $target;
    my $source = 'before <!-- a note --> after';

    my $keep = MockRequest->new(
        is_guest_flag => 0, nodedata => $target, vars => {},
        postdata      => {notelet_source => $source, keep_comments => 1},
    );
    my $r = $api->save($keep);
    is($r->[1]{keep_comments}, 1, 'keep_comments on: reported back as on');
    like($r->[1]{notelet_screened}, qr/<!-- a note -->/, 'keep_comments on: comment kept in the screened notelet');
    is($keep->user->VARS->{noteletKeepComments}, 1, 'keep_comments on: stored as noteletKeepComments');

    my $strip = MockRequest->new(
        is_guest_flag => 0, nodedata => $target, vars => {noteletKeepComments => 1},
        postdata      => {notelet_source => $source, keep_comments => 0},
    );
    $r = $api->save($strip);
    is($r->[1]{keep_comments}, 0, 'keep_comments off: reported back as off');
    unlike($r->[1]{notelet_screened}, qr/<!--/, 'keep_comments off: comment removed');
    ok(!exists $strip->user->VARS->{noteletKeepComments}, 'keep_comments off: an existing setting is cleared');

    # A user who already has the setting sees it on when the editor loads.
    my $payload = $api->notelet_payload(MockRequest->new(
        is_guest_flag => 0, nodedata => $target, vars => {noteletKeepComments => 1, noteletRaw => $source},
    )->user);
    is($payload->{keep_comments}, 1, 'existing setting shows as on in the editor payload');

    # The old mismatched key is cleared on save and no longer read.
    my $stale = MockRequest->new(
        is_guest_flag => 0, nodedata => $target, vars => {nodeletKeepComments => 1},
        postdata      => {notelet_source => $source, keep_comments => 0},
    );
    $r = $api->save($stale);
    is($r->[1]{keep_comments}, 0, 'old key alone does not count as keep-comments');
    ok(!exists $stale->user->VARS->{nodeletKeepComments}, 'old key is cleared on save');
}

done_testing;
