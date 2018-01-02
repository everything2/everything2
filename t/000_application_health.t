#!/usr/bin/perl -w

use strict;
use strict;
use lib qw(/var/everything/ecore);
use File::Basename;
use Test::More;
use Perl::Critic;
use File::Find;

my $critic = Perl::Critic->new(-severity => 1, -theme => "bugs");
sub critique_file
{
  my ($file) = @_;
  
  my $violations = [$critic->critique($file)];
  if(scalar(@$violations))
  {
    return scalar(@$violations);
  }
}

my $basedir = dirname(__FILE__)."/../ecore";

File::Find::find(sub { -e $_ && -f $_ && /\.pm$/ && ok(critique_file($_) == 0, "$_ passes Perl::Critic for bugs")}, $basedir);

done_testing;
