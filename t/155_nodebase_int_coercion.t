#!/usr/bin/perl -w

# Regression: NodeBase::updateNode must not let a non-numeric value reach an
# integer column. MySQL 8.4 strict mode rejects ' '/''/'abc' for int columns
# ("Incorrect integer value") where older MySQL silently coerced to 0. updateNode
# now coerces integer-typed columns at the write layer (restoring the lenient
# behavior) so the whole class -- numwriteups, gotoNode's generic edit handler,
# draft publication_status, etc. -- can't crash a request.

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

$SIG{__WARN__} = sub {
    my $w = shift;
    warn $w unless $w =~ /Could not open log/ || $w =~ /Use of uninitialized value/;
};

initEverything('development-docker');

my $APP = $Everything::APP;
my $DB  = $Everything::DB;

# Self-owned throwaway user: node.reputation + user.numwriteups/experience are
# all int columns across two joined tables.
my $root  = $DB->getNode('root', 'user');
my $uname = 'intcoerce_' . time() . "_$$";
my $uid   = $DB->insertNode($uname, 'user', $root->{node_id}, {});
$DB->sqlUpdate('node', { author_user => $uid }, "node_id=$uid");

# Seed clean non-zero values so a later -> 0 coercion is observable.
{
    my $n = $DB->getNode($uname, 'user', 'force');
    $n->{reputation}  = 5;
    $n->{numwriteups} = 3;
    $n->{experience}  = 8;
    $DB->updateNode($n, -1);
}
is($DB->sqlSelect('reputation', 'node', "node_id=$uid"), 5, 'seed reputation=5');

# Poison with non-numeric strings across both tables.
my $n = $DB->getNode($uname, 'user', 'force');
$n->{reputation}  = ' ';       # space  -> 0
$n->{numwriteups} = ' 42 ';    # padded -> 42
$n->{experience}  = 'abc';     # junk   -> 0
my $ok = eval { $DB->updateNode($n, -1); 1 };
ok($ok, 'updateNode survives non-numeric integer values') or diag($@);

is($DB->sqlSelect('reputation',  'node', "node_id=$uid"), 0,  "node.reputation ' '  coerced to 0");
is($DB->sqlSelect('numwriteups', 'user', "user_id=$uid"), 42, "user.numwriteups ' 42 ' coerced to 42");
is($DB->sqlSelect('experience',  'user', "user_id=$uid"), 0,  "user.experience 'abc' coerced to 0");

# Valid integers (incl. negative and zero) pass through untouched.
{
    my $v = $DB->getNode($uname, 'user', 'force');
    $v->{reputation}  = -3;
    $v->{numwriteups} = 9;
    $v->{experience}  = 0;
    $DB->updateNode($v, -1);
}
is($DB->sqlSelect('reputation',  'node', "node_id=$uid"), -3, 'valid negative int preserved');
is($DB->sqlSelect('numwriteups', 'user', "user_id=$uid"), 9,  'valid int preserved');
is($DB->sqlSelect('experience',  'user', "user_id=$uid"), 0,  'valid zero preserved');

# cleanup
$DB->sqlDelete('user', "user_id=$uid");
$DB->sqlDelete('node', "node_id=$uid");

done_testing();
