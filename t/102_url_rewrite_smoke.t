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

# Some round-trip tests follow the server's 303 redirect-to-canonical;
# leave that on (the default) so we can assert we land on the right node
# and don't infinite-loop. A second UA with redirects off is used to
# inspect the redirect URL itself.
my $UA_NOFOLLOW = LWP::UserAgent->new(timeout => 15, max_redirect => 0);

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
# /title/Foo+Bar — legacy '+'-as-space convention used by hard-coded links
# like Messages.js's inbox link (#4143).
#############################################################################
{
	# Message Inbox is a real superdoc on prod and seeded in dev.
	my $body = fetch_ok('/title/Message+Inbox', '/title/<name>+<name>');
	like($body // '', qr/Message\s+Inbox/i,
		'/title/Message+Inbox resolves to the Message Inbox superdoc');
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

#############################################################################
# #4145 — redirect-to-canonical round-trip
#
# Direct-search hits trigger a 303 from urlGen using rewriteCleanEscape.
# If the encoder double-encodes or the helper mis-parses the result,
# users infinite-loop between the canonical URL and the Findings page.
#
# The cases below cover every special-char class that has caused trouble:
#   * apostrophe (#4145 — Clockmaker / Neiboku's Secret Library)
#   * ampersand  (#4060 — JD / Sense & Sensibility)
#   * literal +  (Writeups+plusses, a lesson in love)
#   * multi-space (#3418 — preserves the run)
#
# Each case checks four things:
#   (a) the search form URL (?node=…) lands on the right node
#   (b) the canonical URL (rewriteCleanEscape output) lands on the same
#       node
#   (c) the response is the node page, NOT Findings — which would mean
#       the redirect mis-parsed
#   (d) following the 303 chain doesn't visit the same URL twice
#       (explicit infinite-loop detection)
#############################################################################

# follow_chain — walk a redirect chain manually, capturing every URL
# visited. Returns (final_response, \@chain). Fails the test loudly if any
# URL repeats (the smoking gun for the #4145 loop).
sub follow_chain {
	my ($start_path, $label, $max_hops) = @_;
	$max_hops //= 5;
	my @chain = ($start_path);
	my %seen  = ($start_path => 1);
	my $r;
	for (1 .. $max_hops) {
		$r = $UA_NOFOLLOW->get("$BASE$chain[-1]");
		last unless $r->code =~ /^30[1237]$/;
		my $next = $r->header('Location') // '';
		# Strip absolute scheme/host if present (server returns relative URL,
		# but be defensive).
		$next =~ s{^https?://[^/]+}{};
		if ($seen{$next}++) {
			fail("$label — redirect loop detected, chain: " . join(' -> ', @chain, $next));
			return ($r, \@chain);
		}
		push @chain, $next;
	}
	pass("$label — no redirect loop (chain length " . scalar(@chain) . ')');
	return ($r, \@chain);
}

# resolve_and_check — full round-trip assertion for one title. Searches
# via ?node=, follows any redirects (loop-checking), then asserts the
# final body contains the title and is not the Findings page.
sub resolve_and_check {
	my ($title, $body_match) = @_;
	$body_match //= qr/\Q$title\E/i;

	my $query_url = '/?node=' . uri_escape($title);
	my ($r, $chain) = follow_chain($query_url,
		"resolve '$title' from search form");

	ok($r->is_success, "'$title' resolves with 2xx (chain: "
		. join(' -> ', @$chain) . ')')
		or diag('final code ' . $r->code . ', body head: '
			. substr($r->decoded_content // '', 0, 200));

	my $body = $r->decoded_content // '';
	like($body, $body_match,
		"'$title' response mentions the title we asked for");
	unlike($body, qr/Here's the stuff we found when you searched/,
		"'$title' lands on node page, not Findings (no bounce)");

	# Now hit the canonical URL directly — rewriteCleanEscape output.
	# This is the URL urlGen would generate for the redirect.
	my $canonical = '/title/' . $APP->rewriteCleanEscape($title);
	my ($r2, $chain2) = follow_chain($canonical,
		"resolve '$title' from canonical URL ($canonical)");
	ok($r2->is_success, "canonical URL for '$title' resolves with 2xx");
	my $body2 = $r2->decoded_content // '';
	like($body2, $body_match,
		"canonical URL for '$title' lands on the right node");
	unlike($body2, qr/Here's the stuff we found when you searched/,
		"canonical URL for '$title' is the actual node, not Findings");
}

{
	# Apostrophe — the Clockmaker case.
	my $apos = $DB->getNode("Neiboku's Secret Library", 'e2node');
	if (!$apos) {
		fail("seed fixture \"Neiboku's Secret Library\" missing — run tools/seeds.pl");
	} else {
		resolve_and_check("Neiboku's Secret Library", qr/Neiboku/i);
	}
}

{
	# Ampersand — the JD case (already covered by #4060 but this exercises
	# the new redirect path too).
	my $amp = $DB->getNode('Sense & Sensibility', 'e2node');
	if (!$amp) {
		fail('seed fixture "Sense & Sensibility" missing — run tools/seeds.pl');
	} else {
		resolve_and_check('Sense & Sensibility', qr/Sense/i);
	}
}

{
	# Literal plus in title — seeded by the existing front-page fixture set.
	my $plus = $DB->getNode('Writeups+plusses, a lesson in love', 'e2node');
	if ($plus) {
		resolve_and_check('Writeups+plusses, a lesson in love',
			qr/Writeups\+plusses/i);
	} else {
		diag('skipping literal-plus case — fixture not present in this dev DB');
	}
}

{
	# Hash in title — JD/cruxfau case (#4132). Single % verifies that the
	# encoded URL round-trips correctly: LinkNode emits '%23' for '#', the
	# server-side helper decodes it back to '#' for lookup.
	my $hash = $DB->getNode('Star Trek #9: Triangle', 'e2node');
	if ($hash) {
		resolve_and_check('Star Trek #9: Triangle',
			qr/Star\s+Trek\s+#9/i);
	} else {
		diag('skipping hash case — fixture not present (re-run qareload)');
	}
}

{
	# Multi-space title — #3418 fixture. Verifies both that
	# rewriteCleanEscape preserves the run (as %20%20) and that the helper
	# decodes it back to a real double space.
	my $ms = $DB->getNode(
		'I was raised on red pepper and blood.  I am so hot if you strike me I will light like a match.',
		'e2node');
	if ($ms) {
		resolve_and_check(
			'I was raised on red pepper and blood.  I am so hot if you strike me I will light like a match.',
			qr/red pepper and blood/i);
	} else {
		diag('skipping multi-space case — fixture not present');
	}
}

#############################################################################
# Loop-detection sanity: confirm follow_chain actually catches loops.
# Build a deliberately wrong URL that we know will route to Findings, then
# confirm follow_chain reports no loop (Findings doesn't redirect, just
# renders). This is the negative control for the loop-detector itself.
#############################################################################
{
	# Truly-bogus search routes to the "Nothing Found" superdoc (terminal),
	# not Findings. Either way, the property the loop-detector cares about
	# is "didn't redirect-loop" — both terminal pages satisfy it.
	my ($r, $chain) = follow_chain(
		'/?node=' . uri_escape('definitely-not-a-real-node-xyz-12345'),
		'loop-detector control — bogus search reaches a terminal page without looping');
	ok($r->is_success, 'bogus search resolves with 2xx (terminal page)');
	like($r->decoded_content // '',
		qr/Here's the stuff we found when you searched|Nothing Found|nothing_found/,
		'bogus search reaches Findings or Nothing Found (either is fine for the control)');
}

done_testing;
