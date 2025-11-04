#!/usr/bin/perl

use lib qw(/var/libraries/lib/perl5);
use strict;
use warnings;
use FindBin;
use Perl::Critic;
use File::Basename;

my $config = dirname(__FILE__)."/../.perlcriticrc";

my $critic = Perl::Critic->new(-severity => 1, -theme => "bugs", -profile => $config);

if(defined($ENV{"CRITIC_FULL"}))
{
  $critic = Perl::Critic->new(-severity => 1, -theme => "core", -profile => $config);
}

if($ARGV[0])
{
  critique_file($ARGV[0]);
}else{
  my $libraries = "$FindBin::Bin/../ecore";
  foreach my $file(`find $libraries -type f`)
  {
    chomp $file;
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
