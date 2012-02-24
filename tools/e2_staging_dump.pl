#!/usr/bin/perl -w

use strict;
use DBI;

my $tables = 
{
	# Make sure to get the stored procedures somewhere
	"node" => "--routines",
	"iplog" => "--no-data",
	"iplog2" => "--no-data",
	# This is close enough to what we want
	"links" => "--where='linktype != 0'",
	"message" => "--no-data",
	"heaven" => "--no-data",
	"nodebak" => "--no-data",
	"ftsearch" => "--no-data",
	"ftcache" => "--no-data",
	"ftdict" => "--no-data",
	"deletedhits" => "--no-data",
	"hits" => "--no-data",
};

my $password = $ARGV[0];

my $dbh = DBI->connect("DBI:mysql:database=everything","root", $password);

die "No database" unless $dbh;

my $sth = $dbh->prepare("SHOW TABLES");

$sth->execute();

my $now = [localtime()];
my $dumpfile = "everything.staging.".($now->[5]+1900).sprintf("%02d",$now->[4]).sprintf("%02d",$now->[3]).".sql";


my $table_list;

while(my $line = $sth->fetchrow_arrayref)
{
	my $table = $line->[0];
	next if $table eq "currentusers";
	push @$table_list, $table;
}

foreach my $table(@$table_list, "currentusers")
{
	print STDERR "Dumping $table\n";
	my $extra = "";
	if(exists $tables->{$table})
	{
		$extra = $tables->{$table};
	}
	`mysqldump --single-transaction $extra --user=root everything $table >> $dumpfile`;
}

print STDERR "Compressing output\n";

`gzip $dumpfile`;
