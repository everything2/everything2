#!/usr/bin/perl
use strict;
use warnings;
use LWP::UserAgent;
use JSON;
use URI::Escape;
use Getopt::Long;

# tools/bing-webmaster.pl
#
# Pull SEO telemetry from the Bing Webmaster Tools API so we have real Bing-side data
# (impressions, clicks, top queries, crawl health) to tune the site with -- exactly the
# data we were blind to during the sitemap-freeze investigation. As Bing re-crawls the
# now-fresh sitemap, the impressions recovery should show up in GetRankAndTrafficStats.
#
# Auth: a Bing Webmaster Tools API key (Webmaster Tools -> Settings -> API access ->
# Generate). Pass via --apikey or the BING_WEBMASTER_API_KEY env var. For prod
# automation we could stash it in s3://secrets.everything2.com next to the other app
# secrets and read it the same way; for ad-hoc use the env var is fine.
#
# Usage:
#   BING_WEBMASTER_API_KEY=xxxx perl tools/bing-webmaster.pl
#   perl tools/bing-webmaster.pl --apikey xxxx --site https://everything2.com
#   perl tools/bing-webmaster.pl --json          # raw API JSON for every section
#   perl tools/bing-webmaster.pl --days 14        # trend window for the summary
#   perl tools/bing-webmaster.pl --help
#
# Field names in the human summary are best-effort against the documented Bing shapes;
# --json always prints the ground truth so you can see exactly what the API returned.
# API base: https://ssl.bing.com/webmaster/api.svc/json/<Method>?apikey=..&siteUrl=..

my %opt = (
    site   => 'https://everything2.com',
    apikey => $ENV{BING_WEBMASTER_API_KEY},
    days   => 30,
);
GetOptions( \%opt, 'site=s', 'apikey=s', 'json', 'days=i', 'help' )
    or die "bad options; run --help\n";

if ( $opt{help} ) { print _usage(); exit 0; }
die "No API key. Set BING_WEBMASTER_API_KEY or pass --apikey (see --help).\n"
    unless $opt{apikey};

my $ua = LWP::UserAgent->new( timeout => 45, agent => 'e2-bing-webmaster/1.0' );

# --- API helper: GET <base>/<method>?apikey=..&siteUrl=..&<params>, return $data->{d}
sub api {
    my ( $method, %params ) = @_;
    my $url
        = "https://ssl.bing.com/webmaster/api.svc/json/$method"
        . "?apikey="  . uri_escape( $opt{apikey} )
        . "&siteUrl=" . uri_escape( $opt{site} );
    $url .= "&$_=" . uri_escape( $params{$_} ) for sort keys %params;

    my $resp = $ua->get($url);
    unless ( $resp->is_success ) {
        warn "  [!] $method: HTTP " . $resp->status_line . "\n";
        my $body = $resp->decoded_content // '';
        warn "      $body\n" if length($body) && length($body) < 600;
        return;
    }
    my $data = eval { decode_json( $resp->decoded_content ) };
    if ($@) { warn "  [!] $method: JSON parse error: $@\n"; return; }
    return exists $data->{d} ? $data->{d} : $data;    # Bing wraps results in { d: ... }
}

