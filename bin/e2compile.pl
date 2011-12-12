#!/usr/bin/perl

use strict;
use lib qw(/usr/local/everything);
use Everything;
initEverything 'everything';
use Everything::HTML;
use Data::Dumper;

foreach my $current_type (qw(htmlcode superdoc)){

	my $nodetype = getNode($current_type,'nodetype');
	
	my $dbh = $DB->getDatabaseHandle();
	my $csr = $dbh->prepare('SELECT node_id FROM node where type_nodetype='.$nodetype->{node_id});
	$csr->execute();

	`mkdir -p lib/Everything/Compiled`;
my $handle;
open $handle, ">lib/Everything/Compiled/$current_type.pm";
print $handle <<"HEADING1";
#!/usr/bin/perl -w
use strict;
use Everything;
use Everything::HTML;
use Everything::Experience;

package Everything::Compiled::$current_type;
# This file was automatically generated by e2compile.pl

HEADING1

print $handle q|
BEGIN
{
	foreach my $sub qw(getRandomNode handle_errors query_vars_string tagApprove htmlScreen cleanupHTML tableWellFormed debugTag debugTablescreenTable buildTable breakTags unMSify encodeHTML decodeHTML htmlFormatErr htmlErrorUsers htmlErrorGods jsWindow urlGen getCode getPages getPageForType getPage rewriteCleanEscape urlGenNoParams linkNode linkNodeTitle nodeName evalCode htmlcode embedCode parseCode stripCode listCode quote insertNodelet updateNodelet genContainer containHtml displayPage gotoNode confirmUser parseLinks urlDecode loginUser getCGI getTheme printHeader handleUserRequest cleanNodeName clearGlobals opNuke opLogin opLogout opNew getOpCode execOpCode isSuspended mod_perlInit mod_perlpsuedoInit escapeAngleBrackets isSpider findIsSpider showPartialDiff showCompleteDiff generate_test_cookie assign_test_condition check_test_substitutions recordUserAction processVarsSet)
	{
		eval("\$Everything::Compiled::|.$current_type.q|::{$sub} = *Everything::HTML::$sub;");
	}

|;

my $var_mapping = 
{
	'$NODE' => '::HTML::GNODE',
	'$dbh' => '::',
	'$USER' => '::HTML::',
	'$GNODE' => '::HTML::',
	'%HTMLVARS' => '::HTML::',
	'$DB' => '::',
	'%CONFIG' => '::',
	'$VARS' => '::HTML::',
	'$query' => '::HTML::',
	'$HTTP_ERROR_CODE' => '::HTML::',
	'$ERROR_HTML' => '::HTML::',
	'$SITE_UNAVAILABLE' => '::HTML::',
	'$IS_SPIDER' => '::HTML::',
	'$TEST' => '::HTML::',
	'$TEST_CONDITION' => '::HTML::',
	'$TEST_SESSION_ID' => '::HTML::',
	'$THEME' => '::HTML::',
	'$CACHESTORE' => '::HTML::',
	'$NODELET' => '::HTML::',
	'%HEADER_PARAMS' => '::HTML::',	
};

print $handle "use vars qw(".join(" ",keys %$var_mapping).");\n";

foreach my $var (keys %$var_mapping)
{
	my $rawname = $var;
	$rawname =~ s/^[\$\%]//g;
	my $mapping = $var_mapping->{$var};
	if($mapping =~ /::$/)
	{
		$mapping .= $rawname;
	}

	print $handle '*Everything::Compiled::'.$current_type.'::'.$rawname.' = *Everything'.$mapping.";\n";
}

print $handle <<'HEADING3';

	foreach my $sub qw(getRef getId getTables getNode getNodeById getType getNodeWhere selectNodeWhere selectNode nukeNode insertNode updateNode updateLockedNode replaceNode transactionWrap initEverything removeFromNodegroup replaceNodegroup insertIntoNodegroup canCreateNode canDeleteNode canUpdateNode canReadNode updateLinks updateHits getVars setVars selectLinks isGroup isNodetype isGod lockNode unlockNode getCompiledCode clearCompiledCode dumpCallStack getCallStack printErr printLog)
	{
		eval("\$Everything::Compiled::htmlcode::{$sub} = *Everything::$sub;");
	}
}

HEADING3

	while(my $row = $csr->fetchrow_hashref())
	{
		my $current_object = getNode($row->{'node_id'});
		next if $current_object->{node_id} == 401321;
		
		my $title = $current_object->{title};
		next if
		$title =~ s/[\s-]/_/g;
		$title = "__$current_type"."_$title";
		print $handle "\n\n";
		print $handle "# ".$current_object->{title}." (node_id: ".$current_object->{node_id}.")\n";
		print $handle "sub ".$title."\n";
		print $handle "{\n";
		print $handle "\n\n";

		if($current_type eq "htmlcode")
		{
			print $handle " # Begin code from DB\n";
			print $handle $current_object->{code}."\n";
		}elsif($current_type eq "superdoc")
		{
			print $handle "#SUPERDOC STUFF HERE\n";
		}

		print $handle "}\n\n";
	}

	print $handle "\n\n";
	print $handle "1;";

	close $handle;
}
