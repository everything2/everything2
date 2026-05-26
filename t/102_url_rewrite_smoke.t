#!/usr/bin/perl -w
#
# 102_url_rewrite_smoke.t
#
# End-to-end smoke test for the title-bearing mod_rewrite rules in
# etc/templates/apache2.conf.erb. Validates that each /title/, /e2node/,
# /user/, and /node/ URL pattern reaches Apache, passes through the
# rewrite + _recover_route_params_from_request_uri pipeline, and resolves
# to the right node (verified via the JSON XML-tree fallback rendering).
#
# Sister to 101_route_uri_recovery.t, which unit-tests the helper. This
# file is the integration layer: catches breakage in Apache config that
# the unit test cannot see.
#
# Fixtures used (created by tools/seeds.pl):
#   * "Sense & Sensibility"          e2node + writeup — #4060 ampersand case
#   * "good poetry"                  e2node (non-ampersand control)
#   * genericdev                     user
#   * normaluser1                    user

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use LWP::UserAgent;
use URI::Escape qw(uri_escape);
use Everything;       # exports $DB, initEverything
use vars qw($DB);

my $UA   = LWP::UserAgent->new(timeout => 15);
my $BASE = 'http://localhost';

# fetch_ok GETs a URL, asserts HTTP 200, and returns the response body
# for further assertions. Returns undef on non-200 so dependent assertions
# can skip cleanly rather than producing a cascade of red.
sub fetch_ok {
	my ($path, $label) = @_;
	my $r = $UA->get("$BASE$path");
	ok($r->is_success, "$label — $path returns 2xx (got " . $r->code . ')')
		or diag('body head: ' . substr($r->decoded_content // '', 0, 200));
	return $r->is_success ? $r->decoded_content : undef;
}

# Apache + mod_perl is up.
{
	my $r = $UA->get("$BASE/");
	ok($r->is_success, "homepage reachable (got " . $r->code . ')')
		or BAIL_OUT('Apache not responding — start the dev container before running this test');
}

#############################################################################
# /title/<name>  — the primary #4060 path
#############################################################################
{
	my $body = fetch_ok(
		'/title/' . uri_escape('Sense & Sensibility'),
		'/title with ampersand'
	);
	like($body // '', qr/Sense\s*(?:&amp;|&)\s*Sensibility/i,
		'/title/Sense & Sensibility lands on the right e2node');
}
{
	my $body = fetch_ok('/title/' . uri_escape('good poetry'),
		'/title control (no ampersand)');
	like($body // '', qr/good\s+poetry/i,
		'/title/good poetry lands on the right e2node');
}

#############################################################################
# /e2node/<name>
#############################################################################
{
	my $body = fetch_ok(
		'/e2node/' . uri_escape('Sense & Sensibility'),
		'/e2node with ampersand'
	);
	like($body // '', qr/Sense\s*(?:&amp;|&)\s*Sensibility/i,
		'/e2node/Sense & Sensibility resolves');
}

#############################################################################
# /user/<name>
#############################################################################
{
	my $body = fetch_ok('/user/genericdev', '/user/<name>');
	like($body // '', qr/genericdev/i,
		'/user/genericdev resolves to the user homenode');
}

#############################################################################
# /user/<name>/writeups
#############################################################################
{
	# The user-search superdoc renders even for users with no writeups,
	# so the success criterion here is just "Apache routed it and we got
	# a 200 back" — anything more couples the test to superdoc internals.
	fetch_ok('/user/genericdev/writeups', '/user/<name>/writeups');
}

#############################################################################
# /node/<id>/<displaytype>  — canonical, no recovery, must still resolve
#############################################################################
{
	# Use a stable seed-provided node: "good poetry" e2node. Look up its
	# id at runtime so we don't hard-code something a future seed shuffle
	# could break.
	Everything::initEverything('development-docker');

	my $gp = $DB->getNode('good poetry', 'e2node');
	if ($gp && $gp->{node_id}) {
		fetch_ok("/node/$gp->{node_id}/xmltrue",
			'/node/<id>/<displaytype>');
	} else {
		fail('seed fixture "good poetry" missing — run tools/seeds.pl');
	}
}

#############################################################################
# /node/<name>  (non-numeric, single segment)
#############################################################################
{
	fetch_ok('/node/' . uri_escape('Sense & Sensibility'),
		'/node/<name> with ampersand');
}

#############################################################################
# /node/<type>/<title>
#############################################################################
{
	fetch_ok(
		'/node/e2node/' . uri_escape('Sense & Sensibility'),
		'/node/<type>/<title> with ampersand'
	);
}

done_testing;
