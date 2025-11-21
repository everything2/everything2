package Everything::XML;

############################################################
#
#        Everything::XML.pm
#                A module for the XML stuff in Everything
#
############################################################

use strict;
use warnings;
use Everything;
use XML::Generator;
use XML::Parser;

## no critic (ProhibitAutomaticExportation)

sub BEGIN
{
   use Exporter();
   use vars qw($VERSIONS @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
   @ISA=qw(Exporter);
   @EXPORT=qw(
      node2xml
	);
}

use vars qw($NODE);
use vars qw($VARS);
use vars qw($isVars);
use vars qw(@activetag);
use vars qw(%TABLES);
use vars qw($nodetype);
use vars qw(@FIXES);
use vars qw($XMLGEN);
use vars qw($XMLPARSE);

####################################################################
#
#	Sub 
#		genTag
#
#	purpose
#		simple wrapper function to generate an xml tag
#		using XML::Generator
#
#	parameters
#		tag -- the name of the tag to generate
#		content -- the stuff to be put inside the tag
#		PARAMS -- hash reference containing tag attributes
#		embedXML -- don't make the content xml-safe (we'll embed XML)

sub genTag {
	my ($tag, $content, $PARAMS, $embedXML) = @_;
	return unless $tag;
	$PARAMS ||= {};
	
	$XMLGEN = new XML::Generator if not $XMLGEN; 
	
        if(defined($content))
        {
          unless($embedXML)
          {
  	    $content = makeXmlSafe($content);
          }
        }
	return $XMLGEN->$tag($PARAMS,$content)."\n";
}

#####################################################################
#	Sub
#		makeXmlSafe
#
#	purpose
#		make a string not interfere with the xml
#
#	parameters
#		str - the literal string 
sub makeXmlSafe {
	my ($str) = @_;
        
	#we use an HTML convention...  
	$str =~ s/\&/\&amp\;/g;
	$str =~ s/\</\&lt\;/g;
	$str =~ s/\>/\&gt\;/g;

	return $str;
}

#####################################################################
#	Sub
#		unMakeXmlSafe
#
#	purpose 
#		decode something encoded by makeXmlSafe
#	
#	parameters
#		str - da string!
sub unMakeXmlSafe {
	my ($str) = @_;

	$str =~ s/\&amp\;/\&/g;
	$str =~ s/\&lt\;/\</g;
	$str =~ s/\&gt\;/\>/g;
	return $str;
}

######################################################################
#	Sub
#		vars2xml
#
#	purpose
#		Take a "vars" hash -- generate a vars tag with nested item tags
#		also, change node references to a type/title format
#
#	parameters
#		tag - the varable tag 
#		VARS - a hash reference containing the variable data 
#			(procured from getVars)
#		PARAMS - optional additional parameters
#
sub vars2xml {
	my ($tag, $VARS, $PARAMS) = @_;
	$PARAMS ||= {};
	my $varstr = "";
	
	foreach my $key (keys %$VARS) {
#		print "generating variable for $key\n";
		$varstr.="\t\t";
		if ($key =~ /_(\w+)$/ and $$VARS{$key} =~ /^\d+$/) {
		#this is a node reference
			$varstr.= noderef2xml($key, $$VARS{$key});
		} else {
			$varstr.= genTag $key, $$VARS{$key}; 
		}
	}
	return genTag ($tag, "\n".$varstr."\t", $PARAMS, 'parseth not the xml tags');
}

#################################################################
#	Sub
# 		group2xml
#
#	purpose
#		take a list of node references and return them in XML form
#		
#   parameters
#		tag -- the group's parent tag
#		group- a reference to a list of nodes
#		PARAMS -- hash reference with optional additional parameters

sub group2xml {
	my ($tag, $group, $PARAMS) = @_;
	$PARAMS ||= {};
	my $ingroup = "";
	my $count = 1;
	foreach (@$group) {
		my $localtag = "groupnode" . $count++;
		$ingroup.="\t\t" 
			.noderef2xml($localtag, $_, {table=>'nodegroup'}) ;
	}
	return genTag($tag, "\n".$ingroup."\t", $PARAMS, "don't parse me please");
}

##################################################################
#	Sub
#		noderef2xml
#
#	purpose
#		generate a tag that references a node by type and title
#
#	parameters
#		tag -- the field to generate
#		node_id -- the node's numeric id (or the node itself)
#		PARAMS -- additional attributes for the tag
#
sub noderef2xml {
	my ($tag, $node_id, $PARAMS) = @_;
	$PARAMS ||= {};

	my $POINTED_TO = $Everything::DB->getNodeById($node_id);
	my ($title, $typetitle, $TYPE);

	if (keys %$POINTED_TO) {
		$title = $$POINTED_TO{title};
		$typetitle = $$POINTED_TO{type}{title};
	} else {
		# This can happen with the '-1' field values when nodetypes
		# are inherited.
		$title = $node_id;
		$typetitle = "literal_value";
	}
	$$PARAMS{type} = $typetitle;

	return genTag ($tag, $title, $PARAMS);
}

###################################################################
#	Sub
#		node2xml
#
#	purpose
#		return a node to us in PORTABLE well-formed XML
#
#	parameters
#		NODE - the node to generate XML for

sub node2xml
{
	my ($NODE, $EXCEPT) = @_;
	getRef ($NODE); 
	$EXCEPT ||= [];

	my %newhash = %$NODE;
	my $N = \%newhash;
	#create a copy of the node so that we can mess around with it

	my @NOFIELDS = ('hits', 
		'createtime', 
		'table', 
		'type', 
		'lasttime',
		'lockedby_user',
		'locktime',
		'tableArray',
		'resolvedInheritance', 'passwd', 'nltext', 'sqltablelist');

   push @NOFIELDS, @$EXCEPT if $EXCEPT;

	foreach (@NOFIELDS) {
		delete $$N{$_} if exists $$N{$_};
	}

	foreach (keys %$N) {
		delete $$N{$_} if /_id$/;
	}


	my $str = "";
	$XMLGEN = new XML::Generator unless $XMLGEN;
	$str.= $XMLGEN->INFO('rendered by Everything::XML.pm') ."\n";
	#note: should also include server, date/time info

	my @tables = getTables($NODE);
	push @tables, 'node';

	my (%fieldtable); 

	foreach my $table (@tables) {
		my @fields = $Everything::DB->getFields($table);
		foreach (@fields) {
			$fieldtable{$_} = $table if (exists $$N{$_});
		}
	}

	#now we catch the node table
	my @keys = sort {$a cmp $b} (keys %$N);	
	foreach my $field (@keys) {
		my %attr = (table => $fieldtable{$field});
		$str .= "\t";	
		if (ref $$N{$field} eq "ARRAY") {
			#we have to deal with a group
			delete $attr{table};	
			$str.= group2xml($field, $$N{$field}, \%attr);
		
		} elsif ($field eq 'vars') {
			#we have a setting hash
			$str.= vars2xml($field, getVars($N), \%attr);
		
		} elsif ($field =~ /_\w+$/ and defined($N->{$field}) and $N->{$field} =~ /^\d+$/) {
			# This field is a node reference.  We need to resolve this
			# reference to a node name and type.
			$str.= noderef2xml($field, $$N{$field}, \%attr);
		
		} else { 
			$str.= genTag($field, $$N{$field}, \%attr);
		}
	}

	return $XMLGEN->NODE($str);
}
1;
