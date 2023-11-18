#!/usr/bin/perl -w

use lib qw(/var/libraries/lib/perl5);
use strict;
use File::Basename;
use Cwd 'abs_path';
use Test::Harness;
use File::Find;

my $testfiles;
my $dirname = dirname(abs_path($0));
my $wanted = sub {$testfiles->{$_}=1 if /\.t$/ and not /\legacy\//};

find({wanted => $wanted, no_chdir => 1}, $dirname);


runtests(sort {$a cmp $b} keys %$testfiles);

