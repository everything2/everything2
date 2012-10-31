#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Everything;
use Everything::S3;

my $s3 = Everything::S3->new("backup");

my $data = "123";
my $hostname = `hostname`; chomp $hostname;

my $logdirs = ["/var/log/apache2","/var/log/everything"];

foreach my $logdir(@$logdirs)
{
	my $nowtime = [gmtime()]; $nowtime = ($nowtime->[5]+1900).sprintf("%02d",$nowtime->[4]+1).sprintf("%02d",$nowtime->[3]).sprintf("%02d",$nowtime->[2]);
	my $dirhandle;
	opendir $dirhandle,"$logdir";
	while (my $file = readdir($dirhandle))
	{
		my $filename = "$logdir/$file";
		next unless -f $filename; #Skips . and ..
		next unless my ($filetime) = $filename =~ /(\d{10})\.log$/;
		print commonLogLine("Considering '$filename'\n");
		print commonLogLine("Comparing $filetime versus $nowtime\n");
		if($filetime < $nowtime)
		{
			print "$filename is an upload candidate\n";
			my $filesize = [stat($filename)];
			if($filesize->[7] == 0)
			{
				print commonLogLine("'$filename' is empty, deleting\n");
				`rm -f $filename`; 
			}else{
				print commonLogLine("Gzipping '$filename'\n");
				`gzip --best $filename`;
				$filename .= ".gz";
				print commonLogLine("Uploading '$filename' to s3\n");
				$s3->upload_file("$hostname/$file.gz", $filename);
				print commonLogLine("removing '$filename'\n");
				`rm -f $filename`;
			}
		}else{
			print commonLogLine("'$filename' is too new, skipping\n");
		}
	}
}
