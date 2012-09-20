#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);

use DBI;
use Everything;

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
	"deletedhits" => "--no-data",
	"hits" => "--no-data",
};

my $password = $Everything::CONF->{everypass};
my $user = $Everything::CONF->{everyuser};
my $host = $Everything::CONF->{everything_dbserv};

my $dbh = DBI->connect("DBI:mysql:database=everything;host=$host",$user, $password);

die "No database" unless $dbh;

my $sth = $dbh->prepare("SHOW TABLES");

$sth->execute();

my $now = [localtime()];
my $dumpfile = "everything.staging.".($now->[5]+1900).sprintf("%02d",$now->[4]+1).sprintf("%02d",$now->[3]).".sql";


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
	`mysqldump --single-transaction $extra --user=$user --password=$password --host=$host everything $table >> $dumpfile`;
}

print STDERR "Compressing output\n";

`gzip $dumpfile`;
