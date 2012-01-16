#!/usr/bin/perl -w -I /var/everything/ecore

use strict;
use Everything;
initEverything 'everything';

my $swaplimit = 1500 * 1000; # default to 1.5k * 1k kB => 1.5GB
$swaplimit = $CONFIG{'swap_limit'} if $CONFIG{'swap_limit'};

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

if ($swap > $swaplimit) {
	Everything::printLog("checkApache.pl: Killing Apache due to swap $swap kB being over limit of $swaplimit kB.");
	`/etc/init.d/apache2 stop`;
	sleep 5;
	`killall -9 apache2`;
	sleep 2;
	`/etc/init.d/apache2 start`;
}

