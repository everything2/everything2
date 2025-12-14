#!/usr/bin/perl -w
#
# cron_extract_writeup_content.pl
#
# Extracts writeup content from production database for link parsing comparison tests.
# Uploads JSON to S3 for retrieval and analysis.
#
# This job should be run periodically (weekly?) to provide fresh test data for
# comparing server-side parseLinks() against client-side E2HtmlSanitizer.js
#
# Usage:
#   cron_extract_writeup_content.pl               # Sample + recent only (default, memory-safe)
#   cron_extract_writeup_content.pl --full        # Include full export (requires lots of memory)
#   cron_extract_writeup_content.pl --sample-only # Just the 1000 random sample
#
# S3 bucket configuration required in everything.conf.json:
#   "s3": {
#     "writeup_export": {
#       "bucket": "e2-writeup-exports"
#     }
#   }
#
# Output files in S3:
#   - writeup-content-sample.json     (random 1000 sample, uncompressed)
#   - writeup-content-recent.json     (last 30 days, uncompressed)
#   - writeup-content-full.json.gz    (all writeups, compressed - only with --full)
#   - manifest.json                   (metadata about the export)

use strict;
use warnings;
use lib qw(/var/libraries/lib/perl5);
use lib qw(/var/everything/ecore);

use Everything;
use Everything::HTML;
use Everything::S3;
use JSON;
use IO::Compress::Gzip qw(gzip $GzipError);
use POSIX qw(strftime);
use Getopt::Long;

# Parse command line options
my $do_full = 0;
my $sample_only = 0;
GetOptions(
    'full' => \$do_full,
    'sample-only' => \$sample_only,
) or die "Usage: $0 [--full] [--sample-only]\n";

initEverything 'everything';

$DB->{cache}->setCacheSize(50);

print $APP->commonLogLine("Starting writeup content extraction");
print "Region: " . $Everything::CONF->current_region . "\n";
print "Mode: " . ($do_full ? "full" : ($sample_only ? "sample-only" : "sample+recent")) . "\n";

my $s3 = Everything::S3->new("writeup_export");
unless ($s3) {
    print $APP->commonLogLine("ERROR: Could not initialize S3 for writeup_export");
    print "Make sure 'writeup_export' is configured in s3 section of everything.conf.json\n";
    exit 1;
}

my $json = JSON->new->utf8->canonical;
my $timestamp = strftime("%Y-%m-%dT%H:%M:%SZ", gmtime());
my $date_30_days_ago = strftime("%Y-%m-%d", localtime(time - 30 * 24 * 60 * 60));

# Get writeup type node_id
my $writeup_type = $DB->getNode('writeup', 'nodetype');
unless ($writeup_type) {
    print $APP->commonLogLine("ERROR: Could not find writeup nodetype");
    exit 1;
}
my $writeup_type_id = $writeup_type->{node_id};

print $APP->commonLogLine("Writeup type_nodetype: $writeup_type_id");

# ============================================================================
# 1. Random sample (1000 writeups) - for quick testing
# ============================================================================
print $APP->commonLogLine("Extracting random sample (1000 writeups)");

my $sample_sql = qq{
    SELECT n.node_id, n.title, n.createtime, d.doctext, u.title as author
    FROM node n
    JOIN document d ON n.node_id = d.document_id
    JOIN node u ON n.author_user = u.node_id
    WHERE n.type_nodetype = ?
    ORDER BY RAND()
    LIMIT 1000
};

my $sample_data = extract_writeups($sample_sql, [$writeup_type_id]);
my $sample_json = $json->encode({
    extracted_at => $timestamp,
    type => 'random_sample',
    count => scalar(@{$sample_data->{writeups}}),
    writeups => $sample_data->{writeups}
});

print $APP->commonLogLine("Uploading random sample (" . length($sample_json) . " bytes)");
$s3->upload_data("writeup-content-sample.json", $sample_json, { content_type => "application/json" });

