#!/usr/bin/perl -w
# Everything::API::content_reports -- GET /api/content_reports (list) + /:driver (detail).
#
# The content-reports datastash work + the ?driver selector used to run inside
# Everything::Page::content_reports's buildReactData; it now lives in this editor-gated API
# (#4511), the Page is a pure gate, and React reads ?driver off the URL. The report LABELS live
# in React, so this API must ship only driver ids + backend-derived data (counts, node refs).

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::API::content_reports;
use MockRequest;

initEverything('development-docker');
ok($DB,  'Database connection established');
ok($APP, 'Application object created');

my $api = Everything::API::content_reports->new();
ok($api, 'Created content_reports API instance');

is_deeply($api->routes, { '/' => 'list', ':driver' => 'driver(:driver)' },
    'routes: / -> list, :driver -> driver(:driver)');

my $editor_req    = MockRequest->new(title => 'ed',   is_editor_flag => 1);
my $nonedit_req   = MockRequest->new(title => 'norm', is_editor_flag => 0);
my $guest_req     = MockRequest->new(title => 'Guest User', is_guest_flag => 1, is_editor_flag => 0);

#############################################################################
# Gate: only editors
#############################################################################
for my $case (['guest', $guest_req], ['non-editor', $nonedit_req]) {
    my ($label, $req) = @$case;
    my $r = $api->list($req);
    is($r->[0], $api->HTTP_OK, "list: $label -> HTTP 200 (never a 4xx)");
    is($r->[1]{success}, 0, "list: $label denied");
    is($r->[1]{error}, 'Editors only', "list: $label gets the editors-only error");

    my $d = $api->driver($req, 'editing_invalid_authors');
    is($d->[1]{success}, 0, "driver: $label denied");
}

#############################################################################
# list: editor -> view=list, reports carry driver+count and NO label copy
#############################################################################
my $list = $api->list($editor_req);
is($list->[0], $api->HTTP_OK, 'list: editor -> HTTP 200');
is($list->[1]{success}, 1, 'list: editor -> success');
is($list->[1]{view}, 'list', 'list: view=list');
is(ref($list->[1]{reports}), 'ARRAY', 'list: reports is an array');
if (@{$list->[1]{reports}}) {
    my $rep = $list->[1]{reports}[0];
    ok(exists $rep->{driver}, 'list: report row has driver id');
    ok(exists $rep->{count},  'list: report row has count');
    ok(!exists $rep->{title}, 'list: report row ships NO title (label lives in React)');
    like($rep->{count}, qr/^\d+$/, 'list: count is numeric');
}

#############################################################################
# driver: valid driver -> view=driver + nodes; invalid -> error flag, no copy
#############################################################################
my $valid = $api->driver($editor_req, 'editing_invalid_authors');
is($valid->[1]{success}, 1, 'driver(valid): success');
is($valid->[1]{view}, 'driver', 'driver(valid): view=driver');
is($valid->[1]{driver}, 'editing_invalid_authors', 'driver(valid): echoes the driver id');
ok(!$valid->[1]{error}, 'driver(valid): no error flag');
is(ref($valid->[1]{nodes}), 'ARRAY', 'driver(valid): nodes is an array');
for my $n (@{$valid->[1]{nodes}}) {
    ok(!exists $n->{error} || $n->{error} == 1, 'driver(valid): node error (if any) is a bare flag, not copy');
    last;
}

my $bogus = $api->driver($editor_req, 'no_such_driver_zzz');
is($bogus->[1]{success}, 1, 'driver(bogus): HTTP-level success (soft error)');
is($bogus->[1]{view}, 'driver', 'driver(bogus): view=driver');
is($bogus->[1]{driver}, 'no_such_driver_zzz', 'driver(bogus): echoes the id');
is($bogus->[1]{error}, 1, 'driver(bogus): error is a bare flag (copy lives in React)');
ok(!exists $bogus->[1]{nodes}, 'driver(bogus): no nodes');

done_testing();
