#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use Perl::Critic;

my $critic = Perl::Critic->new(-severity => 1, -theme => "bugs");

if(defined($ENV{"CRITIC_FULL"}))
{
  $critic = Perl::Critic->new(-severity => 1, -theme => "core && !cosmetic && !complexity", -exclude => ["RequireArgUnpacking","RequireVersionVar"]);
}

if($ARGV[0])
{
  critique_file($ARGV[0]);
}else{
  my $libraries = "$FindBin::Bin/../ecore";
  foreach my $file(`find $libraries -type f`)
  {
    chomp $file;
    print "Evaluating: ".$file."\n";
    critique_file($file);
  }
}

sub critique_file
{
  my ($file) = @_;
  
  my $violations = [$critic->critique($file)];
  if(scalar(@$violations))
  {
    print "$file\n";
    print @$violations;
  } 
}
