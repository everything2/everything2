#!/usr/bin/perl -w

use strict;
use File::Basename;
use Cwd 'abs_path';
use Test::Harness;
use File::Find;

my $testfiles;
my $dirname = dirname(abs_path($0));
find(sub {$testfiles->{$_}=1 if /\.t$/}, $dirname);

runtests(sort {$a cmp $b} keys %$testfiles);

