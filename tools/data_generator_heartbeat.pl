#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Everything;

initEverything 'everything';

print "Starting data generator: ".localtime()." (".time().")\n";

my $seen_modules;

my $force;
$force = 1 if defined($ARGV[0]) and $ARGV[0] eq "force";

foreach my $dir (@INC)
{
  my $full_directory_path = "$dir/Everything/DataStash";
  if(-d $full_directory_path)
  {
    my $dirhandle;
    opendir $dirhandle, $full_directory_path;
    foreach my $file(readdir($dirhandle))
    {
       next if($file =~ /^\.{1,2}$/);
       next if $seen_modules->{$file};
       require "$full_directory_path/$file";
       $seen_modules->{$file} = 1;
       my $classname = $file; $classname =~ s/\.pm$//g;
       print "Evaluating generator '$classname'...";
       my $generator = "Everything::DataStash::$classname"->new(DB => $Everything::DB, CONF => $Everything::CONF, APP => $Everything::APP);

       print "".($generator->generate_if_needed($force)?("updated"):("not needed"))."\n";
    }
  }
}

print "Finished data generator: ".localtime()." (".time().")\n";
