#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching RequireDotMatchAnything)
## no critic (ValuesAndExpressions ProhibitInterpolationOfLiterals ProhibitMagicNumbers)

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "$FindBin::Bin/lib";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;

$SIG{__WARN__} = sub {
    my $warning = shift;
    warn $warning unless $warning =~ /Could not open log/
                      || $warning =~ /Use of uninitialized value/;
};

initEverything('development-docker');

my $APP = $Everything::APP;
my $DB  = $Everything::DB;

ok($DB, "Database connection established");

# Node::user::infravision is the single source of truth for "can this user see
# cloaked (invisible) users". It must be true for: anyone with the infravision
# user var, OR editors, OR chanops — so the Other Users nodelet, the XML
# tickers, everything_finger, and the API session response all agree (#3389).

# --- Editors get infravision implicitly (no var needed) ---
{
    my $editor = $APP->node_by_name('genericeditor', 'user');
    ok($editor, 'loaded genericeditor');
    ok($editor->is_editor, 'genericeditor is an editor');
    ok(!$editor->VARS->{infravision}, 'genericeditor has no infravision var set');
    ok($editor->infravision, 'editor without the var still has infravision (#3389)');
}

# --- Chanops get infravision implicitly ---
{
    my $chanop = $APP->node_by_name('genericchanop', 'user');
    ok($chanop, 'loaded genericchanop');
    ok($chanop->is_chanop, 'genericchanop is a chanop');
    ok(!$chanop->VARS->{infravision}, 'genericchanop has no infravision var set');
    ok($chanop->infravision, 'chanop without the var still has infravision (#3389)');
}

# --- A plain user with neither the var nor a role has no infravision ---
{
    my $plain = $APP->node_by_name('normaluser1', 'user');
    ok($plain, 'loaded normaluser1');
    ok(!$plain->is_editor && !$plain->is_chanop, 'normaluser1 is neither editor nor chanop');
    ok(!$plain->VARS->{infravision}, 'normaluser1 has no infravision var');
    ok(!$plain->infravision, 'plain user has no infravision');
}

# --- The infravision var alone grants it (no role required) ---
{
    my $plain = $APP->node_by_name('normaluser2', 'user');
    ok($plain, 'loaded normaluser2');
    ok(!$plain->is_editor && !$plain->is_chanop, 'normaluser2 has no role');

    my $vars = $plain->VARS;
    my $had_var = $vars->{infravision};
    $vars->{infravision} = 1;
    Everything::setVars($plain->NODEDATA, $vars);

    # Re-fetch fresh so we exercise the accessor against persisted VARS.
    my $reloaded = $APP->node_by_id($plain->node_id, 'force');
    ok($reloaded->infravision, 'infravision var alone grants infravision');

    # Cleanup — restore prior state.
    my $cv = $reloaded->VARS;
    if ($had_var) { $cv->{infravision} = $had_var; }
    else          { delete $cv->{infravision}; }
    Everything::setVars($reloaded->NODEDATA, $cv);
    $DB->{dbh}->commit() unless $DB->{dbh}->{AutoCommit};
}

# --- The API session property loop surfaces infravision the same way: it calls
#     $user->infravision and includes it when truthy. Mirror that to prove the
#     reporter's symptom ("I do not receive the infravision property") is gone
#     for editors. ---
{
    my $editor = $APP->node_by_name('genericeditor', 'user');
    my %display;
    for my $property ('infravision') {
        my $p = $editor->$property;
        $display{$property} = $p if $p;
    }
    ok($display{infravision}, 'editor receives the infravision property (session-style read)');
}

done_testing();
