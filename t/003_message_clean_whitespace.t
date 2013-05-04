#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Test::More;
use Everything;

initEverything 'everything';
unless($APP->inDevEnvironment())
{
	plan skip_all => "Not in the development environment";
	exit;
}

ok($APP->messageCleanWhitespace(" testing\nhere") eq "testing here");
ok($APP->messageCleanWhitespace(" test  message ") eq "test message");
ok($APP->messageCleanWhitespace(" hello ") eq "hello");
ok($APP->messageCleanWhitespace("1234") eq "1234");
ok($APP->messageCleanWhitespace("     \n     ") eq "");

done_testing();
