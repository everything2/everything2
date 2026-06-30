#!/usr/bin/env perl

use strict;
use lib qw(/var/libraries/lib/perl5);
use lib qw(/var/everything/ecore);
use Everything;
use JSON;
use Paws;
use File::Find;

initEverything 'everything';
print "Starting nodepack update job\n";
my $s3 = Paws->service('S3', 'region' => $Everything::CONF->current_region);

my $nodepack_bucket = "nodepack.everything2.com";
my $tmpdir = "/tmp/nodepack-$$";

`mkdir -p $tmpdir`;
print `cd $tmpdir && /usr/bin/perl -I/var/everything/ecore -I/var/libraries/lib/perl5  /var/everything/ecoretool/ecoretool.pl export 2>&1`;

# Refuse to publish a partial nodepack. The export runs as a child process; if it
# died part-way (historically: an orphaned dbtable node aborted it), uploading the
# truncated set would silently drop every node after the failure point. Bail loudly
# instead so the S3 nodepack is never left in a half-written, "looks complete" state.
if($? != 0)
{
  print "ERROR: ecoretool export exited non-zero (".($? >> 8)."); refusing to upload a partial nodepack.\n";
  exit 1;
}

# Generate the permanent hydration cache bundle (#4423) and upload it under a
# top-level 'hydration/' S3 key. ops/nodepack-refresh.rb routes that prefix to the
# repo top level (not nodepack/), so the bundle stays visible at the root rather
# than buried among the nodepack XML. Same partial-refusal discipline as the export.
print `cd $tmpdir && /usr/bin/perl -I/var/everything/ecore -I/var/libraries/lib/perl5 /var/everything/ecoretool/ecoretool.pl hydrate --database everything --output $tmpdir/hydration/hydration_cache.json 2>&1`;
if($? != 0)
{
  print "ERROR: ecoretool hydrate exited non-zero (".($? >> 8)."); refusing to upload a partial nodepack.\n";
  exit 1;
}
if(open(my $hfh, "<", "$tmpdir/hydration/hydration_cache.json"))
{
  local $/ = undef;
  my $hdata = <$hfh>;
  close($hfh);
  $s3->PutObject("Bucket" => $nodepack_bucket, "Key" => "hydration/hydration_cache.json", "Body" => $hdata);
  print "Uploaded hydration/hydration_cache.json\n";
}else{
  print "ERROR: could not read generated hydration bundle: $!\n";
  exit 1;
}

my $files = [];
File::Find::find({wanted => sub {push @$files,$File::Find::name if -e && /\.xml$/}}, $tmpdir);

foreach my $file(@$files)
{
  my $filedata;
  if(open(my $fh, "<", $file))
  {
    local $/ = undef;
    $filedata = <$fh>;
  }else{
    print "Could not open file: $!";
    exit;
  }
  my $relative_file = $file;
  $relative_file =~ s/^$tmpdir\/nodepack\///g;
  $s3->PutObject("Bucket" => $nodepack_bucket, "Key" => $relative_file, "Body" => $filedata);
  print "Uploaded $relative_file\n"; 
}

print "Finished nodepack update job\n";
