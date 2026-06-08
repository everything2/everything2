#!/usr/bin/perl -w
#
# Per-code-path memory-leak gate using Test::LeakTrace. Complements the
# whole-app soak harness (tools/psgi-leak-harness.pl): this pins specific hot
# paths and fails in `prove` if a warmed call leaks SVs -- catching leaks in CI
# instead of in a multi-day soak. The PSGI/Starman model makes per-request leaks
# matter (mod_perl's SizeLimit used to mask them); this is the early-warning net.
#
use strict;
use lib qw(/var/libraries/lib/perl5 /var/everything/ecore);
use Test::More;
use Test::LeakTrace qw(no_leaks_ok);   # compile-time: gives no_leaks_ok its (&) prototype
use Everything;

initEverything 'everything';

unless ( $APP->inDevEnvironment() ) {
    plan skip_all => "Not in the development environment";
    exit;
}

# Warm each path first -- the NodeCache's one-time fill is expected retention,
# not a leak. After warming, a *repeated* call should retain nothing new.
my $warm = sub { my $code = shift; $code->() for 1 .. 3; };

# Hottest path: getNode by (title,type) and by node_id.
$warm->( sub { $DB->getNode( 'Cool Archive', 'superdoc' ) } );
no_leaks_ok { $DB->getNode( 'Cool Archive', 'superdoc' ) }
    'getNode(title,type) warm: no per-call SV leak';

$warm->( sub { $DB->getNode(2) } );
no_leaks_ok { $DB->getNode(2) }
    'getNode(node_id) warm: no per-call SV leak';

# Nodetype resolution (every request does this many times).
$warm->( sub { $DB->getType('superdoc') } );
no_leaks_ok { $DB->getType('superdoc') }
    'getType warm: no per-call SV leak';

done_testing();
