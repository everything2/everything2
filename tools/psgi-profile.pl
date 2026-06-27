#!/usr/bin/perl
# NYTProf request-handling profiler for the PSGI app. Profiles ONLY the measured
# request loop (app load + warmup are excluded via DB::disable/enable_profile),
# so the report reflects per-request hot subs, not one-time Moose compilation.
#
#   # -d:NYTProf loads at startup, BEFORE this script's `use lib`, so NYTProf must
#   # already be on @INC -- prepend the vendored lib via PERL5LIB or it won't be found:
#   PERL5LIB=/var/libraries/lib/perl5 perl -d:NYTProf /var/everything/tools/psgi-profile.pl [N] [routes-file]
#   SOAK_COOKIE="userpass=..." PERL5LIB=/var/libraries/lib/perl5 perl -d:NYTProf ... (authed handlers)
#   nytprofcsv --out /tmp/nytprof.csv nytprof.out   # then sort by exclusive time
use strict;
use warnings;
use lib '/var/libraries/lib/perl5';
use Plack::Test;
use HTTP::Request::Common qw(GET);

my $n           = $ARGV[0] || 800;
my $routes_file = $ARGV[1] || '/var/everything/tools/leak-routes.txt';
my $cookie      = $ENV{SOAK_COOKIE};

open my $fh, '<', $routes_file or die "routes: $!";
my @routes = grep { length } map { my $l = $_; chomp $l; $l =~ s/\s*#.*//; $l =~ s/^\s+|\s+$//g; $l } <$fh>;
die "no routes\n" unless @routes;

# Don't profile app compilation / warmup -- only the request loop below.
DB::disable_profile() if defined &DB::disable_profile;

my $app  = do '/var/everything/app.psgi';
die "app.psgi did not return CODE\n" unless ref $app eq 'CODE';
my $test = Plack::Test->create($app);
my $mk   = $cookie ? sub { GET $_[0], Cookie => $cookie } : sub { GET $_[0] };

$test->request( $mk->( $routes[ $_ % @routes ] ) ) for 1 .. 100;   # warm

DB::enable_profile() if defined &DB::enable_profile;
$test->request( $mk->( $routes[ $_ % @routes ] ) ) for 1 .. $n;    # MEASURED
DB::finish_profile() if defined &DB::finish_profile;

print "profiled $n requests over ", scalar(@routes), " routes\n";
