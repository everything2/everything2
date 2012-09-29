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

`mysqldump -u$user --single-transaction --routines --triggers $pass -h$host $db | gzip --best > "$tmpdir/$filename"`;
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
		}else{
			print "Could not find node 'backup ready mail' of type 'mail'\n";
		}
	}else{
		print "Could not send email, notification_email not set!\n";
	}
}else{
	print "File upload failed\n";
}

`rm -rf $tmpdir`;
