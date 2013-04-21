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
use CGI;
use CGI::Carp qw(set_die_handler);
use Carp qw(longmess);

sub BEGIN {
	use Exporter ();
	use vars qw($DB $VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@ISA=qw(Exporter);
	@EXPORT=qw(
              %HEADER_PARAMS
              $DB
              $NODE
              $VARS
              $PAGELOAD
              $query
              jsWindow
              createNodeLinks
              parseLinks
              stripCode
              htmlScreen
              screenTable
              cleanupHTML
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
              parseCode
              embedCode
              displayPage
              gotoNode
              confirmUser
              urlDecode
              encodeHTML
              decodeHTML
              escapeAngleBrackets
              rewriteCleanEscape
              processVarsSet
              showPartialDiff
              showCompleteDiff
              recordUserAction
              unMSify
              mod_perlInit

              castVote
              adjustExp
              adjustRepAndVoteCount
              adjustGP
              allocateVotes
              hasVoted
              getVotes
              getHRLF

              changeRoom
              insertIntoRoom
              cloak
              uncloak
              );
}

use vars qw($HTTP_ERROR_CODE $ERROR_HTML $SITE_UNAVAILABLE $query);
use vars qw($VARS);
use vars qw($GNODE);
use vars qw($USER);
use vars qw($TEST);
use vars qw($TEST_CONDITION);
use vars qw($TEST_SESSION_ID);
use vars qw($THEME);
use vars qw($PAGELOAD);
use vars qw(%HEADER_PARAMS);

my $HTTP_ERROR_CODE = 400;
my $SITE_UNAVAILABLE = <<ENDPAGE;
<html>
<head><title>Site Temporarily Unavailable</title>
</head>
<body>
<h1>Hamster Ball Jam in Cubicle Z</h1>
<p>
There is a temporary problem with Everything2.  Please hold while we contact the rodent experts.
</p>
</body>
</html>
ENDPAGE

    my $ERROR_HTML = <<ENDPAGE;
<html>
<head><title>Site Temporarily Unavailable</title>
</head>
<body>
<h1>Hamster Twinkie Overdose</h1>
<p>
The server hamsters have lost it.  They sent out a list of demands,
but nobody could understand their note.  It read:
</p>
<pre>
ERROR
</pre>
<p>
We're getting the best in rodent nutrition and negotiation on it.
</p>
</body>
</html>
ENDPAGE

my %NO_SIDE_EFFECT_PARAMS = (
	'node' => 1
	, 'author' => 1
	, 'a' => 1
	, 'node_id' => 1
	, 'type' => 1
	, 'guest' => 1
	, 'lastnode_id' => 'delete'
	, 'searchy' => 1
	, 'originalTitle' => 1
	, 'should_redirect' => 'delete'
);
     
sub getRandomNode {
        my $limit = $DB->sqlSelect("max(e2node_id)", "e2node");
        my $min = $DB->sqlSelect("min(e2node_id)", "e2node");
        my $rnd = int(rand($limit-$min));
        
        $rnd+= $min;

        my $e2node = $DB->sqlSelect("e2node_id", "e2node"
            , "e2node_id=$rnd "
              . "AND EXISTS(SELECT 1 FROM nodegroup WHERE nodegroup_id = e2node_id)"
            );

        $e2node||=getRandomNode();

        $e2node;
}

sub handle_errors {

    CORE::die(@_) if CGI::Carp::ineval();

    Everything::printLog("Trying to handle error.");

    my $errorFromPerl = shift;
    $errorFromPerl .=
      "Call stack:\n"
      . (join "\n" => reverse getCallStack())
      ;
    Everything::printLog($errorFromPerl);
    Everything::printLog(query_vars_string());
    if (defined $query) {

        $errorFromPerl = encodeHTML($errorFromPerl);
        my $errorHeader = <<ENDHEADER;
Status: $HTTP_ERROR_CODE Internal Hamster Error
Content-type: text/html

ENDHEADER
        my $errorText = $ERROR_HTML;
        $errorText =~ s/\bERROR\b/$errorFromPerl/;
        $query->print($errorHeader . $errorText);
	exit;

    } else {

        print $errorFromPerl;

    }
}

sub query_vars_string {
	my $error = '';

	if (defined $query && defined $query->Vars()) {
		my $params = $query->Vars();
		for (keys %$params) {
			$error .= "\t- param: " . $_ . " = " . $query->param($_) . "\n";
		}
	}

	return $error;
}



######################################################################
#	sub
#		tagApprove
#
#	purpose
#		determines whether or not a tag (and its specified attributes)
#		are approved or not.  Returns the cleaned tag.  Used by cleanupHTML
#
sub tagApprove {
	my ($close, $tag, $attr, $APPROVED) = @_;

	$tag = uc($tag) if (exists $$APPROVED{uc($tag)});
	$tag = lc($tag) if (exists $$APPROVED{lc($tag)});
	
	if (exists $$APPROVED{$tag}) {
		unless ( $close ) {
			if ( $attr ) {
				if ( $attr =~ qr/\b(\w+)\b\=['"]?(\w+\b%?)["']?/i ) {
					my ( $name , $value ) = ( $1 , $2 ) ;
					return '<'.$close.$tag.' '.$name.'="'.$value.'">' if ( $$APPROVED{$tag} =~ /\b$name\b/i ) ;
					return '<'.$close.$tag.' '.$name.'="'.$value.'">' if $$APPROVED{ noscreening } ;
				}
			}
		}
		'<'.$close.$tag.'>' ;
	} else {
		return '' unless $$APPROVED{ noscreening } ;
		$$APPROVED{$tag} .= '' ;
		return &tagApprove ;
	}
}


#############################################################################
#	sub
#		htmlScreen
#
#	purpose
#		screen out html tags from a chunk of text
#		returns the text, sans any tags that aren't "APPROVED"
#   Now defers all the work to cleanupHTML
#
#	params
#		text -- the text to filter
#		APPROVED -- ref to hash where approved tags are keys.  Null means
#			all HTML will be taken out.
#
sub htmlScreen {
	my ($text, $APPROVED) = @_;
	$APPROVED ||= {};

	$text = cleanupHTML($text, $APPROVED);
	$text;
}

######################################################################
#	Sub
#		cleanupHTML
#	Purpose
#		This function cleans up ragged HTML (such as may be
#		encountered in a writeup), performing three main
#		functions:
#		  * Tag screening, a la htmlScreen
#		  * Tag balancing, ensuring that all tags are closed
#		  * Table sanitisation, ensuring table elements are
#		    correctly nested. 
#       Params
#               text -- the text/html to filter
#               APPROVED -- ref to hash where approved tags are keys.
#                   Null means all HTML will be taken out.
#                   { noscreening => 1 } means no HTML will be taken out.
#		preapproved_ref -- ref to hash/cache of 'pre-approved'
#		    tags.
#               debug -- a function to render a debug message into HTML.
#
#       Returns
#               The text stripped of any HTML tags that are not
#               approved, balanced and cleaned up.
#		
#	Limitations:
#		  * Input is assumed to be HTML 4.0, not XHTML.
#		  * Tags with optional closing elements are not
#		    explicitly closed.
#		  * HTML does not recognise the XML empty element
#		   format, so we do not look for it explicitly.
#
#	Benchmarking on a Pentium M indicates that this process is
#	approximately 3% faster than the existing htmlScreen.  
#
#	Algorithm features:
# 		  * Scans tags with m//g construct
#		  * Stacks and unstacks nested tags on finding opening
#		    and closing
#		    tags.
#		  * Validates tags using a (persistent) memoisation
#		    cache mapping source tags to 'approved' tags with
#		    invalid tags or attributes stripped. Since most
#		    tags appearing in writeups will be repeated many
#		    times (eg. the '<p>' tags) the majority of tags
#		    should be  found in this cache.
#		  * Enforces correct table element nesting using a map
#		    of tag -> valid parent tag
# 		    For any element which has such a tag, the
# 		    immediate superior (ie. top of the stack) must
# 		    match.
# 
sub cleanupHTML {
    my ($text, $approved, $preapproved_ref, $debug) = @_;
    my @stack;
    my ($result, $tag, $ctag) = ('', '', '');
    # Compile frequently-used regular exprs
    my $open_tag = qr'^<(\w+)(.*?)>(.*)'ms;
    my $close_tag = qr'^</(\w+)(.*?)>(.*)'ms;
    # Separate regexps to handle the (unlikely) case we encounter an
    # incomplete tag. The positional matches are the same as above.
    my $incomplete_open_tag = qr'^<(\w+)(.*)(.*)'ms;
    my $incomplete_close_tag = qr'^</(\w+)(.*)(.*)'ms;
    my $key;                      # Cache key
    my $approved_tag;
    my $outer_text;
    # Map of nested tags to mandatory direct parents.
    my %nest = ('tr' => { 'table' => 1, 'tbody' => 1, 'thead' => 1 },
		'tbody' => { 'table' => 1 },
		'thead' => { 'table' => 1 },
		'td' => { 'tr' => 1 },
		'th' => { 'tr' => 1 });
    my $nest_in;
    # Optional-close tag names. Mapping with a hash seems to be
    # something like twice as quick as using a single regexp.
    my %no_close = ('p' => 1, 'br' => 1, 'hr' => 1,
		    'img' => 1, 'input' => 1, 'link' => 1);
    
    # Delete any incomplete tags, including comments. These may be the result of truncating
    # source HTML, eg. for Cream of the Cool.
    $text =~ s/<(?:[^>]*|!--(?:[^-]*|-[^-]|--[^>])*)$//;
    
    # Scan tags by recognising text starting with '<'. Experiments with
    # Firefox show that malformed opening tags (missing the closing '>')
    # still count as opened tags, so we follow this behaviour.
    for ($text =~ m{(^[^<]+|<[^<]+)}mig) {
	if (/$open_tag/ || /$incomplete_open_tag/) {
	    # Opening tag.
	    $key = $1.$2;
	    $tag = lc $1;
	    $outer_text = $3;
	    $approved_tag = $preapproved_ref->{$key};
	    # Handle miss in the pre-approved tag map
	    unless (defined($approved_tag)) {
		$approved_tag = tagApprove('', $1, $2,
					   $approved) || '';
		$preapproved_ref->{$key} = $approved_tag;
	    }
	    # Check correct nesting, and disapprove if not!
	    if (   ($nest_in = $nest{$tag})
		&& !$nest_in->{$stack[$#stack]}) {
		my @extra;
		my $opening;
		# Choose one of the parent tags, effectively at random
		my $missing;
		do {
			# Choose one of the parent tags, effectively at random
			$missing = (keys %$nest_in)[0];
		    unshift @extra, $missing;
		    $opening = '<'.$missing.'>'.$opening;
		    if ($debug) {
			$opening = ($debug->("Missing <$missing> before <$tag>")
				    . $opening);
		    }
		} while (   ($nest_in = $nest{$missing})
			 && !$nest_in->{$stack[$#stack]});
		push @stack, @extra;
		$result .= $opening;
	    }
	    if ($approved_tag) {
		push @stack, $tag;
	    } elsif ($debug) {
		$result .= $debug->("Disallowed tag <$tag>");
	    }
	    $result .= $approved_tag.$outer_text;
	} elsif (/$close_tag/ || /$incomplete_close_tag/) {
	    # Closing tag
	    my $closing;
	    my @popped;
	    $tag = lc $1;
	    $key = '/'.$1.$2;
	    $outer_text = $3;
	    $approved_tag = $preapproved_ref->{$key};
	    unless (defined($approved_tag)) {
		$approved_tag = tagApprove('/', $1,
					   $2,
					   $approved) || '';
		$preapproved_ref->{$key} = $approved_tag;
	    }
	    if ($approved_tag) {
		# Before closing this element, close any unclosed
		# elements which have been opened since then. We find
		# the matching closing element by digging through the
		# stack to find the matching opening tag. On
		# encountering a close tag for an unopened tag, we dig
		# through the entire stack, and restore it on reaching
		# the bottom without finding the tag. This sounds
		# fairly expensive, but we make the following
		# assumptions:
		#   1. Unopened close tags will be infrequent in the
		#      source HTML, and 
		#   2. The stack will be short as structures are
		#      typically not deeply nested, hence searching
		#      and restoring it will be inexpensive.
		for (;;) {
		    $ctag = pop @stack;
		    push @popped, $ctag;
		    if ($ctag eq $tag) {
			# Found the tag.
			last;
		    } elsif (defined($ctag)) {
			# Insert an extra closing tag.
			$closing .= "</$ctag>"
			    unless $no_close{$ctag};
			if ($debug) {
			    $result .= $debug->("Unclosed <$ctag>");
			}
		    } else {
			# Closed something
			# which was never
			# opened. Just ignore
			# it. Remove the tag
			# and restore the stack.
			s/^[^>]*>?//;
			@stack = reverse @popped;
			$approved_tag = '';
			$closing = '';
			if ($debug) {
			    $result .= $debug->("No matching open tag "
						. "for closing </$tag>");
			}
			last;
		    }
		}
	    } elsif ($debug) {
		$result .= $debug->("Disallowed tag </$tag>");
	    }
	    $result .= $closing.$approved_tag.$outer_text;
	} else {
	    # Plain text at the beginning of the text.
	    $result .= $_;
	}
    }
    # Close any remaining unclosed tags
    while (defined($ctag = pop @stack)) {
	unless ($no_close{$ctag}) {
	    $result .= "</$ctag>";
	    if ($debug) {
		$result .= $debug->("Unclosed <$ctag>");
	    }
	}
    }
    # Clear the prepapproved cache if it's too large.
    if (int(keys(%$preapproved_ref)) > 200) {
	%$preapproved_ref = ();
    }
    return $result;
};


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
    for ($_[0] =~ m{<(/?table|/?tr|/?th|/?td/?tbody/?thead)[\s>]}ig) {
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
                if (($top.$tag) !~ /^(table(tr|tbody)?|(tbody|thead)tr|tr(td|th)|(td|th)(table))$/);
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
    $html =~ s{<((/?)(table|tr|td|th|thead|tbody)((\s[^>]*)|))>}{debugTag $1}ige;
    return "<p><strong>Table formatting error: $error</strong></p>".$html;
}

sub screenTable {
    my ($text) = @_;
    my ($valid, $error) = tableWellFormed($text);
    $text = debugTable ($error, $text) if ! $valid;
    $text;
}


#############################################################################
#	Sub
#		buildTable
#
#	Purpose
# This is a useful little function that forms nice html tables given two array
#   references.  The first is the column labels, the second is an array
#   reference to hash references of data.  Each hash reference should contain
#   a key for each element in the label reference pointing to the value you
#   would like displayed, e.g.:
# $labels = ['name','email];
# $rows = [{'name'=>'Dann Stayskal','email'=>'dann@stayskal.com'},
#          {'name'=>'Jaubert Moniker','email'=>'andy@destructupad.net'}];
#   If a row contains a key not in a label, that data will be discarded.  If a
#   label contains a title with no matching keys, you will have a blank column.
# The third option you can give it is a formatting option - 'nolabels','nodelet',
#   'fullwidth', or any combination of the three (it just regexps it out).
#   The 'nolabels' option will hide the column labels and give the background of
#   the first row of data the color usually reserved for labels.  the 'nodelet'
#   option does the same thing, only it uses the darker version of a table data
#   color and smalls the font.  'fullwidth' and 'fullheight' add 'width=100%'
#   and 'height=100%' (yeah, I know it's not pure html4.01. It renders, though.)
#   to the table tag.
# The fourth option defines the table's "align" attribute; added to help us
#   break away from <center> tags. This can be modified as soon as CSS has a
#   good way to align tables. Possible values: 'left', 'center', 'right';
#   'center' is probably the only one we'll need to use.
# The fifth option defines the data cells' style="vertical-align" attribute.
#   Possible values: 'top', 'middle', 'bottom'. Added because middle-aligned
#  lists in softlink tables are fugly. --alexander
#
# NEW IN VERSION 2! - this now pulls formatting data from CSS:
#   <elem class="title"> and <elem class="data">
#   $$THEME{color_border} needs to be set, too!
sub buildTable
{
	my ($labels,$data,$options,$tablealign,$datavalign) = @_;
	return '<i>no data</i>' unless $data;
	
	my $borderColor = $$THEME{color_border} || $$THEME{table_border_color}
										|| $$THEME{dataTitleBackground};
	my $width = ($options=~/fullwidth/) ? 'width="100%"' : '';
	my $tablealignment = ($tablealign eq 'left' || $tablealign eq 'center' || $tablealign eq 'right')
		? ' align="'.$tablealign.'"' : '';
	my $datavalignment = ($datavalign eq 'top' || $datavalign eq 'middle' || $datavalign eq 'bottom')
		? ' valign="'.$datavalign.'"' : '';
	$options=~/class=['"]?(\w+)['"]?/;
	my $class = $1;
	
	my $str='<table '.$width.' class='.$class.'>';
	
	$str.='<tr>'.join('',map({'<th>'.$_.'</th>'} @$labels))
		.'</tr>' unless $options =~/nolabels/;
	
	foreach my $row (@$data){
		$str.='<tr>';
		foreach my $label (@$labels){
			if( !defined $$row{$label} )
			{
				$$row{$label} = '&nbsp;';
			}
			if (($options =~ /nolabels/)&&($label eq $$labels[0])) {
				$str.='<th'.$datavalignment.'>'.$$row{$label}.'</th>';
			} else {
				$str.='<td'.$datavalignment.'>'.$$row{$label}.'</td>';
			}
		}
		$str.='</tr>';
	}
	
	$str.='</table>';
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
    my ($blocks) = "pre|center|li|ol|ul|h1|h2|h3|h4|h5|h6|blockquote|dd|dt|dl|p|table|td|tr|th|tbody|thead";
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
	return $APP->encodeHTML($html, $adv);
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

	$str = htmlErrorUsers($code, $err, $warn);

	if($DB->isApproved($USER, $dbg))
	{
		$str = htmlErrorGods($code, $err, $warn);
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
	if ($GNODE) { $error .= "Node: $$GNODE{title}\n"; }
	else { $error .= "Node: null\n"; }

	if ($USER) { $error .= "User: $$USER{title}\n"; }
	else { $error .= "User: null\n"; }
	$error .= "User agent: " . $query->user_agent() . "\n" if defined $query;
	$error .= "Code:\n$code\n";
	$error .= "Error:\n$err\n";
	$error .= "Warning:\n$warn";
	$error .= "Params:\n";
	$error .= query_vars_string();
	$error .= longmess();
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

	my $str = "<dl>\n"
		. "<dt>Error:</dt><dd>"
		. encodeHTML($err)
		. "</dd>\n"
		. "<dt>Warning:</dt><dd>"
		. encodeHTML($warn)
		. "</dd>\n"
		;

	my $count = 1;
	$str .= "<dt>Code</dt><dd><pre>";
	foreach my $line (@mycode)
	{
		$str .= sprintf("%4d: ", $count) . "$line\n";
		$count++;
	}

	# Print the callstack to the browser too, so we can see where this
	# is coming from.
	my $ignoreMe = 3;
	$str .= "\n\n<b>Call Stack</b>:\n";
	$str .= (join "\n", reverse getCallStack($ignoreMe));
	$str .= "\n<b>End Call Stack</b>\n";
	
	$str.= "</pre></dd>";
	$str.="</dl>\n";
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
#       Generates URLs. Old code calls this directly, but this should
#       not be necessary anymore. Prefer linkNode instead.
#
#   Parameters
#
#       $REF - hashref parameters for the URL like viewcode, etc.
#
#       noquotes - in case you don't want quotes around the URL.
#
#       $NODE - hashref of the node linking to.

sub urlGen {
  my ($REF, $noquotes, $NODE) = @_;
  my $nosemantic = $query ? $query->param('nosemantic') : 0;

  my $str;
  $str .= '"' unless $noquotes;

  if($NODE){
    $str .= urlGenNoParams($NODE,1);
  }
  #Preserve backwards-compatibility
  else{
    if($$REF{node} && !$nosemantic){
      my $nodetype = $$REF{type} || $$REF{nodetype};
      if($nodetype){
        $str .= "/node/$nodetype/".rewriteCleanEscape($$REF{node});
      }
      else{
        $str .= "/title/".rewriteCleanEscape($$REF{node});
      }
    }
    elsif($$REF{node_id} && $$REF{node_id} =~ /^\d+$/){
      $str .= "/node/$$REF{node_id}";
    }
    else{ $str .= "/"; }
  }

  delete $$REF{node_id};
  delete $$REF{node};
  delete $$REF{nodetype};
  delete $$REF{type};
  delete $$REF{lastnode_id} if defined $$REF{lastnode_id} && $$REF{lastnode_id} == 0;
  my $anchor = '#'.$$REF{'#'} if $$REF{'#'};
  delete $$REF{'#'};

  #Our mod_rewrite rules can now handle this properly
  my $quamp = '?';

  # Cycle through all the keys of the hashref for node_id, etc.
  foreach my $key (keys %$REF) {
    my $value = "";
    $value = CGI::escape($$REF{$key}) if defined $$REF{$key};
    $str .= $quamp . CGI::escape($key) .'='. $value;
    $quamp = $noquotes eq 'no escape' ? '&' : '&amp;' ;
  }

  $str .= $anchor if $anchor;
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
#
sub getCode
{
	my ($funcname) = @_;

	if (getId($TEST)) { $funcname = check_test_substitutions($funcname); }
	my $CODE = getNode($funcname, getType("htmlcode"));
	if (wantarray) {
		return ($$CODE{code}, $CODE) if defined( $CODE );
		return ('"";', undef);
	} else {
		return $$CODE{code} if defined( $CODE );
		return '"";';
	}
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
	my $ORIGTYPE = int $$TYPE{node_id};
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
		
		%WHEREHASH = ( -pagetype_nodetype => $$TYPE{node_id},
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
						{ -pagetype_nodetype => getId(getType("node")),
						displaytype => $displaytype}, 
						$PAGETYPE);

				$PAGE or ($PAGE) =  getNodeWhere(
						{ -pagetype_nodetype => $ORIGTYPE,
						displaytype => "display" },
						$PAGETYPE );
				$PAGE or ($PAGE) = getNodeWhere(
						{ -pagetype_nodetype => getId(getType("node")),
						  displaytype => "display"},
						$PAGETYPE);
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
	$displaytype = 'display' unless $displaytype;


	my $PAGE = getPageForType $TYPE, $displaytype;
	$PAGE ||= getPageForType $TYPE, 'display';

	die "can't load a page $displaytype for $$TYPE{title} type" unless $PAGE;

	$PAGE;
}

sub rewriteCleanEscape {
  my ($string) = @_;
  $string = CGI::escape(CGI::escape($string));
  # Make spaces more readable
  # But not for spaces at the start/end or next to other spaces
  $string =~ s/(?<!^)(?<!\%2520)\%2520(?!$)(?!\%2520)/\+/gs;
  return $string;
}

sub urlGenNoParams {
  my ($NODE, $noquotes) = @_;
  my $nosemantic = $query ? $query->param('nosemantic') : 0;
  $NODE ||= "";
  if (not ref $NODE) {
    if ($noquotes) {
      return "/node/$NODE";
    }
    else {
      return "\"/node/$NODE\"";
    }
  } elsif ($nosemantic) {
    return "/node/".getId($NODE);
  }

  my $retval = "";
  my $typeTitle = $$NODE{type}{title} || "";
  if ($typeTitle eq 'e2node') {
    $retval = "/title/".rewriteCleanEscape($$NODE{title});
  }
  elsif ($typeTitle eq 'user') {
    $retval = "/$typeTitle/".rewriteCleanEscape($$NODE{title});
  }
  elsif ($typeTitle eq 'writeup' || $typeTitle eq 'draft'){
  	# drafts and writeups have the same link for less breakage
    my $author = getNodeById($NODE -> {author_user}, "light");

    #Some older writeups are buggy and point to an author who doesn't
    #exist anymore. --[Swap]
    if (ref $author) {
      $author = $author -> {title};
      my $title = $NODE -> {title};

      $title =~ s/ \([^\)]*\)$// if $typeTitle eq 'writeup'; #Remove the useless writeuptype

      $author = rewriteCleanEscape($author);

      $retval = "/user/$author/writeups/".rewriteCleanEscape($title);
    }
    else{
      $retval = "/node/".getId($NODE);
    }
  }
  elsif ($$NODE{type}{restrictdupes} && $typeTitle && $$NODE{title}) {
    $retval = "/node/$typeTitle/"
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
# Sub
#  linkNode
#
# Purpose
#  Generates an HTML hyperlink.
#
# Parameters
#  $NODE   - A node hashref or id of the node that we want to link to.
#  $title  - A string with the text to display in the anchor text.
#  $PARAMS - A hashref with any optional CGI params.
#
# Returns
#  The HTML for linking to the node, with CGI params.
#
sub linkNode {
  my ($NODE, $title, $PARAMS) = @_;

  return if not ref $NODE and $NODE =~ /\D/;
  $NODE = getNodeById($NODE, 'light') unless ref $NODE;

  $title ||= $$NODE{title};
  my $tags = "";

  #any params that have a "-" preceding 
  #get added to the anchor tag rather than the URL
  foreach my $key (keys %$PARAMS) {

    next unless ($key =~ /^-/);
    my $pr = substr $key, 1;
    $tags .= " $pr=\"$$PARAMS{$key}\"";
    delete $$PARAMS{$key};

  }

  my $exist_params = (keys(%$PARAMS) > 0);

  return
       "<a href="
      . ($exist_params ? urlGen($PARAMS,0,$NODE) : urlGenNoParams($NODE) )
      . $tags . ">$title</a>";
}


#############################################################################
sub linkNodeTitle {
  my ($nodename, $lastnode, $escapeTags) = @_;
  my ($title, $linktitle, $linkAnchor, $href) = ('', '', '', '/');
  $nodename ||= "";
  ($nodename, $title) = split /\s*[|\]]+/, $nodename;
  $title = $nodename if $title =~ m/^\s*$/;
  $nodename =~ s/\s+/ /gs;

  my $str = "";
  my ($tip, $isNode);

  #If we figure out a clever way to find the nodeshells, we should fix
  #this variable.
  $isNode = 1;

  #A direct link draws near! Command?
  if($nodename =~ /\[/){ # usually no anchor: check *if* before seeing *what* for performance
    my $anchor ;
    ($tip,$anchor) = split /\s*[[\]]/, $nodename;
    $title = $tip if $title eq $nodename ;

    $nodename = $tip;
    $tip =~ s/"/&quot;/g;
    $nodename = rewriteCleanEscape($nodename);
    $anchor = rewriteCleanEscape($anchor);

    if($escapeTags){
      $title =~ s/</\&lt\;/g;
      $title =~ s/>/\&gt\;/g;
      $tip =~ s/</\&lt\;/g;
      $tip =~ s/>/\&gt\;/g;
    }

    my ($nodetype,$user) = split /\bby\b/, $anchor;
    $nodetype =~ s/^\s*|^\+|\s*$|\+$//g;
    $user =~ s/\+/ /g;
    $user =~ s/^\s*|^\+|\s*$|\+$//g;
    $linktitle = $tip;

    #Aha, trying to link to a discussion post
    if($nodetype =~ /^\d+$/){

      $href = "/node/debate/$nodename";
      $linkAnchor = "#debatecomment_$nodetype";

    } else {

      $nodetype = "node" unless getType($nodetype);

      #Perhaps direct link to a writeup instead?
      if (grep /^$nodetype$/, ("","e2node","node","writeup","draft") ){

        #Anchors are case-sensitive, need to get the exact username.
        $user = getNode($user,"user");
        my $authorid = ($user? "?author_id=$$user{node_id}" : "");
        $user = ($user? $$user{title} : "");

        $href = "/title/$nodename$authorid";
        $linkAnchor = "#$user";

      }

      #Else, direct link to nodetype. Let's hope the users know what
      #they're doing.
      else {
        $href = ($nodetype eq "user" ? "/" : "/node/") ."$nodetype/$nodename";
      }

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

    $linktitle = $tip;
    $href = "/title/" .rewriteCleanEscape($nodename);
  }

  getRef $lastnode;
  my $lastnodeQuery = "";
  $lastnodeQuery = "?lastnode_id=$$lastnode{node_id}" if $lastnode && ref $lastnode eq 'HASH';
  $str .= "<a href=\"$href$lastnodeQuery$linkAnchor\" title=\"$linktitle\" "
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
	$type = "" unless $type;

	if (not $select_group or @$select_group == 0)
	{ 
		# We did not find an exact match, so do a search thats a little
		# more fuzzy.
		$search_group =
        	        $APP->searchNodeName($node, \@types, $soundex, 1);
	
		if($search_group && @$search_group > 0)
		{
			$NODE = getNodeById($Everything::CONF->{system}->{search_results});
			$$NODE{group} = $search_group;
		}
		else
		{
			$NODE = getNodeById($Everything::CONF->{system}->{not_found_node});
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
		my ($e2node, $node_forward, $draftCount) = (undef, undef, 0);
		foreach (@{ $select_group}) {
			next unless canReadNode($user_id, $_);
			getRef($_);
			$e2node = $_ if $$_{type}{title} eq 'e2node';
			$node_forward = $_ if $$_{type}{title} eq 'node_forward';
			$draftCount++ if $$_{type}{title} eq 'draft';
			push @canread, $_;
		}

		#jb says: 4/14/2002 - Enhancement made here to default to an e2node
		#instead of going to the findings page.  If there are more than one item, and
		#none of them is an e2node, then all you'll get "Findings:"

		#jb says: 5/02/2002 - Fixes here to use gotoNode instead of displayPage
		#see [root log: May 2002] for the long reason

		return gotoNode($Everything::CONF->{system}->{not_found_node}, $user_id, 1) unless @canread;
		return gotoNode($canread[0], $user_id, 1) if @canread == 1;

		# Allow a node_forward to bypass an e2node if we're clicking through from
		#  one node to another
		return gotoNode($node_forward, $user_id, 1)
			if $node_forward && $e2node && defined $query->param('lastnode_id');

		return gotoNode($e2node, $user_id, 1) if $e2node;
		return gotoNode($node_forward, $user_id, 1) if $node_forward;

		if (scalar @canread - $draftCount == 1) {
			for my $notDraft (@canread) {
				return gotoNode($notDraft, $user_id, 1)
					if $$notDraft{type}{title} ne 'draft';
			}
		}

		#we found multiple nodes with that name.  ick
		my $NODE = getNodeById( $Everything::CONF->{system}->{default_duplicates_node} );
		
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
	$@ = undef;
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
#		[0] the function name
#		[1] the arguments in a comma delimited list (must be string), or
#			more than one argument: can be anything
#
#
sub htmlcode {
	my ($splitter, $returnVal) = ('');
	my @returnArray;
	my $encodedArgs = "(no arguments)";
	my $htmlcodeName = shift;

	my ($htmlcodeCode, $codeNode) = getCode($htmlcodeName);

	# localize @_ to insure encodeHTML doesn't mess with our args
	my @savedArgs = @_;

	# Old-style htmlcode call. We will eventually change the way this works
	# By creating an embedded htmlcode entrypoint which is smarter about doing the split
	# But for now, emulate the old behavior

	if(scalar(@savedArgs) == 1 && !ref($savedArgs[0]))
	{
		@savedArgs = split(/\s*,\s*/, $savedArgs[0]);
	}

	$encodedArgs = encodeHTML($encodedArgs);

	my $warnStr = "<p>Calling htmlcode $htmlcodeName"
				;
	my $function;

	# If we are doing a new-style htmlcode call (or have no arguments)
	#  we can use the cached compilation of this function

	if ($splitter eq "") {
		$function = getCompiledCode($codeNode, \&evalCode);
	}
	return "<p>htmlcode '$htmlcodeName ' raised compile-time error:</p>\n $function"
		if ref \$function eq 'SCALAR' ;

	if (wantarray) {
		@returnArray = &$function(@savedArgs);
	} else {
		$returnVal = &$function(@savedArgs);
	}

	if ($@) {
		$returnVal = htmlFormatErr ($htmlcodeCode, $@, $warnStr);
	}

	if (wantarray && !$@) {
		return @returnArray;
	} else {
		return $returnVal;
	}

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
		if ( $args ) {
			$args =~ s/\\/\\\\/g ;
			$args =~ s/"/\\"/g ; #prohibit exploits/avoid errors
			$args =  evalCode( '"'.$args.'"' ) ; #resolve variables
  		}
		$block = htmlcode( $func , $args );
	} elsif ($char eq '%') {
		$block =~ s/^\%(.*)\%$/$1/s;
		$block = evalCode ($block, @_);
	}

	# Block needs to be defined, otherwise the search/replace regex
	# stuff will break when it gets an undefined return from this.
	$block = "" unless defined $block;

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
		   /embedCode("$1",$CURRENTNODE)/egsx;
		           $text;


}

#############################################################################
#	Sub
#		stripCode
#
#	Purpose
#		A companion to parseCode so that E2 code that might have been once
#		evaluated can be treated like comments and stripped out.  Used
#		to deal elegantly when users lose codehome.
#
#	Parameters
#		text -- the string containing code to strip
#
sub stripCode {
	my ($text) = @_;
	$text =~ s/\[(?:\{.*?\}|\".*?\"|\%.*?\%)\]//gs;
	return $text;
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

	"<pre>" . join ("\n", @lines) . "</pre>";
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
	my ($NODELET) = @_;
	getRef $NODELET;

	# I'm going to forget about this later, so I need to write this down here
	# Basically the nodelet containers want a global nodelet object so they know what they are 
	# talking about, rather than using a display subroutine of some sort. By localizing it
	# to $PAGELOAD, we prevent a whole class of memory corruption bugs in nodelets

	$PAGELOAD->{current_nodelet} = $NODELET;
	my ($pre, $post) = ('', '');

        #my $html = genContainer($$NODELET{parent_container})
        #       if $$NODELET{parent_container};

        my $container = $$THEME{generalNodelet_container};
        $container ||= getId(getNode('nodelet container','container'));
	($pre, $post) = genContainer($container) if $container;
	
	# Make sure the nltext is up to date
	updateNodelet($NODELET);
	return "" unless ($$NODELET{nltext} =~ /\S/);

	delete $PAGELOAD->{current_nodelet};	
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
	my $isGuest = 0;
	my $page = "";
	$isGuest = 1 if $APP->isGuest($user_id);

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
        $dsp = "display" unless $dsp;

	my $PAGE = getPage($NODE, $query->param('displaytype'));
	$$NODE{datatype} = $$PAGE{mimetype};
	$page = $$PAGE{page};

	die "NO PAGE!" unless $page;

	$page = parseCode($page, $NODE);
	
	if ($$PAGE{parent_container}) {
		my ($pre, $post) = genContainer($$PAGE{parent_container});
		$page = $pre.$page.$post;
	}
	setVars $USER, $VARS unless $APP->isGuest($USER);
	printHeader($$NODE{datatype}, $page, $lastnode);

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
		$NODE = getNodeById($Everything::CONF->{system}->{search_results});
		$$NODE{group} = $node_id;
	}

	unless ($NODE) { $NODE = getNodeById($Everything::CONF->{system}->{not_found_node}); }	
	
	unless (canReadNode($user_id, $NODE)) {
		$NODE = getNodeById($Everything::CONF->{system}->{permission_denied});
	}
	#these are contingencies various things that could go wrong

	my $displaytype = $query->param("displaytype");

	my $updateAllowed = !$no_update && canUpdateNode($user_id, $NODE);

	if ($updateAllowed && $$NODE{type}{verify_edits}) {
		my $type = $$NODE{type}{title};
		if (!htmlcode('verifyRequest', "edit_$type")) {

			$updateAllowed = 0;

			# Blank the passed values if this looks like an XSRF
			if ($query->param('add') || $query->param('group')
				|| grep(/^${type}_/, $query->Vars)) {
				$query->delete_all();
			}
		}
	}

	if ($updateAllowed) {
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
	

	#updateHits ($NODE, $USER) unless $query->param('op') ne "" or $query->param("displaytype") eq "ajaxupdate";

	# Create softlinks -- a linktype of 0 is the default
	my $linktype = 0;
	$linktype = getNodeById($Everything::CONF->{system}->{guest_link})
		if $APP->isGuest($USER);

	my $lastnode = $query->param('lastnode_id');
	my ($fromNodeLinked, $toNodeLinked) =
		updateLinks($NODE, $lastnode, $linktype, $$USER{user_id});

	my $shouldRedirect = $query->param("should_redirect");
	# Redirect to URL without lastnode_id if this is a GET request and we only
	#  have params that we know to have no side-effects
	$shouldRedirect = 1
		if defined $query->param('lastnode_id') && $query->request_method() eq 'GET'
			&& $$NODE{type}{title} eq 'e2node'
			;

	if ($shouldRedirect) {
		my $redirQuery = new CGI($query);
		my $safeToRedirect = 1;
		$redirQuery->delete('op') if $redirQuery->param('op') eq "";
		foreach ($redirQuery->param) {
			$safeToRedirect = 0 unless defined $NO_SIDE_EFFECT_PARAMS{$_};
			$redirQuery->delete($_) if $NO_SIDE_EFFECT_PARAMS{$_} eq 'delete';
		}

		if ($safeToRedirect) {
			my $url = $redirQuery->url(-base => 1, -rewrite => 1);
			my $noQuotes = 1;

			# For port redirection that might happen without Apache's knowledge before we
			#  got here, remove the por from the URL. (Yes, this is lame.)
			$url =~ s!(://[^/]+):\d+!$1!;
			$url .= urlGen({%{$redirQuery->Vars}}, $noQuotes, $NODE);

			$redirQuery->redirect(
				-uri => $url
				, -nph => 0
				, -status => 303
			);
			return;
		}
	}

	# So we can cache even linked pages, remove lastnode_id
	# unless it's a superdoc (so Findings: still gets the param)
	if ($APP->isGuest($USER) && $$NODE{type}{title} ne 'superdoc') {
		$query->delete('lastnode_id');
	}

	# Check if we were just silently redirected from a softlink creation,
	#  and pass that node_id through
	if (!$fromNodeLinked) {
		my $sth = $DB->getDatabaseHandle()->prepare("
			CALL get_recent_softlink($$USER{node_id}, $$NODE{node_id});
		");
		$sth->execute();
		($fromNodeLinked) = $sth->fetchrow_array();
	}

	$query->param('softlinkedFrom', $fromNodeLinked);

	# make sure editing user is allowed to edit
	if ($displaytype and $displaytype eq "edit") {
		unless (canUpdateNode ($USER, $NODE)) {
			$NODE = getNodeById($Everything::CONF->{system}->{permission_denied});
			$query->param('displaytype', 'display');
		}
	}

	displayPage($NODE, $user_id);
}


#############################################################################
sub parseLinks {
       my ($text, $NODE, $escapeTags) = @_;

       #Using ! for the s operator so that we don't have to escape all
       #those damn forward slashes. --[Swap]

       #Pipelinked external links, if no anchor text in the pipelink,
       #fill the anchor text with the "[link]" text.

       $text =~ s!\[                         #Open bracket
                  \s*(https?://[^\]\|\[<>"]+) #The URL to match
                  \|\s*                      #The pipe
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
                 \s*(https?://[^\]\|\[<>"]+)
                 \]
                 !<a href="$1" rel="nofollow" class="externalLink">$1</a>!gsx;

       #Ordinary internal e2 links.
       $text =~ s!\[([^[\]]*(?:\[[^\]|]*[\]|][^[\]]*)?)]!linkNodeTitle ($1, $NODE,$escapeTags)!egs;
	   # [^\[\]]+ any text in square brackets
	   # ((?:\[[^\]|]* '[' then optionally: nodetype/author also in square brackets
	   # [\]|] tolerate forgetting either closing ']' or pipe
	   # [^[\]]*) then any more text in the brackets
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
	$theme_id ||= $Everything::CONF->{system}->{default_theme};
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
	$datatype = "text/html" unless $datatype;
	my @cookies = ();

	push @cookies, generate_test_cookie();

	if ($lastnode && $lastnode > 0) {
		push @cookies, $query->cookie( -name=>'lastnode_id', -value=>'');

	} elsif ($lastnode == -1) {

	} else {
		push @cookies, $query->cookie('lastnode_id', '');
	}
	if ($$USER{cookie}) {
		push @cookies, $$USER{cookie};
	}
	
	my $extras = {};
	if($Everything::CONF->{'utf8'})
	{
		$extras->{charset} = 'utf-8';
	}
	if(@cookies)
	{
		$extras->{cookie} = \@cookies;
	}


	if($ENV{SCRIPT_NAME}) {
		$query->header(-type=> $datatype, 
			       -content_length => $len,
			       %HEADER_PARAMS,%$extras);
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
sub handleUserRequest{
  my $user_id = $$USER{node_id};
  my $node_id;
  my $nodename;
  my $author;
  my $code;
  my $handled = 0;
  my $noRemoveSpaces = 0;

  my $defaultNode = $Everything::CONF->{system}->{default_node};

  if ( $APP->isGuest($USER) ){
    $defaultNode = $Everything::CONF->{system}->{default_guest_node};
  }

  if ($query->param('node')) {
    # Searching for a node my string title
    my $type  = $query->param('type');

    $nodename = cleanNodeName($query->param('node'), $noRemoveSpaces);

    $author = $query -> param("author");
    $author = getNode($author,"user");

    if ($nodename eq "") {
      gotoNode($defaultNode, $user_id);
      return;
    }

    if ($author and $type eq 'writeup') {
      my $parent_e2node = getNode($nodename, 'e2node', 'light');
      $parent_e2node = getId($parent_e2node);

      # Prefer a writeup whose parent matches the title exactly, if any
      # if not, prefer a draft with exact title, if any
      # otherwise, a writeup starting with the given title
      my @choices = ();
      push @choices , ['writeup', { -parent_e2node => $parent_e2node}] if $parent_e2node;
      push @choices , ['draft', {title => $nodename}],
        ['writeup', {"-LIKE-title" => $DB->quote($nodename . '%')}];

      foreach (@choices){
          my ($writeup) =
            getNodeWhere(
              {
                "-author_user" => $$author{user_id},
                %{$_->[1]}
              }
              , $_->[0]
            );

          if ($writeup) {
            gotoNode($writeup, $user_id);
            return;
          }
      }

    }

    if ($query->param("author") && $type eq 'writeup') {
      # Since an author specific search didn't work, throw out the
      #  author and search for e2nodes instead
      $query->delete("author");
      $query->param("type", 'e2node');
      $query->param("should_redirect", 1);
    }
    $query->param("node", $nodename);

    if ($query->param('op') ne 'new') {
      nodeName($nodename, $user_id);
    }
    else {
      gotoNode($Everything::CONF->{system}->{permission_denied}, $user_id);
    }
  }
  elsif ($node_id = $query->param('node_id')) {
    #searching by ID
    gotoNode($node_id, $user_id);
  }
  else {
    #no node was specified -> default
    gotoNode($defaultNode, $user_id);
  }

}

sub cleanNodeName
{
	return $APP->cleanNodeName(@_);
}

#############################################################################
sub clearGlobals
{
	$GNODE = "";
	$USER = "";
	$VARS = "";
	$THEME = "";
        $PAGELOAD = {};
        $TEST = "";
	$TEST_CONDITION = "";
        $TEST_SESSION_ID = "";

	$query = "";
}


#############################################################################
sub opNuke
{
	my $user_id = $$USER{node_id};
	my $node_id = $query->param("node_id");

	return if $APP->getParameter($node_id, "prevent_nuke");
	nukeNode($node_id, $user_id);
}


#############################################################################
#	Sub
#		opLogin
#
#	Purpose
#		log in user with plain text password and set login cookie
#		with username and hashed password
#

sub opLogin
{
	my $user = $query->param("user");
	my $passwd = $query->param("passwd");
	$USER = loginUser($user, $passwd) if $user && $passwd;

	return if !$USER || $APP->isGuest($USER); 

	$user = $USER -> {title};
	$passwd = $USER -> {passwd};

	$USER -> {cookie} = $query -> cookie(
		-name => $Everything::CONF -> {cookiepass}
		, -value => "$user|$passwd"
		, -expires => $query->param('expires'));
}

#############################################################################
#	Sub
#		loginUser
#
#	Purpose
#		log in user or set Guest User. Set $VARS. Update last seen
#		time and room for logged in user
#
#	Parameters
#		user name and plain text password, or none to use cookie
#
#	Returns
#		user hashref
#

sub loginUser
{
	my ($username, $pass, $cookie) = @_;

	unless ($username && $pass or !$query)
	{
		$cookie = $query->cookie($Everything::CONF->{cookiepass})
			#jb 5-19-02: To support wap phones and maybe other clients/configs without cookies:
			|| $query->param($Everything::CONF->{cookiepass});
	
		($username, $pass) = split(/\|/, $cookie) if $cookie;
	}

	my $user = confirmUser($username, $pass, $cookie) if $username && $pass;
	$user ||= getNodeById($Everything::CONF->{system}->{guest_user});

	$VARS = getVars($user);

	return $user if !$user
		|| $APP->isGuest($user)
		|| $query -> param('ajaxIdle');

	my $TIMEOUT_SECONDS = 4 * 60;

	my $sth = $DB->getDatabaseHandle()->prepare("
		CALL update_lastseen($$user{node_id});
		");
	$sth->execute();
	my ($seconds_since_last, $now) = $sth->fetchrow_array();
	$user -> {lastseen} = $now;

	insertIntoRoom($$user{in_room}, $user, $VARS)
		if $seconds_since_last > $TIMEOUT_SECONDS;

	return $user;
}

#############################################################################
#	Sub
#		confirmUser
#
#	Purpose
#		Check user credentials if presented.
#
#	Parameters
#		user name, password, cookie
#
#	Returns
#		The USER node hash reference if credentials are accepted,
#		otherwise 0

sub confirmUser
{
	my ($username, $pass, $cookie) = @_;

	my $user = getNode($username, 'user');
	return 0 unless $user && $user -> {acctlock} == 0;

	unless ($cookie)
	{
		# login with plaintext password. May reset password or activate account first:
		$APP -> checkToken($user, $query) if $query -> param('token');
		$pass = $APP -> hashString($pass, $user -> {salt});
	}

	return $user if $pass eq $user -> {passwd};
	return 0 if $user -> {salt};

	# legacy user with unsalted password
	return $APP -> updateLogin($user, $query, $cookie);
}

#############################################################################
sub opLogout
{
	# The user is logging out.  Nuke their cookie.
	my $cookie = $query->cookie(-name => $Everything::CONF->{cookiepass}, -value => "");
	my $user_id = $Everything::CONF->{system}->{guest_user};	

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
	my $removeSpaces = 1;
	my $nodename = cleanNodeName($query->param('node'), $removeSpaces);

	if (canCreateNode($user_id, $DB->getType($type)) and !$APP->isGuest($USER))
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
		$query->param("node_id", $Everything::CONF->{system}->{permission_denied});
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
	return $OPNODE;
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
  my ($OPCODE, $opCodeCode);
  my $handled = 0;
  
  return 0 unless(defined $op && $op ne "");
  
  my $logError = sub {
    my $condition = shift;
    if ($@){
      Everything::printLog("Problem when $condition $op opcode:\n");
      my $params = $query->Vars();
      for (keys %$params) {
        Everything::printLog("- param: " . $_ . " = " . $query->param($_));
      }
      Everything::printLog($@);
    }
  };

  my $opCodeTest = sub {
    my $code = shift;
    my $compiled = eval $code;
    &$logError("compiling");
    return $compiled;
  };

  $OPCODE = getOpCode($op);

  # For built-in opcodes, like new, there will normally be no $OPCODE
  if ($OPCODE) {

    $opCodeCode = getCompiledCode($OPCODE, $opCodeTest);
    unless ($@)
    {
      $handled = eval { &$opCodeCode(); };
      &$logError("running");
    }

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
    elsif($op eq 'throwerror' && isGod($USER))
    {
      Everything::throwError();
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
	my ($db) = @_;

	if($Everything::CONF->{maintenance_mode})
	{
		my $maintenance_html;
		
		if(!$maintenance_html) #intentionally mod_perl 'unsafe'
		{
			my $handle;
			open $handle,"/var/everything/www/maintenance.html";
			{
				local $/ = undef;
				$maintenance_html = <$handle>;
				close $handle;
			}
		}	
		print "Content-Type: text/html\n\n$maintenance_html\n";
		return;
	}

	#blow away the globals
	clearGlobals();

	$query = getCGI();

	# Initialize our connection to the database
	Everything::initEverything($db);

	if (!defined $DB->getDatabaseHandle()) {
		$query->print($SITE_UNAVAILABLE);
		return;
	}

	# Get the HTML variables for the system.  These include what
	# pages to show when a node is not found (404-ish), when the
	# user is not allowed to view/edit a node, etc.  These are stored
	# in the dbase to make changing these values easy.	
	%HEADER_PARAMS = ( );

	set_die_handler(\&handle_errors);
	return if $query->user_agent and $query->user_agent =~ /WebStripper/;
	$USER = loginUser();

	#assign_test_condition();

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

	$DB->closeTransaction();
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
# Sub
#   showPartialDiff
#
# Purpose
#   Given two pieces of code, shows a brief diff between them that
#   only includes the lines that have been affected by the change.
#   This was originally in the [patch display page] htmlpage.
#
# Parameters
#   $codeOrig  - old code to diff
#   $codeNew   - new code to diff
#
# Returns
#   The HTML-ready diff.

sub showPartialDiff{
  my ($codeOrig,$codeNew) = @_;

  use Algorithm::Diff qw(diff);

  my $diffs = diff([split("\n", $codeOrig)], [split("\n", $codeNew)]);
  return 'Nothing changed!' unless @$diffs;

  my $str = '';

  my $chunk;
  my $line;

  my $s;

  foreach $chunk (@$diffs) {
    foreach $line (@$chunk) {
      my ($sign, $lineno, $text) = @$line;
      $s = sprintf("%4d$sign %s\n", $lineno+1, encodeHTML($text));
      if ($sign eq '+') {
        $s = '<font color="#008800">'.$s.'</font>';
      }
      elsif ($sign eq '-') {
        $s = '<font color="#880000">'.$s.'</font>';
      }
      $str .= $s;
    }
    $str .= "\n";  #blank line between chunks
  }

  return $str;
}

#############################################################################
# Sub
#   showCompleteDiff
#
# Purpose
#   Same as showPartialDiff, but showing all of the code and the
#   differing lines in context.
#
# Parameters
#   $codeOrig  - old code to diff
#   $codeNew   - new code to diff
#
# Returns
#   The HTML-ready diff.

sub showCompleteDiff{
  my ($codeOrig,$codeNew) = @_;
  use Algorithm::Diff qw(sdiff);


  my @diff = sdiff([split("\n", $codeOrig)], [split("\n", $codeNew)]);
  my @minusBuffer = ();
  my @plusBuffer = ();
  my $html = '';

  my $renderDiffLine  = sub {
    my ($sign, $line) = @_;

    # [ ] replace colors with CSS classes

    my $color = '';
    if ($sign eq '+') {
      $color = '#008800';
    }
    elsif ($sign eq '-') {
      $color = '#880000';
    }

    my $html = '';
    if ($color) {
      $html .= "<span style=\"color: $color\">";
    }
    $html .= $sign . ' ' . encodeHTML($line);
    if ($color) {
      $html .= "</span>";
    }
    return $html;
  };

  my $flushDiffBuffers = sub {
    my $html = '';

    foreach (@minusBuffer) {
      $html .= &$renderDiffLine(@$_);
    }
    @minusBuffer = ();

    foreach (@plusBuffer) {
      $html .= &$renderDiffLine(@$_);
    }
    @plusBuffer = ();

    return $html;
  };

  while (@diff) {
    my ($sign, $left, $right) = @{shift @diff};

    if ($sign eq '-') {
      push @minusBuffer, ['-', $left];

    }
    elsif ($sign eq '+') {
      push @plusBuffer, ['+', $right];

    }
    elsif ($sign eq 'c') {
      push @minusBuffer, ['-', $left];
      push @plusBuffer, ['+', $right];

    }
    elsif ((@minusBuffer || @plusBuffer)
           && $right =~ /^\s*$/
           && @diff
           && ${$diff[0]}[0] ne 'u') {

      # whitespace lines surrounded by changes should be included in
      # the changes
      # [ ] doesn't take into account multiple unchanged whitespace
      # lines in a row
      push @minusBuffer, ['-', $left];
      push @plusBuffer, ['+', $right];

    }
    else {
      $html .= &$flushDiffBuffers();
      $html .= &$renderDiffLine(' ', $right);
    }

    if (!@diff) {
      $html .= &$flushDiffBuffers();
    }
  }

  return $html;
}


#####################
# sub 
#   generate_test_cookie 
#
# purpose
#   quick and dirty factory for creating a cookie from $TEST
#
# params
#   none, but checks $TEST and $TEST_CONDITION
#
# returns
#   condition cookie
sub generate_test_cookie {
   return if $TEST_CONDITION eq 'optout';
   return $query->cookie("condition", "") unless $TEST and $TEST_CONDITION; 

   return $query->cookie(-name=>'condition',
                         -value=> join("|", (getId($TEST), $$TEST{starttime}, $TEST_CONDITION, $TEST_SESSION_ID)),
                         -expires=>'+1y',
			 -path=>'/'); 
}

#####################
# sub 
#   assign_test_condition
#
# purpose
#   check to see if tests are running, if so stamp 'em
#   if the user has a condition, load $TEST
#
# params 
#   none, but checks $USER globals, cookies, and $query params
# 
# returns
#   none
#
sub assign_test_condition {
  return if isGod($USER);
  $TEST_CONDITION = '';
  my ($T) = getNodeWhere({ enabled => 1 }, 'mvtest');
  return unless $T;

  $TEST = $T;
  getRef $TEST;

  my $current_condition = $query->cookie('condition');
  if ($current_condition eq 'optout') {
    $TEST_CONDITION = 'optout';
    return;
  }

  #if a user has logged in and been assigned a test, the users own vars
  #trump anything the cookie says (except for optout)
  if (!$APP->isGuest($USER) and exists $$VARS{mvtest_condition} and $$VARS{mvtest_condition} != $current_condition) {
     if ($$VARS{mvtest_condition} eq 'optout') {
        $TEST_CONDITION = 'optout';
        return;
     }
     $current_condition = $$VARS{mvtest_condition};        
  }

  #we use the test_id/starttime as a dual key to confirm the test we have a
  #cookie for is a valid test
  my ($id, $starttime, $condition, $session_id);
  if ($current_condition) {
     ($id, $starttime, $condition, $session_id) = split "\\|", $current_condition;
  }

  if ($current_condition and $id == getId($TEST) and $starttime eq $$TEST{starttime} and $session_id) {
     $TEST_CONDITION  = $condition;
     $TEST_SESSION_ID = $session_id;
  } else {
     #if no assigned condition, or the cookie is no longer valid, assign 
     my @potential_conditions = split ",", $$TEST{conditions};
     if (@potential_conditions) {
        $TEST_CONDITION = $potential_conditions[int(rand(@potential_conditions))];      
        $TEST_SESSION_ID = int(rand(2147483647));
     } 
  }

  #if a user is logged in, make sure that the condition info is written to their
  #user vars
  if ( !$APP->isGuest($USER) ) {
    $$VARS{mvtest_condition} = join("|", (getId($TEST), $$TEST{starttime}, $TEST_CONDITION, $TEST_SESSION_ID)); 
  } 

  #the cookie for the test is stamped in the printHeader() function
  #which calls the generate_test_cookie function
}

######################
# sub
#   check_test_substitutions
#
# purpose
#   determine from $TEST whether we have substitutions for a given htmlcode
#   this is called by getCode to "filter" what users see
#
# params
#   htmlcode name
#
# returns
#   new htmlcode name, or original
#
sub check_test_substitutions {
  my ($htmlcode) = @_;

  return $htmlcode if not getId($TEST) or $TEST_CONDITION eq 'optout' or not $TEST_CONDITION;
  
  my $key = $TEST_CONDITION. "|". $htmlcode;   
  my $V = getVars($TEST);
  if (exists $$V{$key} and getNode($$V{$key}, 'htmlcode')) {
    return $$V{$key};
  }

  return $htmlcode;
}

######################
# sub
#   recordUserAction
#
# purpose
#   Log a user action with the current user's session id and condition
#
# params
#   action (node or node_id), source_node_id, target_node_id
#
# returns
#   nothing
#
sub recordUserAction {
  my ($action, $source_node_id, $target_node_id) = @_;

  # Stop logging immediately if somebody's opted out
  return if ($TEST_CONDITION eq 'optout');
  # Logging won't work for gods because they aren't asssigned a SESSION_ID
  return if isGod($USER);
  # Don't log if there's no active session
  return if !$TEST_SESSION_ID;

  $action = getNode($action, 'useraction') if !ref $action;
  my $action_id = int($$action{node_id}) if $action;

  my %setValues =
    (
      -useraction_id => $action_id
      , -useraction_session_id => $TEST_SESSION_ID
      , useraction_condition => $TEST_CONDITION
    );

  getId($source_node_id);
  getId($target_node_id);

  $setValues{'-useraction_source_node_id'} = $source_node_id if $source_node_id;
  $setValues{'-useraction_target_node_id'} = $target_node_id if $target_node_id;

  if (!$action_id) {

    Everything::printLog("Unable to log user action because '$action' isn't a valid action.");
    return;

  } else {

    $DB->sqlInsert('useractionlog', \%setValues);

  }

}

#####################
# sub 
#   process_vars_set
#
# purpose
#   Update package variables if a node was updated which affects them
#
# params
#   $updated_node -- the updated node
#
# returns
#   nothing
sub processVarsSet {
	my $updated_node = shift;

	if ($$updated_node{node_id} == $$USER{node_id}) {
		$VARS = getVars($updated_node);
	}
}


# Former inhabitants of the experience module

########################################################################
#
#	allocateVotes
#
#	give votes to a specific user.  it's assumed that at some point 
#	at a given interval, each user is allocated their share of votes
#
sub allocateVotes {
	my ($user, $numvotes) = @_;
	getRef($user);

	$$user{votesleft} = $numvotes;
	updateNode($user, -1);
}

#########################################################################
#
#	adjustRepAndVoteCount
#
#	adjust reputation points for a node as well as vote count, potentially
#
sub adjustRepAndVoteCount {
	my ($node, $pts, $voteChange) = @_;
	getRef($node);

	$$node{reputation} += $pts;
	# Rely on updateNode to discard invalid hash entries since
	#  not all voteable nodes may have a totalvotes column
	$$node{totalvotes} += $voteChange;
	updateNode($node, -1);
}

##########################################################################
#
#	adjustExp
#
#	adjust experience points
#
#	ideally we could optimize this, since its only inc one field.
#
sub adjustExp {
	my ($user, $points) = @_;
	getRef($user);

	$$user{experience} += $points;

	# Only update user immediately if we're not in a transaction
	updateNode($user, -1);
	1;
}

###
#
#       adjust GP
#
#       ideally we could optimize this, since its only inc one field.
#
sub adjustGP {
        my ($user, $points) = @_;
        getRef($user);
        my $V=getVars($user);
        return if ((exists $$V{GPoptout})&&(defined $$V{GPoptout}));
        $$user{GP} += $points;
        updateNode($user,-1);
        1;
}

###################################################################
#
#	getVotes
#
#	get votes for a certain node.  returns
#	a list of vote hashes.  If you specify a user, it returns
#	only the vote hash for the users vote (if exists)
#
sub getVotes {
	my ($node, $user) = @_;

	return hasVoted($node, $user) if $user;

	my $csr = $DB->sqlSelectMany("*", "vote", "vote_id=".getId($node));
	my @votes;

	while (my $VOTE = $csr->fetchrow_hashref()) {
		push @votes, $VOTE;
	}
	
	@votes;
}

##########################################################################
#	hasVoted -- checks to see if the user has already voted on this Node
#
#	this is a primary key lookup, so it should be very fast
#
sub hasVoted {
	my ($node, $user) = @_;

	my $VOTE = $DB->sqlSelect("*", 'vote', "vote_id=".getId($node)." 
		and voter_user=".getId($user));

	return 0 unless $VOTE;
	$VOTE;
}

##########################################################################
#	insertVote -- inserts a users vote into the vote table
#
#	note, since user and node are the primary keys, the insert will fail
#	if the user has already voted on a given node.
#
sub insertVote {
	my ($node, $user, $weight) = @_;
	my $ret = $DB->sqlInsert('vote', { vote_id => getId($node),
		voter_user => getId($user),
		weight => $weight,
		-votetime => 'now()'
		});
	return 0 unless $ret;
	#the vote was unsucessful

	1;
}

###########################################################################
#
#	castVote
#
#	this function does a number of things -- sees if the user is
#	allowed to vote, inserts the vote, and allocates exp/rep points
#
sub castVote {
  my ($node, $user, $weight, $noxp, $VSETTINGS) = @_;
  getRef($node, $user);

  my $voteWrap = sub {

    my ($user, $node, $AUTHOR) = @_;

    #return if they don't have any votes left today
    return unless $$user{votesleft};

    #jb says: Allow for $VSETTINGS to be specified. This will save
    # us a few cycles in castVote
    $VSETTINGS ||= getVars(getNode('vote settings', 'setting'));
    my @votetypes = split /\s*\,\s*/, $$VSETTINGS{validTypes};

    #if no types are specified, the user can vote on anything
    #otherwise, they can only vote on "validTypes"
    return if (@votetypes and not grep(/^$$node{type}{title}$/, @votetypes));

    my $prevweight;
    $prevweight  = $DB->sqlSelect('weight',
                                  'vote',
                                  'voter_user='.$$user{node_id}
                                  .' AND vote_id='.$$node{node_id}
                                  );

    # If user had already voted, update the table manually, check that the vote is
    # actually different.
    my $alreadyvoted = (defined $prevweight && $prevweight != 0);
    my $voteCountChange = 0;
    my $action;

    if (!$alreadyvoted) {

      insertVote($node, $user, $weight);

      if ($$node{type}{title} eq 'poll') {
         $action = 'votepoll';
      } elsif ($weight > 0) {
         $action = 'voteup';
      } else {
         $action = 'votedown';
      }

      $voteCountChange = 1;

    } else {

        $DB->sqlUpdate("vote"
                       , { -weight => $weight, -revotetime => "NOW()" }
                       , "voter_user=$$user{node_id}
                          AND vote_id=$$node{node_id}"
                       )
          unless $prevweight == $weight;

        if ($weight > 0) {
           $action = 'voteflipup';
        } else {
           $action = 'voteflipdown';
        }

    }

    recordUserAction($action, $$node{node_id});
    adjustRepAndVoteCount($node, $weight-$prevweight, $voteCountChange);

    #the node's author gains 1 XP for an upvote or a flipped up
    #downvote.
    if ($weight>0 and $prevweight <= 0) {
      adjustExp($AUTHOR, $weight);
    }
    #Revoting down, note the subtle difference with above condition
    elsif($weight < 0 and $prevweight > 0){
       adjustExp($AUTHOR, $weight);
    }


    #the voter has a chance of receiving a GP
    if (rand(1.0) < $$VSETTINGS{voterExpChance} &&  !$alreadyvoted) {
      adjustGP($user, 1) unless($noxp);
      #jb says this is for decline vote XP option
      #we pass this $noxp if we want to skip the XP option
    }

    $$user{votesleft}-- unless ($alreadyvoted and $weight==$prevweight);

  };

  my $superUser = -1;
  updateLockedNode(
    [ $$user{user_id}, $$node{node_id}, $$node{author_user} ]
    , $superUser
    , $voteWrap
  );

  1;
}

sub getHRLF
{
  my ($user) = @_;
  $$user{numwriteups} ||= 0;
  return 1 if $$user{numwriteups} < 25;
  return $$user{HRLF} if $$user{HRLF};
  my $hrstats = getVars(getNode("hrstats", "setting"));
  
  return 1 unless $$user{merit} > $$hrstats{mean};
  return 1/(2-exp(-(($$user{merit}-$$hrstats{mean})**2)/(2*($$hrstats{stddev})**2)));
};

# Former inhabitants of the room module
sub insertIntoRoom {
  my ($ROOM, $U, $V) = @_;

  getRef $U;
  $V ||= getVars($U);
  my $user_id=getId($U);
  my $room_id=getId($ROOM);
  $room_id = 0 unless $ROOM;
  my $vis = $$V{visible} if exists $$V{visible};
  $vis ||= 0;
  my $borgd = 0;
  $borgd = 1 if $$V{borged};

  $DB->sqlInsert("room"
    , {
            room_id => $room_id,
            member_user => $user_id,
            nick => $$U{title},
            borgd => $borgd,
            experience => $$U{experience},
            visible => $vis,
            op => isGod($U)
    }
    , {
            nick => $$U{title},
            borgd => $borgd,
            experience => $$U{experience},
            visible => $vis,
            op => isGod($U)
    }
  );

}


sub changeRoom {
  my ($user, $ROOM) = @_;
  getRef $user;
  my $room_id=getId($ROOM);
  $room_id=0 unless $ROOM;

  unless ($$user{in_room} == $room_id) {
    $$user{in_room} = $room_id;
    updateNode($user, -1);
  }
  $DB->sqlDelete("room", "member_user=".getId($user));
    
  insertIntoRoom($ROOM, $user);
}

sub cloak {
  my ($user, $vars) = @_;
  my $setvarflag;
  $setvarflag = 1 unless $vars; 
  $vars ||= getVars $user;
  
  $$vars{visible}=1;
  setVars($user, $vars) if $setvarflag;
  $DB->sqlUpdate('room', {visible => 1}, "member_user=".getId($user));
}

sub uncloak {
  my ($user, $vars) = @_;
  my $setvarflag;
  $setvarflag = 1 unless $vars; 
  $vars ||= getVars $user;
  
  $$vars{visible}=0;
  setVars($user, $vars) if $setvarflag;
  $DB->sqlUpdate('room', {visible => 0}, "member_user=".getId($user));
}





1;


#############################################################################
# End of package
#############################################################################
1;

