#!/usr/bin/perl -w

use strict;
use DBI;

my $dbh = DBI->connect("DBI:mysql:everything:localhost;mysql_enable_utf8=1", "everyuser", "", {AutoCommit => 1});

my $E2DB="mysql --default-character-set=utf8 -u root everything";


my $tables_to_convert =
{
	"node" =>
	{
		"title" => ["char(240)", "ALTER TABLE node DROP INDEX title", "CREATE INDEX title on node (title, type_nodetype)"],
	},
};

my $reference_tables =
{
	"node" =>
	{
		
	},
};


sub convert_table_column
{
	my ($table, $column, $definition, $pre, $post) = @_;
	my $latin1_check_csr = $dbh->prepare("SELECT    COLUMN_NAME,   TABLE_NAME,   CHARACTER_SET_NAME,   COLUMN_TYPE,   COLLATION_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = 'everything' and CHARACTER_SET_NAME='latin1' and TABLE_NAME='$table' and COLUMN_NAME='$column'");
	$latin1_check_csr->execute();

	if(my $row = $latin1_check_csr->fetchrow_arrayref())
	{
		print STDERR "Converting $table.$column\n";
	}else{
		print STDERR "Not converting $table.$column, not latin1\n";
		return;
	}

	if(defined $pre)
	{
		sql_verbose_do($pre);
	}

	sql_verbose_do("ALTER TABLE $table MODIFY COLUMN $column $definition CHARACTER SET utf8 COLLATE utf8_unicode_ci");
	sql_verbose_do("UPDATE $table SET $column=CONVERT(CONVERT(binary $column USING latin1) using utf8)");

	if(defined $post)
	{
		sql_verbose_do($post);
	}
}

sub sql_verbose_do
{
	my ($cmd) = @_;

	print STDERR localtime()."\n";
	print STDERR "$cmd"."\n";
	$dbh->do($cmd);
}

my $latin1_search = $dbh->prepare("SELECT TABLE_NAME, COLUMN_NAME, COLUMN_TYPE FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = 'everything' and CHARACTER_SET_NAME='latin1'");

$latin1_search->execute();

while (my $row = $latin1_search->fetchrow_arrayref())
{
	my ($latin1_table, $latin1_column, $latin1_type) = @$row;
	next if exists($tables_to_convert->{$latin1_table}->{$latin1_column});
	
	 convert_table_column($latin1_table, $latin1_column, $latin1_type);
}

foreach my $latin1_table (keys %$tables_to_convert)
{
	foreach my $latin1_column (keys %{$tables_to_convert->{$latin1_table}})
	{
		my $latin1_type = $tables_to_convert->{$latin1_table}->{$latin1_column};
		my ($pre, $post);
		if(ref $latin1_type eq "ARRAY") #Has pre and post
		{
			$pre = $latin1_type->[1];
			$post = $latin1_type->[2];
			$latin1_type = $latin1_type->[0];
		}

		convert_table_column($latin1_table, $latin1_column, $latin1_type,$pre,$post);
	}
}

