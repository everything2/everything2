#!/usr/bin/perl
# tools/psgi-leak-harness.pl
#
# In-process memory-leak harness for the PSGI app (app.psgi).
#
# Drives synthetic requests straight through the app coderef with Plack::Test --
# no HTTP, single process -- so memory growth is cleanly attributable (no
# multi-worker noise). Reports, between a warm baseline and a load batch:
#   * RSS growth, total and per-request (the leak RATE)
#   * the Devel::Gladiator arena census DIFF -- which SV types / blessed classes
#     are accumulating (what is leaking)
#
# This is meant to be ITERATED on: vary --requests / --warm / the route manifest
# to isolate which paths leak and how fast, then drill in with Devel::MAT/Cycle.
#
# Run inside the dev container (where the app, DB, and Devel::* tools live):
#   docker exec -e E2_DOCKER=development e2devapp \
#     perl /var/everything/tools/psgi-leak-harness.pl --requests 3000 --warm 300
#   docker exec -e E2_DOCKER=development e2devapp \
#     perl /var/everything/tools/psgi-leak-harness.pl --routes /var/everything/tools/leak-routes.txt
#
use strict;
use warnings;
use lib '/var/libraries/lib/perl5';   # carton bundle (Plack, Devel::Gladiator, ...)
use lib '/var/everything/ecore';
use Getopt::Long;
use Plack::Test;
use HTTP::Request::Common qw(GET);
use Devel::Gladiator qw(arena_ref_counts);

my ($requests, $warm, $routes_file, $top, $threshold, $cookie) = (3000, 300, undef, 25, 1.0, undef);
GetOptions(
    'requests=i'  => \$requests,
    'warm=i'      => \$warm,
    'routes=s'    => \$routes_file,
    'top=i'       => \$top,
    'threshold=f' => \$threshold,    # KB/request that counts as a suspected leak
    'cookie=s'    => \$cookie,       # e.g. "userpass=..." so authed API handlers actually run
) or die "bad options\n";

# Build a GET request, attaching the auth cookie if one was provided.
my $mkreq = $cookie ? sub { GET $_[0], Cookie => $cookie } : sub { GET $_[0] };

my @routes = $routes_file
    ? do {
        open my $fh, '<', $routes_file or die "routes $routes_file: $!";
        grep { length } map { my $l = $_; chomp $l; $l =~ s/^\s+|\s+$//g; $l =~ /^#/ ? '' : $l } <$fh>;
      }
    : (
        '/',
        '/title/Cool+Archive',
        '/node/superdoc/Cool+Archive',
        '/index.pl?node_id=529746',
        '/index.pl?node=Everything+User+Search&type=superdoc',
        '/api/sessions',
      );
die "no routes\n" unless @routes;

sub rss_kb {
    open my $fh, '<', '/proc/self/status' or return 0;
    while (<$fh>) { return $1 if /^VmRSS:\s+(\d+)/ }
    return 0;
}

$| = 1;
print "=== PSGI leak harness ===\n";
printf "  routes=%d  warm=%d  requests=%d\n", scalar(@routes), $warm, $requests;

my $app = do '/var/everything/app.psgi';
die "app.psgi did not return a CODE ref (\$@=$@)\n" unless ref $app eq 'CODE';
my $test = Plack::Test->create($app);

# Warm: fill the NodeCache, run every code path once, let one-time allocations
# settle so they don't masquerade as a leak in the measured batch.
$test->request( $mkreq->( $routes[ $_ % @routes ] ) ) for 1 .. $warm;

my $rss0     = rss_kb();
my $census0  = arena_ref_counts();
my $start    = time;

$test->request( $mkreq->( $routes[ $_ % @routes ] ) ) for 1 .. $requests;

my $elapsed  = ( time - $start ) || 1;
my $rss1     = rss_kb();
my $census1  = arena_ref_counts();

# --- RSS report ---
my $delta_rss = $rss1 - $rss0;
my $per_req   = $delta_rss / $requests;
printf "\n=== RSS ===\n";
printf "  warm baseline : %d KB\n", $rss0;
printf "  after %-6d : %d KB\n", $requests, $rss1;
printf "  growth        : %+d KB  (%.3f KB/request)\n", $delta_rss, $per_req;
printf "  throughput    : %.0f req/s (in-process)\n", $requests / $elapsed;

# --- Census diff: what kind of thing is accumulating? ---
my %delta;
$delta{$_} = ( $census1->{$_} // 0 ) - ( $census0->{$_} // 0 ) for keys %$census1;
my @grew = grep { $delta{$_} > 0 } sort { $delta{$b} <=> $delta{$a} } keys %delta;

printf "\n=== Arena census growth (top %d) -- SV type / blessed class that grew ===\n", $top;
printf "  %-48s %12s\n", 'TYPE / CLASS', 'DELTA';
for my $i ( 0 .. $top - 1 ) {
    last unless defined $grew[$i];
    printf "  %-48s %+12d\n", $grew[$i], $delta{ $grew[$i] };
}

# --- Verdict ---
print "\n=== verdict ===\n";
if ( $per_req > $threshold ) {
    printf "  LEAK SUSPECTED: %.3f KB/request sustained growth (> %.1f).\n", $per_req, $threshold;
    print  "  Next: drill into the top-growing class above with Devel::Cycle on an\n";
    print  "  instance, or a Devel::MAT::Dumper heap dump diff across two batches.\n";
    exit 1;
}
printf "  OK: %.3f KB/request (<= %.1f). Re-run with more --requests to confirm it stays flat.\n",
    $per_req, $threshold;
exit 0;
