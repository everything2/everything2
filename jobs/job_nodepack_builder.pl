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

# Hydration cache bundle (#4423): a best-effort ADD-ON, generated + uploaded AFTER
# the core nodepack is safely published under a top-level 'hydration/' S3 key
# (ops/nodepack-refresh.rb routes that prefix to the repo root). Wrapped so ANY
# failure (generation or upload) logs and continues -- it must never leave the
# nodepack unpublished (an earlier ordering bug did exactly that). Read :raw so the
# UTF-8 JSON ships as bytes; a wide-char body breaks PutObject's Content-Length.
eval {
  print `cd $tmpdir && /usr/bin/perl -I/var/everything/ecore -I/var/libraries/lib/perl5 /var/everything/ecoretool/ecoretool.pl hydrate --database everything --output $tmpdir/hydration/hydration_cache.json 2>&1`;
  die "hydrate exited non-zero (".($? >> 8).")\n" if $? != 0;
  open(my $hfh, "<:raw", "$tmpdir/hydration/hydration_cache.json") or die "could not read bundle: $!\n";
  local $/ = undef; my $hdata = <$hfh>; close($hfh);
  $s3->PutObject("Bucket" => $nodepack_bucket, "Key" => "hydration/hydration_cache.json", "Body" => $hdata);
  print "Uploaded hydration/hydration_cache.json\n";
  1;
} or do {
  print "WARNING: hydration cache bundle skipped (#4423); nodepack published without it: $@";
};

print "Finished nodepack update job\n";
