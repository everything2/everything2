#!/usr/bin/perl -w
# Everything::API::sqlprompt -- POST /api/sqlprompt/query (#4442, Refs #4298).
#
# The root-only SQL console's query execution used to run inside
# Everything::Page::sql_prompt's buildReactData (execute SQL + write the
# sqlprompt_wrap var off query params, during render). It now lives here, gated to
# the SAME username whitelist the page enforced (jaybonci, root) -- deliberately NOT
# is_admin. Tests the gate, empty-query rejection, a real query, hide_results, and
# the bad-SQL error path (a successful API call carrying a SQL-level error).
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::API::sqlprompt;
use MockRequest;

initEverything('development-docker');
ok($DB, 'Database connection established');

my $api = Everything::API::sqlprompt->new();
ok($api, 'Created sqlprompt API instance');
is_deeply($api->routes, {'query' => 'run_query'}, 'routes: query -> run_query');

#############################################################################
# Gate: a logged-in but non-whitelisted user is refused (200 + success=0)
#############################################################################
my $nonroot = MockRequest->new(title => 'normaluser1', postdata => {query => 'SELECT 1'});
my $r = $api->run_query($nonroot);
is($r->[0], $api->HTTP_OK, 'non-root returns 200 (never a 4xx from an API)');
is($r->[1]{success}, 0, 'non-root cannot run queries');
like($r->[1]{error}, qr/unauthorized/i, 'unauthorized error');

#############################################################################
# Root, empty query -> rejected
#############################################################################
$r = $api->run_query(MockRequest->new(title => 'root', postdata => {}));
is($r->[1]{success}, 0, 'empty query rejected');

#############################################################################
# Root, real query -> executes + returns an ordered result set
#############################################################################
$r = $api->run_query(MockRequest->new(
    title => 'root', postdata => {query => 'SELECT 1 AS one, 2 AS two'}));
is($r->[1]{success}, 1, 'root query succeeds');
is($r->[1]{results}{error}, 0, 'no SQL error');
is_deeply($r->[1]{results}{columns}, ['one', 'two'], 'columns echoed in order');
is($r->[1]{results}{rows_fetched}, 1, 'one row fetched');
is($r->[1]{results}{rows}[0]{one}{value}, 1, 'cell value present');

#############################################################################
# Root, hide_results -> query runs but no rows fetched
#############################################################################
$r = $api->run_query(MockRequest->new(
    title => 'root', postdata => {query => 'SELECT 1 AS one', hide_results => 1}));
is($r->[1]{success}, 1, 'hidden-results query succeeds');
is($r->[1]{results}{rows_fetched}, 0, 'hide_results suppresses row fetch');

#############################################################################
# Root, bad SQL -> successful API call carrying a SQL-level error
#############################################################################
$r = $api->run_query(MockRequest->new(
    title => 'root', postdata => {query => 'SELECT FROM WHERE bogus'}));
is($r->[1]{success}, 1, 'bad SQL is still a successful API call (HTTP_OK)');
is($r->[1]{results}{error}, 1, 'bad SQL flagged as a result-level error');
ok($r->[1]{results}{message}, 'an error message is present');

done_testing;