# ============================================================================
# 2. Recent writeups (last 30 days) - for testing new content patterns
# ============================================================================
my $recent_data = { writeups => [] };
my $recent_json = '';

unless ($sample_only) {
    print $APP->commonLogLine("Extracting recent writeups (last 30 days)");

    my $recent_sql = qq{
        SELECT n.node_id, n.title, n.createtime, d.doctext, u.title as author
        FROM node n
        JOIN document d ON n.node_id = d.document_id
        JOIN node u ON n.author_user = u.node_id
        WHERE n.type_nodetype = ?
        AND n.createtime >= ?
        ORDER BY n.createtime DESC
    };

    $recent_data = extract_writeups($recent_sql, [$writeup_type_id, $date_30_days_ago]);
    $recent_json = $json->encode({
        extracted_at => $timestamp,
        type => 'recent_30_days',
        since => $date_30_days_ago,
        count => scalar(@{$recent_data->{writeups}}),
        writeups => $recent_data->{writeups}
    });

    print $APP->commonLogLine("Uploading recent writeups (" . length($recent_json) . " bytes)");
    $s3->upload_data("writeup-content-recent.json", $recent_json, { content_type => "application/json" });
}

# ============================================================================
# 3. Full export (all writeups, gzipped) - streamed to avoid OOM
#    Skipped with --sample-only flag
# ============================================================================
my $full_count = 0;
my $full_with_links = 0;
my $full_total_length = 0;

unless ($sample_only) {
    print $APP->commonLogLine("Extracting full writeup corpus (streaming mode)");

    my ($full_count_result, $compressed_size) = extract_writeups_streaming(
        $s3, $writeup_type_id, $timestamp, $json,
        \$full_count, \$full_with_links, \$full_total_length
    );

    print $APP->commonLogLine("Full export complete: $full_count writeups, $compressed_size bytes compressed");
} else {
    print $APP->commonLogLine("Skipping full export (--sample-only mode)");
}

# ============================================================================
# 4. Manifest file - metadata about the export
# ============================================================================
my $manifest = {
    generated_at => $timestamp,
    region => $Everything::CONF->current_region,
    mode => $do_full ? 'full' : ($sample_only ? 'sample-only' : 'sample+recent'),
    files => {
        'writeup-content-sample.json' => {
            description => 'Random sample of 1000 writeups',
            count => scalar(@{$sample_data->{writeups}}),
            compressed => 0,
            size_bytes => length($sample_json)
        }
    }
};

# Add recent if exported
unless ($sample_only) {
    $manifest->{files}{'writeup-content-recent.json'} = {
        description => "Writeups from last 30 days (since $date_30_days_ago)",
        count => scalar(@{$recent_data->{writeups}}),
        compressed => 0,
        size_bytes => length($recent_json)
    };
}

# Add full if exported (not in sample-only mode)
unless ($sample_only) {
    $manifest->{files}{'writeup-content-full.json.gz'} = {
        description => 'Full writeup corpus (gzip compressed, streamed)',
        count => $full_count,
        compressed => 1
    };
}

# Statistics
$manifest->{statistics} = {
    sample_count => scalar(@{$sample_data->{writeups}}),
    recent_count => scalar(@{$recent_data->{writeups}}),
    full_count => $full_count,
    full_with_links => $full_with_links,
    full_average_length => $full_count > 0 ? int($full_total_length / $full_count) : 0,
    sample_with_links => count_with_links($sample_data->{writeups}),
    sample_average_length => average_length($sample_data->{writeups})
};

my $manifest_json = $json->pretty->encode($manifest);
print $APP->commonLogLine("Uploading manifest");
$s3->upload_data("manifest.json", $manifest_json, { content_type => "application/json" });

print $APP->commonLogLine("Export complete. Sample: " . scalar(@{$sample_data->{writeups}}) . ", Full: $full_count writeups");

