#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Everything;
use Everything::Search;
use Everything::HTML;
use XML::Simple;

initEverything 'everything';

my $xs = XML::Simple->new("NoSort" => 1, "KeepRoot" => 1, "NoAttr" => 1, "SuppressEmpty" => "");
my $user = getNode('root','user');
foreach my $file(`diff -r nodepack.pre/ nodepack.live/ 2>&1 | grep ^Only | grep nodepack.pre/`)
{
	if($file =~ /nodepack\.pre\/\/(.*?)\:\ (.*?)\.xml/)
	{
		$file = "nodepack.pre/$1/$2.xml";
	}else{
		next;
	}
	
	chomp $file;
	my $N = $xs->XMLin($file);
	$N = $N->{node};

	print STDERR "Deleting node: $N->{title}\n";
	$DB->nukeNode($N->{node_id},$user);
}

