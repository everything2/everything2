#!/usr/bin/perl -w

use strict;
use Carp;
use DBI;
use Encode::Encoder;

my $dbh = DBI->connect("DBI:mysql:everything:localhost;mysql_enable_utf8=1", "everyuser", "", {AutoCommit => 1});

my $E2DB="mysql --default-character-set=utf8 -u root everything";

# Don't need this anymore, indexes are going to be fine
my $tables_to_convert =
{
};

my $reference_tables =
{
	"node" => "title",
	"message" => "msgtext",
	"document" => "doctext",
};


sub make_count_table
{
	my ($flavor, $table, $column) = @_;

	if(exists($reference_tables->{$table}) and $reference_tables->{$table} eq $column)
	{
		my $count_table = "_".$flavor."_".$table."_".$column."_length";
		sql_verbose_do("DROP TABLE IF EXISTS $count_table");
		sql_verbose_do("CREATE TABLE $count_table (id INT NOT NULL PRIMARY KEY, ".$flavor."length INT)");
		sql_verbose_do("INSERT INTO $count_table SELECT $table"."_id as id, CHAR_LENGTH($column) AS ".$flavor."length FROM $table");
	}
}

sub convert_table_column
{
	my ($table, $column, $definition, $pre, $post) = @_;

	return unless $table eq "node" and $column eq "title";

	make_count_table("latin1",$table,$column);

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


	my $conversion_table = "_utf8_conversion_table_$table";
	sql_verbose_do("DROP TABLE IF EXISTS $conversion_table");
	sql_verbose_do("CREATE TABLE IF NOT EXISTS $conversion_table LIKE $table");
	sql_verbose_do("INSERT INTO $conversion_table SELECT * from $table");
	sql_verbose_do("ALTER TABLE $conversion_table MODIFY $column $definition character set utf8 COLLATE utf8_unicode_ci");

	my $table_explanation = explain_table($table);
	delete $table_explanation->{$column};

	my $data_loop_csr = $dbh->prepare("SELECT * FROM $table");
	$data_loop_csr->execute();

	while(my $main_table_row = $data_loop_csr->fetchrow_hashref())
	{
		my $encoded = Encode::Encoder->new($main_table_row->{$column})->latin1->utf8;
		my $updates;
		foreach my $key (keys %$table_explanation)
		{
			if(defined($main_table_row->{$key}))
			{
				push @$updates, "$key=".$dbh->quote($main_table_row->{$key});
			}else{
				push @$updates, "$key IS NULL";
			}
		} 
		my $update_str = "UPDATE $conversion_table SET $column=".$dbh->quote($encoded)." WHERE ".join(" AND ", @$updates);
		my $count = $dbh->do($update_str);
		if($count != 1)
		{
			confess("Update of utf8 booster failed: ($count rows): $update_str");			
		}
	}

	sql_verbose_do("DROP table $table");
	sql_verbose_do("RENAME TABLE $conversion_table TO $table");

	if(defined $post)
	{
		sql_verbose_do($post);
	}

	make_count_table("utf8",$table,$column);
}

sub explain_table
{
	my ($table) = @_;
	my $result;

	my $explain_csr = $dbh->prepare("EXPLAIN $table");
	$explain_csr->execute();
	while(my $row = $explain_csr->fetchrow_arrayref())
	{
		$result->{$row->[0]} = $result->{$row->[1]};
	}

	return $result;
}

sub sql_verbose_do
{
	my ($cmd) = @_;

	print STDERR localtime()."\n";
	print STDERR "$cmd"."\n";
	return $dbh->do($cmd);
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

