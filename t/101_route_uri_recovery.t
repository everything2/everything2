#!/usr/bin/perl -w
#
# 101_route_uri_recovery.t
#
# Unit-test Everything::HTML::_recover_route_params_from_request_uri.
# This is the helper that re-derives node/type/author CGI params from the
# raw REQUEST_URI to work around the lossy title-bearing mod_rewrite rules
# in etc/templates/apache2.conf.erb (issue #4060).
#
# Each pattern in the helper gets a positive case plus a percent-encoded
# variant where Apache would otherwise have mangled the title.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything::HTML;

# Minimal CGI stand-in: captures param() writes into a flat hash. Only
# the (name => value) setter form is used by the helper, which keeps this
# mock trivial. Don't widen it without checking the helper still needs it.
package FakeCGI;
sub new   { return bless { _p => {} }, shift }
sub param {
	my ($self, $name, $value) = @_;
	if (@_ >= 3) { $self->{_p}{$name} = $value; return $value; }
	return $self->{_p}{$name};
}
sub all   { return $_[0]->{_p} }
package main;

# Run the helper with a given REQUEST_URI and return the resulting params.
sub recover {
	my ($uri) = @_;
	local $ENV{REQUEST_URI} = $uri;
	my $q = FakeCGI->new;
	Everything::HTML::_recover_route_params_from_request_uri($q);
	return $q->all;
}

#############################################################################
# Pattern: /title/<name>  — primary #4060 case
#############################################################################
{
	my $p = recover('/title/good%20poetry');
	is($p->{node}, 'good poetry', '/title/ decodes %20 to space');
	ok(!exists $p->{type}, '/title/ leaves type alone');
}
{
	my $p = recover('/title/Sense%20%26%20Sensibility');
	is($p->{node}, 'Sense & Sensibility',
		'/title/ decodes %26 to & — the #4060 regression case');
}
{
	# Query string must not leak into the captured node title.
	my $p = recover('/title/Sense%20%26%20Sensibility?displaytype=xmltrue');
	is($p->{node}, 'Sense & Sensibility',
		'/title/ strips query string before matching');
}
{
	# Trailing slash variant.
	my $p = recover('/title/good%20poetry/');
	is($p->{node}, 'good poetry', '/title/ tolerates a trailing slash');
}

#############################################################################
# Pattern: /e2node/<name>
#############################################################################
{
	my $p = recover('/e2node/Sense%20%26%20Sensibility');
	is($p->{node}, 'Sense & Sensibility', '/e2node/ decodes ampersand title');
}

#############################################################################
# Pattern: /user/<name>
#############################################################################
{
	my $p = recover('/user/genericdev');
	is($p->{node}, 'genericdev',  '/user/ sets node to username');
	is($p->{type}, 'user',        '/user/ sets type=user');
}
{
	my $p = recover('/user/user%20with%20space');
	is($p->{node}, 'user with space', '/user/ decodes %20 in username');
	is($p->{type}, 'user',            '/user/ still tags type=user when decoding');
}

#############################################################################
# Pattern: /user/<name>/writeups
#############################################################################
{
	my $p = recover('/user/genericdev/writeups');
	is($p->{usersearch}, 'genericdev',                '/user/X/writeups sets usersearch');
	is($p->{node},       'everything user search',    '/user/X/writeups routes to user-search superdoc');
	is($p->{type},       'superdoc',                  '/user/X/writeups sets type=superdoc');
}

#############################################################################
# Pattern: /user/<name>/writeups/<title>  — most specific, tested first
#############################################################################
{
	my $p = recover('/user/normaluser1/writeups/Sense%20%26%20Sensibility%20%28thing%29');
	is($p->{author}, 'normaluser1',                       '/user/X/writeups/Y sets author');
	is($p->{node},   'Sense & Sensibility (thing)',       '/user/X/writeups/Y decodes title');
	is($p->{type},   'writeup',                           '/user/X/writeups/Y sets type=writeup');
}

#############################################################################
# Pattern: /node/<id>/<displaytype>  — already-canonical, no recovery
#############################################################################
{
	my $p = recover('/node/2219931/xmltrue');
	is(scalar keys %$p, 0, '/node/<id>/<displaytype> leaves params untouched (already canonical)');
}

#############################################################################
# Pattern: /node/<name>  (non-numeric first segment, no further path)
#############################################################################
{
	my $p = recover('/node/genericdev');
	is($p->{node}, 'genericdev', '/node/<name> sets node from path');
}
{
	my $p = recover('/node/Sense%20%26%20Sensibility');
	is($p->{node}, 'Sense & Sensibility',
		'/node/<name> decodes ampersand title');
}

#############################################################################
# Pattern: /node/<type>/<title>  — only when first segment is non-numeric
#############################################################################
{
	my $p = recover('/node/e2node/Sense%20%26%20Sensibility');
	is($p->{type}, 'e2node',              '/node/<type>/<title> sets type');
	is($p->{node}, 'Sense & Sensibility', '/node/<type>/<title> decodes title');
}
{
	# Numeric first segment must NOT be reinterpreted as a type.
	# Per the helper, /node/<id>/<word> falls into the earlier branch and is
	# left alone; this guards against a future regex shuffle.
	my $p = recover('/node/2219931/xmltrue');
	ok(!exists $p->{type},
		'/node/<id>/<word> leaves type unset (numeric guard)');
}

#############################################################################
# #4143: '+' in the path must decode to space (legacy E2 convention used by
# hard-coded URLs like Messages.js's /title/Message+Inbox). Apache + CGI used
# to handle this for free; once the helper started overriding CGI params from
# REQUEST_URI, it had to honor the same convention or the inbox link 404s.
#############################################################################
{
	my $p = recover('/title/Message+Inbox');
	is($p->{node}, 'Message Inbox',
		'/title/Foo+Bar decodes "+" to space — the #4143 inbox link case');
}
{
	# Encoded plus survives as a literal plus — the "C++" guarantee that
	# justifies decoding bare '+' as space in the first place.
	my $p = recover('/title/C%2B%2B');
	is($p->{node}, 'C++',
		'/title/ preserves %2B as literal "+" (C++ titles still work)');
}
{
	# Mixed: encoded plus AND bare plus in the same captured segment.
	my $p = recover('/title/foo+bar%2Bbaz');
	is($p->{node}, 'foo bar+baz',
		'/title/ handles bare "+" and "%2B" independently in one segment');
}
{
	# /user/Foo+Bar route also has to honor the convention.
	my $p = recover('/user/user+with+plus');
	is($p->{node}, 'user with plus', '/user/ decodes "+" to space');
}

#############################################################################
# Defensive: missing / empty REQUEST_URI is a no-op
#############################################################################
{
	local $ENV{REQUEST_URI};
	delete $ENV{REQUEST_URI};
	my $q = FakeCGI->new;
	Everything::HTML::_recover_route_params_from_request_uri($q);
	is(scalar keys %{$q->all}, 0, 'undef REQUEST_URI is a no-op');
}
{
	my $q = FakeCGI->new;
	local $ENV{REQUEST_URI} = '';
	Everything::HTML::_recover_route_params_from_request_uri($q);
	is(scalar keys %{$q->all}, 0, 'empty REQUEST_URI is a no-op');
}

#############################################################################
# Defensive: a path that matches none of the routes is also a no-op
#############################################################################
{
	my $p = recover('/some/random/api/path');
	is(scalar keys %$p, 0, 'unmatched path leaves params untouched');
}

done_testing;
