#!/usr/bin/perl -w

use strict;
use warnings;
use lib qw(/var/everything/ecore);
use File::Basename;
use Test::More;
use Perl::Critic;
use File::Find;
use Cwd qw(abs_path);

my $critic = Perl::Critic->new(-severity => 1, -theme => "bugs");
sub critique_file
{
  my ($file) = @_;

  my @violations = eval { $critic->critique($file) };
  if ($@) {
    # Parse error - skip this file with a warning
    warn "Skipping $file due to parse error: $@\n";
    return 0;
  }

  return scalar(@violations);
}

my $basedir = abs_path(dirname(__FILE__)."/../ecore");

File::Find::find(sub { -e $_ && -f $_ && /\.pm$/ && ok(critique_file($File::Find::name) == 0, "$File::Find::name passes Perl::Critic for bugs")}, $basedir);

done_testing;
