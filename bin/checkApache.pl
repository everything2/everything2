#!/usr/bin/perl -w

use strict;

open MEMINFO, "/proc/meminfo";
    
my %info = ();
while (<MEMINFO>) {
	my ($name, $value, $unit) = split /\s+/;
	#print "$name -> $value\n";  
	$info{$name} = $value;
}


my $swap = $info{'SwapTotal:'} - $info{'SwapFree:'};

if ($swap > 1500000) { #150 megs into swap
	`/etc/init.d/apache2 stop`;
	sleep 2;
	`killall -9 apache2`;
	sleep 2;
	`/etc/init.d/apache2 start`;
}



