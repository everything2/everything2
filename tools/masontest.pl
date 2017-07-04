#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Everything;
use Data::Dumper;
my $masondir = "/var/everything/templates";

foreach my $template_file (`find $masondir -type f`)
{
  chomp $template_file;
  next if $template_file =~ /Base.mc$/;
  $template_file =~ s/^$masondir//g;
  print "$template_file\n";

  print Data::Dumper->Dump([$Everything::MASON->load($template_file)]);
}
