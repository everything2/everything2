#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Everything;

initEverything 'everything';

print "Starting data generator: ".localtime()." (".time().")\n";

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
       require "$full_directory_path/$file";
       my $classname = $file; $classname =~ s/\.pm$//g;
       print "Evaluating generator '$classname'...";
       my $generator = "Everything::DataStash::$classname"->new(DB => $Everything::DB, CONF => $Everything::CONF);

       print "".($generator->generate_if_needed()?("updated"):("not needed"))."\n";
    }
  }
}

print "Finished data generator: ".localtime()." (".time().")\n";