# ============================================================================
# Helper functions
# ============================================================================

sub extract_writeups {
    my ($sql, $params) = @_;

    my $sth = $DB->{dbh}->prepare($sql);
    $sth->execute(@$params);

    my @writeups;
    my $count = 0;

    while (my $row = $sth->fetchrow_hashref()) {
        push @writeups, {
            node_id => int($row->{node_id}),
            title => $row->{title},
            doctext => $row->{doctext} // '',
            author => $row->{author},
            createtime => $row->{createtime},
        };

        $count++;
        if ($count % 5000 == 0) {
            print $APP->commonLogLine("  Extracted $count writeups...");
        }
    }

    $sth->finish();

    return { writeups => \@writeups };
}

sub count_with_links {
    my ($writeups) = @_;
    my $count = 0;
    for my $wu (@$writeups) {
        $count++ if $wu->{doctext} && $wu->{doctext} =~ /\[/;
    }
    return $count;
}

sub average_length {
    my ($writeups) = @_;
    return 0 unless @$writeups;

    my $total = 0;
    for my $wu (@$writeups) {
        $total += length($wu->{doctext} // '');
    }
    return int($total / scalar(@$writeups));
}

# Memory-efficient streaming export that writes directly to a temp file
# then uploads, never holding all writeups in memory at once
sub extract_writeups_streaming {
    my ($s3, $writeup_type_id, $timestamp, $json, $count_ref, $with_links_ref, $total_length_ref) = @_;

    use File::Temp qw(tempfile);

    my $sql = qq{
        SELECT n.node_id, n.title, n.createtime, d.doctext, u.title as author
        FROM node n
        JOIN document d ON n.node_id = d.document_id
        JOIN node u ON n.author_user = u.node_id
        WHERE n.type_nodetype = ?
        ORDER BY n.node_id
    };

    my $sth = $DB->{dbh}->prepare($sql);
    $sth->execute($writeup_type_id);

    # Create temp file for gzipped output
    my ($tmp_fh, $tmp_filename) = tempfile(SUFFIX => '.json.gz', UNLINK => 1);

    # Open gzip stream to temp file
    my $gz = IO::Compress::Gzip->new($tmp_fh)
        or die "Cannot create gzip stream: $GzipError\n";

    # Write JSON header
    $gz->print('{"extracted_at":"' . $timestamp . '","type":"full_export_streaming","writeups":[');

    my $count = 0;
    my $first = 1;

    while (my $row = $sth->fetchrow_hashref()) {
        my $doctext = $row->{doctext} // '';

        # Track statistics
        $$count_ref++;
        $$total_length_ref += length($doctext);
        $$with_links_ref++ if $doctext =~ /\[/;

        # Build writeup object
        my $wu = {
            node_id => int($row->{node_id}),
            title => $row->{title},
            doctext => $doctext,
            author => $row->{author},
            createtime => $row->{createtime},
        };

        # Write comma separator (except for first)
        $gz->print(',') unless $first;
        $first = 0;

        # Write JSON for this writeup
        $gz->print($json->encode($wu));

        $count++;
        if ($count % 10000 == 0) {
            print $APP->commonLogLine("  Streamed $count writeups...");
        }
    }

    $sth->finish();

    # Write JSON footer with count
    $gz->print('],"count":' . $count . '}');
    $gz->close();

    # Get compressed size
    my $compressed_size = -s $tmp_filename;

    print $APP->commonLogLine("Uploading full export ($compressed_size bytes compressed)");

    # Upload the temp file to S3
    open(my $upload_fh, '<:raw', $tmp_filename) or die "Cannot read temp file: $!\n";
    local $/;
    my $compressed_data = <$upload_fh>;
    close($upload_fh);

    $s3->upload_data("writeup-content-full.json.gz", $compressed_data, { content_type => "application/gzip" });

    return ($count, $compressed_size);
}
