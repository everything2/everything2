#!/usr/bin/perl -w

use strict;
use lib qw(/var/libraries/lib/perl5);
use lib qw(/var/everything/ecore);
use Everything;
use Everything::HTML;
use Everything::S3;

initEverything 'everything';

$DB->{cache}->setCacheSize(50);

print "In region: ".$Everything::CONF->current_region."\n";
my $s3 = Everything::S3->new("sitemap");
print $APP->commonLogLine("Starting up");

my $current_batch = 1;
print $APP->commonLogLine("Fetching batches");
my $batches = $APP->sitemap_batches;
my $batch_count = scalar(@$batches);
print $APP->commonLogLine("Fetched $batch_count batches");

# Guard: never publish an empty sitemap. An empty batch list means the job failed to
# do its work -- fail loudly (non-zero exit -> cron status 'fail') rather than silently
# overwriting the live index.xml with an empty one and reporting success.
die "FATAL: sitemap_batches returned 0 batches -- refusing to publish an empty sitemap\n" if $batch_count == 0;

foreach my $batch(@$batches)
{
  print commonLogLine("Starting batch: $current_batch");
  sitemap_file_create($batch, $current_batch);
  $current_batch++;
}

sub sitemap_file_create
{
  my ($batch, $batch_number) = @_;
  
  my $sitemap_file = $APP->sitemap_batch_xml($batch);

  print $APP->commonLogLine("Uploading batch: $batch_number");
  my $uploaded = $s3->upload_data("$batch_number.xml", $sitemap_file, {"content_type" => "application/xml"});
  die "FATAL: sitemap batch upload failed for $batch_number.xml\n" unless $uploaded;
  print $APP->commonLogLine("Finishing batch: $batch_number");
}

print $APP->commonLogLine("Creating indexes for $batch_count batches");
my $index_uploaded = $s3->upload_data("index.xml", $APP->sitemap_index($batch_count), {"content_type" => "application/xml"});
die "FATAL: sitemap index upload failed\n" unless $index_uploaded;
print $APP->commonLogLine("Sitemap generation complete: $batch_count batches published");
