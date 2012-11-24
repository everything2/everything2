#!/usr/bin/perl -w

use strict;
use lib qw(/root/everything2/ecore);
use Everything;
use Everything::HTML;
use Data::Dumper;

initEverything 'everything';

my $usertype = getType('user');
my $csr = $DB->sqlSelectMany('node_id','node','type_nodetype='.getId($usertype));
my $virgil = getNode("Virgil","user");
while(my $row = $csr->fetchrow_arrayref())
{
	my $U = getNodeById($row->[0]);

	my $converted = $APP->convertScratchPadsForUser($U);
	next unless $converted;

	if(scalar(@$converted) != 0)
	{
		my $message = "Attention user: We have converted the scratch pads (of which you had ".(scalar (@$converted)).") into the [Drafts] feature that has replaced it. See [Everything2 Tech Update - Nov 2012: Retiring scratch pads] for more details.";
		$DB->sqlInsert("message", {"msgtext" => $message,"author_user" => $$virgil{node_id},"for_user" => $$U{node_id} });

		print $U->{title}." - ".scalar(@$converted)."\n";
	}
}
