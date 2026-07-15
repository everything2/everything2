#!/usr/bin/perl -w
# The numbered new-nodes consolidation (#4537): 25 / everything_new_nodes / e2n / enn / ekn were
# five identical Pages differing only by a record count. The count now lives in React config and
# this one API serves them all. Pins the records clamp (injection surface), the payload shape, and
# the notnew JSON-boolean (#4108).

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::API::newnodes;
use MockRequest;

initEverything('development-docker');
ok($DB, 'DB connection established');

my $api = Everything::API::newnodes->new;
is_deeply($api->routes, { '/' => 'list' }, 'newnodes: routes');

my $call = sub { $api->list(MockRequest->new(is_guest_flag => 0, query_params => { %{$_[0] || {}} })) };

#############################################################################
# Shape
#############################################################################
my $r = $call->({ records => 5 });
is($r->[0], $api->HTTP_OK, 'returns HTTP 200');
is($r->[1]{success}, 1, 'success');
is($r->[1]{records}, 5, 'records echoed');
ok(ref($r->[1]{nodelist}) eq 'ARRAY', 'nodelist is an array');
cmp_ok(scalar(@{$r->[1]{nodelist}}), '<=', 5, 'at most `records` rows');

SKIP: {
    my $row = $r->[1]{nodelist}[0];
    skip 'no writeups in dev DB', 5 unless $row;
    like("$row->{node_id}",   qr/^\d+$/, 'node_id present');
    like("$row->{author_id}", qr/^\d+$/, 'author_id present');
    ok(exists $row->{parent_title} && exists $row->{author_name}, 'parent_title + author_name present');
    ok(exists $row->{writeuptype} && exists $row->{publishtime}, 'writeuptype + publishtime present');
    # notnew must be a JSON boolean (\1/\0), NOT a "0"/"1" string that JS would mis-truth (#4108)
    is(ref($row->{notnew}), 'SCALAR', 'notnew is a JSON boolean (scalar ref), not a string');
}

#############################################################################
# records clamp -- it flows into LIMIT, so it must be int + bounded (1..1024)
#############################################################################
is($call->({ records => 99999 })->[1]{records}, 1024, 'records capped at 1024');
is($call->({ records => 0 })->[1]{records},     25,   'records 0 is falsy -> default 25');
is($call->({ records => -5 })->[1]{records},    1,    'negative records -> 1');
is($call->({ records => 'abc' })->[1]{records}, 1,    'non-numeric records -> 1 (int strips)');
is($call->({})->[1]{records},                   25,   'default records = 25 when absent');

# an injection attempt is stripped to its leading digits by int(), never interpolated raw
is($call->({ records => '5; DROP TABLE writeup; --' })->[1]{records}, 5,
    'records injection stripped to 5 (int, injection-safe)');

done_testing();
