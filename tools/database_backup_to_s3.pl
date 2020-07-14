#!/usr/bin/perl -w

use strict;
use lib qw(/var/libraries/lib/perl5);
use lib qw(/var/everything/ecore);
use Everything;
use Everything::S3;

my $uploader = Everything::S3->new("backup");
my $tmpdir = "/tmp/everything_backup_$$";
`mkdir -p $tmpdir`;

initEverything 'everything';

my $user = $Everything::CONF->everyuser;
my $pass = $Everything::CONF->everypass;
my $host = $Everything::CONF->everything_dbserv;
my $db = "everything";

my $time = [gmtime()];
my $year = $time->[5] + 1900;
my $mon = sprintf("%02d", $time->[4] + 1);
my $day = sprintf("%02d", $time->[3]);

if($pass ne "")
{
	$pass = "-p$pass";
}

my $filename = "everything.$year$mon$day.sql.gz";

print commonLogLine("Starting mysqldump to tmpdir: '$tmpdir'");

`mysqldump -u$user --single-transaction --routines --triggers $pass -h$host $db | gzip --best > "$tmpdir/$filename"`;
print commonLogLine("Completed mysqldump, starting upload");

if($uploader->upload_file($filename, "$tmpdir/$filename"))
{
  my $topic = "database-backup-complete";
  if($Everything::CONF->environment eq "production")
  {
    $APP->sns_notify($topic, "Backup ready on S3: $filename", "Backup is ready on S3: $filename");
    print commonLogLine("Sent SNS topic to $topic");
  }
}else{
	print commonLogLine("File upload failed!");
}

`rm -rf $tmpdir 2>&1`;
