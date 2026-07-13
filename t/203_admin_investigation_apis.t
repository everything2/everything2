#!/usr/bin/perl -w
# The admin-investigation-tools report -> API tranche (#4530): ip_hunter, who_killed_what,
# voting_data. Each moved its params + query out of a Page (now a pure gate) into an admin-gated API.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use JSON;
use Everything;
use Everything::API::ip_hunter;
use Everything::API::who_killed_what;
use Everything::API::voting_data;
use MockRequest;

initEverything('development-docker');
ok($DB, 'DB connection established');

my $admin    = sub { MockRequest->new(is_admin_flag => 1, is_guest_flag => 0, query_params => { %{$_[0] || {}} }) };
my $nonadmin = sub { MockRequest->new(is_admin_flag => 0, is_guest_flag => 0, query_params => { %{$_[0] || {}} }) };

# A node_id must serialize as a JSON number, not a string (#4152). Encode the payload
# and assert the raw JSON has no quoted digits for the given key.
sub is_json_number {
    my ($payload, $key) = @_;
    my $json = JSON->new->encode($payload);
    unlike($json, qr/"\Q$key\E"\s*:\s*"/, "$key serializes as a JSON number, not a string (#4152)");
}

#############################################################################
# ip_hunter -- admin only
#############################################################################
my $ih = Everything::API::ip_hunter->new;
is_deeply($ih->routes, { '/' => 'list' }, 'ip_hunter: routes');

is($ih->list($nonadmin->())->[1]{state}, 'admin', 'ip_hunter: non-admin -> admin state');

my $shell = $ih->list($admin->());
is($shell->[1]{success}, 1, 'ip_hunter: admin no-search -> shell');
ok(!$shell->[1]{search_type}, 'ip_hunter: shell has no search_type');
is($shell->[1]{result_limit}, 500, 'ip_hunter: result_limit echoed');

my $iu = $ih->list($admin->({ hunt_name => 'root' }));
is($iu->[1]{success}, 1, 'ip_hunter: user search ok');
is($iu->[1]{search_type}, 'user', 'ip_hunter: search_type user');
ok(ref($iu->[1]{results}) eq 'ARRAY', 'ip_hunter: results array');
is_json_number($iu->[1], 'user_id');

is($ih->list($admin->({ hunt_name => 'no_such_user_zzz' }))->[1]{state}, 'user_not_found',
    'ip_hunter: unknown user -> user_not_found');

# IP search: a bogus documentation IP returns an (empty) result set, never dies.
my $ii = $ih->list($admin->({ hunt_ip => '192.0.2.123' }));
is($ii->[1]{success}, 1, 'ip_hunter: ip search ok');
is($ii->[1]{search_type}, 'ip', 'ip_hunter: search_type ip');
# an injection attempt in the IP is quoted, never interpolated raw -> still just returns rows/none
my $inj = $ih->list($admin->({ hunt_ip => "1.2.3.4' OR '1'='1" }));
is($inj->[1]{success}, 1, 'ip_hunter: quoted IP injection attempt is safe');

#############################################################################
# who_killed_what -- admin only
#############################################################################
my $wkw = Everything::API::who_killed_what->new;
is($wkw->list($nonadmin->())->[1]{state}, 'admin', 'who_killed_what: non-admin -> admin state');

# default target = the acting admin (here: a mock admin, node_id 1 via MockUser default)
my $wself = $wkw->list($admin->());
is($wself->[1]{success}, 1, 'who_killed_what: default (self) ok');
ok(exists $wself->[1]{total_kills} && ref($wself->[1]{kills}) eq 'ARRAY',
    'who_killed_what: total_kills + kills');

my $wr = $wkw->list($admin->({ heavenuser => 'root' }));
is($wr->[1]{success}, 1, 'who_killed_what: root ok');
is($wr->[1]{target_user}, 'root', 'who_killed_what: target echoed');
is_json_number($wr->[1], 'target_user_id');

is($wkw->list($admin->({ heavenuser => 'no_such_user_zzz' }))->[1]{state}, 'user_not_found',
    'who_killed_what: unknown user -> user_not_found');

# limit is clamped
is($wkw->list($admin->({ heavenuser => 'root', limit => 99999 }))->[1]{limit}, 500,
    'who_killed_what: limit clamped to 500');

#############################################################################
# voting_data -- admin only
#############################################################################
my $vd = Everything::API::voting_data->new;
is($vd->list($nonadmin->())->[1]{state}, 'admin', 'voting_data: non-admin -> admin state');

my $vr = $vd->list($admin->({ voteday => '2020-01-01' }));
is($vr->[1]{success}, 1, 'voting_data: date range ok');
is($vr->[1]{search_type}, 'date_range', 'voting_data: date_range type');
is(scalar(@{$vr->[1]{results}}), 1, 'voting_data: one date-range row');

my $vm = $vd->list($admin->({ votemonth => 1, voteyear => 2020 }));
is($vm->[1]{search_type}, 'monthly', 'voting_data: monthly type');
is(scalar(@{$vm->[1]{results}}), 31, 'voting_data: 31 daily rows');

# a garbage date is stripped to digits/dashes before it can be interpolated (injection-safe)
my $vinj = $vd->list($admin->({ voteday => "2020-01-01'; DROP TABLE vote; --" }));
is($vinj->[1]{success}, 1, 'voting_data: garbage date survives (stripped, injection-safe)');
like($vinj->[1]{voteday}, qr/^[\d-]+$/, 'voting_data: voteday sanitized to digits/dashes');

done_testing();
