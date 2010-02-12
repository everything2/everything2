#!/usr/bin/perl -w

use strict;

my $max_semaphores = 35;
my @semaphores = `ipcs -s|grep 'www-data\\|apache'`;

if (scalar @semaphores > $max_semaphores) {

	`/etc/init.d/apache2 stop`;
	sleep 5;
	`killall -9 apache2`;
	sleep 2;
	
	# Semaphores may have been released once apache shut down
	#  so we refresh our list so we don't kill stale ids
	@semaphores = `ipcs -s|grep 'www-data\\|apache'`;
	for my $sem_line (@semaphores) {
		my $semid = (split /\s+/, $sem_line)[1];
		`ipcrm -s $semid`;
	}
	`/etc/init.d/apache2 start`;
	sleep 2;

}

open MEMINFO, "/proc/meminfo";

my %info = ();
while (<MEMINFO>) {
	my ($name, $value, $unit) = split /\s+/;
	#print "$name -> $value\n";  
	$info{$name} = $value;
}


my $swap = $info{'SwapTotal:'} - $info{'SwapFree:'};

if ($swap > 150000) { #150 megs into swap
	`/etc/init.d/apache2 stop`;
	sleep 5;
	`killall -9 apache2`;
	sleep 2;
	`/etc/init.d/apache2 start`;
}

