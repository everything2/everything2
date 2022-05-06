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
exit;

my $current_batch = 1;
print $APP->commonLogLine("Fetching batches");
my $batches = $APP->sitemap_batches;

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
  $s3->upload_data("$batch_number.xml", $sitemap_file, {"content_type" => "application/xml"});
  print $APP->commonLogLine("Finishing batch: $batch_number");
}

print $APP->commonLogLine("Creating indexes for ".scalar(@$batches)." batches");
$s3->upload_data("index.xml", $APP->sitemap_index(scalar(@$batches)), {"content_type" => "application/xml"});