# Bing serializes dates as "/Date(1719705600000-0000)/" (epoch millis). -> "YYYY-MM-DD".
sub bing_date {
    my ($v) = @_;
    return '?' unless defined $v;
    return $v unless $v =~ /Date\((\d+)/;
    my @t = gmtime( $1 / 1000 );
    return sprintf( '%04d-%02d-%02d', $t[5] + 1900, $t[4] + 1, $t[3] );
}

# --- collect every section --------------------------------------------------
my %report = (
    rank_and_traffic => api('GetRankAndTrafficStats'),
    query_stats      => api('GetQueryStats'),
    page_stats       => api('GetPageStats'),
    crawl_stats      => api('GetCrawlStats'),
    crawl_issues     => api('GetCrawlIssues'),
    feeds            => api('GetFeeds'),
);

if ( $opt{json} ) {
    print JSON->new->canonical(1)->pretty(1)->encode( \%report );
    exit 0;
}

# --- human-readable summary -------------------------------------------------
print "Bing Webmaster -- $opt{site}   (", scalar(gmtime), " UTC)\n";
print "=" x 64, "\n";

_section_rank_and_traffic( $report{rank_and_traffic} );
_section_top_queries( $report{query_stats} );
_section_top_pages( $report{page_stats} );
_section_feeds( $report{feeds} );
_section_crawl( $report{crawl_stats}, $report{crawl_issues} );
exit 0;

# ---------------------------------------------------------------------------
sub _section_rank_and_traffic {
    my ($rows) = @_;
    print "\n## Impressions & clicks (last $opt{days} days)\n";
    return print "  (no data)\n" unless ref $rows eq 'ARRAY' && @$rows;

    # newest first, then take the requested window
    my @r = sort { ( $b->{Date} // '' ) cmp ( $a->{Date} // '' ) } @$rows;
    @r = @r[ 0 .. $opt{days} - 1 ] if @r > $opt{days};

    my ( $imp, $clk ) = ( 0, 0 );
    $imp += $_->{Impressions} // 0 for @r;
    $clk += $_->{Clicks}      // 0 for @r;
    printf "  totals: %d impressions, %d clicks  (CTR %.2f%%)\n",
        $imp, $clk, $imp ? 100 * $clk / $imp : 0;

    printf "  %-12s %12s %10s %12s\n", 'DATE', 'IMPRESSIONS', 'CLICKS', 'AVG POS';
    for my $d ( @r[ 0 .. ( @r > 10 ? 9 : $#r ) ] ) {
        printf "  %-12s %12d %10d %12s\n",
            bing_date( $d->{Date} ),
            $d->{Impressions}            // 0,
            $d->{Clicks}                 // 0,
            defined $d->{AvgImpressionPosition}
            ? sprintf( '%.1f', $d->{AvgImpressionPosition} )
            : '-';
    }
    print "  (showing the 10 most recent of $opt{days})\n" if @r > 10;
}

sub _section_top_queries {
    my ($rows) = @_;
    print "\n## Top queries by impressions (aggregated)\n";
    return print "  (no data)\n" unless ref $rows eq 'ARRAY' && @$rows;

    # GetQueryStats returns one row per query PER TIME SLICE, so the same query appears
    # many times. Aggregate to a single line: sum impressions/clicks, impression-weighted
    # average position.
    my %agg;
    for my $q (@$rows) {
        my $name = $q->{Query} // '?';
        my $impr = $q->{Impressions} // 0;
        $agg{$name}{impr} += $impr;
        $agg{$name}{clk}  += $q->{Clicks} // 0;
        if ( defined $q->{AvgImpressionPosition} ) {
            $agg{$name}{posw} += $q->{AvgImpressionPosition} * ( $impr || 1 );
            $agg{$name}{posd} += ( $impr || 1 );
        }
    }

    my @names = sort { $agg{$b}{impr} <=> $agg{$a}{impr} } keys %agg;
    printf "  %-40s %8s %7s %8s\n", 'QUERY', 'IMPR', 'CLICKS', 'AVG POS';
    for my $name ( @names[ 0 .. ( @names > 25 ? 24 : $#names ) ] ) {
        my $a    = $agg{$name};
        my $disp = length($name) > 40 ? substr( $name, 0, 38 ) . '..' : $name;
        printf "  %-40s %8d %7d %8s\n",
            $disp, $a->{impr}, $a->{clk},
            $a->{posd} ? sprintf( '%.1f', $a->{posw} / $a->{posd} ) : '-';
    }
    print "  (" . scalar(@names) . " distinct queries in the window)\n";
}

sub _section_top_pages {
    my ($rows) = @_;
    print "\n## Top pages by impressions\n";
    return print "  (no data)\n" unless ref $rows eq 'ARRAY' && @$rows;

    my %agg;    # same per-slice duplication as queries -> aggregate per page URL
    for my $p (@$rows) {
        my $url = $p->{Page} // $p->{Url} // '?';
        $agg{$url}{impr} += $p->{Impressions} // 0;
        $agg{$url}{clk}  += $p->{Clicks} // 0;
    }
    my @urls = sort { $agg{$b}{impr} <=> $agg{$a}{impr} } keys %agg;
    printf "  %-54s %8s %7s\n", 'PAGE', 'IMPR', 'CLICKS';
    for my $u ( @urls[ 0 .. ( @urls > 20 ? 19 : $#urls ) ] ) {
        my $disp = length($u) > 54 ? '..' . substr( $u, -52 ) : $u;
        printf "  %-54s %8d %7d\n", $disp, $agg{$u}{impr}, $agg{$u}{clk};
    }
}

sub _section_feeds {
    my ($rows) = @_;
    print "\n## Submitted sitemaps -- Bing's view (did it pick up the fresh one?)\n";
    return print "  (no sitemaps reported to Bing)\n" unless ref $rows eq 'ARRAY' && @$rows;
    for my $f (@$rows) {
        printf "  %s\n", ( $f->{Url} // '?' );
        printf "    last read: %s   URLs: %s   in index: %s   errors: %s\n",
            bing_date( $f->{LastCrawled} // $f->{LastCrawledDate} ),
            ( $f->{UrlCount}    // '?' ),
            ( $f->{UrlsInIndex} // $f->{IndexedCount} // '?' ),
            ( $f->{ErrorCount}  // $f->{Errors} // 0 );
    }
}

sub _section_crawl {
    my ( $stats, $issues ) = @_;
    print "\n## Crawl health\n";
    if ( ref $stats eq 'ARRAY' && @$stats ) {
        my @s = sort { ( $b->{Date} // '' ) cmp ( $a->{Date} // '' ) } @$stats;
        printf "  %-12s %10s %9s %9s %9s\n", 'DATE', 'CRAWLED', 'IN INDEX', 'ERRORS', 'BLOCKED';
        for my $d ( @s[ 0 .. ( @s > 7 ? 6 : $#s ) ] ) {
            printf "  %-12s %10d %9d %9d %9d\n",
                bing_date( $d->{Date} ),
                $d->{CrawledPages}    // 0,
                $d->{InIndex}         // 0,
                $d->{CrawlErrors}     // 0,
                $d->{BlockedByRobotsTxt} // 0;
        }
    }
    else {
        print "  (no crawl stats)\n";
    }

    if ( ref $issues eq 'ARRAY' && @$issues ) {
        printf "  crawl issues: %d URL(s) flagged\n", scalar @$issues;
        for my $i ( @$issues[ 0 .. ( @$issues > 10 ? 9 : $#$issues ) ] ) {
            printf "    %s  %s\n", ( $i->{Url} // '?' ), ( $i->{Issues} // $i->{HttpCode} // '' );
        }
        print "    (showing 10 of " . scalar(@$issues) . ")\n" if @$issues > 10;
    }
    else {
        print "  crawl issues: none reported\n";
    }
}

sub _usage {
    return <<'USAGE';
bing-webmaster.pl -- pull SEO telemetry from the Bing Webmaster Tools API.

  --apikey KEY   Bing Webmaster API key (or set BING_WEBMASTER_API_KEY)
  --site URL     verified site (default: https://everything2.com)
  --days N       trend window for the impressions/clicks summary (default: 30)
  --json         print raw API JSON for every section (ground truth) instead of a summary
  --help         this message

Sections: GetRankAndTrafficStats (impressions/clicks), GetQueryStats (top queries,
aggregated), GetPageStats (top pages), GetFeeds (submitted-sitemap status), and
GetCrawlStats + GetCrawlIssues (crawl health). Get a key at Bing Webmaster Tools ->
Settings -> API access -> Generate.
USAGE
}
