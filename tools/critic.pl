#!/usr/bin/perl -w

use Perl::Critic;

my $critic = Perl::Critic->new(-severity => 1, -theme => "bugs");

foreach my $file(`find /var/everything/ecore -type f`)
{
  chomp $file;
  print "$file\n";
  my $violations = [$critic->critique($file)];
  print @$violations;
}
