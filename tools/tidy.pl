#!/usr/bin/perl -w

use lib qw(/var/libraries/lib/perl5);
use Perl::Tidy;

foreach my $file(`find /var/everything/ecore -type f`)
{
  chomp $file;
  print "$file\n";
  Perl::Tidy::perltidy("source" => $file, "destination" => "/tmp/tidy");
  print `diff -u $file /tmp/tidy`;
  `rm /tmp/tidy`;
}
