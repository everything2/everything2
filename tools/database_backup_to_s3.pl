#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Everything;
use Everything::S3;
use Everything::MAIL;

my $uploader = Everything::S3->new("backup");
my $tmpdir = "/tmp/everything_backup_$$";
`mkdir -p $tmpdir`;

my $user = $Everything::CONF->{'everyuser'};
my $pass = $Everything::CONF->{'everypass'};
my $host = $Everything::CONF->{'everything_dbserv'};
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
	if($Everything::CONF->{notification_email} ne "")
	{
		my $email = getNode("backup ready mail", "mail");
		if($email)
		{
			$email->{doctext} =~ s/\<filename\>/$filename/g;
			$email->{title} = "Backup ready on S3: $filename";
			node2mail($Everything::CONF->{notification_email},$email,1);
			print commonLogLine("Sent email to: ".$Everything::CONF->{notification_email});
		}else{
			print commonLogLine("Could not find node 'backup ready mail' of type 'mail'");
		}
	}else{
		print commonLogLine("Could not send email, notification_email not set");
	}
}else{
	print commonLogLine("File upload failed!");
}

`rm -rf $tmpdir 2>&1`;
