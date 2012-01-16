package Everything::XML;

############################################################
#
#        Everything::XML.pm
#                A module for the XML stuff in Everything
#
############################################################

use strict;
use Everything;
use XML::Generator;
use XML::Parser;

sub BEGIN
{
   use Exporter();
   use vars qw($VERSIONS @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
   @ISA=qw(Exporter);
   @EXPORT=qw(
      xml2node
      xmlfile2node
      node2xml
	  initXmlParse
	  fixNodes 
	  dumpFixes
	  readTag	
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

###########################################################################
#	Sub
#		readTag
#
#	purpose - to quickly read an xml tag, without parsing the whole document
#		right now, it doesn't read attributes, only contents.
#
sub readTag {
	my ($tag, $xml) = @_;
	if ($xml =~ /\<\s*$tag.*?\>(.*?)\<\s*\/$tag.*?\>/gsi) {
		return unMakeXmlSafe($1);
	}
	"";
}


#############################################################################
#	Sub
#		start_handler
#
#	Purpose  
#		This is a callback for the XML parser.  This gets called when we
#		hit a start XML tag.
#
sub start_handler {
	my $parser = shift @_;
	my $tag = shift @_;
	
	# Initialize the tag
	my $isReference = 0;
	
	# Clear the field for this tag.  We will set it later.
	$$NODE{$tag} = "";

	while (@_) {
		my $attr = shift @_;
		my $val = shift @_;
		
		if ($attr eq "table") {
			if ($tag eq "vars") {
				$isVars = 1;
			}
			# Add this tag to the list of fields for the given table.
			push @{ $TABLES{$val} }, $tag;	
		} elsif (($attr eq "type") && ($val ne "literal_value")) {
			# This tag represents a reference to another node.  Add
			# this to the list of fixes that we will need to apply later.
			$isReference=1;
			push @FIXES, {type => $val, field => $tag, title => $tag, isVars => $isVars};
		}
	}

	push @activetag, { isReference => $isReference, title => $tag};
}

#############################################################################
#	Sub
#		char_handler
#
#	Purpose
#		Callback for the XML parser, this gets called on data between the
#		start and end tag.
#
sub char_handler {
	my ($parser, $data) = @_;
	my $tag = pop @activetag;

	if ($isVars) {
		$$VARS{$$tag{title}} .= $data;
	} else {
		$$NODE{$$tag{title}} .= $data;
	}
	push @activetag, $tag;
}

#############################################################################
#	Sub
#		end_handler
#
#	Purpose
#		Callback for the XML parser.  This gets called when it encounters
#		the end tag.
#
sub end_handler {
	my $tag = pop @activetag;

	if ($isVars and $$tag{isReference}) {
		my $fix = pop @FIXES;
		$$fix{title} = $$VARS{$$tag{title}};
		push @FIXES, $fix;
		$$VARS{$$tag{title}} = -1;
	} elsif ($$tag{isReference}) {
		# If this tag is a field value that is reference to another node,
		# we need to mark the value as needing fixing.

		# Set the title of the fix
		my $fix = pop @FIXES;
		$$fix{title} = $$NODE{$$tag{title}};
		push @FIXES, $fix;

		if ($$tag{title} eq "type_nodetype")
		{
			# This is referencing a nodetype, check to see if we already have
			# it loaded.  If not, we need to mark the nodetype field as
			# unknown for now.
			$nodetype = $$NODE{type_nodetype}; 
			if ($DB->getType($nodetype)) {
				$$NODE{type_nodetype} = getId $DB->getType($nodetype); 	
			} else {
				$$NODE{type_nodetype} = -1;
			}
		} else {
			$$NODE{$$tag{title}} = -1;
		}
	} elsif ($$tag{title} eq "vars") {
		$isVars = 0;
		delete $$VARS{vars};
	}
	
}

##############################################################################
#	sub
#		findRef
#
#	purpose
#		find a node referred to by a node reference.  Spit out an error if 
#		it isn't found and the printError flag is set.  
#		Returns the referenced node's id
#
sub findRef {
	my ($FIX, $printError) = @_;
	
	my ($REFNODE) = $DB->getNodeWhere( { title=>$$FIX{title} },
		$DB->getType($$FIX{type}) );

	if (not getId($REFNODE)) {
		print "ERROR!  Fix failed on $$FIX{node_id}: needs" .
				" a $$FIX{type} named $$FIX{title}\n" if $printError;	 
		return -1;
	}

	getId $REFNODE;
}


#############################################################################
#	sub
#		fixNodes		
#
#	purpose
#		fix all errors registered in the @FIXES array
#		these are usually broken dependancies, and node references
#		to nodes that didn't exist when the node was inserted from the XML
#
sub fixNodes 
{
	my ($printError) = @_;
	my @UNFIXED;
	
	while ($_ = shift @FIXES) {
		next if ($$_{field} eq "group");
		
		my $id = findRef $_, $printError;
		if ($id == -1) {
			push @UNFIXED, $_;
			next;
		}
		#the node that we have a dependancy for isn't available
		
		if ($$_{isVars}) {
			my $TEMPVARS = getVars $$_{node_id};
			$$TEMPVARS{$$_{field}} = $id unless $$TEMPVARS{$$_{field}} != -1; 
			setVars $$_{node_id}, $TEMPVARS;
		} elsif ($$_{field} =~ /^groupnode/) {	
			my $GROUP = $$_{node_id};
			insertIntoNodegroup($GROUP, -1, $id);
		} else {
			my $N = $DB->getNodeById($$_{node_id});
			$$N{$$_{field}} = $id; 
			$DB->updateNode($N, -1);
		}
	}
	push @FIXES, @UNFIXED;
	#leave unresolved fixes on the list
}

###########################################################################
#	sub 
#		dumpFixes
#
#	purpose
#		print out the fixes array for debugging
#
sub dumpFixes {
	foreach (@FIXES) {
		print "Node $$_{node_id} needs $$_{title} ($$_{type}) for "
			."its $$_{field} field.";
		print "  (VARS)  " if $$_{isVars};
		print "\n";
	}
}

###########################################################################
#	Sub
#		initXmlParse
#	
#	purpose
#		initialize the global XMLPARSE object, and returns it
#		if you care.
#
#
sub initXmlParse {
	$XMLPARSE ||= new XML::Parser (ErrorContext => 2);
	$XMLPARSE->setHandlers(Char => \&char_handler, End => \&end_handler,
		Start => \&start_handler);


	@FIXES = ();

	$XMLPARSE;
}


#########################################################################
#	Function
#		xml2node
#
#	purpose
#		takes a chunk of XML -- returns a $NODE hash
#		any broken dependancies are pushed on @FIXES, and the node is 
#		inserted into the database (with -1 on any broken fields)
#		returns the node_id of the new node
#
#	parameters
#		xml -- the string of xml to parse
#
sub xml2node{
	my ($xml) = @_;
	my $TYPE;
	
	# Start with a clean "vars".
	%TABLES = ();
	%$NODE = ();
	%$VARS = ();
	$nodetype = "";
	$isVars = 0;

	my $node_id;

	# parse the XML
	$XMLPARSE = initXmlParse unless $XMLPARSE;
	$XMLPARSE->parse($xml);
	
	$TYPE = $DB->getType($nodetype);
	if (defined $TYPE) {
		#we already have the nodetype for this loaded...
		my $title = $$NODE{title};
		my %data = ();
		my @ta = @{ $$TYPE{tableArray} };
		my $tableArray = \@ta;
		
		my @fields;
		my $table;
		
		push @$tableArray, "node";
		foreach $table (@$tableArray) {
			push @fields, @{ $TABLES{$table} };
		}
		pop @$tableArray;
		
		#perhaps we already have this node, in which case we should update it
		my $OLDNODE = $DB->getNode($title, $TYPE);
		my $OLDVARS = {};
	
		if ($OLDNODE) {
			$OLDVARS = getVars $OLDNODE if exists $$OLDNODE{vars};
			@$OLDNODE{@fields} = @$NODE{@fields};
			if (isGroup($$OLDNODE{type})) {
				replaceNodegroup ($OLDNODE, [], -1);
			}
			$DB->updateNode ($OLDNODE, -1);
			$node_id = getId($OLDNODE);
		} else {
			#otherwise, we insert the node into the database
			@data{@fields} = @$NODE{@fields};
			if (isGroup($DB->getType($nodetype))) {
				foreach (keys %data) {
					delete $data{$_} if /^groupnode/;
				}
				$node_id = $DB->replaceNode ($title, getId($TYPE), -1);
			} else {
				$node_id = $DB->replaceNode ($title,
					getId($TYPE), -1, \%data);
			}
		}

		if (keys %$VARS) {
			@$VARS{keys %$OLDVARS} = values %$OLDVARS if $nodetype eq 'setting';
				#we never replace old settings in a setting node 
			setVars $node_id, $VARS;
		}

		foreach (@FIXES) {
			$$_{node_id} = $node_id if not $$_{node_id};
		}
		return $node_id;
	}

	#if we don't have a nodetype, we have to assemble everything from tables
	#  NOTE: vars fields and group fields will not work unless their proper nodetypes
	#  exist!  This only works for simple types of nodes

	foreach (keys %$NODE) {
		$$NODE{$_} = $DB->quote($$NODE{$_});
	}
	
	# First, insert the node table information.  We need to do this to get
	# the node id.
	my @fields = @{ $TABLES{node} };
	my $sql = "INSERT INTO node ";
	$sql .= "(createtime,". join(",",@fields) . ")\n";
	$sql .= "VALUES (now(),". join(",",@$NODE{@fields}) .")\n";
	$DB->getDatabseHandle()->do($sql) or die "SQL insert for node failed.";
	$node_id = $DB->sqlSelect('LAST_INSERT_ID()');
	
	# Now that we have our node id, we can insert the infor the rest
	# of the tables.
	foreach my $table (keys %TABLES) {
		#we do an insert on the table
		next if $table eq 'node';
		
		@fields = @{ $TABLES{$table} };
		
		my $sql = "INSERT INTO $table ";
		$sql .= "(" . $table . "_id," . join(", ", @fields).")\n";	
		$sql .= "VALUES ($node_id,".join(', ', @$NODE{@fields}).")\n";	
		$DB->getDatabaseHandle()->do($sql) or 
			die "owie.  SQL insert for table $table failed";
		delete @$NODE{@fields};
	}

	foreach (@FIXES) {
		$$_{node_id} = $node_id if not $$_{node_id};
	}

		$node_id;
};

####################################################################
#
#	Sub
#		xmlfile2node
#
#	purpose
#		wrapper for xml2node that takes a filename as a parameter
#		rather than a string of XML
#
#
sub xmlfile2node {
    my ($filename) = @_;
	
	open MYXML, $filename or die "could not access file $filename";
	my $file = join "", <MYXML>;
	close MYXML;
	xml2node($file);	
}

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
	
	no strict 'refs';
	$content = makeXmlSafe($content) unless $embedXML;	
	*{(ref $XMLGEN) ."::$tag"}->($XMLGEN, $PARAMS, $content)."\n";
	#tricky, but that's how XML::Generator works...
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

	$str;
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
	$str;
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
	genTag ($tag, "\n".$varstr."\t", $PARAMS, 'parseth not the xml tags');
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
		my $tag = "groupnode" . $count++;
		$ingroup.="\t\t" 
			.noderef2xml($tag, $_, {table=>'nodegroup'}) ;
	}
	genTag($tag, "\n".$ingroup."\t", $PARAMS, "don't parse me please");
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

	my $POINTED_TO = $DB->getNodeById($node_id);
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
	$$PARAMS{type}  = $typetitle;

	genTag ($tag, $title, $PARAMS);
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


	my $str;
	$XMLGEN = new XML::Generator unless $XMLGEN;
	$str.= $XMLGEN->INFO('rendered by Everything::XML.pm') ."\n";
	#note: should also include server, date/time info

	my @tables = getTables($NODE);
	push @tables, 'node';

	my (%fieldtable); 

	foreach my $table (@tables) {
		my @fields = $DB->getFields($table);
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
		
		} elsif ($field =~ /_\w+$/ and $$N{$field} =~ /^\d+$/) {
			# This field is a node reference.  We need to resolve this
			# reference to a node name and type.
			$str.= noderef2xml($field, $$N{$field}, \%attr);
		
		} else { 
			$str.= genTag($field, $$N{$field}, \%attr);
		}
	}

	$XMLGEN->NODE($str);
}
1;
