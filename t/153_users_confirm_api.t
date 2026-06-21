#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching RequireDotMatchAnything)
## no critic (ValuesAndExpressions ProhibitInterpolationOfLiterals ProhibitMagicNumbers ProhibitEmptyQuotes)

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "$FindBin::Bin/lib";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;
use Everything::API::users;
use MockRequest;

$SIG{__WARN__} = sub {
    my $w = shift;
    warn $w unless $w =~ /Could not open log/ || $w =~ /Use of uninitialized value/;
};

initEverything('development-docker');

my $APP = $Everything::APP;
my $DB  = $Everything::DB;
my $api = Everything::API::users->new();

ok($api, 'Created users API instance');

# ---------------------------------------------------------------------------
# Throwaway test user with an established salt.
# ---------------------------------------------------------------------------
my $root  = $DB->getNode('root', 'user');
my $uname = 'confirmtest_' . time() . "_$$";
my $uid   = $DB->insertNode($uname, 'user', $root->{node_id}, {});
ok($uid, "created throwaway user $uname ($uid)");

# Real users own themselves; insertNode made root the author, which would block
# the self-update inside updatePassword/checkToken. Fix ownership + seed a known
# salt/passwd via direct SQL (updateNode on a bare inserted user won't persist).
my ($ipass, $isalt) = $APP->saltNewPassword('initpass');
$DB->sqlUpdate('node', { author_user => $uid }, "node_id=$uid");
$DB->sqlUpdate('user', { salt => $isalt, passwd => $ipass }, "user_id=$uid");
$DB->{cache}->flushCache() if $DB->{cache};    # drop the salt-less cached insert
my $tuser = $DB->getNode($uname, 'user', 'force');
ok($tuser->{salt}, 'test user has a salt');

my $virgil = $DB->getNode('Virgil', 'user');

# Helper: build a confirm request
sub confirm_req {
    my (%p) = @_;
    return MockRequest->new(postdata => { %p });
}

# ---------------------------------------------------------------------------
# Failure branches (these never reach login()).
# ---------------------------------------------------------------------------
is($api->confirm(confirm_req(action => 'reset', expiry => time() + 600))->[1]{state},
    'missing_params', 'missing token/username -> missing_params');

is($api->confirm(confirm_req(username => $uname, token => 'x', action => 'frobnicate',
        expiry => time() + 600))->[1]{state},
    'invalid_action', 'bad action -> invalid_action');

is($api->confirm(confirm_req(username => 'no_such_user_zzz_' . time(), token => 'x',
        action => 'reset', expiry => time() + 600))->[1]{state},
    'no_user', 'unknown user -> no_user');

is($api->confirm(confirm_req(username => $uname, token => 'x', action => 'reset',
        expiry => time() - 10))->[1]{state},
    'expired', 'past expiry -> expired');

# Valid-looking request but wrong token -> login_required (checkToken fails)
is($api->confirm(confirm_req(username => $uname, passwd => 'whatever',
        token => 'totally-bogus-token', action => 'reset', expiry => time() + 600))->[1]{state},
    'login_required', 'bad token -> login_required');

# Right token for passA but submitting passB -> getToken mismatch -> login_required
{
    my $expiry = time() + 600;
    my $token  = $APP->getToken($tuser, 'passA', 'reset', $expiry);
    is($api->confirm(confirm_req(username => $uname, passwd => 'passB',
            token => $token, action => 'reset', expiry => $expiry))->[1]{state},
        'login_required', 'token/password mismatch -> login_required');
}

# acctlock + activate -> locked
{
    $DB->sqlUpdate('user', { acctlock => 1 }, "user_id=$uid");
    $DB->{cache}->flushCache() if $DB->{cache};   # so confirm's getNode sees acctlock=1
    my $expiry = time() + 600;
    my $token  = $APP->getToken($DB->getNode($uname, 'user', 'force'), 'p', 'activate', $expiry);
    is($api->confirm(confirm_req(username => $uname, passwd => 'p',
            token => $token, action => 'activate', expiry => $expiry))->[1]{state},
        'locked', 'acctlocked activate -> locked');
    $DB->sqlUpdate('user', { acctlock => 0 }, "user_id=$uid");
    $DB->{cache}->flushCache() if $DB->{cache};
}

# ---------------------------------------------------------------------------
# RESET happy path -> password actually changes + logs in.
# ---------------------------------------------------------------------------
{
    my $newpass = 'resetpass_' . time();
    my $expiry  = time() + 600;
    my $u       = $DB->getNode($uname, 'user', 'force');
    my $token   = $APP->getToken($u, $newpass, 'reset', $expiry);

    my $req = confirm_req(username => $uname, passwd => $newpass,
        token => $token, action => 'reset', expiry => $expiry);
    my ($s, $r) = @{ $api->confirm($req) };

    is($s, $api->HTTP_OK, 'reset -> HTTP_OK');
    ok($r->{success}, 'reset -> success');
    is($r->{state}, 'success_reset', 'reset -> success_reset');

    my $fresh = $DB->getNode($uname, 'user', 'force');
    is($APP->hashString($newpass, $fresh->{salt}), $fresh->{passwd},
        'reset actually updated the stored password');
    ok(!$req->is_guest, 'logged in after reset');
    is($req->user->title, $uname, 'logged in as the right user');
}

# ---------------------------------------------------------------------------
# ACTIVATE happy path -> password set, logged in, Virgil welcome PM sent.
# ---------------------------------------------------------------------------
{
    my $actpass = 'actpass_' . time();
    my $expiry  = time() + 600;
    my $u       = $DB->getNode($uname, 'user', 'force');
    my $token   = $APP->getToken($u, $actpass, 'activate', $expiry);

    my $pm_before = $virgil ? $DB->sqlSelect('count(*)', 'message',
        "for_user=$uid AND author_user=$virgil->{node_id}") : 0;

    my $req = confirm_req(username => $uname, passwd => $actpass,
        token => $token, action => 'activate', expiry => $expiry);
    my ($s, $r) = @{ $api->confirm($req) };

    is($r->{state}, 'success_activate', 'activate -> success_activate');
    is($r->{profileUrl}, "/node/$uid", 'activate returns the profile URL');

    my $fresh = $DB->getNode($uname, 'user', 'force');
    is($APP->hashString($actpass, $fresh->{salt}), $fresh->{passwd},
        'activate set the stored password');
    ok(!$req->is_guest, 'logged in after activate');

  SKIP: {
        skip 'no Virgil user', 1 unless $virgil;
        my $pm_after = $DB->sqlSelect('count(*)', 'message',
            "for_user=$uid AND author_user=$virgil->{node_id}");
        is($pm_after, $pm_before + 1, 'activation sent the Virgil welcome PM');
    }
}

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
$DB->sqlDelete('message', "for_user=$uid OR author_user=$uid");
$DB->sqlDelete('user', "user_id=$uid");
$DB->sqlDelete('node', "node_id=$uid");

done_testing();
