#!/usr/bin/perl -w

# Regression: a non-integer numwriteups (e.g. a stray ' ' in VARS) must not blow
# up the own-profile render. numwriteups is `int NOT NULL`, and under MySQL 8.4
# strict mode writing ' ' dies ("Incorrect integer value: ' '"). ' ' is truthy
# so the old `$settings->{numwriteups} || 0` let it through to updateNode.
# Fixed by int()-ing it in Everything::Controller::user::_setup_user_vars.

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
use Everything::Controller::user;

$SIG{__WARN__} = sub {
    my $w = shift;
    warn $w unless $w =~ /Could not open log/ || $w =~ /Use of uninitialized value/;
};

initEverything('development-docker');

my $APP = $Everything::APP;
my $DB  = $Everything::DB;

# Throwaway self-owned user (so the self-update in _setup_user_vars persists).
my $root  = $DB->getNode('root', 'user');
my $uname = 'numwstrict_' . time() . "_$$";
my $uid   = $DB->insertNode($uname, 'user', $root->{node_id}, {});
my ($p, $s) = $APP->saltNewPassword('pw123456');
$DB->sqlUpdate('node', { author_user => $uid }, "node_id=$uid");
$DB->sqlUpdate('user', { salt => $s, passwd => $p }, "user_id=$uid");

# Poison VARS with the bad value, and a fresh nwriteupsupdate so the recompute
# branch is skipped and the value flows straight to the int column.
my $uref = $DB->getNodeById($uid, 'force');
my $vars = $APP->getVars($uref);
$vars->{numwriteups}     = ' ';
$vars->{nwriteupsupdate} = time();
Everything::setVars($uref, $vars);
$DB->updateNode($uref, -1);
$DB->{cache}->flushCache() if $DB->{cache};

my $node       = $APP->node_by_id($uid);   # blessed user node (own profile)
my $controller = Everything::Controller::user->new();
ok($controller, 'constructed Everything::Controller::user');

my $ok = eval { $controller->_setup_user_vars($node, $node, 1); 1 };
ok($ok, '_setup_user_vars survives a non-integer numwriteups') or diag($@);

my $fresh = $DB->getNodeById($uid, 'force');
is($fresh->{numwriteups}, 0, 'numwriteups was coerced to int 0 on write');

# cleanup
$DB->sqlDelete('user', "user_id=$uid");
$DB->sqlDelete('node', "node_id=$uid");

done_testing();
