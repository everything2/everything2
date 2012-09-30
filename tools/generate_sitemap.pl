#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Everything;
use Everything::HTML;
use Everything::S3;

use XML::Generator;

initEverything 'everything';
my $xg = XML::Generator->new(':pretty');
my $tmpdir = "/tmp/sitemaps_$$";
`mkdir $tmpdir`;

my $sitemapnum = 0;
my $sitemapfiles;

my $urls = 0;
my $e2 = "http://everything2.com";
my $sitemaphandle;

$DB->{cache}->setCacheSize(50);

open_sitemapfile();
foreach my $includetype(qw(e2node writeup user))
{
	my $csr = $DB->sqlSelectMany($includetype."_id",$includetype);
	while(my $row = $csr->fetchrow_hashref())
	{
		my $N = getNodeById($row->{$includetype."_id"});
		next unless $N;
		$urls++;

		my $edittime;
		if($N->{type}{title} eq "writeup")
		{
			$edittime = writeup_edittime($N);
		}elsif($N->{type}{title} eq "e2node")
		{
			my $edittimes;
			next unless defined $N->{group};
			next if scalar(@{$N->{group}}) == 0;
			foreach my $writeupnode(@{$N->{group}})
			{
				my $thisnode = getNode($writeupnode);
				next unless $thisnode;
				push @$edittimes, writeup_edittime($thisnode);
				undef $thisnode;
			}
			next unless $edittimes;

			$edittimes = [sort {$b cmp $a} @$edittimes];
			$edittime = $edittimes->[0];
			undef $edittimes;
		}elsif($N->{type}{title} eq "user")
		{
			$edittime = $N->{lasttime};
			if($edittime =~ /0000-00-00/)
			{
				# User never logged in
				next;
			}
		}

		next unless $edittime;
		add_node_to_sitemap($N, $edittime);

		if($urls >= 50000)
		{
			$urls = 0;
			close_sitemapfile();
			$sitemapnum++;
			open_sitemapfile();
		}

		undef $N;
	}
}

close_sitemapfile();
sleep(3);
`gzip -f /$tmpdir/*.xml`;
my $indexfile;
open $indexfile, ">/$tmpdir/index.xml";
print $indexfile '<?xml version="1.0" encoding="UTF-8"?>
<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'."\n";
foreach my $sitemapfile (@$sitemapfiles)
{
	my $thistime = [localtime()];
	my $thistimestring = ($thistime->[5]+1900)."-".sprintf('%02d',$thistime->[4]+1)."-".sprintf('%02d',$thistime->[3]);
	print $indexfile $xg->sitemap($xg->loc("$e2/sitemap/$sitemapfile"), $xg->lastmod($thistimestring))."\n";
}

print $indexfile '</sitemapindex>';
close $indexfile;

my $s3 = Everything::S3->new("sitemap");

foreach my $sitemapfile(@$sitemapfiles,"index.xml")
{
	$s3->upload_file($sitemapfile, "$tmpdir/$sitemapfile");
}

sub close_sitemapfile
{
	print $sitemaphandle '</urlset>';
	close $sitemaphandle;
}

sub open_sitemapfile
{
	open $sitemaphandle, ">/$tmpdir/$sitemapnum.xml";
	print $sitemaphandle '<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'."\n";
	push @$sitemapfiles, "$sitemapnum.xml.gz";
}

sub add_node_to_sitemap
{
	my ($N, $edittime) = @_;
	
	print $sitemaphandle $xg->url(
		$xg->loc("$e2".urlGenNoParams( $N , 'noQuotes' )),
		defined($edittime)?($xg->lastmod($edittime)):(undef),
	)."\n";
}

sub writeup_edittime
{
	my ($N) = @_;

	my $edittime = $N->{edittime};
	if($edittime =~ /0000-00-00/)
	{
		$edittime = $N->{createtime};
	}
	return $edittime;
}

`rm -rf $tmpdir`;
