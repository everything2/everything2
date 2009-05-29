package Everything::HTML;
#
#	Copyright 1999,2000 Everything Development Company
#
#		A module for the HTML stuff in Everything.  This
#		takes care of CGI, cookies, and the basic HTML
#		front end.
#
#############################################################################

use strict;
use Everything;
use Everything::MAIL;
use Everything::Search;
use Everything::CacheStore;
#use StopWatch;
require CGI;
use CGI::Carp qw(fatalsToBrowser);


sub BEGIN {
	use Exporter ();
	use vars qw($DB $VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@ISA=qw(Exporter);
	@EXPORT=qw(
		%HEADER_PARAMS
		$DB
		%HTMLVARS
		$query
		jsWindow
		createNodeLinks
		parseLinks
		htmlScreen
		screenTable
		breakTags
		htmlFormatErr
		quote
		urlGen
		urlGenNoParams
		getCode
		getPage
		getPages
		getPageForType
		linkNode
		linkNodeTitle
		nodeName
		evalCode
		htmlcode
		embedCode
		displayPage
		gotoNode
		confirmUser
		urlDecode
		encodeHTML
		decodeHTML
    escapeAngleBrackets
		unMSify
		mod_perlInit
                mod_perlpsuedoInit);
}

use vars qw($query);
use vars qw(%HTMLVARS);
use vars qw($GNODE);
use vars qw($USER);
use vars qw($VARS);
use vars qw($THEME);
use vars qw($NODELET);
use vars qw($CACHESTORE);
use vars qw(%HEADER_PARAMS);
my $PAGELOAD = 0;
my $NUMPAGELOADS = 10;
     
sub getRandomNode {
        my $limit = $DB->sqlSelect("max(e2node_id)", "e2node");
        my $min = $DB->sqlSelect("min(e2node_id)", "e2node");
        my $rnd = int(rand($limit-$min));
        
	$rnd+= $min;

        my $e2node = $DB->sqlSelect("e2node_id", "e2node", "e2node_id=$rnd");

        $e2node||=getRandomNode();

        $e2node;
}


 
######################################################################
#	sub
#		tagApprove
#
#	purpose
#		determines whether or not a tag (and it's specified attributes)
#		are approved or not.  Returns the cleaned tag.  Used by htmlScreen
#
sub tagApprove {
    my ($close, $tag, $attr, $APPROVED) = @_;

    $tag = uc($tag) if (exists $$APPROVED{uc($tag)});
    $tag = lc($tag) if (exists $$APPROVED{lc($tag)});

    if (exists $$APPROVED{$tag}) {
        my @aprattr = split ",", $$APPROVED{$tag};
        my $cleanattr;
        foreach (@aprattr) {
            if (($attr =~ /\b$_\b\='(\w+?%?)'/i) or
                ($attr =~ /\b$_\b\="(\w+?%?)"/i) or
                ($attr =~ /\b$_\b\="?'?(\w*\b%?)/i)) {
                $cleanattr.=" ".$_.'="'.$1.'"';
            }
        }
        "<".$close.$tag.$cleanattr.">";
    } else { ""; }
}


#############################################################################
#	sub
#		htmlScreen
#
#	purpose
#		screen out html tags from a chunk of text
#		returns the text, sans any tags that aren't "APPROVED"		
#
#	params
#		text -- the text to filter
#		APPROVED -- ref to hash where approved tags are keys.  Null means
#			all HTML will be taken out.
#
sub htmlScreen {
	my ($text, $APPROVED) = @_;
	$APPROVED ||= {};

	if ($text =~ /\<[^>]+$/) { $text .= ">"; }

  #The simple-minded approach won't serve us here... The code below is
  #intended to escape tags *except* in the cases of [link <anchor>] or
  #[link <anchor>|text], so that direct links in linkNodeTitle can
  #work. This is ugly, and I eagerly await a better solution. --[Swap]
	$text =~ s!

              ((?:\[(.*?)\]))             #Either match a square bracket...
             |
               <\s*(/?)([^\>|\s]+)(.*?)>  #Or match a tag

            !
             my $bracket = $1;
             my ($slash,$tag,$attrib) = ($3,$4,$5);
             if ($bracket) {
               #Matched a pipelink with the right anchor format
               if ($bracket =~ /\[([^<>]*<.*>)\s*\|(.*)\]/s) {

                              #However, screen the title text
                 ($2 ? "[$1|".htmlScreen($2,$APPROVED)."]" : "[$1]");
               }

               #Pipelink, but wrong anchor format, screen both parts
               elsif ($bracket =~ /\[(.*)\|(.*)\]/s) {
                 ($2 ? "[".htmlScreen($1,$APPROVED)."|"
                  .htmlScreen($2,$APPROVED)."]"
                  : "[".htmlScreen($1,$APPROVED)."]");
               }

               #Matched a hardlink with the right anchor format
               elsif ($bracket =~ /\[([^<>]*<.*>)\s*\]/s) {
                 "[$1]";
               }

               #Matched a hardlink, but not the right format, so screen
               #all of it.
               elsif ($bracket =~ /\[(.*)\]/s) {
                 "[".htmlScreen($1,$APPROVED)."]";
               }
             }

             #Match an HTML tag. Screen it.
             else{
               tagApprove($slash,$tag,$attrib,$APPROVED);
             }
            !gsex;

	$text;
}


#############################################################################
#       sub
#               screenTable
# 
#       purpose
#               screen out broken tables
#               returns the HTML as it was for valid tables, otherwise helps to debug.
#
#       params
#               text -- the text to filter
#
# By [call] - see [edev: Tables and HTML Validation]
# Okay, in brief:
# fast 'cause it's optimised to the 'common' cases:
# Most writeups have no tables. Zoooom!
# Writeups that have tables will mostly have valid tables:
#   => Only a quick parse to validate.
# We 'enforce' the validity of tables by outputting debug info
#   for badly formed tables. This is UGLY so writeup authors will
#   fix 'em quick.
# In an HTMLcode, so compilation of this code is amortised.
# [screenHTML] should still be used, and can be used to control
#   attributes in the tags. Ideally this works on the output of
#   screenHTML, but only because the 'debug' output uses <div>s
#   with dashed outlines to help HTML writers find their oopsies.


# Should be reasonably fast: scans through the HTML using a m''g, which
# is about as fast as anything in perl can be. Stacks the tags (only
# looks at table tags) and checks the structural validity by 
# matching a two-level context descriptor (stack . tag) against
# an RE describing valid contexts. (again, perl and RE => faster than
# a bunch of ifs or whatever)
sub tableWellFormed ($) {
    my (@stack);
    for ($_[0] =~ m{<(/?table|/?tr|/?th|/?td)[\s>]}ig) {
        my $tag = lc $_;
        my $top = $stack[$#stack];

        if (substr($tag, 0, 1) eq '/') {
            # Closing tag. Pop from stack and check that they match.
            return (0, "$top closed with $tag")
              if pop @stack ne substr($tag, 1);
        } else {
            # Opening tag. Push, and check context is valid.
            push @stack, $tag;
            return (0, "$tag inside $top") 
                if (($top.$tag) !~ /^(table(tr)?|tr(td|th)|(td|th)(table))$/);
        }
    }
    return (0, "Unclosed table elements: " . join ", ", @stack)
        if ($#stack != -1);
    return 1;
}

sub debugTag ($) {
    my ($tag) = @_;
    my $htmltag = $tag;
    $htmltag =~ s/</&lt;/g; # should be encodeHTML, but of course
                            # I don't have that in my standalone testbench.
    $htmltag = "<strong><small>&lt;" . $htmltag . "&gt;</small></strong>";

    if (substr($tag, 0, 1) ne '/') {
        return $htmltag . "<div style=\"margin-left: 16px; border: dashed 1px grey\">";
    } else {
        return "</div>". $htmltag;
    }
}

sub debugTable ($$) {
    my ($error, $html) = @_;
    $html =~ s{<((/?)(table|tr|td|th)((\s[^>]*)|))>}{debugTag $1}ige;
    return "<p><strong>Table formatting error: $error</strong></p>".$html;
}

sub screenTable {
    my ($text) = @_;
    my ($valid, $error) = tableWellFormed($text);
    $text = debugTable ($error, $text) if ! $valid;
    $text;
}



#############################################################################
#       sub
#               breakTags
#
#       purpose
#               Insert paragraph tags where none are found
#

sub breakTags {

  my ($text) = @_;
  # Format if necessary - adapted from [call]'s code from his own ecore
  unless ($text =~ /<\/?p[ >]/i || $text =~ /<br/i) {

    # Replace all newlines in inappropriate elementswith placeholders
    my @ignorenewlines = ("pre", "ol", "ul", "dl", "table");
    foreach my $currenttag (@ignorenewlines) {
      # match attributes in HTML tags by seeing everything up to the closing >

      while ($text =~ /<$currenttag((.*?)\n(.*?))<\/$currenttag/si) {
        my $temp = $1;
        $temp =~ s%\n%<e2 newline placeholder>%g;
        $text =~ s%<$currenttag((.*?)\n(.*?))</$currenttag%<$currenttag$temp</$currenttag%si;
      }

    }


    # Replace all leftover \ns with BRs, and BRBR with P

    $text =~ s%^\s*%%g;
    $text =~ s%\s*$%%g;
    $text =~ s%\n%<br>%g;
    $text =~ s%\s*<br>\s*<br>%</p>\n\n<p>%g;
    $text =~ s%\n\s*\n%</p>\n\n<p>%g;
    $text = '<p>' . $text . '</p>';
    my ($blocks) = "pre|center|li|ol|ul|h1|h2|h3|h4|h5|h6|blockquote|dd|dt|dl|p|table|td|tr|th";
    $text =~ s"<p><($blocks)"<$1"g;
    $text =~ s"</($blocks)></p>"</$1>"g;
    # Clean up by replacing newlines placeholders with proper \ns again.
    #
    $text =~ s"<e2 newline placeholder>"\n"g;

  }

  $text;
}

########################################################################
#  Sub
#       unMSify
#
#  purpose
#       check for, and convert unconventional ASCII chars
#       to plaintext
#
sub unMSify {
   my ($s) = @_;
   return $s unless $s =~ /[\x82-\x9C]/;

   #this code was blatantly stolen from "demoronizer.pl"
   # originally by John Walker
   # http://www.fourmilab.ch/webtools/demoroniser/

   $s =~ s/\x82/,/g;
   $s =~ s-\x83-<em>f</em>-g;
   $s =~ s/\x84/,,/g;
   $s =~ s/\x85/.../g;

   $s =~ s/\x88/^/g;
#    $s =~ s-\x89- °/°°-g;

   $s =~ s/\x8B/</g;
   $s =~ s/\x8C/Oe/g;

##    $s =~ s/\x91/`/g;
       $s =~ s/\x91/'/g;
   $s =~ s/\x92/'/g;
   $s =~ s/\x93/"/g;
   $s =~ s/\x94/"/g;
   $s =~ s/\x95/*/g;
##    $s =~ s/\x96/-/g;
       $s =~ s/\x96/&ndash;/g;
##    $s =~ s/\x97/--/g;
       $s =~ s/\x97/&mdash;/g;
##    $s =~ s-\x98-<sup>~</sup>-g;
       $s =~ s/\x98/~/g;
##    $s =~ s-\x99-<sup>TM</sup>-g;
       $s =~ s/\x99/&trade;/g;

   $s =~ s/\x9B/>/g;
   $s =~ s/\x9C/oe/g;

   $s;
}





#############################################################################
#	Sub
#		encodeHTML
#
#	Purpose
#		Convert the HTML markup characters (>, <, ", etc...) into encoded
#		characters (&gt;, &lt;, &quot;, etc...).  This causes the HTML to be
#		displayed as raw text in the browser.  This is useful for debugging
#		and displaying the HTML.
#
#	Parameters
#		$html - the HTML text that needs to be encoded.
#		$adv - Advanced encoding.  Pass 1 if some non-HTML, but Everything
#			specific characters should be encoded.
#
#	Returns
#		The encoded string
#
sub encodeHTML
{
	my ($html, $adv) = @_;

	# Formerly the '&amp;' *had* to be done first.  Otherwise, it would convert
	# the '&' of the other encodings. However, it is now designed not to encode &s that are part of entities.
        #$html =~ s/&(?!\#(?>x[0-9a-fA-F]+|[0-9]+);)/&amp;/g;

        $html =~ s/\&/\&amp\;/g;
        #$html =~ s/&(?!\#(?>x[0-9a-fA-F]+|[0-9]+);|[a-zA-Z])/&amp;/g;
	$html =~ s/\</\&lt\;/g;
	$html =~ s/\>/\&gt\;/g;
	$html =~ s/\"/\&quot\;/g;

	if($adv)
	{
		$html =~ s/\[/\&\#91\;/g;
		$html =~ s/\]/\&\#93\;/g;
	}

	return $html;
}


#############################################################################
#	Sub
#		decodeHTML
#
#	Purpose
#		This takes a string that contains encoded HTML (&gt;, &lt;, etc..)
#		and decodes them into their respective ascii characters (>, <, etc).
#
#		Also see encodeHTML().
#
#	Parameters
#		$html - the string that contains the encoded HTML
#		$adv - Advanced decoding.  Pass 1 if you would also like to decode
#			non-HTML, Everything-specific characters.
#
#	Returns
#		The decoded HTML
#
sub decodeHTML
{
	my ($html, $adv) = @_;

	$html =~ s/\&amp\;/\&/g;
	$html =~ s/\&lt\;/\</g;
	$html =~ s/\&gt\;/\>/g;
	$html =~ s/\&quot\;/\"/g;

	if($adv)
	{
		$html =~ s/\&\#91\;/\[/g;
		$html =~ s/\&\#93\;/\]/g;
	}

	return $html;
}


#############################################################################
#	Sub
#		htmlFormatErr
#
#	Purpose
#		An error has occured and we need to print or log it.  This will
#		do the appropriate action based on who the user is.
#
#	Parameters
#		$code - the code snipit that is causing the error
#		$err - the error message returned from the system
#		$warn - the warning message returned from the system
#
#	Returns
#		An html/text string that will be displayed to the browser.
#
sub htmlFormatErr
{
	my ($code, $err, $warn) = @_;
	my $str;

        my $dbg = getNode("debuggers", "usergroup");

        #if(isGod($USER))
        if($DB->isApproved($USER, $dbg))
	{
		$str = htmlErrorGods($code, $err, $warn);
	}
	else
	{
		$str = htmlErrorUsers($code, $err, $warn);
	}

	$str;
}


#############################################################################
#	Sub
#		htmlErrorUsers
#
#	Purpose
#		Format an error for the general user.  In this case we do not
#		want them to see the error or the perl code.  So we will log
#		the error and give them a simple one.
#
#		You can define a custom error text by creating an htmlcode
#		node that formats a string error.  The code is passed a single
#		numeric value that can be used to reference the error that is
#		written to the log file.  However, be very careful that your
#		htmlcode for your custom message doesn't have an error, or
#		you may cause a user to get stuck in an infinite loop.  Since,
#		an error in that code would cause the system to call itself
#		to handle the error.
#
#	Parameters
#		$code - the code snipit that is causing the error
#		$err - the error message returned from the system
#		$warn - the warning message returned from the system
#
#	Returns
#		An html/text string that will be displayed to the browser.
#
sub htmlErrorUsers
{
	my ($code, $err, $warn) = @_;
	my $errorId = int(rand(9999999));  # just generate a random error id.
	my $str = htmlcode("htmlError", $errorId);

	# If the site does not have a piece of htmlcode to format this error
	# for the users, we will provide a default.
	if((not defined $str) || $str eq "")
	{
		$str = "Server Error (Error Id $errorId)!";
		$str = "<font color=\"#CC0000\"><b>$str</b></font>";
		
		$str .= "<p>An error has occured.  Please contact the site";
		$str .= " administrator with the Error Id.  Thank you.";
	}

	# Print the error to the log instead of the browser.  That way users
	# do not see all the messy perl code.
	my $error = "Server Error (#" . $errorId . ")\n";
        $error .= "Node: $$GNODE{title}\n";

	$error .= "User: $$USER{title}\n";
	$error .= "User agent: " . $query->user_agent() . "\n" if defined $query;
	$error .= "Code:\n$code\n";
	$error .= "Error:\n$err\n";
	$error .= "Warning:\n$warn";
	Everything::printLog($error);

	$str;
}


#############################################################################
#	Sub
#		htmlErrorGods
#
#	Purpose
#		Print an error for a god user.  This will dump the code, the call
#		stack and any other error information.  You probably don't want
#		the average user of a site to see this stuff.
#
#	Parameters
#		$code - the code snipit that is causing the error
#		$err - the error message returned from the system
#		$warn - the warning message returned from the system
#
#	Returns
#		An html/text string that will be displayed to the browser.
#
sub htmlErrorGods
{
	my ($code, $err, $warn) = @_;
	my $error = $err . $warn;
	my $linenum;

	$code = encodeHTML($code);

	my @mycode = split /\n/, $code;
	while($error =~ /line (\d+)/sg)
	{
		# If the error line is within the range of the offending code
		# snipit, make it red.  The line number may actually be from
		# a perl module that the evaled code is calling.  If thats the
		# case, we don't want some bogus number to add lines.
		if($1 < (scalar @mycode))
		{
			# This highlights the offendling line in red.
			$mycode[$1-1] = "<FONT color=cc0000><b>" . $mycode[$1-1] .
				"</b></font>";
		}
	}

	my $str = "<B>$@ $warn</B><BR>";

	my $count = 1;
	$str.= "<PRE>";
	foreach my $line (@mycode)
	{
		$str .= sprintf("%4d: $line\n", $count++, $str);
	}

	# Print the callstack to the browser too, so we can see where this
	# is coming from.
	$str .= "\n\n<b>Call Stack</b>:\n";
	my @callStack = getCallStack();
	while(my $func = pop @callStack)
	{
		$str .= "$func\n";
	}
	$str .= "<b>End Call Stack</b>\n";
	
	$str.= "</PRE>";
	$str;
}


#############################################################################
sub jsWindow
{
	my($name,$url,$width,$height)=@_;
	"window.open('$url','$name','width=$width,height=$height,scrollbars=yes')";
}



#############################################################################
#   Sub
#       urlGen
#
#   Purpose
#       Generates URLs. Still uses the old-style non-semantic URLs; please see urlGenNoParams
#
#   Parameters
#       hashref of node_id and any other parameters for the URL like viewcode, etc.
#       noquotes - in case you don't want quotes around the URL.

sub urlGen {
	my ($REF, $noquotes) = @_;

	my $str;
	$str .= '"' unless $noquotes;
	$str .= "$ENV{SCRIPT_NAME}?"; # Usually index.pl

	# Cycle through all the keys of the hashref for node_id, etc.
	foreach my $key (keys %$REF) {
		$str .= CGI::escape($key) .'='. CGI::escape($$REF{$key}) .'&amp;';
	}
	$str = substr($str,0,-5);
	$str .= '"' unless $noquotes;
	$str;
}


#############################################################################
#   Sub
#       getCode
#
#   Purpose
#       This gets the node of the appropriate htmlcode function
#
#   Parameters
#       funcname - The name of the function to rerieve
#       args - optional arguments to the function.
#           arguments must be in a comma delimited list, as with
#           embedded htmlcode calls
#
sub getCode
{
	my ($funcname, $args) = @_;
#	$args = "" if not defined $args;	
	my $CODE = getNode($funcname, getType("htmlcode"));
	
	return '"";' unless (defined $CODE);

	my $str;
	$str = "\@\_ = split (/\\s\*,\\s\*/, '$args');\n" if defined $args;
	$str .= $$CODE{code};

	return $str;
}


#############################################################################
#	Sub
#		getPages
#
#	Purpose
#		This gets the edit and display pages for the given node.  Since
#		nodetypes can be inherited, we need to find the display/edit pages.
#
#		If the given node is a nodetype, it will get the display pages for
#		that particular nodetype rather than the main 'nodetype'.
#		Difference is subtle between this function and getPage().  If you
#		pass a nodetype to getPage() it will return the htmlpages to display
#		it, while this will return the htmlpages needed to display nodes
#		of the type passed in.
#
#		For example, lets say you pass the nodetype 'document' to both
#		this and getPage().  This would return 'document display page'
#		and 'document edit page', while getPage would return 'nodetype
#		dipslay page' and 'nodetype edit page'.
#
#	Parameters
#		$NODE - the nodetype in which to get the display/edit pages for.
#
#	Returns
#		An array containing the display/edit pages for this nodetype.
#
sub getPages
{
	my ($NODE) = @_;
	getRef $NODE;
	my $TYPE;
	my @pages;

	$TYPE = $NODE if (isNodetype($NODE) && $$NODE{extends_nodetype});
	$TYPE ||= getType($$NODE{type_nodetype});

	push @pages, getPageForType($TYPE, "display");
	push @pages, getPageForType($TYPE, "edit");

	return @pages;
}


#############################################################################
#	Sub
#		getPageForType
#
#	Purpose
#		Given a nodetype, get the htmlpages needed to display nodes of this
#		type.  This runs up the nodetype inheritance hierarchy until it
#		finds something.
#
#	Parameters
#		$TYPE - the nodetype hash to get display pages for.
#		$displaytype - the type of display (usually 'display' or 'edit')
#
#	Returns
#		A node hashref to the page that can display nodes of this nodetype.
#
sub getPageForType
{
	my ($TYPE, $displaytype) = @_; 
	my %WHEREHASH;
	my $PAGE;
my $ORIGTYPE = $$TYPE{node_id};
	my $PAGETYPE;
	
	$PAGETYPE = getType("htmlpage");
	$PAGETYPE or die "HTML PAGES NOT LOADED!";

	# Starting with the nodetype of the given node, We run up the
	# nodetype inheritance hierarchy looking for some nodetype that
	# does have a display page.
	do
	{
		# Clear the hash for a new search
		undef %WHEREHASH;
		
		%WHEREHASH = (pagetype_nodetype => $$TYPE{node_id}, 
				displaytype => $displaytype);
		
		if ($THEME) {
			$WHEREHASH{ownedby_theme} = $$THEME{theme_id}; 
			($PAGE) = getNodeWhere(\%WHEREHASH, $PAGETYPE);
			
			delete $WHEREHASH{ownedby_theme} unless $PAGE;
			#if we didn't get a page for the current theme, do a default
		} 


		($PAGE) = getNodeWhere(\%WHEREHASH, $PAGETYPE) unless $PAGE;

		if(not defined $PAGE)
		{
			if($$TYPE{extends_nodetype})
			{
				$TYPE = getType($$TYPE{extends_nodetype});
			}
			else
			{

			# No pages for the specified nodetype were found.
				# Use the default node display.
				($PAGE) = getNodeWhere (
						{pagetype_nodetype => getId(getType("node")),
						displaytype => $displaytype}, 
						$PAGETYPE);



				$PAGE or ($PAGE) =  getNodeWhere(
						{pagetype_nodetype => $ORIGTYPE,
						displaytype => "display" },
						$PAGETYPE );

		#		$PAGE or die "No default pages loaded.  " .  
		#			"Failed on page request for $WHEREHASH{pagetype_nodetype}" .
		#			" $WHEREHASH{displaytype}\n";
			}
		}
	} until($PAGE);

	return $PAGE;
}


#############################################################################
#	Sub
#		getPage
#
#	Purpose
#		This gets the htmlpage of the specified display type for this
#		node.  An htmlpage is basically a database form that knows
#		how to display the information for a particular nodetype.
#
#	Parameters
#		$NODE - a node hash of the node that we want to get the htmlpage for
#		$displaytype - the type of display of the htmlpage (usually
#			'display' or 'edit')
#
#	Returns
#		The node hash of the htmlpage for this node.  If none can be
#		found it uses the basic node display page.
#
sub getPage
{
	my ($NODE, $displaytype) = @_; 
	my $TYPE;
	
	getRef $NODE;
	$TYPE = getType($$NODE{type_nodetype});
	$displaytype ||= $$VARS{'displaypref_'.$$TYPE{title}}
	  if exists $$VARS{'displaypref_'.$$TYPE{title}};
	$displaytype ||= $$THEME{'displaypref_'.$$TYPE{title}}
	  if exists $$THEME{'displaypref_'.$$TYPE{title}};
	$displaytype ||= 'display';


	my $PAGE = getPageForType $TYPE, $displaytype;
	$PAGE ||= getPageForType $TYPE, 'display';

	die "can't load a page $displaytype for $$TYPE{title} type" unless $PAGE;

	$PAGE;
}

sub rewriteCleanEscape {
	my ($string) = @_;
	$string = CGI::escape(CGI::escape($string));
	return $string;
}

sub urlGenNoParams {
	my ($NODE, $noquotes) = @_;
	if (not ref $NODE) {
    if ($noquotes) {
      return "/node/$NODE";
    }
    else {
      return "\"/node/$NODE\"";
		}
	}

	my $retval = "";
  if ($$NODE{type}{title} eq 'e2node') {
    $retval = "/title/".rewriteCleanEscape($$NODE{title});
  }
  elsif ($$NODE{type}{title} eq 'user') {
    $retval = "/".$$NODE{type}{title}."/".rewriteCleanEscape($$NODE{title});
	}
  elsif ($$NODE{type}{restrictdupes} && $$NODE{title}) {
		$retval = "/node/".$$NODE{type}{title}."/"
              .rewriteCleanEscape($$NODE{title});
	}
  else {
		$retval = "/node/".getId($NODE);
	}

	if ($noquotes) {
    return $retval;
  }
  else {
    return '"'.$retval.'"';
  }
}




#############################################################################
sub linkNode {
	my ($NODE, $title, $PARAMS) = @_;
	#getRef $NODE;	

	return if not ref $NODE and $NODE == -1;
	return unless $NODE;
	unless ($title) {
		$NODE = getNodeById($NODE, 'light') unless ref $NODE;
		$title = encodeHTML($$NODE{title});
	}
#	return unless ref $NODE;	

	

	if ($NODE == -1) {return "<a>$title</a>";}
	$title ||= encodeHTML($$NODE{title});
	$$PARAMS{node_id} = getId $NODE;
	my $tags = "";

	$$PARAMS{lastnode_id} = getId ($GNODE) unless exists $$PARAMS{lastnode_id};
	#any params that have a "-" preceding 
	#get added to the anchor tag rather than the URL
	foreach my $key (keys %$PARAMS) {

		next unless ($key =~ /^-/); 
		my $pr = substr $key, 1;
		$tags .= " $pr=\"$$PARAMS{$key}\""; 
		delete $$PARAMS{$key};
	}
	if ((keys(%$PARAMS) == 2 && exists $$PARAMS{lastnode_id}) or (keys(%$PARAMS) == 1)) {
		if ($$PARAMS{lastnode_id} == 0) {
			"<a onmouseup=\"document.cookie='lastnode_id=0; ; path=/'; 1;\" href=" . urlGenNoParams($NODE) . $tags . ">$title</a>";
		} else {
			"<a onmouseup=\"document.cookie='lastnode_id=".$$PARAMS{lastnode_id}."; ; path=/'; 1;\" href=" . urlGenNoParams($NODE) . $tags . ">$title</a>";
		}
	} else {
		"<a href=" . urlGen ($PARAMS) . $tags . ">$title</a>";
	}
}


#############################################################################
sub linkNodeTitle {
	my ($nodename, $lastnode, $escapeTags) = @_;
  my $title;
	($nodename, $title) = split /\|/, $nodename;
	$title = $nodename if $title eq "";
	$nodename =~ s/\s+/ /gs;

	my $str = "";
  my ($tip, $isNode);

  #A direct link draws near! Command?
  if($nodename =~ /^([^\[\]]+)\[(.+)\]?$/){
    my ($anchor,$originalnodename);
    $originalnodename = $nodename;
    $nodename = $1;
    $anchor = $2;

    $tip = $nodename;
    $tip =~ s/"/''/g;

    $title = $nodename if $title eq $originalnodename;

    if($escapeTags){
      $title =~ s/</\&lt\;/g;
      $title =~ s/>/\&gt\;/g;
      $tip =~ s/</\&lt\;/g;
      $tip =~ s/>/\&gt\;/g;
    }

    my ($nodetype,$user) = split /\bby\b/, $anchor;
    $nodetype =~ s/^\s*//;
    $nodetype =~ s/\s*$//;
    $user =~ s/^\s*//;
    $user =~ s/\s*$//;

    $nodename = rewriteCleanEscape($nodename);

    #Aha, trying to link to a discussion post
    if($nodetype =~ /^\d+$/){
      $str .= "<a onmouseup=\"document.cookie='lastnode_id=0; ; "
              ."path=/'; 1;\" title=\"$tip\" href=\""
              ."/node/debate/$nodename#debatecomment_$nodetype";
    }

    #Perhaps direct link to a writeup instead?
    elsif(grep /^$nodetype$/, ("","e2node","node","writeup") ){
      #Anchors are case-sensitive, need to get the exact username.
      $user = getNode($user,"user");
      $user = ($user? $$user{title} : "");

      $str .= "<a onmouseup=\"document.cookie='lastnode_id="
               .($lastnode? $lastnode : 0)."; ; "
               ."path=/'; 1;\" title=\"$tip\" href=\""
               ."/title/$nodename#$user";
    }

    #Or maybe a scratch pad?
    elsif($nodetype =~ /^scratch/){
      $str .= "<a onmouseup=\"document.cookie='lastnode_id=0; ;"
               ."path=/'; 1;\" title=\"$tip\" href=\""
               ."/scratch/$user/$nodename";
    }

    #Else, direct link to nodetype. Let's hope the users know what
    #they're doing.
    else{
      $str .= "<a onmouseup=\"document.cookie='lastnode_id="
              .($lastnode? $lastnode : 0)."; ;"
              ."path=/'; 1;\" title=\"$tip\" href=\""
              .($nodetype eq "user" ? "/" : "/node/")
              ."$nodetype/$nodename";
    }
  }

  #Plain ol' link, no direct linking.
  else {
    if($escapeTags){
      $title =~ s/</\&lt\;/g;
      $title =~ s/>/\&gt\;/g;
      $nodename =~ s/</\&lt\;/g;
      $nodename =~ s/>/\&gt\;/g;
    }
    $tip = $nodename;
    $tip =~ s/"/''/g;

    #my $isNode = getNodeWhere({ title => $nodename});
    $isNode = 1;
    my $urlnode = CGI::escape($nodename);
    #$str .= "<a title=\"$tip\" href=\"$ENV{SCRIPT_NAME}?node=$urlnode";
    #if ($lastnode) { $str .= "&amp;lastnode_id=" . getId($lastnode);}
    if (!$lastnode) {
      $str .= "<a onmouseup=\"document.cookie='lastnode_id=0; ; "
        ."path=/'; 1;\" title=\"$tip\" href=\"/title/"
          .rewriteCleanEscape($nodename);
    }
    else {
      $str .= "<a onmouseup=\"document.cookie='lastnode_id=$lastnode; ; "
        ."path=/'; 1;\"  title=\"$tip\" href=\"/title/"
          .rewriteCleanEscape($nodename);
    }
  }
  $str .= "\" "
          .( $isNode ? "class='populated'" : "class='unpopulated'")
         ." >$title</a>";


	$str;
}


#############################################################################
#	Sub
#		nodeName
#
#	Purpose
#		This looks for a node by the given name.  If it finds something,
#		it displays the node.
#
#	Parameters
#		$node - the string name of the node we are looking for.
#		$user_id - the user trying to view this node (for authorization)
#
#	Returns
#		nothing
#
sub nodeName
{
	my ($node, $user_id) = @_;

	if (my $KW = getNode ('keyword settings', 'setting')) {
		my $WORDS = getVars $KW;	
		my $title = lc($node) ."_node";
		#please note -- this means that keywords must be in lower case...

		if (exists $$WORDS{$title}) {
			gotoNode($$WORDS{$title}, $user_id);
			return;
		}
	}

	my $matchall = $query->param("match_all");
	my $soundex = $query->param("soundex");

	my @types = $query->param("type");
	foreach(@types) {
		$_ = getId($DB->getType($_));
	}

	my ($select_group, $search_group, $NODE);
	unless ($soundex or $query->param("match_all")) 
		# exact match only if these options are off
	{
		my %selecthash = (title => $node);
		my @selecttypes = @types;
		$selecthash{type_nodetype} = \@selecttypes if @selecttypes;
		$select_group = $DB->selectNodeWhere(\%selecthash);
	}

	my $type = $types[0];
	$type ||= "";

	if (not $select_group or @$select_group == 0)
	{ 
		# We did not find an exact match, so do a search thats a little
		# more fuzzy.
		$search_group =
        	        searchNodeName($node, \@types, $soundex, 1);
	
		if($search_group && @$search_group > 0)
		{
			$NODE = getNodeById($HTMLVARS{search_group});
			$$NODE{group} = $search_group;
		}
		else
		{
			$NODE = getNodeById($HTMLVARS{not_found});	
		}

		displayPage ($NODE, $user_id);
	}
	elsif (@$select_group == 1)
	{
		# We found one exact match, goto it.
		my $node_id = $$select_group[0];
		gotoNode ($node_id, $user_id);
		return;
	}
	else
	{
		my @canread;
                #4/14/2002: Work begins here
                my $e2node;	
		foreach (@{ $select_group}) {
		   next unless canReadNode($user_id, $_);
                   getRef($_);
                   $e2node = $_ if($$_{type_nodetype} == getId($DB->getType('e2node')));	
		   push @canread, $_;
		}

		#jb says: 4/14/2002 - Enhancement made here to default to an e2node
                #instead of going to the findings page.  If there are more than one item, and
                #none of them is an e2node, then all you'll get "Findings:"

                #jb says: 5/02/2002 - Fixes here to use gotoNode instead of displayPage
                #see [root log: May 2002] for the long reason

		#return displayPage($HTMLVARS{not_found}, $user_id) unless @canread;
		return gotoNode($HTMLVARS{not_found}, $user_id, 1) unless @canread;
		#return displayPage($canread[0], $user_id) if @canread == 1;
		return gotoNode($canread[0], $user_id, 1) if @canread == 1;
                #return displayPage($e2node, $user_id) if $e2node;
                return gotoNode($e2node, $user_id, 1) if $e2node;

		#we found multiple nodes with that name.  ick
		my $NODE = getNodeById($HTMLVARS{duplicate_group});
		
		$$NODE{group} = \@canread;
		displayPage($NODE, $user_id);
	}
}


#############################################################################
#this function takes a bit of code to eval 
#and returns it return value.
#
#it also formats errors found in the code for HTML
sub evalCode {
	my ($code, $CURRENTNODE) = @_;
	#these are the vars that will be in context for the evals

	my $NODE = $GNODE;
	my $warnbuf = "";

	local $SIG{__WARN__} = sub { 
		$warnbuf .= $_[0] 
		 unless $_[0] =~ /^Use of uninitialized value/;
	};

	$code =~ s/\015//gs;
	my $str = eval $code;

 	local $SIG{__WARN__} = sub {};
	$str .= htmlFormatErr ($code, $@, $warnbuf) if ($@ or $warnbuf); 
	$str;
}

#########################################################################
#	sub htmlcode
#
#	purpose
#		allow for easy use of htmlcode functions in embedded perl
#		[{textfield:title,80}] would become:
#		htmlcode('textfield', 'title,80');
#
#	args
#		func -- the function name
#		args -- the arguments in a comma delimited list
#
#
sub htmlcode {
	my ($func, $args) = @_;
	my $code = getCode($func, $args);
	evalCode($code) if($code);
}

#############################################################################
#a wrapper function.
sub embedCode {
	my $block = shift @_;

	my $NODE = $GNODE;
	
	$block =~ /^(\W)/;
	my $char = $1;
	
	if ($char eq '"') {
		$block = evalCode ($block . ';', @_);	
	} elsif ($char eq '{') {
		#take the arguments out
		
		$block =~ s/^\{(.*)\}$/$1/s;
		my ($func, $args) = split /\s*:\s*/, $block;
		$args ||= "";
		my $pre_code = "\@\_ = split (/\\s*,\\s*/, \"$args\"); ";
		#this line puts the args in the default array
		
		$block = embedCode ('%'. $pre_code . getCode ($func) . '%', @_);
	} elsif ($char eq '%') {
		$block =~ s/^\%(.*)\%$/$1/s;
		$block = evalCode ($block, @_);	
	}
	
	# Block needs to be defined, otherwise the search/replace regex
	# stuff will break when it gets an undefined return from this.
	$block ||= "";

	return $block;
}


#############################################################################
sub parseCode {
	my ($text, $CURRENTNODE) = @_;

	# the order is:  
	# [% %]s -- full embedded perl
	# [{ }]s -- calls to the code database
	# [" "]s -- embedded code strings
	#
	# this is important to know when you are writing pages -- you 
	# always want to print user data through [" "] so that they
	# cannot embed arbitrary code...
	#
	# someday I'll come up with a better way to do that...


		 $text=~s/
		  \[
		  (
		  \{.*?\}
		  |".*?"
		  |%.*?%
		  )
		  \]
		   /embedCode($1,$CURRENTNODE)/egsx;
		           $text;


}

###################################################################
#	Sub
#		listCode
#
#	Purpose
#		To list code so that it will not be parsed by Everything or the browser
#
#	Parameters
#		code -- the block of code to display
#		numbering -- set to true if linenumbers are desired
#
sub listCode {
	my ($code, $numbering) = @_;
	return unless($code); 

	$code = encodeHTML($code, 1);

	my @lines = split /\n/, $code;
	my $count = 1;

	if($numbering)
	{
		foreach my $ln (@lines) {
			$ln = sprintf("%4d: %s", $count++, $ln);
		}
	}

	"<PRE>" . join ("\n", @lines) . "</PRE>";
}


#############################################################################
sub quote {
	my ($text) = @_;

	$text =~ s/([\W])/sprintf("&#%03u", ord $1)/egs;
	$text; 
}


#############################################################################
sub insertNodelet
{
	($NODELET) = @_;
	getRef $NODELET;
	my ($pre, $post) = ('', '');

        #my $html = genContainer($$NODELET{parent_container})
        #       if $$NODELET{parent_container};

        my $container = $$THEME{generalNodelet_container};
        $container ||= getId(getNode('nodelet container','container'));
	($pre, $post) = genContainer($container) if $container;
	
	# Make sure the nltext is up to date
	updateNodelet($NODELET);
	return unless ($$NODELET{nltext} =~ /\S/);
	
	# now that we are guaranteed that nltext is up to date, sub it in.
	return $pre.$NODELET->{nltext}.$post;
}


#############################################################################
#	Sub
#		updateNodelet
#
#	Purpose
#		Nodelets store their code in the nlcode (nodelet code) field.
#		This code is not eval-ed every time the nodelet is displayed.
#		Call this function every time you display a nodelet.  This
#		will eval the code if the specified interval has passed.
#
#		The updateinterval field dictates how often we eval the nlcode.
#		If it is -1, we eval the code the first time and never do it
#		again.
#
#	Parameters
#		$NODELET - the nodelet to update
#
sub updateNodelet
{
	my ($NODELET) = @_;
	my $interval;
	my $lastupdate;
	my $currTime = time; 

	getRef $NODELET;

	$interval = $$NODELET{updateinterval};
	$lastupdate = $$NODELET{lastupdate};
	$lastupdate ||= 0;
	$interval = 0 unless defined $interval;

        return if $interval;
        #we update nodes async

	# Return if we have generated it, and never want to update again (-1) 
	return if($interval == -1 && $lastupdate != 0);
	
	# If we are beyond the update interal, or this thing has never
	# been generated before, generate it.
#	if((not $currTime or not $interval) or
#		($currTime > $lastupdate + $interval) || ($lastupdate == 0))
	if ($interval == 0)
	{
		$$NODELET{nltext} = parseCode($$NODELET{nlcode}, $NODELET);
		$$NODELET{lastupdate} = $currTime; 

#		updateNode($NODELET, -1) unless $interval == 0;
		#if interval is zero then it should only be updated in cache
	}
	
	""; # don't return anything
}


#############################################################################
sub genContainer {
	my ($CONTAINER) = @_;
	getRef $CONTAINER;
	my $replacetext;
	# Create prefix and suffix code fields
	if (! exists $CONTAINER->{_context_prefix}) {
		($CONTAINER->{_context_prefix},
		 $CONTAINER->{_context_suffix})
		    = split('CONTAINED_STUFF', $CONTAINER->{context});
	}
	my $prefix = parseCode ($CONTAINER->{_context_prefix}, $CONTAINER);
	my $suffix = parseCode ($CONTAINER->{_context_suffix}, $CONTAINER);

	if ($$CONTAINER{parent_container}) {
		my ($parentprefix, $parentsuffix)
		    = genContainer($$CONTAINER{parent_container});
		return ($parentprefix.$prefix, $suffix.$parentsuffix);
	} 
	
	return ($prefix, $suffix);
}


############################################################################
#	Sub	containHtml
#
#	purpose
#		Wrap a given block of HTML in a container specified by title
#		hopefully this makes containers easier to use
#
#	params
#		container - title of container
#		html - html to insert
#
sub containHtml {
	my ($container, $html) =@_;
	my ($TAINER) = getNode($container, getType("container"));
	my ($pre, $post) = genContainer($TAINER);
	return $pre.$html.$post;
}


#############################################################################
#	Sub
#		displayPage
#
#	Purpose
#		This is the meat of displaying a node to the user.  This gets
#		the display page for the node, inserts it into the appropriate
#		container, prints the HTML header and then prints the page to
#		the users browser.
#
#	Parameters
#		$NODE - the node to display
#		$user_id - the user that is trying to 
sub displayPage
{
	my ($NODE, $user_id) = @_;
	getRef $NODE, $USER;
	die "NO NODE!" unless $NODE;
	$GNODE = $NODE;
	%HEADER_PARAMS = ();
	my $isGuest = 0;
	my $page = "";
	$isGuest = 1 if ($user_id == $HTMLVARS{guest_user});

	my $lastnode;
	if ($$NODE{type}{title} eq 'e2node') {
		$lastnode = getId($NODE);
	}elsif ($$NODE{type}{title} eq 'writeup') {
		$lastnode = $$NODE{parent_e2node};
	} elsif ($$NODE{type}{title} eq 'jscript' or $$NODE{type}{title} eq 'stylesheet') {
		$lastnode = -1;
	}
	

        #jb says fix here. We need to check for displaytype, because on xmltrue and future data
        #outputs, guest user loads on e2nodes would be broken
        #4-17-2002

        my $dsp = $query->param('displaytype');
        $dsp ||= "display";

	if($dsp eq "display"){
		if ($isGuest and $CACHESTORE and $page = $CACHESTORE->retrievePage($$NODE{node_id})) {
			printHeader($$NODE{datatype}, $$page, $lastnode);
			$query->print($$page);
			return "";
		}
        }

	my $PAGE = getPage($NODE, $query->param('displaytype'));
        #jb says: minor hack here 
	$$NODE{datatype} = $$PAGE{mimetype};
        $page = $$PAGE{page};

	die "NO PAGE!" unless $page;

	$page = parseCode($page, $NODE);
	if ($$PAGE{parent_container}) {
		my ($pre, $post) = genContainer($$PAGE{parent_container});
		$page = $pre.$page.$post;
	}
   
  #  my $XP = $$USER{experience};
#	delete $$USER{experience};  #hopefully this will clear up XP corruption
	setVars $USER, $VARS unless getId($USER) == $HTMLVARS{guest_user};
 #   $$USER{experience} = $XP;	
	printHeader($$NODE{datatype}, $page, $lastnode);

#	TOTAL HACK for SSL
    #$page =~ s|http\:(//thepope\.org/img)|https:$1|gs if $query->url =~ /^https/;
	#($ENV{SCRIPT_NAME} =~ /^https/);
	
	# We are done.  Print the page to the browser.
#	$page =~ s|http://thepope\.org/img/|http://216.200.201.213/~thepope/img/|gs;
#	$page =~ s|http://adfu\.blockstackers\.com/|http://216.200.201.212/~adfu/|gs;
	if ($isGuest and $CACHESTORE and $CACHESTORE->canCache($NODE, $query)) { 
       $CACHESTORE->cachePage($$NODE{node_id}, $page);	
	}
	#jb - AWESOME
	$query->print($page);
	$page = "";
}


#############################################################################
#the function where we go when we actually know which $NODE we want to view
sub gotoNode
{
	my ($node_id, $user_id, $no_update) = @_;

        #jb: no_update will short out the canUpdateNode stuff
        #it's a little hacky, but basically it will keep people
        #from editing nodes by name and shave off a pile of 
        #cycles. Editing by name is unnecessary

	my $NODE = {};
	unless (ref ($node_id) eq 'ARRAY') {
		# Is there a reason why we are "force"ing this node?
		# A 'force' causes us not to use the cache.
		$NODE = getNodeById($node_id, 'force');
	}
	else {
		$NODE = getNodeById($HTMLVARS{search_group});
		$$NODE{group} = $node_id;
	}

	unless ($NODE) { $NODE = getNodeById($HTMLVARS{not_found}); }	
	
	unless (canReadNode($user_id, $NODE)) {
		$NODE = getNodeById($HTMLVARS{permission_denied});
	}
	#these are contingencies various things that could go wrong

        unless($no_update){

	if (canUpdateNode($user_id, $NODE)) {
		if (my $groupadd = $query->param('add')) {
			insertIntoNodegroup($NODE, $user_id, $groupadd,
				$query->param('orderby'));
		}
		
		if ($query->param('group')) {
			my @newgroup;

			my $counter = 0;
			while (my $item = $query->param($counter++)) {
				push @newgroup, $item;
			}

			replaceNodegroup ($NODE, \@newgroup, $user_id);
		}

		my @updatefields = $query->param;
		my $updateflag;

		my $RESTRICTED = getVars(getNode('restricted fields', 'setting'));
		$RESTRICTED ||= {};
		foreach my $field (@updatefields) {
			if ($field =~ /^$$NODE{type}{title}\_(\w*)$/) {
				next if exists $$RESTRICTED{$1} or exists $$RESTRICTED{"$$NODE{type}{title}\_$1"};	
				$$NODE{$1} = $query->param($field);
				$updateflag = 1;
			}	
		}
		if ($updateflag) {
			updateNode($NODE, $USER); 
			if (getId($USER) == getId($NODE)) { $USER = $NODE; }
		}
	}
	
        } #unless $no_update

	updateHits ($NODE);
	if ($query->cookie('lastnode_id')) {
		$query->param('lastnode_id', $query->cookie('lastnode_id'));
	}
	updateLinks ($NODE, $query->param('lastnode_id')) if $query->param('lastnode_id') and getId($USER) != $HTMLVARS{guest_user};

	my $displaytype = $query->param("displaytype");

	#if we are accessing an edit page, we want to make sure user
	#has rights -- also, lock the page
	#we unlock the page on command as well...
	if ($displaytype and $displaytype eq "edit") {
		if (canUpdateNode ($USER, $NODE)) {
			if (not lockNode($NODE, $USER)) {
				$NODE = getNodeById($HTMLVARS{node_locked});
				$query->param('displaytype', 'display');
			} 
		} else {
			$NODE = getNodeById($HTMLVARS{permission_denied});
			$query->param('displaytype', 'display');
		}
	} elsif ($query->param('op') eq "unlock") {
		unlockNode ($USER, $NODE);
	}

	displayPage($NODE, $user_id);
}


#############################################################################
sub confirmUser {
	my ($nick, $crpasswd) = @_;

	my $USER = getNode($nick, getType('user'));

        #jb says: added this line
        return 0 unless($$USER{acctlock} == 0);

	if (crypt ($$USER{passwd}, $$USER{title}) eq $crpasswd) {
		my $rows = $DB->getDatabaseHandle()->do("
			UPDATE user SET lasttime=now() WHERE
			user_id=$$USER{node_id}
			") or die;

		#jb says: perf speedup here. One less node commit
		#per user per page
		#further note: only works in 1.0

		#$$USER{lasttime} = $DB->sqlSelect("NOW()");
		#return $USER;

		 #'Force' it to make sure we don't get a cached version
	 	 return getNodeById($USER, 'force');
	} 
	return 0;
}


#############################################################################
sub parseLinks {
       my ($text, $NODE, $escapeTags) = @_;

       #Using ! for the s operator so that we don't have to escape all
       #those damn forward slashes. --[Swap]

       #Pipelinked external links, if no anchor text in the pipelink,
       #fill the anchor text with the "[link]" text.

       $text =~ s!\[                         #Open bracket
                  \s*(https?://[^\]\|\[<>]+) #The URL to match
                  \|                         #The pipe
                  ([^\]\|\[]+)?              #The possible anchor text
                  \]                         #Close bracket

                 !"<a href=\"$1\" rel=\"nofollow\" class=\"externalLink\">"

                   .(defined $2 ? $2 : "&#91;link&#93;")   #If no anchor text, use "[link]"
                     ."</a>";
                 !gesx;

       #External links without piping, show the link itself as the
       #anchor text.
       $text =~ s!
                \[
                 \s*(https?://[^\]\|\[<>]+)
                 \]
                 !<a href="$1" rel="nofollow" class="externalLink">$1</a>!gsx;

       #Ordinary internal e2 links.
       $text =~ s!\[([^\[\]]*(\[.*\]?|.*)?)\]!linkNodeTitle ($1, $NODE,$escapeTags)!egs;
	   # [^\[\]]* any text in square brackets
	   # (\[.* '[' then nodetype/author also in square brackets
	   # \]? tolerate forgetting closing ']',
	   # |.*)? but all that only if it is a pipelink
       $text = unMSify($text);
       return $text;
}



#############################################################################
sub urlDecode {
	foreach my $arg (@_) {
		tr/+/ / if $_;
		$arg =~ s/\%(..)/chr(hex($1))/ge;
	}

	$_[0];
}


#############################################################################
#	Sub
#		loginUser
#
#	Purpose
#		For each page request, we need to know the user trying to view
#		the page.  This logs in a user if they are logging in and stores
#		the info in a cookie.  If they have already logged in, we use
#		their cookie information.
#
#	Parameters
#		None.  Uses global package vars.
#
#	Returns
#		The USER node hash reference
#
sub loginUser
{
	my ($user_id, $cookie, $user, $passwd);
	my $USER_HASH;
	
	
        #jb 5-19-02: To support wap phones and maybe other clients/configs without cookies:

        my $oldcookie = $query->cookie("userpass");
        $oldcookie ||= $query->param("userpass");

        if($oldcookie)                     
	{
		$user_id = confirmUser (split (/\|/, urlDecode ($oldcookie)));
	}
	
	# If all else fails, use the guest_user
	$user_id ||= $HTMLVARS{guest_user};				

	# Get the user node
	$USER_HASH = getNodeById($user_id);	

	die "Unable to get user!" unless ($USER_HASH);

        #jb: [root log: november 2001]. This is to prevent locked
        #users from coming back online.  Stops their authentication

        $USER_HASH = getNodeById($HTMLVARS{guest_user}) unless($$USER_HASH{acctlock} == 0);

	# Assign the user vars to the global.
	$VARS = getVars($USER_HASH);
	
	# Store this user's cookie!
	$$USER_HASH{cookie} = $cookie if $cookie; 

	return $USER_HASH;
}


#############################################################################
#	Sub
#		getCGI
#
#	Purpose
#		This gets and sets up the CGI interface for an individual request.
#
#	Parameters
#		None
#
#	Returns
#		The CGI object.
#
sub getCGI
{
	my $cgi;
	
	if ($ENV{SCRIPT_NAME}) { 
		$cgi = new CGI;
	} else {
		$cgi = new CGI(\*STDIN);
	}

	if (not defined ($cgi->param("op"))) {
		$cgi->param("op", "");
	}

	return $cgi;
}

############################################################################
#	Sub
#		getTheme
#
#	Purpose
#		this creates the $THEME variable that various components can
#		reference for detailed settings.  The user's theme is a system-wide
#		default theme if not specified, then a "themesetting" can be 
#		used to override specific values.  Finally, if there are user-specific
#		settings, they are kept in the user's settings
#
#		this function references global variables, so no params are needed
#

sub getTheme {
	my $theme_id;
	$theme_id = $$VARS{preferred_theme} if $$VARS{preferred_theme};
	$theme_id ||= $HTMLVARS{default_theme};
	my $TS = getNodeById $theme_id;

	if ($$TS{type}{title} eq 'themesetting') {
		#we are referencing a theme setting.
		my $BASETHEME = getNodeById $$TS{parent_theme};
		$THEME = getVars $BASETHEME;
		my $REPLACEMENTVARS = getVars $TS;
		@$THEME{keys %$REPLACEMENTVARS} = values %$REPLACEMENTVARS;
		$$THEME{theme_id} = getId($BASETHEME);
		$$THEME{themesetting_id} = getId($TS);
    } else {
		#this whatchamacallit is a theme
		$THEME = getVars $TS;
		$$THEME{theme_id} = getId($TS);
	}

	#we must also check the user's settings for any replacements over the theme
	foreach (keys %$THEME) {
		if (exists $$VARS{"theme".$_}) {
			$$THEME{$_} = $$VARS{"theme".$_};
		}
	}
	#$THEME= {};
	1;
}

#############################################################################
#	Sub
#		printHeader
#
#	Purpose
#		For each page we serve, we need to pass standard HTML header
#		information.  If we are script, we are responsible for doing
#		this (the web server has no idea what kind of information we
#		are passing).
#
#	Parameters
#		$datatype - (optional) the MIME type of the data that we are
#			to display	('image/gif', 'text/html', etc).  If not
#			provided, the header will default to 'text/html'.
#
sub printHeader
{
	my ($datatype, $page, $lastnode) = @_;

 	my $len = length $page;
	# default to plain html
	$datatype ||= "text/html";
	my @cookies = ();
	if ($lastnode && $lastnode > 0) {
	#	push @cookies, $query->cookie( -name=>'lastnode_id', -value=>$lastnode);
		push @cookies, $query->cookie( -name=>'lastnode_id', -value=>'');

	} elsif ($lastnode == -1) {

	} else {
		push @cookies, $query->cookie('lastnode_id', '');
	}
	if ($$USER{cookie}) {
		push @cookies, $$USER{cookie};
	}
	
	if($ENV{SCRIPT_NAME}) {
		if (@cookies) {
			$query->header(-type=> $datatype, 
				       -cookie=> \@cookies,
				       -content_length => $len,
				       %HEADER_PARAMS);
		} else {
			$query->header(-type=> $datatype,
				       -content_length => $len,
				       %HEADER_PARAMS);
		}
	}
}


#############################################################################
#	Sub
#		handleUserRequest
#
#	Purpose
#		This check the CGI information to find out what the user is trying
#		to do and executes their request.
#
#	Parameters
#		None.  Uses the global package variables.
#
sub handleUserRequest
{
	my $user_id = $$USER{node_id};
	my $node_id;
	my $nodename;
	my $code;
	my $handled = 0;

	if ($query->param('node'))
	{
		# Searching for a node my string title
		my $type  = $query->param('type');
		my $TYPE = getType($type);
		
		$nodename = cleanNodeName($query->param('node'));

		if($nodename eq "")
		{
			gotoNode($HTMLVARS{default_node}, $user_id);
			return;
		}

		$query->param("node", $nodename);
		
		if ($query->param('op') ne 'new')
		{
			nodeName ($nodename, $user_id, $type); 
		}
		else
		{
			gotoNode($HTMLVARS{permission_denied}, $user_id);
		}
	}
	elsif ($node_id = $query->param('node_id'))
	{
		#searching by ID
		gotoNode($node_id, $user_id);
	}
	else
	{
		#no node was specified -> default
		gotoNode($HTMLVARS{default_node}, $user_id);
	}
}


#############################################################################
#	Sub
#		cleanNodeName
#
#	Purpose
#		We limit names of nodes so that they cannot contain certain
#		characters.  This is so users can't play games with the names
#		of their nodes.
#
#	Parameters
#		$nodename - the raw name that the user has given
#
#	Returns
#		The name after we have cleaned it up a bit
#
sub cleanNodeName
{
	my ($nodename) = @_;

	# For some reason, searching for ? hoses the search engine.
	$nodename = "" if($nodename eq "?");

	$nodename =~ tr/[]|<>//d;
	$nodename =~ s/^\s*|\s*$//g;
	$nodename =~ s/\s+/ /g;
	$nodename ="" if $nodename=~/^\W$/;
	#$nodename = substr ($nodename, 0, 80);

	return $nodename;
}

#############################################################################
sub clearGlobals
{
	$GNODE = "";
	$USER = "";
	$VARS = "";
	$NODELET = "";
	$THEME = "";

	$query = "";
}


#############################################################################
sub opNuke
{
	my $user_id = $$USER{node_id};
	my $node_id = $query->param("node_id");


	return if grep(/^$node_id$/, values(%HTMLVARS)) ;
	
	nukeNode($node_id, $user_id);
}


#############################################################################
sub opLogin
{
	my $user = $query->param("user");
	my $passwd = $query->param("passwd");
	my $user_id;
	my $cookie;

	my $U = getNode($user,'user');
    $user = $$U{title} if $U;

	$user_id = confirmUser ($user, crypt ($passwd, $user));
	
	# If the user/passwd was correct, set a cookie on the users
	# browser.
	$cookie = $query->cookie(-name => "userpass", 
		-value => $query->escape($user . '|' . crypt ($passwd, $user)), 
		-expires => $query->param("expires")) if $user_id;

	$user_id ||= $HTMLVARS{guest_user};

	$USER = getNodeById($user_id);
	$VARS = getVars($USER);

	$$USER{cookie} = $cookie if($cookie);
}


#############################################################################
sub opLogout
{
	# The user is logging out.  Nuke their cookie.
	my $cookie = $query->cookie(-name => 'userpass', -value => "");
	my $user_id = $HTMLVARS{guest_user};	

	$USER = getNodeById($user_id);
	$VARS = getVars($USER);

	$$USER{cookie} = $cookie if($cookie);
}


#############################################################################
sub opNew
{
	my $node_id = 0;
	my $user_id = $$USER{node_id};
	my $type = $query->param('type');
	my $TYPE = getType($type);
	my $nodename = cleanNodeName($query->param('node'));
	
	if (canCreateNode($user_id, $DB->getType($type)) and $user_id != $HTMLVARS{guest_user})
	{
		$node_id = insertNode($nodename,$TYPE, $user_id);

		if($node_id == 0)
		{
			# It appears that the node already exists.  Get its id.
			$node_id = $DB->sqlSelect("node_id", "node", "title=" .
				$DB->quote($nodename) . " && type_nodetype=" .
				$$TYPE{node_id});
		}

		$query->param("node_id", $node_id);
		$query->param("node", "");
	} 
	else
	{
		$query->param("node_id", $HTMLVARS{permission_denied});
	}
}


#############################################################################
#	Sub
#		getOpCode
#
#	Purpose
#		Get the 'op' code for the specified operation.
#
sub getOpCode
{
	my ($opname) = @_;
	my $OPNODE = getNode($opname, "opcode");
	my $code = '"";';
	
	$code = $$OPNODE{code} if(defined $OPNODE);

	return $code;
}


#############################################################################
#	Sub
#		execOpCode
#
#	Purpose
#		One of the CGI parameters that can be passed to Everything is the
#		'op' parameter.  "Operations" are discrete pieces of work that are
#		to be executed before the page is displayed.  They are useful for
#		providing functionality that can be shared from any node.
#
#		By creating an opcode node you can create new ops or override the
#		defaults.  Just becareful if you override any default operations.
#		For example, if you override the 'login' op with a broken
#		implementation you may not be able to log in.
#
#	Parameters
#		None
#
#	Returns
#		Nothing
#
sub execOpCode
{
	my $op = $query->param('op');
	my $code;
	my $handled = 0;
	
	return 0 unless(defined $op && $op ne "");
	
	$code = getOpCode($op);
	if (defined $code) {
		$handled = eval($code);
		Everything::printLog($@) if $@;
#		Everything::printLog("executed opcode $op \n$code");
	}	

	unless($handled)
	{
		# These are built in defaults.  If no 'opcode' nodes exist for
		# the specified op, we have some default handlers.

		if($op eq 'login')
		{
			opLogin()
		}
		elsif($op eq 'logout')
		{
			opLogout();
		}
		elsif($op eq 'nuke')
		{
			opNuke();
		}
		elsif($op eq 'new')
		{
			opNew();
		}
	}
}

#############################################################################
#	Sub
#               isSuspended
#
#       Purpose
#               Checks the suspension table for access to a certain feature.
#
#       Parameters        
#               $usr - The user to check if they are suspended
#               $sustype - The type of suspension to check
#                        
#       Returns       
#               the suspension_id if suspended for the type
#               undef otherwise
#

sub isSuspended              
{
        my ($usr, $sustype) = @_;

        return undef unless $usr and $sustype and $sustype = getNode($sustype, "sustype");
        return $DB->sqlSelect("suspension_id", "suspension", "suspension_user=$$usr{node_id} 
         and suspension_sustype=$$sustype{node_id}");

}

#############################################################################
#	Sub
#		mod_perlInit
#
#	Purpose
#		This is the "main" function of Everything.  This gets called for
#		each page load in an Everything system.
#
#	Parameters
#		$db - the string name of the database to get our information from.
#
#	Returns
#		nothing useful
#
sub mod_perlInit
{
	my ($db, $staticNodetypes, $memcache) = @_;

	#$Everything::PERLTIME ||= new StopWatch();
	#$Everything::SQLTIME ||= new StopWatch();

	# Start the perl timer
	#$Everything::PERLTIME->start();
	
	#blow away the globals
	clearGlobals();

	# Initialize our connection to the database
	Everything::initEverything($db, 0, $memcache);
	#print STDERR localtime(time)."\t".$DB->{cache}->getCacheSize() ."\n";

	# Get the HTML variables for the system.  These include what
	# pages to show when a node is not found (404-ish), when the
	# user is not allowed to view/edit a node, etc.  These are stored
	# in the dbase to make changing these values easy.	
	%HTMLVARS = %{ eval (getCode('set_htmlvars')) };

	$query = getCGI();
    return if $query->user_agent and $query->user_agent =~ /WebStripper/;
	$USER = loginUser();
    #init the cache
	$CACHESTORE ||= new Everything::CacheStore "cache_store:web4";





       #only for Everything2.com
       if ($query->param("op") eq "randomnode") {
               $query->param("node_id", getRandomNode());
       }


	# Execute any operations that we may have
	execOpCode();
	
	# Fill out the THEME hash
	getTheme();

	# Do the work.
	handleUserRequest();
	if ($$USER{title} eq 'dem bones') {
         open (BONESLOG, "|/usr/sbin/cronolog --symlink=/var/log/everything/bones_log /var/log/everything/%Y/%m/%d/bones_log");
         my $log = localtime(time)
          ."\t$$USER{title}\t$$GNODE{title} ($$GNODE{type}{title})\n" if ref $USER and ref $GNODE;
         print BONESLOG $log;
         close BONESLOG;
	     }

	if (isGod($USER) or $$USER{title} eq 'cureobsession') {
         open (GODSLOG, "|/usr/sbin/cronolog --symlink=/var/log/everything/gods_log /var/log/everything/%Y/%m/%d/gods_log");
         my $log = localtime(time);
	$log.= "\t$$USER{title}\t$$GNODE{title} ($$GNODE{type}{title})" if ref $USER and ref $GNODE;
	$log .= " op=".$query->param("op") if $query->param("op");
 	$log .= " displaytype=".$query->param("displaytype") if $query->param("displaytype");
	$log .="\n";
         print GODSLOG $log;
         close GODSLOG;
	     }

#	my $darkwatch = {"Gritcka" => 1, "wrinkly" => 1, "Frankie" => 1};

#	if($darkwatch->{$USER->{title}} or $GNODE->{title} eq "SQL Prompt" or $query->param("sentmessage") =~ /frankie/i)
#	{
#		my $log = localtime()."\t$$USER{title}\t($$GNODE{title})" if ref $USER and ref $GNODE;

#		foreach(qw/sqlquery displaytype sentmessage/)
#		{
#			$log.="\t$_: ".$query->param($_) if $query->param($_);
#		}
#
#		$log.="\n";
#		open DARKLOG, ">> /home/jaybonci/logs/darklog";
#		print DARKLOG $log;
#		close DARKLOG;
#	}

	#$Everything::PERLTIME->stop();
	$PAGELOAD++;
	
##	if($PAGELOAD > $NUMPAGELOADS)
##	{
##		my $totaltime = $Everything::PERLTIME->report();
##		my $sqltime = $Everything::SQLTIME->report();
##		my $perltime = $totaltime - $sqltime;
#
#		# Get the average time
#		$perltime = $perltime / $NUMPAGELOADS;
#		$sqltime = $sqltime / $NUMPAGELOADS;
#
#		if(open(TIMELOG, ">> /tmp/pagetime.log"))
#		{
#			my $time = Everything::getTime();
#			print TIMELOG "$time: (loads: $NUMPAGELOADS) perl: $perltime, sql: $sqltime\n";
#			close(TIMELOG);
#		}
#
#		$PAGELOAD = 0;
#
#		#$Everything::PERLTIME->reset();
#		#$Everything::SQLTIME->reset();
#	}
}




sub mod_perlpsuedoInit
{
	my ($db, $staticNodetypes) = @_;

	clearGlobals();

	Everything::initEverything($db);
	%HTMLVARS = %{ eval (getCode('set_htmlvars')) };

	$query = getCGI();
    return if $query->user_agent =~ /WebStripper/;
	$USER = loginUser();
    #init the cache
	$CACHESTORE ||= new Everything::CacheStore "cache_store:web4";

       #only for Everything2.com
       if ($query->param("op") eq "randomnode") {
               $query->param("node_id", getRandomNode());
       }


	# Execute any operations that we may have
	execOpCode();
	
	# Fill out the THEME hash
	getTheme();

	# Do the work.
	#handleUserRequest();
}

#############################################################################
# Sub
#   escapeAngleBrackets
#
# Purpose
#   Escapes angle brackets but *only* if they're not inside square
#   brackets. This is intended for bits of user input that is not
#   allowed to have any HTML but is allowed bracket [linking].
#
# Parameters
#   $text - the text  to escape
#
# Returns
#   The escaped text
sub escapeAngleBrackets{
  my ($text) = @_;

  #These two lines do regexp magic (man perlre, grep down to
  #assertions) to escape < and > but only if they're not inside
  #brackets. They're a bit inefficient, but since they text they're
  #working on is usually small, it's all good. --[Swap]

  $text =~ s/((?:\[(.*?)\])|>)/$1 eq ">" ? "&gt;" : "$1"/egs;
  $text =~ s/((?:\[(.*?)\])|<)/$1 eq "<" ? "&lt;" : "$1"/egs;

  return $text;
}

#############################################################################
# End of package
#############################################################################

1;
