#!/usr/bin/perl -w
#
# Web-scoped hydration bake-in (#4439).
#
# Hydration moved out of the shared Everything::NodeBase::new into the web boot path
# (app.psgi), so it is unconditional for the web app but structurally OFF for the
# cron/batch scripts and the test suite -- which boot through initEverything directly
# and never run app.psgi. There is no env flag and no CONF knob any more; the boot
# path itself is the scope.
#
# This asserts BOTH halves of that contract:
#   1. a bare initEverything (the cron/test path) does NOT load the bundle, and
#   2. booting app.psgi + one request DOES hydrate this worker (once).
#
use strict;
use warnings;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5);
use Test::More;
use Everything;

initEverything 'everything';
my $gu = $Everything::CONF->guest_user;

# --- half 1: the shared boot path (what cron + the test suite use) stays lean ----
ok( !exists $DB->{cache}{hydrationExempt}{$gu},
    'bare initEverything (cron/test path) does NOT load the hydration bundle' );

# --- half 2: the web boot path (app.psgi) hydrates, per worker, on first request -
my $bundle = '/var/everything/hydration/hydration_cache.json';
plan skip_all => "no hydration bundle at $bundle" unless -r $bundle;

my $app = eval { do '/var/everything/app.psgi' };
plan skip_all => "app.psgi unavailable: $@" unless ref $app eq 'CODE';
require Plack::Test;
require HTTP::Request::Common;
my $test = Plack::Test->create($app);
$test->request( HTTP::Request::Common::GET('/') );    # first request -> per-worker guard fires

ok( exists $DB->{cache}{hydrationExempt}{$gu},
    'app.psgi boot hydrates this worker: Guest User is now resident (hydration-exempt)' );

# and a core node is served resident, with zero DB queries
my $dbh = $DB->{dbh};
sub selects { my @r = $dbh->selectrow_array("SHOW SESSION STATUS LIKE 'Com_select'"); return $r[1]; }
$DB->{cache}->clearSessionCache;
my $b  = selects();
my $nt = getNodeById(1);
is( selects() - $b, 0, 'core node (node_id 1) served from the hydration cache with 0 DB queries' );
is( $nt->{title}, 'nodetype', 'node_id 1 is the nodetype nodetype (bundle intact)' );

done_testing();
