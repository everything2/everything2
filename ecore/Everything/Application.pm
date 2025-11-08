#!/usr/bin/perl

use strict;
use warnings;
package Everything::Application;
use Everything;
use Everything::S3;

use DateTime;
use DateTime::Format::Strptime;

use Paws;
use LWP::UserAgent;

# For convertDateToEpoch
use Date::Calc;

# For rewriteCleanEscape, urlGen
use CGI qw(-utf8);

# For getCallStack
use Devel::Caller qw(caller_args);

# For add_notification
use JSON;

# For sitemap_batch_xml
use XML::Generator;

# For optimally_compress_page
use Compress::Zlib;
use IO::Compress::Brotli;
use IO::Compress::Deflate;
use Encode;

# For updateNewWriteups
use Everything::DataStash::newwriteups;

# For parse_timestamp
use Time::Local;

# For htmlScreen
use HTML::Scrubber;
use HTML::Defang;

use vars qw($PARAMS $PARAMSBYTYPE);
BEGIN {
	$PARAMS = 
	{
		# Tested in 000_test_cloaking.t
		"cancloak" => 
		{
			"on" => ["user"],
			"description" => "Grants the user a courtesy chatterbox cloaking utility",
			"assignable" => ["admin"],
			"validate" => "set_only",
		},
		
		# Tested in 000_test_cloaking.t
		"level_override" => 
		{
			"on" => ["user"],
			"description" => "Hard sets a level on a user",
			"assignable" => ["admin"],
			"validate" => "integer",
		},
		# TODO: Add test
		"hide_chatterbox_staff_symbol" =>
		{
			"on" => ["user"],
			"description" => "Hides the '\@' or '\$' symbol in the Other Users nodelet",
			"assignable" => ["admin"],
			"validate" => "set_only",
		},

		"prevent_nuke" => 
		{
			"description" => "Prevent the node from being nuked, via the Nuke node key",
			"assignable" => ["admin"],
			"validate" => "set_only",
		},

		#TODO: Add test
		"allow_message_archive" =>
		{
			"on" => ["usergroup"],
			"description" => "On usergroups, allow the messages to be archived",
			"assignable" => ["admin"],
			"validate" => "set_only",
		},

		#TODO: Add test
		"usergroup_owner" =>
		{
			"on" => ["usergroup"],
			"description" => "On usergroups, set the owner",
			"assignable" => ["admin"],
			"validate" => "integer",
		},

		"prevent_vote" =>
		{
			"on" => ["e2node", "writeup"],
			"description" => "On e2nodes, writeups contained therein are no longer votable. On writeups, that writeup is unvotable",
			"assignable" => ["admin"],
			"validate" => "set_only",
		},

		"allow_book_parameters" =>
		{
			"on" => ["writeup"],
			"description" => "Mark this writeup as being about a book, allowing other parameters",
			"assignable" => ["admin"],
			"validate" => "set_only", 
		},

		# TODO: Write a validator for book isbns
		"book_isbn" =>
		{
			"on" => ["writeup"],
			"description" => "Mark this writeup as referring to a particular book isbn-10 or isbn-13",
			"assignable" => ["admin"],
			"validate" => "isbn",
		},

		"book_edition" =>
		{
			"on" => ["writeup"],
			"description" => "Mark this as being about a book of a particular edition",
			"assignable" => ["admin"],
		},
	
		"book_numpages" =>
		{
			"on" => ["writeup"],
			"description" => "Mark this as being about a book with a particular number of pages",
			"assignable" => ["admin"],
			"validate" => "integer",
		},

		"book_author" =>
		{
			"on" => ["writeup"],
			"description" => "Mark this as being about a book with this author",
			"assignable" => ["admin"],
		},
		"supported_sheet" =>
		{
			"on" => ["stylesheet"],
			"description" => "Supported for general use",
			"assignable" => ["admin"],
			"validate" => "integer",
		},
                "depended_upon_sheet" =>
                {
			"on" => ["stylesheet"],
			"description" => "Sheet is protected as it is required by a supported sheet",
			"assignable" => ["admin"],
			"validate" => "integer",
                },
		"last_update" =>
		{
			"on" => ["datastash"],
			"description" => "When the stash was last updated",
			"assignable" => ["admin"],
			"validate" => "integer"
		},
		"disable_bookmark" =>
		{
			"description" => "Prevent bookmarking on this node or type",
			"assignable" => ["admin"],
			"validate" => "integer",
		},
		"override_disable_bookmark" =>
		{
			"description" => "Allow bookmarking on this node, even if it is disabled on the type",
			"assignable" => ["admin"],
			"validate" => "integer",
		},
		"disable_cool" => 
		{
			"description" => "Prevent cool on this node or type",
			"assignable" => ["admin"],
			"validate" => "integer"
		},
		"override_disable_cool" =>
		{
			"description" => "Allow cool on this node, even if it is disabled on the type",
			"assignable" => ["admin"],
			"validate" => "integer",
		},
		"disable_weblog" => 
		{
			"description" => "Prevent weblogging on this node or type",
			"assignable" => ["admin"],
			"validate" => "integer",
		},
		"override_disable_weblog" =>
		{
			"description" => "Allow weblog on this node, even if it is disabled on the type",
			"assignable" => ["admin"],
			"validate" => "integer",
		},
		"disable_category" =>
		{
			"description" => "Prevent adding this node or nodetype to a category",
			"assignable" => ["admin"],
			"validate" => "integer",
		},
		"override_disable_category" =>
		{
			"description" => "Allow category on this node, even if it is disabled on the type",
			"assignable" => ["admin"],
			"validate" => "integer",
		},
	};

	foreach my $param(keys %$PARAMS)
	{
		if(exists($PARAMS->{$param}->{on}))
		{
			foreach my $type (@{$PARAMS->{$param}->{on}})
			{
				$PARAMSBYTYPE->{$type}->{$param} = $PARAMS->{$param};
			}
		}else{
			$PARAMSBYTYPE->{_ALLTYPES}->{$param} = $PARAMS->{$param};
		}
	}
}

use vars qw($PARAMVALIDATE);

$PARAMVALIDATE = 
{
	"set_only" => sub 
	{
		my ($this, $node, $user, $val) = @_;
		return if not defined $val;
		return($val == 1);	
	},
	"integer" => sub
	{
		my ($this, $node, $user, $val) = @_;
		return($val eq int($val));
	},
	"isbn" => sub
	{
		my ($this, $node, $user, $val) = @_;
		return ($val =~ /^\d{10}$/ or $val =~ /^\d{3}\-\d{10}$/);
	},
        "admin" => sub
        {
		my ($this, $node, $user, $val) = @_;
		return 1 if defined($user) and $user eq '-1';
                return 1 if defined($user) and $this->isEditor($user);
        	return 0;
	},
	"self" => sub
	{
		my ($this, $node, $user, $val) = @_;
		return $node->{node_id} == $user->{node_id};
	},
        "system" => sub
        {
                my ($this, $node, $user, $val) = @_;
		return 1 if defined($user) and $user eq '-1';
        	return 0;
	},
};

sub new
{
	my ($class, $db, $conf) = @_;
	return bless {"db" => $db, "conf" => $conf}, $class;
}


#############################################################################
#	Sub
#		updatePassword
#
#	purpose
#		create a new salt, update user with new salt and new hashed password,
#		(optionally) unlock user account
#
#	arguments
#		(hashref) user, new password, [(boolean) unlock]
#
#	returns
#		result of DB update
#

sub updatePassword
{
	my ($this, $user, $pass) = @_;

	($user->{passwd}, $user->{salt}) = $this -> saltNewPassword($pass);
	return $this->{db}->updateNode($user, $user);
}

#############################################################################
#	Sub
#		saltNewPassword
#
#	purpose
#		create a new salt and use it to hash a given password
#
#	parameter
#		cleartext password
#
#	returns
#		array containing salt and hash
#

sub saltNewPassword
{
	my ($this, $pass) = @_;

	my $shaPrefix = '$6$';
	my $saltLength = 20;

	my @base64 = ('A' .. 'Z', 'a' .. 'z', 0 .. 9, '.', '/');
	my $salt = $shaPrefix.join('', @base64[ map { rand 64 } ( 1 .. $saltLength ) ]);

	my $pwhash = $this -> hashString($pass, $salt);
	return ($pwhash, $salt);
}

#############################################################################
#	Sub
#		hashString
#
#	Purpose
#		hash a password/string using a salt.
#
#	Parameters
#		cleartext password/string, salt
#
#	Returns
#		hashed password
#

sub hashString
{
	my ($this, $pass, $salt) = @_;

	$pass = crypt($pass, $salt);
	# Salt prefix reveals algorithm, and we store the salt separately anyway
	$pass =~ s/^.*\$//;

	return $pass;
}

#############################################################################
#	Sub
#		getToken
#
#	Purpose
#		generate a token to activate a new account
#		or reset a lost password
#
#	Parameters
#		a user (NODE), password, action,
#		(optional) token expiry timestamp
#
#	Returns
#		a new token, or (boolean) passed check
#

sub getToken
{
	my ($this, $user, $pass, $action, $expiry) = @_;

	my $token = $this->hashString("$action$pass$expiry", $user -> {salt});
	# email clients may parse dots at end of links as outside link
	$token =~ s/\.+$//;
	return $token;
}

#############################################################################
#	Sub
#		getTokenLinkParameters
#
#	purpose
#		provide parameters for a link to allow a user to activate a new
#		account or reset their password
#
#	Parameters
#		(hashref) user, (string) what action the link is for,
#		password, (optional) expiry timestamp, (optional) page url
#

sub getTokenLinkParameters
{
	my ($this, $user, $pass, $action, $expiry) = @_;

	my $token = $this -> getToken($user, $pass, $action, $expiry);

	return {
		user => $$user{title} || $$user{nick}
		, token => $token
		, action => $action
		, expiry => $expiry
	};
}

#############################################################################
#	Sub
#		checkToken
#
#	purpose
#		check validity of token presented to activate or reset an account
#		and update account appropriately
#
#	parameter
#		(hashref) user, CGI object
#


sub checkToken
{
	my ($this, $user, $query) = @_;

	my $action = $query->param('action');
	my $expiry = $query->param('expiry');
	my $passwd = $query->param('passwd');
	my $token = $query->param('token');

	return if ($expiry && time() > $expiry)
		or ($action ne 'activate' && $action ne 'reset')
		or $this->getToken($user, $passwd
			, $action, $expiry) ne $token;

	$this->updatePassword($user, $passwd);
	return $this->securityLog($this->{db}->getNode($action eq 'activate' ? 'Sign up' : 'Reset password', 'superdoc')
		, $user, "$$user{title} account $action");

}

#############################################################################
#	Sub
#		updateLogin
#
#	purpose
#		log in a user whose password has not yet been hashed,
#		and hash it
#
#	parameter
#		(hashref) user, CGI object, old login cookie
#
#	returns
#		user hashref if user was logged in and updated, 0 if not
#

sub updateLogin
{
	my ($this, $user, $query, $cookie) = @_;

        $this->devLog("Updating login for user to salt: $user->{title}");

	  return 0 if substr($query->param('passwd'), 0, 10) ne $user->{passwd}
		&& $this->urlDecode($cookie) ne $user->{title}.'|'.crypt($user->{passwd}, $user->{title});

	$this->updatePassword($user, $user->{passwd});

	# set new login cookie, unless we're going to anyway (and avoid infinite loop)
        Everything::HTML::oplogin() unless $query->param('op') eq 'login';
	return $user;
}

######################################################################
#	sub
#		cleanWordAggressive
#
#	Purpose
#		Rudimentarily trim plural, 'ed' suffixes from words.
#
#	Params
#		word	word to trim.
#
#	Returns
#		trimmed word.
#
#	Caveats
#		- This is a very simple trimmer, so some trimmings will
#         yield the incorrect new form of word (e.g. 'tied' becomes
#         'ty').  But most will be done correctly.
#       - This function could use a lot of improvement. Dropping
#         'ing' suffixes and improving replacement-suffix decision
#         making both would improve translation accuracy considerably.
#
#
######################################################################

sub cleanWordAggressive
{
	my ($this, $word) = @_;

	study $word;
	
	# trim trailing 'ed' suffixes
	$word =~ s/ssed$/ss/i;
	$word =~ s/ied$/y/i;
	$word =~ s/([cs])ed$/$1e/i;
	$word =~ s/([aeiou]{2}[^aeiou])ed$/$1/i;
	$word =~ s/([^aeiou]{2}[aeiou][^aeiou])ed$/$1/i;
	$word =~ s/([aeiou]{1}[^aeiou])ed$/$1e/i;
	$word =~ s/([^aeiou]{2})ed$/$1/i;
	
	# depluralize
	$word =~ s/(.{2,})ies$/$1y/i;
	$word =~ s/(.*[^eius])s$/$1/i;
	$word =~ s/sses$/ss/i;
	$word =~ s/([cs]h)es$/$1/i;
	$word =~ s/(.*)es$/$1e/i;

	# drop double chars at end of word, except for [lsaeiou]
	$word =~ s/([^lsaeiou])\1$/$1/;
	
	return $word;

}


#############################################################################
#	Sub
#		makeClean
#
#	Purpose
#       Takes a text string and removes HTML tags, drops all punctuation
#       embedded in words (except for '/' which is turned into its own
#       word), condenses whitespace, and returns the string.
#
#	Parameters
#       $text   The text string to process.
#
#	Returns
#		The cleaned string.
#
############################################################################
sub makeClean
{
    my ($this, $text) = @_;
    $text = lc($text);
	
    study $text;
    	
	# eliminate any HTML tags.
	$text =~ s/\<.*\>//g;
			
	# turn '/' into ' / '
	$text =~ s|/| / |g;

	# condense multiple whitespace.
	$text =~ s/\s{2,}/ /g;
	
	# drop trailing/leading whitespace.
	$text =~ s/^\s+//;
	$text =~ s/\s+$//;
	
	# eliminate all punctuation within letter/digit-containing words.
	$text =~ s/(\w)[^\w\s_]+/$1/g;
	$text =~ s/[^\w\s_]+(\w)/$1/g;

	return $text;
}

#############################################################################
#	Sub
#		makeCleanWords
#
#	Purpose
#       Cleans the string with makeClean, truncates each word to 20 chars,
#		and returns an array of the words in the text string.
#
#	Parameters
#       $text   The text string to process.
#		$harder	Aggressively clean each word with cleanWordAggressive,
#				if $this->{conf}->clean_search_words_aggressively is also set.
#
#	Returns
#		The array of words extracted from $text.
#
############################################################################
sub makeCleanWords
{
    my ($this, $text, $harder) = @_;
    $text = $this->makeClean($text);
	$harder &&= $this->{conf}->clean_search_words_aggressively;
	
	my @words = ();
	if ($text) {
		@words = map { substr($_, 0, 20) } split(/\s/, $text);
		
		if ($harder && @words)
		{
			@words = map { $this->cleanWordAggressive($_) }  @words;
		}
	}
	
	return @words;
}

#############################################################################
#	Sub
#		searchNodeName
#
#	Purpose
#		This is the node search function.  You give a search string
#		containing the words that you want, and this returns a list
#		of nodes (just the node table info, not the complete node).
#		The list is ordered such that the best matches come first.
#
#       Setting $useSoundex will do approximate matching using soundex
#       values rather than the actual words.  Matches with more
#       exact term matches will come first before the approximates.
#
#       Setting $matchAny will require only one search term to match;
#       if unset, all search terms must match.
#
#		The substring "typeis TYPE" in $searchWordswill restrict the search
#		by the given TYPE. Example: "everything typeis document"
#
#   Parameters
#       $searchWords    the search string to use to find node matches.
#       $TYPE           an array of nodetype IDs of the types that we want to
#                       restrict the search (useful for only returning
#                       results of a particular nodetype.
#       $useSoundex     1=use soundex values rather than words for matching.
#       $matchAny       1=match any single term, instead of all.
#
#	Returns
#		A sorted list of node hashes (just the node table info), in
#		order of best matches to worst matches. An additional key
#       'search_ranking' is added to each node hash, containing an integer
#       describing the 'reliability' of the match. Higher integers mean
#		better matches.
#
#	Package-global variables you should know about
#		$this->{conf}->clean_search_words_aggressively	1=try to trim plural, 'ed' suffixes from words
#		$this->{conf}->search_row_limit			maximum number of rows to return from a search.
#
#	Note
# 		If you get 'not found' on search queries which should return something,
# 		you probably need to increase tmp_table_size on the mysql server. Big
# 		GROUP BY queries require larger temporary tables.
#
#		We should probably take some measure to prevent nodes appearing which
#		are unreadable by the current user.
#
##############################################################################
sub searchNodeName {
	my ($this, $searchWords, $TYPE, $useSoundex, $matchAny) = @_;

	# clean the search words, aggressively if needed.
	my @prewords = $this->makeCleanWords($searchWords, 1);
	
	my ($typestr, $wherestr, $havingstr, $rankingstr) = ('') x 4;
	my %cooltypes = ();
	
	my $typePrefix = "n.type_nodetype IN (";
	$TYPE=[$TYPE] if (UNIVERSAL::isa($TYPE,'HASH'));

	if(ref($TYPE) eq 'ARRAY' and @$TYPE) {
		foreach(@$TYPE) { $cooltypes{$this->{db}->getId($_)} = 1 }
		$typestr .= $typePrefix . $this->{db}->getId(shift @$TYPE);
		$typePrefix = ", ";
		foreach(@$TYPE) { $typestr .= $typePrefix . $this->{db}->getId($_); }
	}
	
	my @words = ();
	my $typeis = 0;
	foreach (@prewords) {
		if ($typeis)
		{
			my $type = $this->{db}->getType($_);
			if ($type)
			{
				$typestr .= $typePrefix . $$type{node_id};
				$typePrefix = ", ";
			}
			$typeis = 0;
		}
		elsif ($_ eq "typeis")
		{
			$typeis = 1;	# next word is type spec
		}
		else
		{
			push(@words, $_) unless (exists $this->{conf}->nosearch_words->{$_} or length($_) < 2);
		}
	}
	
	$typestr .= ")" if ($typestr);

	if (not @words)
	{
    #No words should mean no search results
    return ();
	}
	else
	{
		$typestr = "AND $typestr" if ($typestr);
		
		if ($this->{conf}->clean_search_words_aggressively)
		{
			@words = map {$this->cleanWordAggressive($_) } @words;
		}

    	@words = map {$this->{db}->{dbh}->quote($_)} @words;

    	if ($useSoundex)
	    {
    	    $wherestr =
        		"sw.soundex_value in (SOUNDEX(" .
				join("), SOUNDEX(", @words) .
				"))";
    	}
    	else
    	{
        	$wherestr =
        		"sw.word IN (" .
	        	join(", ", @words) .
    	    	")";
	    }
		$wherestr = "($wherestr)";
		
		if ($matchAny or $useSoundex or (scalar @words > 1))
		{
			$rankingstr =
					"SUM((sw.word = " .
    				join(") + (sw.word = ", @words) .
    				"))";
  		
	  		if ($useSoundex)
  			{
  				$rankingstr =
  					"(2 * " . $rankingstr . ") + " .
  					"SUM((sw.soundex_value = SOUNDEX(" .
	  				join(")) + (sw.soundex_value = SOUNDEX(", @words) .
  					")))";
  				# when using soundex, exact word matches get a weight of 2
  				# and soundex word matches get a weight of 1. Non-exact
  				# soundex matches get no weight.
	  		}
  		}
	  	else
  		{
	  		$rankingstr = '1';
  		}
    	
	    $havingstr = ($matchAny) ? '' : "HAVING COUNT(sw.node_id) = " . ($#words+1);
	}	
   	
   	my @ret = ();
	my $searchRowLimit = $this->{conf}->search_row_limit;

#    my $sql =
#    	"
#    	SELECT  $rankingstr AS search_ranking,
#                n.*
#        FROM    searchwords sw,
#                node n
#        WHERE   sw.node_id = n.node_id
#        AND     $wherestr
#        $typestr
#        GROUP   BY sw.node_id
#		$havingstr
#        ORDER   BY search_ranking DESC
#		LIMIT	$searchRowLimit
#        ";
#	$sql =~ s/\t/        /g; printLog $sql;
    my $sql =
    	"
    	SELECT  $rankingstr AS search_ranking, sw.node_id
        FROM    searchwords sw
        WHERE   $wherestr
        GROUP   BY sw.node_id
		$havingstr
        ORDER   BY search_ranking DESC
		LIMIT	$searchRowLimit
        ";

    my $rs = $this->{db}->{dbh}->prepare($sql) || die $!;
	
    $rs->execute;
	
    while(my $m = $rs->fetchrow_hashref)
    {
        #delete $$m{search_ranking};	# should we do this?
        my $N = $this->{db}->getNodeById($$m{node_id}, 'light');
		push @ret, $N if not @$TYPE or exists $cooltypes{$$N{type_nodetype}}; 
    }
    $rs->finish;
	
	return \@ret;
}

##########################################################################
#	Sub
#		insertSearchWord
#
#	Purpose
#		inserts a new node into the database -- for maintainence when 
#		new nodes are created
#
sub insertSearchWord {
	my ($this, $nodetitle, $node_id) = @_;

	my @words = $this->makeCleanWords($nodetitle, 1);
		   	
	if (@words) {
		my %wordhash = ();
			
		for (my $loop = 0; $loop <= $#words; $loop++) {
		    $wordhash{$words[$loop]} = $loop;
		}
		#were we using a larger text field, we would prob use the value
		#of this hash as a frequency entry.  But we're not.  Hurm...
			
		while (my ($word, $wpos) = each %wordhash) {
			$this->{db}->sqlInsert("searchwords", { 
				word => $word, 
				node_id => $node_id,
				-soundex_value => "SOUNDEX(".$this->{db}->{dbh}->quote($word).")" } 
			); 
		}
	}
	return 1;
}


############################################################################
#	Sub
#		removeSearchWord
#
#	Purpose
#		given a node(_id), remove it's entry from the searchword table 
#
sub removeSearchWord {
	my ($this, $NODE) = @_;

	return $this->{db}->sqlDelete("searchwords", "node_id=".$this->{db}->getId($NODE));
}



#############################################################################
#	Sub
#		regenSearchwords
#
#	Purpose
#		Wipe out and repopulate the contents of the searchwords table.
#		Maintenance function.
#
#   Parameters
#		none
#
#	Returns
#		none
#
#############################################################################
sub regenSearchwords
{
	my ($this) = @_;
	local $|=1;
	
	print "Regenerating searchwords, this could take a while...<br><br>\n";

	print 	"Will be cleaning words " .
			(($this->{conf}->clean_search_words_aggressively) ? "" : "non-") .
			"aggressively.<br>\n";
			
	print "Clearing searchwords table<br>\n ";
	$this->{db}->{dbh}->do("DELETE FROM searchwords");
 	
	print "Optimizing searchwords table<br>\n";
	$this->{db}->{dbh}->do("OPTIMIZE TABLE searchwords");

	print "Removing indexes from searchwords to speed upcoming inserts<br>\n";
	$this->{db}->{dbh}->do("  ALTER   TABLE searchwords
	            DROP    INDEX word,
	            DROP    INDEX soundex_value");

	print "Fetching node titles...<br>\n ";
	my $cursor = $this->{db}->{dbh}->prepare( "
		SELECT	title, node_id
		FROM	node
		");

	$cursor->execute || die $!;

	print "Inserting words from node titles into searchwords table...<br>\n ";

	my $insert = $this->{db}->{dbh}->prepare( "
		INSERT
		INTO	searchwords
		VALUES	(?, ?, SOUNDEX(?))
		"); # corresponding fields ought to be
		    # (word, node_id, soundex_value)
			# it's faster if we don't specify that in the INSERT though.
			
	my $nodecount = 0;
	my ($nodeid, $nodetitle, $word, $wpos) = (undef, undef, undef, undef);
	my @words = ();
	while (($nodetitle, $nodeid) = $cursor->fetchrow)
	{
		$nodecount++;
		if ($nodecount % 500 == 0) {
			print "$nodecount nodes...<br>\n ";
		}

		@words = $this->makeCleanWords($nodetitle, 1);
		   	
		if (@words) {
			my %wordhash = ();
			
			for (my $loop = 0; $loop <= $#words; $loop++)
			{
			    $wordhash{$words[$loop]} = $loop;
			}
			
			while (($word, $wpos) = each %wordhash)
			{
				$insert->execute($word, $nodeid, $word) || die $!;
			}
		}
	}
	$cursor->finish;
	
	print "Creating index (word) on searchwords table.<br>\n";
	$this->{db}->{dbh}->do("  ALTER   TABLE searchwords
	            ADD     INDEX word (word)
	        ") || die $!;

    print "Creating index (soundex_value) on searchwords table.<br>\n";
    $this->{db}->{dbh}->do("  ALTER   TABLE searchwords
                ADD     INDEX soundex_value (soundex_value)
            ") || die $!;

	print "<br><b>Done. $nodecount nodes processed.</b><br>\n ";
	return;
}

sub isEditor
{
	my ($this, $user, $nogods) = @_;
	return $this->{db}->isApproved($user,$this->{db}->getNode('content editors','usergroup'), $nogods);
}

sub isDeveloper
{
	my ($this, $user, $nogods) = @_;
	return $this->{db}->isApproved($user,$this->{db}->getNode('edev','usergroup'), $nogods);
}

sub isClientDeveloper
{
	my ($this, $user, $nogods) = @_;
	return $this->{db}->isApproved($user,$this->{db}->getNode('clientdev','usergroup'), $nogods);
}

sub isAdmin
{
	my ($this, $user) = @_;
	return $this->{db}->isGod($user);
}

sub isChanop
{
	my ($this, $user, $nogods) = @_;
	return $this->{db}->isApproved($user, $this->{db}->getNode('chanops','usergroup'),$nogods);
}

#TODO: Work on me some, not sure how I'm going to use this
sub chatSigils
{
	my ($this, $user, $exclude, $nolinks) = @_;
	
	my $sigils = "";
	$sigils .= '@' if $this->isAdmin($user) and not $this->getParameter($user,"hide_chatterbox_staff_symbol");
	$sigils .= '$' if not $this->isAdmin($user) and $this->isEditor($user, "nogods") and not $this->getParameter($user,"hide_chatterbox_staff_symbol");
	$sigils .= '+' if $this->isChanop($user, "nogods") and not $this->getParameter($user,"hide_chatterbox_staff_symbol");
	$sigils .= '%' if $this->isDeveloper($user, "nogods");

	return $sigils;
}

sub getLevel {
	my ($this, $user) = @_;
	$this->{db}->getRef($user);
	return $$user{level} if $$user{level};
	return 0 if $this->isGuest($user);

	my $level_override = $this->{db}->getNodeParam($user, "level_override");
	return $level_override if $level_override;

	my $exp = $$user{experience};
	my $V = Everything::getVars($user);
        my $numwriteups = $$V{numwriteups};

        my $EXP = Everything::getVars($this->{db}->getNode('level experience','setting'));
	my $WRP = Everything::getVars($this->{db}->getNode('level writeups', 'setting'));

	my $maxlevel = 1;
	while (exists $$EXP{$maxlevel}) { $maxlevel++ }

	$exp ||= 0;
	$numwriteups ||= 0;
        my $level = 0;
        for (my $i = 1; $i < $maxlevel; $i++) {
                if ($exp >= $$EXP{$i} and $numwriteups >= $$WRP{$i}) {
                        $level = $i;
                }
        }

        return $level;
}

sub getLevelTitle {
	my ($this, $lvl) = @_;
	$lvl ||= 0;
	my $titles = Everything::getVars($this->{db}->getNode("level titles","setting"));
	return $titles->{$lvl};
}

########################################################################
#

sub userCanCloak
{
  my ($this, $user) = @_;
  $this->{db}->getRef($user);
  return ($this->getLevel($user) >= 10 or $this->isEditor($user) or $this->{db}->getNodeParam($user, "cancloak")) || "0";
}

sub setParameter
{
  my ($this, $node, $user, $param, $paramvalue) = @_;
  
  return unless defined($node);
  return unless defined($user);
  return unless defined($param);

  if(ref $node eq "")
  {
    $node = $this->{db}->getNodeById($node);
  }

  return unless $node;
  my $paramdata = $this->getParameterForType($node->{type}, $param);  
  
  return if !$this->canSetParameter($node,$user,$param);

  if(exists($paramdata->{validate}))
  {
    return if not exists($Everything::Application::PARAMVALIDATE->{$paramdata->{validate}});
    return if not $Everything::Application::PARAMVALIDATE->{$paramdata->{validate}}->($this, $node, $user, $paramvalue);
  }
  
  $this->{db}->setNodeParam($node, $param, $paramvalue);

  # The security log needs a node to map to an action, so we need to use the parameter opcode
  # I don't love the way this works, but I can fix it later pretty easily.
  $this->securityLog($this->{db}->getNode("parameter","opcode"), $user, "Set parameter '$param' as '$paramvalue' on '$$node{title}'");
  return 1;
}

sub delParameter
{
  my ($this, $node, $user, $param) = @_;
  
  return unless defined($node);
  return unless defined($user);
  return unless defined($param);

  if(ref $node eq "")
  {
    $node = $this->{db}->getNodeById($node);
  }

  return unless $node;
  return if !$this->canSetParameter($node,$user,$param);
  $this->{db}->deleteNodeParam($node, $param);

  # The security log needs a node to map to an action, so we need to use the parameter opcode
  # I don't love the way this works, but I can fix it later pretty easily.
  $this->securityLog($this->{db}->getNode("parameter","opcode"), $user, "Deleted parameter '$param' from '$$node{title}'");
  return 1; 
}

sub getParameter
{
  my ($this, $node, $param) = @_;
  return unless defined($node);
  return unless defined($param);

  # Avoid getNode for speed. This is important
  return $this->{db}->getNodeParam($node, $param);
}

sub canSetParameter
{
  my ($this, $node, $user, $param) = @_;

  $this->{db}->getRef($node);
  return unless $node;
  my $paramdata = $this->getParameterForType($node->{type}, $param);  
  if(not defined($paramdata))
  {
    return;
  }
  my $can_assign = 0;
  foreach my $assignable (@{$paramdata->{assignable}})
  {
    if(not exists($Everything::Application::PARAMVALIDATE->{$assignable}))
    {
      return;
    }

    $can_assign = $Everything::Application::PARAMVALIDATE->{$assignable}->($this, $node, $user, undef);
    last if $can_assign;
  }
  return $can_assign;

}

sub getParametersForType
{
  my ($this, $type) = @_;
  if(ref $type eq "")
  {
    if($type =~ /^\d+$/)
    {
      $this->{db}->getRef($type);
    }else{
      $type = $this->{db}->getType($type);
    }
  }
  return unless $type;

  my $paramsbytype = $Everything::Application::PARAMSBYTYPE->{$type->{title}};
  @{$paramsbytype}{keys %{$Everything::Application::PARAMSBYTYPE->{_ALLTYPES}}} = values %{$Everything::Application::PARAMSBYTYPE->{_ALLTYPES}};
  return $paramsbytype;
}

sub getParameterForType
{
  my ($this, $type, $param) = @_;
  return unless defined($param);
  my $all_params_for_type = $this->getParametersForType($type);
  return $all_params_for_type->{$param};
}

sub getNodesWithParameter
{
  my ($this, $param, $value) = @_;
  return unless exists($PARAMS->{$param});
  return $this->{db}->getNodesWithParam($param, $value);
}

sub securityLog
{
  my ($this, $node, $user, $details) = @_;
  $this->{db}->getRef($node);

  if(defined($user) and $user eq "-1")
  {
    $user = $this->{db}->getNode("root","user");
  }else{
    $this->{db}->getRef($user);
  }
  return unless defined($node) and defined($user);
  return $this->{db}->sqlInsert('seclog', { 'seclog_node' => $$node{node_id}, 'seclog_user'=>$$user{node_id}, 'seclog_details'=>$details});
}

sub isGuest
{
  my ($this, $user) = @_;
  return unless defined $user;
  my $userid = undef;
  if(ref $user eq "")
  {
    $userid = $user; 
  }else{
    $userid = $user->{node_id};
  }

  return ($this->{conf}->guest_user == $userid);
}

sub metaDescription
{
  my ($this, $node) = @_;

  my $writeuptext = undef;
  if($node->{type}->{title} eq "writeup")
  {
    $writeuptext = $node->{doctext};
  }elsif($node->{type}->{title} eq "e2node")
  {
    my $WUs = undef;
    my $lede = $this->{db}->getNode("lede","writeuptype");
    foreach my $writeup(@{$node->{group}})
    {
      my $thisWU = $this->{db}->getNodeById($writeup);
      if($thisWU->{wrtype_writeuptype} == $lede->{node_id})
      {
        $writeuptext = $thisWU->{doctext};
	last;
      }
      push @$WUs,$thisWU;
    }
    if($WUs and not defined($writeuptext))
    {
      $WUs = [sort {$b->{reputation} <=> $a->{reputation}} @$WUs];
      $writeuptext = $WUs->[0]->{doctext};
    }
  }
  if($writeuptext)
  {
    study($writeuptext);
    $writeuptext =~ s/\[//g;
    $writeuptext =~ s/\]//g;  
    $writeuptext =~ s/\<.*?\>//g;
    $writeuptext =~ s/\s+/ /g;
    $writeuptext = $this->encodeHTML($writeuptext);

    $writeuptext = substr($writeuptext,0,155);
    $writeuptext =~ s/.{3}$/.../;
  }else{
    $writeuptext = "Everything2 is a community for fiction, nonfiction, poetry, reviews, and more. Get writing help or enjoy nearly a half million pieces of original writing.";
  } 
  return qq|<meta name="description" content="$writeuptext">|;
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
	my ($this, $html, $adv) = @_;

	# Moved from Everything::HTML;
	# Formerly the '&amp;' *had* to be done first.  Otherwise, it would convert
	# the '&' of the other encodings. However, it is now designed not to encode &s that are part of entities.
        #$html =~ s/&(?!\#(?>x[0-9a-fA-F]+|[0-9]+);)/&amp;/g;

	$html ||= "";
	$html =~ s/\&/\&amp\;/g;
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

sub isSpider
{
	my ($this, $agent, $addr) = @_;

	$agent ||= $ENV{HTTP_USER_AGENT};
	$agent ||= "";

	$addr ||= $ENV{HTTP_X_FORWARDED_FOR};
	$addr ||= $ENV{REMOTE_ADDR};
	$addr ||= "";
	
	my $result = $this->{db}->{cache}->pageCacheGet("isSpider|$agent|$addr");
	if(defined $result)
	{
		return $result;
	}
	$result = $this->_isSpiderCheck($agent, $addr);
	$this->{db}->{cache}->pageCacheSet("isSpider|$agent|$addr",$result);
	return $result;
}
	
sub _isSpiderCheck
{
	my ($this, $agent, $addr) = @_;
	study $agent;

	return 1 if ($agent =~ m/AdsBot/);
	return 1 if ($agent =~ /Ask Jeeves\/Teoma/);	# HTTP_USER_AGENT=Mozilla/5.0 (compatible; Ask Jeeves/Teoma; +http://about.ask.com/en/docs/about/webmasters.shtml), IP forwarded 66.235.124.34
	return 1 if ($agent =~ m/Baiduspider/);
	return 1 if ($agent =~ m/BOTW/);
	return 1 if ($agent =~ m/Charlotte/); # searchme.com's spider, which also appears more than once below - hopefully this should cover all of it...
	return 1 if ($agent =~ m/DBLBot/);
	return 1 if ($agent =~ m/DotBot/); # HTTP_USER_AGENT=Mozilla/5.0 (compatible; DotBot/1.1; http://www.dotnetdotcom.org/, crawler@dotnetdotcom.org), IP forwarded 208.115.111.244
	return 1 if ($agent =~ m/fscals/);
	return 1 if ($agent =~ m/FunWeb/); # HTTP_USER_AGENT=Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; FunWebProducts; .NET CLR 2.0.50727), IP forwarded 91.184.161.105
	return 1 if ($agent =~ m/Googlebot/i);
	return 1 if ($agent =~ m/Gigabot/);
	return 1 if ($agent =~ m/heritrix/); # open-sourced IA crawler/archiver
	return 1 if ($agent =~ m=Java/1\.6\.0_10=);
	return 1 if ($agent =~ m/LiteFinder/);
	return 1 if ($agent =~ m/msnbot/);
	return 1 if ($agent =~ m/Nutch/);
	return 1 if ($agent =~ m/ScoutJet/);
	return 1 if ($agent =~ /^Sosospider/);	#'Sosospider+(+http://help.soso.com/webspider.htm)', 124.115.4.192
	return 1 if ($agent =~ m/SurveyBot/);
	return 1 if ($agent =~ m/Twenga/);
	return 1 if ($agent =~ m/Twiceler/);
	return 1 if ($agent =~ m/VoilaBot/i);
	return 1 if ($agent =~ m/Yahoo! Slurp/);

	return 1 if ($agent =~ m/spider/); # Let's hope there's never a legitimate browser with 'spider' or 'crawler' in its useragent string.
	return 1 if ($agent =~ m/crawler/); # Let's hope there's never a legitimate browser with 'spider' or 'crawler' in its useragent string.

	#get user agent name (everything before first slash)
	if($agent =~ m!^([^/]+)/!) {

	my $agentName = $1;

	return 1 if $agentName eq 'OmniExplorer_Bot';	#'OmniExplorer_Bot/6.10.13 (+http://www.omni-explorer.com) WorldIndexer'
	return 1 if $agentName eq 'voyager-hc';	#'voyager-hc/1.0'
	return 1 if $agentName eq 'voyager';	#'voyager/1.0 (+http://www.kosmix.com/html/crawler.html)'
	return 1 if $agentName eq 'ia_archiver';	#'ia_archiver' (Alexa)
	return 1 if $agentName eq 'GurujiBot';	#'GurujiBot/1.0' (+http://www.guruji.com/en/WebmasterFAQ.html), 72.20.109.36
	return 1 if $agentName eq 'ichiro';	#'ichiro/3.0 (http://help.goo.ne.jp/door/crawler.html', 210.150.10.100
	return 1 if $agentName eq 'Sogou web spider';	#'Sogou web spider/4.0(+http://www.sogou.com/docs/help/webmasters.htm#07)', 220.181.19.164
	return 1 if $agentName eq 'DotBot'; # (http://www.dotnetdotcom.org/) - also added 208.115.111.245
	return 1 if $agentName eq 'Gigabot'; # Gigabot/3.0 (http://www.gigablast.com/spider.html), IP forwarded 66.231.189.152
	return 1 if $agentName eq 'Yeti'; # Yeti/1.0 (+http://help.naver.com/robots/), IP forwarded 61.247.222.55)
	return 1 if $agentName eq 'ia_archiver'; # ia_archiver, IP forwarded 209.234.171.37 (Alexa)
	}


	return 1 if ($addr =~ m/69\.118\.193\.20/);
	return 1 if ($addr =~ m/121\.14\.96\./);
	return 1 if ($addr =~ m/77\.88\.27\.25/);
	return 1 if ($addr =~ m/202\.55\.83\.4/);
	return 1 if ($addr =~ m/208\.115\.111\.245/); # DotBot
	return 1 if ($addr =~ m/79\.222\.96\.110/); # HTTP_USER_AGENT=Mozilla/5.0 (compatible; AdShadow +http://adshadow.de)
	return 1 if ($addr =~ m/208\.111\.154\./); # Mozilla/5.0 (X11; U; Linux i686 (x86_64); en-US; rv:1.8.1.11) Gecko/20080109 (Charlotte/0.9t; http://www.searchme.com/support/), IP forwarded 208.111.154.103) - also 208.111.154.15, among other addresses, but should be blocked above
	return 1 if ($addr =~ m/72\.44\.56\.161/); # Mozilla/5.0 (compatible; zermelo; +http://www.powerset.com) [email:paul@page-store.com,crawl@powerset.com], IP forwarded 72.44.56.161)
	return 1 if ($addr =~ m/96\.228\.37\.192/); # (HTTP_USER_AGENT=Mozilla/5.0 (compatible; FSC/1.0 +http://fscals.com), IP forwarded 96.228.37.192

	return 0;
}

sub inDevEnvironment
{
	my ($this) = @_;
	return $this->{conf}->environment eq "development";
}

sub node2mail {
	my ($this, $addr, $node, $html) = @_;
	my @addresses = (ref $addr eq "ARRAY") ? @$addr:($addr);
	my ($user) = $this->{db}->getNodeWhere({node_id => $$node{author_user}},$this->{db}->getType("user"));
	my $subject = $$node{title};
	my $body = $$node{doctext};

	my $from = $this->{conf}->mail_from;
	
	my $email = Paws->service('SES', region => $this->{conf}->current_region);

	my $response = $email->SendEmail(
		'Destination' => {
			'ToAddresses' => \@addresses,
		},
  		'Message' => {
    			'Body' => {
      				'Html' => {
        				'Charset' => 'UTF-8',
        				'Data' => $body,
      				},
    			},
    			'Subject' => {
      				'Charset' => 'UTF-8',
      				'Data' => $subject
    			}
  		},
  		'Source' => $from
	);
	return $response->MessageId;
}

# Replaces the htmlcode of the same name
# Tested in 002
sub convertDateToEpoch
{
  my ($this, $date) = @_;

  my ($d, $t) = split(' ', $date);
  my ($year,$month,$day) = split('-',$d);

  # In the QA environment, lots of dates are 0
  if($year eq "0000")
  {
    return 0;
  }
  my ($hour,$min,$sec) = split(':', $t);
  my $epoch = Date::Calc::Date_to_Time($year,$month,$day, $hour,$min,$sec);
  return $epoch;
}

sub convertEpochToDate
{
  my ($this, $epoch) = @_;
  # Normally gmtime would be appropriate, but in production we use gmtime as localtime
  # In dev, gmtime breaks things

  my $timedata = [localtime($epoch)];
  return join(" ", join("-",$timedata->[5]+1900,sprintf("%02d",$timedata->[4]+1),sprintf("%02d",$timedata->[3])),join(":",sprintf("%02d", $timedata->[2]),sprintf("%02d",$timedata->[1]),sprintf("%02d", $timedata->[0])));
}


# used as a part of the sendPrivateMessage htmlcode refactor, possibly other places
# Tested in 003
sub messageCleanWhitespace
{
	my ($this, $message) = @_;

	#ensure message doesn't have any embeded newlines, which cause headaches
	$message =~ s/\n/ /g; #Strip newlines
	if($message =~ /^\s*(.*?)$/) { $message=$1; } # Strip starts with spaces
	if($message =~ /^(.*?)\s*$/) { $message=$1; } # Strip ends with spaces
	$message =~ s/\s+/ /g;	#only need 1 space between things	
	return $message;
}

# used as a part of the sendPrivateMessage htmlcode refactor
sub isUsergroup
{
	my ($this, $usergroup) = @_;
	return $usergroup->{type}->{title} eq "usergroup";	
}

sub isUser
{
	my ($this, $user) = @_;
	return $user->{type}->{title} eq "user";
}

sub isUserOrUsergroup
{
	my ($this, $user_or_usergroup) = @_;
	return ($this->isUser($user_or_usergroup) or $this->isUsergroup($user_or_usergroup));
}

sub inUsergroup
{
	my ($this, $user, $usergroup, $nogods) = @_;
	if(ref $usergroup eq "")
	{
		$usergroup = $this->{db}->getNode($usergroup, "usergroup");
	}

	return $this->{db}->isApproved($user,$usergroup,$nogods);
}

sub userIgnoresMessagesFrom
{
	my ($this, $user, $nodefrom) = @_;
	my $user_id = $user;
	if(ref $user ne "")
	{
		$user_id = $user->{node_id};
	}
	
	my $nodefrom_id = $nodefrom;
	if(ref $nodefrom ne "")
	{
		$nodefrom_id = $nodefrom->{node_id};
	}

	my $result = $this->{db}->sqlSelect("messageignore_id","messageignore","messageignore_id=".$this->{db}->quote($user_id)." and ignore_node=".$this->{db}->quote($nodefrom_id));
	return $result;
}

sub isUnvotable
{
	my ($this, $node) = @_;
	
	if(ref $node eq "")
	{
		$node = $this->{db}->getNodeById($node);
	}

	return unless $node;
	return unless $node->{type}->{title} eq "e2node" or $node->{type}->{title} eq "writeup";

	if($node->{type}->{title} eq "writeup")
	{
		if($this->getParameter($node, "prevent_vote") )
		{
			return 1;
		}else{
			return $this->isUnvotable($node->{parent_e2node});
		}
	}else{
		return $this->getParameter($node, "prevent_vote");
	}
}

sub isMaintenanceNode
{
	my ($this, $node) = @_;

	if(ref $node eq "")
	{
		$node = $this->{db}->getNodeById($node);
	}

	return unless $node and $node->{node_id};
	return unless $node->{type}->{title} eq "e2node" or $node->{type}->{title} eq "writeup";

	my $maintenance_nodes = [@{$this->{conf}->maintenance_nodes}];

	if($node->{type}->{title} eq "writeup")
	{
		if(grep {$_ == $node->{node_id}} @$maintenance_nodes)
		{
			return 1;
		}else{
			return $this->isMaintenanceNode($node->{parent_e2node});
		}
	}else{
		return (grep {$_ == $node->{node_id}} @$maintenance_nodes);
	}
}

sub getMaintenanceNodesForUser
{
	my ($this, $user) = @_;

	my $uid = $user;
	if(ref $user ne "")
	{
		$uid = $user->{node_id};
	}

	my $maint_nodes = undef;
	foreach my $val (@{$this->{conf}->maintenance_nodes})
	{
		my $node = $this->{db}->getNodeById($val);
		next unless $$node{'group'};

		my $wu_ids = $$node{'group'};

		my $numwus = scalar @$wu_ids;
		foreach my $wu_id (@$wu_ids) {
			my $wu = $this->{db}->getNodeById($wu_id);
			$maint_nodes->{$wu_id} = 1 if defined($wu->{author_user}) and $uid == $$wu{'author_user'};
		}
	}

	return [keys %$maint_nodes];
}

sub canSeeDraft
{
	my ($this, $user, $draft, $disposition) = @_;

	# disposition can either be "edit" or "find"
	$disposition ||= "";

	return 0 if $this->isGuest($user);

	if(ref $user eq "")
	{
		$user = $this->{db}->getNodeById($user);
	}

	if(ref $draft eq "")
	{
		$draft = $this->{db}->getNodeById($draft);
	}

	return 1 if $user->{node_id} == $draft->{author_user};

	# we may not have a complete node. Get needed info
	# jb notes: this is pretty unlikely, I think, but I'll leave it in

	unless ($draft->{publication_status}){
		($draft->{publication_status}, $draft->{collaborators}) = $this->{db}->sqlSelect('publication_status, collaborators', 'draft',"draft_id = $$draft{node_id}");
	}

	return 0 if $disposition eq "edit" && !$draft->{collaborators};

	my $STATUS = $this->{db}->getNodeById($$draft{publication_status});
	return 0 if !$STATUS || $$STATUS{type}{title} ne 'publication_status';

        return 1 if ($STATUS->{title} eq "nuked" or $STATUS->{title} eq "removed") && ($this->isAdmin($user) || $this->isEditor($user));


	my $isEditor = $this->isEditor($user);

	my %equivalents = (
		nuked => 'private',
		removed => $isEditor ? 'public' : 'private',
		review => $isEditor ? 'public' : 'private',
	);

	my $status = $equivalents{$$STATUS{title}} || $$STATUS{title};
	return 0 if ($status eq 'private' and (not $$draft{collaborators} or $disposition eq "edit"));

	# locked users' drafts are private, except removed drafts for editors
	return 0 if (not $isEditor or $$STATUS{title} ne 'removed') and $this->{db}->sqlSelect('acctlock', 'user', "user_id=$$draft{author_user}");

	return 1 if($status eq 'public' and $disposition ne "edit");
	return 1 if($status eq 'findable' and $disposition eq "find");;

	# shared draft or edit check. Check if this user can see/edit
	my @collab_names = split ',', $$draft{collaborators};
	my $UG = undef;

	foreach (@collab_names){
		$_ =~ s/^\s*|\s*$//g;
		return 1 if lc($_) eq lc($$user{title}) or lc($_) eq 'everybody';
		if ($UG = $this->{db}->getNode($_, 'usergroup')){
			my $collab_ids = { map {$_->{node_id}} @{$this->{db}->selectNodegroupFlat($UG)} };
 				return 1 if exists $collab_ids->{$$user{node_id}};
		}
	}

	return 0;


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
	my ($this, $nodename, $removeSpaces) = @_;

	$removeSpaces = 1 if !defined $removeSpaces;

	# For some reason, searching for ? hoses the search engine.
	$nodename = "" if($nodename eq "?");

	$nodename =~ tr/[]|<>//d;
	$nodename =~ s/&quot;/"/g;
	$nodename =~ s/^\s*|\s*$//g if $removeSpaces;
	$nodename =~ s/\s+/ /g if $removeSpaces;

	return $nodename;
}

sub commifyNumber
{
	my ($this, $number) = @_;
	return 0 unless defined $number;
	1 while $number =~ s/^([-+]?\d+)(\d{3})/$1,$2/;
	return $number;
}

# Originally in the htmlcode 'get ips'. Taken unmodified.

sub intFromAddr
{
	my ($this, $addr) = @_;
	return unless $addr =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
	return (
		(int $1) * 256*256*256 
		+ (int $2) * 256 * 256
		+ (int $3) * 256
		+ (int $4)
	);
}

# Originally in the htmlcode 'get ips'.

sub isIpRoutable
{
	my ($this,$addr) = @_;
	my $intAddr = $this->intFromAddr($addr);

	# Presume an address we don't recognize is routable
	#  primarily for IPv6 purposes
	return 1 if !defined $intAddr;

	my $unroutable = [
		{ 'addr' => '0.0.0.0',       'bits' => 8 },
		{ 'addr' => '10.0.0.0',      'bits' => 8 },
		{ 'addr' => '127.0.0.0',     'bits' => 8 },
		{ 'addr' => '169.254.0.0',   'bits' => 16 },
		{ 'addr' => '172.16.0.0',    'bits' => 12 },
		{ 'addr' => '192.168.0.0',   'bits' => 16 },
	];

	my $maxAddr = $this->intFromAddr('255.255.255.255');

	foreach my $block (@$unroutable) {
		my $maskBits = 32 - $$block{bits};
		my $mask = ($maxAddr << $maskBits) & $maxAddr;
		my $blockAddr = $this->intFromAddr($$block{addr});
		return 0 if (($blockAddr & $mask) == ($intAddr & $mask));
	}

	return 1;
};

sub getIp
{
	my ($this) = @_;

	my $forwd = $ENV{HTTP_X_FORWARDED_FOR} || "";
	my $remote = $ENV{REMOTE_ADDR} || "";

	my @addrs =
		grep { ($this->{conf}->environment eq "production")?($this->isIpRoutable($_)):(1) }
		grep { /\S/ }
		split /\s*,\s*/,
		",$forwd,$remote";

	return @addrs if wantarray;

	my $addr = '' . join ',', @addrs;
	return $addr;
}

sub isInfectedIp
{
	my ($this, $ip) = @_;
	return scalar(grep {$_ eq $ip} @{$this->{conf}->infected_ips} );
}

#############################################################################
#	Sub
#		escape
#
#	Purpose
#		This encodes characters that may interfere with HTML/perl/sql
#		into a hex number preceeded by a '%'.  This is the standard HTML
#		thing to do when uncoding URLs.
#
#	Parameters
#		$esc - the string to encode.
#
#	Returns
#		Then escaped string
#
sub escape
{
	my ($this) = shift;
	my ($esc) = @_;

	$esc =~ s/(\W)/sprintf("%%%02x",ord($1))/ge;
	
	return $esc;
}

#############################################################################
#	Sub
#		unescape
#
#	Purpose
#		Convert the escaped characters back to normal ascii.  See escape().
#
#	Parameters
#		An array of strings to convert
#
#	Returns
#		Nothing useful.  The array elements are changed.
# Note: now that this lives in Everything::Application instead of Everything.pm, I think this is unused, but I'm going to leave it just in case
#
sub unescape
{
	my $this = shift;
	foreach my $arg (@_)
	{
		tr/+/ /;
		$arg =~ s/\%(..)/chr(hex($1))/ge;
	}
	
	return 1;
}

sub getVarHashFromStringFast
{
	my $this = shift;
	my $varString = shift;
	my %vars = (split(/[=&]/, $varString));
	foreach (keys %vars) {
		$vars{$_} =~ tr/+/ /;
		$vars{$_} =~ s/\%(..)/chr(hex($1))/ge;
		if ($vars{$_} eq ' ') { $vars{$_} = ""; }
	}
	return %vars;
}

sub getVarStringFromHash
{
	my $this = shift;
	my $varHash = shift;

	# Clean out the keys that have do not have a value.
	foreach (keys %$varHash) {
		# Remove deleted value so they aren't saved
		if (!defined $$varHash{$_}) {
			delete $$varHash{$_};
		}
		# But set blank strings to a single space so
		#  they aren't lost.
		$$varHash{$_} = " " unless $$varHash{$_};
	}
	
	my $varStr =
		join("&", map { $_."=".$this->escape($$varHash{$_}) } (sort keys %$varHash) );
	return $varStr
}

sub cloak {
  my ($this, $user, $vars) = @_;
  my $setvarflag = undef;
  $setvarflag = 1 unless $vars; 
  $vars ||= getVars $user;
  
  $$vars{visible}=1;
  Everything::setVars($user, $vars) if $setvarflag;
  return $this->{db}->sqlUpdate('room', {visible => 1}, "member_user=".$this->{db}->getId($user));
}

sub uncloak {
  my ($this, $user, $vars) = @_;
  my $setvarflag = undef;
  $setvarflag = 1 unless $vars; 
  $vars ||= getVars $user;
  
  $$vars{visible}=0;
  Everything::setVars($user, $vars) if $setvarflag;
  return $this->{db}->sqlUpdate('room', {visible => 0}, "member_user=".$this->{db}->getId($user));
}

sub insertIntoRoom {
  my ($this, $ROOM, $U, $V) = @_;

  $this->{db}->getRef($U);
  $V ||= Everything::getVars($U);
  my $user_id=$this->{db}->getId($U);
  my $room_id=$this->{db}->getId($ROOM);
  $room_id = 0 unless $ROOM;
  my $vis = undef; $vis = $$V{visible} if exists $$V{visible};
  $vis ||= 0;
  my $borgd = 0;
  $borgd = 1 if $$V{borged};

  return $this->{db}->sqlInsert("room"
    , {
            room_id => $room_id,
            member_user => $user_id,
            nick => $$U{title},
            borgd => $borgd,
            experience => $$U{experience},
            visible => $vis,
            op => ($this->isAdmin($U) || 0)
    }
    , {
            nick => $$U{title},
            borgd => $borgd,
            experience => $$U{experience},
            visible => $vis,
            op => ($this->isAdmin($U) || 0)
    }
  );
}

sub changeRoom {
  my ($this, $user, $ROOM, $force) = @_;
  $this->{db}->getRef($user);

  return if $this->isSuspended($user, "changeroom") and not $force;

  my $room_id=$this->{db}->getId($ROOM);
  $room_id=0 unless $ROOM;

  unless ($$user{in_room} == $room_id) {
    $$user{in_room} = $room_id;
    $this->{db}->updateNode($user, -1);
  }
  $this->{db}->sqlDelete("room", "member_user=".$this->{db}->getId($user));
    
  return $this->insertIntoRoom($ROOM, $user);
}

sub inRoomUsers {
  my ($this) = @_;

  my $csr=$this->{db}->sqlSelectMany("*", 'room');

  my $ROOM = {};
  while (my $MEMBER = $csr->fetchrow_hashref) {
     $ROOM->{$$MEMBER{room_id}}{$$MEMBER{member_user}} = $MEMBER;
  }
  $csr->finish;

  return $ROOM;
}

sub refreshRoomUsers {
  my ($this) = @_;

  my $ROOM = $this->inRoomUsers;
  my $actions = [];
  my $csr = $this->{db}->sqlSelectMany("user_id", "user", "lasttime > TIMESTAMPADD(SECOND, -".$this->{conf}->logged_in_threshold.", NOW())");
  $csr->execute;

  while (my ($U) = $csr->fetchrow) {
    $U = $this->{db}->getNodeById($U);
    my $V = Everything::getVars($U);
    my $room_id = $$U{in_room};
    my $user_id = $$U{user_id};

    if (exists ($ROOM->{$room_id}{$user_id})) {
      #the user is still in the room
      delete $ROOM->{$room_id}{$user_id};
    } else {
      #the user needs to be inserted into the room table
      $this->insertIntoRoom($room_id, $U, $V);
      push(@$actions, {"action" => "entrance", "room" => $room_id, "user" => $U->{node_id}})
    }
  }
  $csr->finish;

  #remove everyone who's left a room
  foreach my $room_id (keys %$ROOM) {
    foreach (keys %{ $ROOM->{$room_id}}) {
      $this->{db}->sqlDelete("room", "room_id=$room_id and member_user=$_");

      push(@$actions, {"action" => "departure", "room" => $room_id, "user" => $_})
    }
  }
  return $actions;
}

sub logUserIp {
  my ($this, $user, $vars) = @_;
  return if $this->isGuest($user);

  my @addrs = $this->getIp();
  my $addr = join ',', @addrs;
  return unless $addr;

  return if ($$vars{ipaddy} eq $addr);
  $$vars{ipaddy} = $addr;

  my $hour_limit = 24;
  my $ipquery = qq|SELECT DISTINCT iplog_ipaddy FROM iplog WHERE iplog_user = $$user{user_id} AND iplog_time > DATE_SUB(NOW(), INTERVAL $hour_limit HOUR)|;

  my $previous_addrs = $this->{db}->getDatabaseHandle()->selectall_arrayref($ipquery);
  my %ignore_addrs = ( );

  map { $ignore_addrs{$$_[0]} = 1; } @$previous_addrs if ($previous_addrs);

  map {
    $this->{db}->sqlInsert("iplog", {iplog_user => $$user{user_id}, iplog_ipaddy => $_}) if !$ignore_addrs{$_};
    } @addrs;

  my $infected = grep { $this->isInfectedIp($_) } @addrs;

  if ($infected) {
    $$vars{infected} = 1;
  }

  return;
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
  my ($this, $username, $pass, $cookie, $query) = @_;

  my $user = $this->{db}->getNode($username, 'user');
  unless($user)
  {
    $this->devLog("Could not log in with user: $username as it does not exist");
    return 0;
  }

  unless($user->{acctlock} == 0)
  {
    $this->devLog("Could not log into logged account: $username");
    return 0;
  }

  unless ($cookie)
  {
    # login with plaintext password. May reset password or activate account first:
    if($query and $query->param('token'))
    {
      $this->checkToken($user, $query);
    }

    $pass = $this->hashString($pass, $user->{salt});
  }

  return $user if $pass eq $user->{passwd};
  if($user->{salt})
  {
    $this->devLog("Could not log in because password is salted but doesn't equal what is given");
    return 0;
  }

  # legacy user with unsalted password
  return $this->updateLogin($user, $query, $cookie);
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
  my ($this, $usr, $sustype) = @_;

  return unless $usr and $sustype;

  if(!UNIVERSAL::isa($sustype, "HASH"))
  {
    $sustype = $this->{db}->getNode($sustype, "sustype");
    return unless $sustype;
  }

  my $suspension_info = $this->{db}->sqlSelectHashref("*", "suspension", "suspension_user=$$usr{node_id} and suspension_sustype=$$sustype{node_id}");
 
  return unless $suspension_info->{suspension_id};
 
  # Because the "ends" behavior was added well after the other suspension code was in place, we're going to assume that
  # the old behavior of '0' means never ends
  if(not defined($suspension_info->{ends}) or $this->convertDateToEpoch($suspension_info->{ends}) == 0 )
  {
    # Indefinite suspension
    return $suspension_info;
  }

  if($this->convertDateToEpoch($suspension_info->{ends}) <= time())
  {
    # Time has been served
    $this->unsuspendUser($usr, $sustype);
    return;
  }else{
    # Suspension still valid
    return $suspension_info;
  }
}

sub suspendUser
{
  my ($this, $usr, $sustype, $suspendedby, $duration) = @_;
  return unless $usr and $sustype;

  if(!UNIVERSAL::isa($sustype, "HASH"))
  {
    $sustype = $this->{db}->getNode($sustype, "sustype");
    return unless $sustype;
  }
  
  $this->{db}->getRef($suspendedby);

  if($this->isSuspended($usr, $sustype))
  {
     $this->unsuspendUser($usr, $sustype);
  }

  my $suspension_info = { suspension_user => $usr->{node_id}, suspendedby_user => $suspendedby->{node_id}, suspension_sustype => $sustype->{node_id}};
  $suspension_info->{ends} = $this->convertEpochToDate(time()+$duration) if $duration;

  return $this->{db}->sqlInsert("suspension", $suspension_info );
}

sub unsuspendUser
{
  my ($this, $usr, $sustype) = @_;
  return unless $usr and $sustype;

  if(!UNIVERSAL::isa($sustype, "HASH"))
  {
    $sustype = $this->{db}->getNode($sustype, "sustype");
    return unless $sustype;
  }
  
  return $this->{db}->sqlDelete("suspension", "suspension_user=$$usr{node_id} and suspension_sustype=$$sustype{node_id}");
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
  my ($this, $text) = @_;

  #These two lines do regexp magic (man perlre, grep down to
  #assertions) to escape < and > but only if they're not inside
  #brackets. They're a bit inefficient, but since they text they're
  #working on is usually small, it's all good. --[Swap]

  $text =~ s/((?:\[(.*?)\])|>)/$1 eq ">" ? "&gt;" : "$1"/egs;
  $text =~ s/((?:\[(.*?)\])|<)/$1 eq "<" ? "&lt;" : "$1"/egs;

  return $text;
}

sub getHRLF
{
  my ($this, $user) = @_;
  $$user{numwriteups} ||= 0;
  return 1 if $$user{numwriteups} < 25;
  return $$user{HRLF} if $$user{HRLF};
  my $hrstats = Everything::getVars($this->{db}->getNode("hrstats", "setting"));
  
  return 1 unless $$user{merit} > $$hrstats{mean};
  return 1/(2-exp(-(($$user{merit}-$$hrstats{mean})**2)/(2*($$hrstats{stddev})**2)));
}

sub refreshVotesAndCools
{
  my ($this, $user, $vars) = @_;
  my ($time) = split " ",$$user{lasttime};

 if (not $this->isGuest($user)
  and (not exists $$vars{votetime} or $$vars{votetime} ne $time)) {
   
   my $VOTES = Everything::getVars($this->{db}->getNode('level votes', 'setting'));
   my $COOLS = Everything::getVars($this->{db}->getNode('level cools', 'setting'));

   $$user{level} = undef;
   my $lvl = $this->getLevel($user);
   $$user{level} = $lvl;
   if (exists $$VOTES{$lvl} and $$VOTES{$lvl} =~ /^\d+$/) {
     $$user{votesleft} = $$VOTES{$lvl};
   }
   
  if (exists $$COOLS{$lvl} and $$COOLS{$lvl} =~ /^\d+$/) {
     $$vars{cools} = $$COOLS{$lvl};
   }
   $$vars{votesrefreshed} ||= 0;
   $$vars{votesrefreshed}++;
   $$vars{votetime} = $time;
 }

 $$user{votesleft} = 0 if $this->isSuspended($user, "vote");
 $$vars{cools} = 0 if $this->isSuspended($user, "cool");

 return;
}


##########################################################################
#	insertVote -- inserts a users vote into the vote table
#
#	note, since user and node are the primary keys, the insert will fail
#	if the user has already voted on a given node.
#
sub insertVote {
	my ($this, $node, $user, $weight) = @_;
	my $ret = $this->{db}->sqlInsert('vote', { vote_id => $this->{db}->getId($node),
		voter_user => $this->{db}->getId($user),
		weight => $weight,
		-votetime => 'now()'
		});
	return 0 unless $ret;
	#the vote was unsucessful

	return 1;
}

##########################################################################
#	hasVoted -- checks to see if the user has already voted on this Node
#
#	this is a primary key lookup, so it should be very fast
#
sub hasVoted {
	my ($this, $node, $user) = @_;

	my $VOTE = $this->{db}->sqlSelect("*", 'vote', "vote_id=".$this->{db}->getId($node)." 
		and voter_user=".$this->{db}->getId($user));

	return 0 unless $VOTE;
	return $VOTE;
}

#########################################################################
#
#	adjustRepAndVoteCount
#
#	adjust reputation points for a node as well as vote count, potentially
#
sub adjustRepAndVoteCount {
	my ($this, $node, $pts, $voteChange) = @_;
	$this->{db}->getRef($node);

	$$node{reputation} += $pts;
	# Rely on updateNode to discard invalid hash entries since
	#  not all voteable nodes may have a totalvotes column
	$$node{totalvotes} ||= 0;
	$$node{totalvotes} += $voteChange;
	return $this->{db}->updateNode($node, -1);
}

###########################################################################
#
#	castVote
#
#	this function does a number of things -- sees if the user is
#	allowed to vote, inserts the vote, and allocates exp/rep points
#
sub castVote {
  my ($this, $node, $user, $weight, $noxp, $VSETTINGS) = @_;
  $this->{db}->getRef($node, $user);

  my $voteWrap = sub {

    my ($voteuser, $localnode, $AUTHOR) = @_;

    #return if they don't have any votes left today
    return unless $$voteuser{votesleft};

    $VSETTINGS ||= Everything::getVars($this->{db}->getNode('vote settings', 'setting'));
    my @votetypes = split /\s*\,\s*/, $$VSETTINGS{validTypes};

    #if no types are specified, the user can vote on anything
    #otherwise, they can only vote on "validTypes"
    return if (@votetypes and not grep { /^$$localnode{type}{title}$/ } @votetypes);

    my $prevweight;
    $prevweight  = $this->{db}->sqlSelect('weight',
                                  'vote',
                                  'voter_user='.$$voteuser{node_id}
                                  .' AND vote_id='.$$localnode{node_id}
                                  );

    # If user had already voted, update the table manually, check that the vote is
    # actually different.
    my $alreadyvoted = (defined $prevweight && $prevweight != 0);
    my $voteCountChange = 0;
    my $action;

    if (!$alreadyvoted) {

      $this->insertVote($localnode, $voteuser, $weight);

      if ($$localnode{type}{title} eq 'poll') {
         $action = 'votepoll';
      } elsif ($weight > 0) {
         $action = 'voteup';
      } else {
         $action = 'votedown';
      }

      $voteCountChange = 1;

    } else {

        $this->{db}->sqlUpdate("vote"
                       , { -weight => $weight, -revotetime => "NOW()" }
                       , "voter_user=$$voteuser{node_id}
                          AND vote_id=$$localnode{node_id}"
                       )
          unless $prevweight == $weight;

        if ($weight > 0) {
           $action = 'voteflipup';
        } else {
           $action = 'voteflipdown';
        }

    }

    $this->adjustRepAndVoteCount($localnode, $weight-$prevweight, $voteCountChange);

    #the node's author gains 1 XP for an upvote or a flipped up
    #downvote.
    if ($weight>0 and $prevweight <= 0) {
      $this->adjustExp($AUTHOR, $weight);
    }
    #Revoting down, note the subtle difference with above condition
    elsif($weight < 0 and $prevweight > 0){
       $this->adjustExp($AUTHOR, $weight);
    }


    #the voter has a chance of receiving a GP
    if (rand(1.0) < $$VSETTINGS{voterExpChance} &&  !$alreadyvoted) {
      $this->adjustGP($voteuser, 1) unless($noxp);
      #jb says this is for decline vote XP option
      #we pass this $noxp if we want to skip the XP option
    }

    $$voteuser{votesleft}-- unless ($alreadyvoted and $weight==$prevweight);

  };

  my $superUser = -1;
  $this->{db}->updateLockedNode(
    [ $$user{user_id}, $$node{node_id}, $$node{author_user} ]
    , $superUser
    , $voteWrap
  );

  return 1;
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
	my ($this, $node, $user) = @_;

	return $this->hasVoted($node, $user) if $user;

	my $csr = $this->{db}->sqlSelectMany("*", "vote", "vote_id=".getId($node));
	my @votes;

	while (my $VOTE = $csr->fetchrow_hashref()) {
		push @votes, $VOTE;
	}
	
	return @votes;
}

###
#
#       adjust GP
#
#       ideally we could optimize this, since its only inc one field.
#
sub adjustGP {
        my ($this, $user, $points) = @_;
        $this->{db}->getRef($user);
        my $V=Everything::getVars($user);
        return if ((exists $$V{GPoptout})&&(defined $$V{GPoptout}));
        $$user{GP} += $points;
        $this->{db}->updateNode($user,-1);
        return 1;
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
	my ($this, $user, $points) = @_;
	$this->{db}->getRef($user);

	$$user{experience} += $points;

	# Only update user immediately if we're not in a transaction
	$this->{db}->updateNode($user, -1);
	return 1;
}

sub urlDecode
{
  my $this = shift;

  foreach my $arg (@_)
  {
    tr/+/ / if $_;
    $arg =~ s/\%(..)/chr(hex($1))/ge;
  }

  return $_[0];
}

######################################################################
#	sub
#		tagApprove
#
#	purpose
#		determines whether or not a tag (and its specified attributes)
#		are approved or not.  Returns the cleaned tag.  Used by cleanupHTML
#
sub tagApprove
{
  my ($this, $close, $tag, $attr, $APPROVED) = @_;

  $tag = uc($tag) if (exists $$APPROVED{uc($tag)});
  $tag = lc($tag) if (exists $$APPROVED{lc($tag)});
	
  if (exists $$APPROVED{$tag})
  {
    unless ( $close )
    {
      if ( $attr )
      {
        if ( $attr =~ qr/\b(\w+)\b\=['"]?(\w+\b%?)["']?/i )
        {
          my ( $name , $value ) = ( $1 , $2 ) ;
          return '<'.$close.$tag.' '.$name.'="'.$value.'">' if ( $$APPROVED{$tag} =~ /\b$name\b/i ) ;
          return '<'.$close.$tag.' '.$name.'="'.$value.'">' if $$APPROVED{ noscreening } ;
        }
      }
    }
    return '<'.$close.$tag.'>' ;
  } else {
    return '' unless $$APPROVED{ noscreening } ;
    $$APPROVED{$tag} .= '' ;
    return $this->tagApprove($close,$tag,$attr,$APPROVED);
  }
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
#               approved -- ref to hash where approved tags are keys.
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
    my ($this, $text, $approved, $preapproved_ref, $debug) = @_;
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
    $text = "" if not defined($text);
    $text =~ s/<[^>]*$//;
    $text =~ s/<!--(?:[^-]|-[^-]|--[^>])*$//gsm;
 
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
		$approved_tag = $this->tagApprove('', $1, $2,
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
	    my $closing = "";
	    my @popped = ();
	    $tag = lc $1;
	    $key = '/'.$1.$2;
	    $outer_text = $3;
	    $approved_tag = $preapproved_ref->{$key};
	    unless (defined($approved_tag)) {
		$approved_tag = $this->tagApprove('/', $1,
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
		    if ($ctag and $ctag eq $tag) {
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
}

#############################################################################
#	sub
#		htmlScreen
#
#	purpose
#		screen out html tags from a chunk of text
#		returns the text, sans any tags that aren't "approved_tags"
#   Now defers all the work to cleanupHTML
#
#	params
#		text -- the text to filter
#		approved_tags -- ref to hash where approved tags are keys.  Null means
#			all HTML will be taken out.
#

sub htmlScreen {
	my ($this, $text, $approved_tags) = @_;

  my $defang = HTML::Defang->new(
    "fix_mismatched_tags" => 1,
    "delete_defang_content" => 1
  );

  my $scrubber = HTML::Scrubber->new();
  $scrubber->rules(%{$this->get_html_rules()});
  return $defang->defang($scrubber->scrub($text));
	$approved_tags ||= {};

	$text = $this->cleanupHTML($text, $approved_tags);
	return $text;
}


#############################################################################
#       sub
#               breakTags
#
#       purpose
#               Insert paragraph tags where none are found
#

sub breakTags
{
  my ($this,$text) = @_;

  $text = "" unless(defined($text));
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

  return $text;
}

sub rewriteCleanEscape {
  my ($this,$string) = @_;
  $string = CGI::escape(CGI::escape($string));
  # Make spaces more readable
  # But not for spaces at the start/end or next to other spaces
  $string = "" if not defined($string);
  $string =~ s/(?<!^)(?<!\%2520)\%2520(?!$)(?!\%2520)/\+/gs;
  return $string;
}

sub urlGenNoParams {
  my ($this, $NODE, $noquotes) = @_;
  
  $NODE ||= "";
  if (not ref $NODE) {
    if ($noquotes) {
      return "/node/$NODE";
    }
    else {
      return "\"/node/$NODE\"";
    }
  } 

  my $retval = "";
  my $typeTitle = $$NODE{type}{title} || "";
  if ($typeTitle eq 'e2node') {
    $retval = "/title/".$this->rewriteCleanEscape($$NODE{title});
  }
  elsif ($typeTitle eq 'user') {
    $retval = "/$typeTitle/".$this->rewriteCleanEscape($$NODE{title});
  }
  elsif ($typeTitle eq 'writeup' || $typeTitle eq 'draft'){
  	# drafts and writeups have the same link for less breakage
    my $author = $this->{db}->getNodeById($NODE -> {author_user}, "light");

    #Some older writeups are buggy and point to an author who doesn't
    #exist anymore. --[Swap]
    if (ref $author) {
      $author = $author -> {title};
      my $title = $NODE -> {title};

      $title =~ s/ \([^\)]*\)$// if $typeTitle eq 'writeup'; #Remove the useless writeuptype

      $author = $this->rewriteCleanEscape($author);

      $retval = "/user/$author/writeups/".$this->rewriteCleanEscape($title);
    }
    else{
      $retval = "/node/".$this->{db}->getId($NODE);
    }
  }
  elsif ($$NODE{type}{restrictdupes} && $typeTitle && $$NODE{title}) {
    $retval = "/node/$typeTitle/"
              .$this->rewriteCleanEscape($$NODE{title});
  }
  else {
    my $id = $this->{db}->getId($NODE);
    $id = "" if not defined($id);
    $retval = "/node/$id";
  }

  if ($noquotes) {
    return $retval;
  } else {
    return '"'.$retval.'"';
  }

  return; # Make perlcritic happy
}


#############################################################################
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
  my ($this, $code, $numbering) = @_;
  return unless($code); 

  $code = $this->encodeHTML($code, 1);

  my @lines = split /\n/, $code;
  my $count = 1;

  if($numbering)
  {
    foreach my $ln (@lines) {
      $ln = sprintf("%4d: %s", $count++, $ln);
    }
  }

  return "<pre>" . join ("\n", @lines) . "</pre>";
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
sub tableWellFormed {
    my $this = shift;
    my @stack = ();
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

sub debugTag {
    my ($this, $tag) = @_;
    my $htmltag = $tag;
    $htmltag = "<strong><small>&lt;" . $this->encodeHTML($htmltag) . "&gt;</small></strong>";

    if (substr($tag, 0, 1) ne '/') {
        return $htmltag . "<div style=\"margin-left: 16px; border: dashed 1px grey\">";
    } else {
        return "</div>". $htmltag;
    }
}

sub debugTable {
    my ($this, $error, $html) = @_;
    $html =~ s{<((/?)(table|tr|td|th|thead|tbody)((\s[^>]*)|))>}{$this->debugTag($1)}ige;
    return "<p><strong>Table formatting error: $error</strong></p>".$html;
}

sub screenTable {
    my ($this, $text) = @_;
    my ($valid, $error) = $this->tableWellFormed($text);
    $text = $this->debugTable ($error, $text) if ! $valid;
    return $text;
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
sub buildTable
{
	my ($this, $labels,$data,$options,$tablealign,$datavalign) = @_;
	return '<i>no data</i>' unless $data;
	
	$tablealign = "" if not defined($tablealign);
	$datavalign = "" if not defined($datavalign);

	my $borderColor = undef; 
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
	return $str;
}

sub repairE2Node
{
  my ($this, $syncnode, $no_order) = @_;

  $this->{db}->getRef($syncnode);
  return "" unless($syncnode && $$syncnode{type}{title} eq "e2node");

  # Set noorder if node's order is locked
  $no_order = 1 if ($syncnode->{orderlock_user});

  my $grp = $$syncnode{group};
  my @wus = ();
  my $linktype = $this->{db}->getId($this->{db}->getNode('parent_node', 'linktype'));
  my $update_group = undef; $update_group = 1 unless $no_order;

  foreach(@$grp)
  {
    my $wu = $this->{db}->getNodeById($_);
    my $reject = undef; $reject = 1 unless $wu && $$wu{type}{title} eq "writeup" && !grep {$$_{node_id} == $$wu{node_id}} @wus;
    $update_group ||= $reject;
    next if $reject;

    my $nt = $this->{db}->getNodeById($$wu{wrtype_writeuptype});
    $$wu{title} = $$syncnode{title}.' ('.$$nt{title}.')';
    $$wu{parent_e2node} = $$syncnode{node_id};

    $this->{db}->updateNode($wu, -1);

    # Get a numeric value to easily sort on -- publishtime as is may not be suitable in perl
    # (date format can vary between MySQL versions/settings)
    $$wu{numtime} = $this->{db}->sqlSelect("publishtime+0", "writeup", "writeup_id = $$wu{node_id}");
    push @wus, $wu;
  
    # make sure there is no left-over draft attachment
    $this->{db}->sqlDelete('links', "from_node=$$wu{node_id} AND linktype=$linktype");
  }

  unless ($no_order)
  {
    my $webby = $this->{db}->getId($this->{db}->getNode("Webster 1913", "user"));
    my $lede = $this->{db}->getId($this->{db}->getNode('lede', 'writeuptype'));
    # Sort with lede-type at the top and Webby writeups at the bottom,
    # secondarily sorting by publish time descending
    my $isWebby = sub {
      return 0 if $_[0]->{wrtype_writeuptype} == $lede;
      return 1 unless $_[0]->{author_user} == $webby;
      return 2;
    };
    @wus = sort { &$isWebby($a) <=> &$isWebby($b) || $$a{numtime} <=> $$b{numtime}} @wus;
  }

  if ($update_group)
  {
    # condition avoids infinite recursion through updateNode ...
    $this->{db}->replaceNodegroup($syncnode, \@wus, -1);
    $this->{db}->updateNode($syncnode, -1); # ... but is this necessary?
  }

  return 1;
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
  my ($this, $REF, $noquotes, $NODE) = @_;

  $noquotes = "" unless defined($noquotes);

  my $str = "";
  $str .= '"' unless $noquotes;

  if($NODE){
    $str .= $this->urlGenNoParams($NODE,1);
  }
  #Preserve backwards-compatibility
  else{
    if($$REF{node}){
      my $nodetype = $$REF{type} || $$REF{nodetype};
      if($nodetype){
        $str .= "/node/$nodetype/".$this->rewriteCleanEscape($$REF{node});
      }
      else{
        $str .= "/title/".$this->rewriteCleanEscape($$REF{node});
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
  my $anchor = '';
  $anchor = '#'.$$REF{'#'} if $$REF{'#'};
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
  return $str;
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
  my ($this, $NODE, $title, $PARAMS) = @_;

  return "" if not defined($NODE);
  return "" if not ref($NODE) and $NODE =~ /\D/;
  $NODE = $this->{db}->getNodeById($NODE, 'light') unless ref $NODE;

  $title ||= $$NODE{title};
  $title = "" if not defined($title);
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
      . ($exist_params ? $this->urlGen($PARAMS,0,$NODE) : $this->urlGenNoParams($NODE) )
      . $tags . ">$title</a>";
}


#############################################################################
sub linkNodeTitle {
  my ($this, $nodename, $lastnode, $escapeTags) = @_;
  my ($title, $linktitle, $linkAnchor, $href) = ('', '', '', '/');
  $nodename = "" if not defined($nodename);
  ($nodename, $title) = split /\s*[|\]]+/, $nodename;
  $title = "" if not defined($title);

  $nodename = "" if not defined($nodename);
  $title = $nodename if $title =~ m/^\s*$/;
  $nodename =~ s/\s+/ /gs;

  my $str = "";
  my ($tip, $isNode);

  #If we figure out a clever way to find the nodeshells, we should fix
  #this variable.
  $isNode = 1;

  #A direct link draws near! Command?
  $nodename = "" if not defined($nodename);
  if($nodename =~ /\[/){ # usually no anchor: check *if* before seeing *what* for performance
    my $anchor ;
    ($tip,$anchor) = split /\s*[[\]]/, $nodename;
    $title = $tip if $title eq $nodename ;

    $nodename = $tip;
    $tip =~ s/"/&quot;/g;
    $nodename = $this->rewriteCleanEscape($nodename);
    $anchor = $this->rewriteCleanEscape($anchor);

    if($escapeTags){
      $title =~ s/</\&lt\;/g;
      $title =~ s/>/\&gt\;/g;
      $tip =~ s/</\&lt\;/g;
      $tip =~ s/>/\&gt\;/g;
    }

    my ($nodetype,$user) = split /\bby\b/, $anchor;
    $nodetype ||= "";
    $user ||= "";
    $nodetype =~ s/^\s*|^\+|\s*$|\+$//g;
    $user =~ s/\+/ /g;
    $user =~ s/^\s*|^\+|\s*$|\+$//g;
    $linktitle = $tip;

    #Aha, trying to link to a discussion post
    if($nodetype =~ /^\d+$/){

      $href = "/node/debate/$nodename";
      $linkAnchor = "#debatecomment_$nodetype";

    } else {

      $nodetype = "node" unless $this->{db}->getType($nodetype);
      #Perhaps direct link to a writeup instead?
      if (grep {/^$nodetype$/ } ("","e2node","node","writeup","draft") ){

        #Anchors are case-sensitive, need to get the exact username.
        $user = $this->{db}->getNode($user,"user");
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
    $tip = "" unless defined($nodename);
    $tip =~ s/"/''/g;

    $linktitle = $tip;
    $href = "/title/" .$this->rewriteCleanEscape($nodename);
  }

  $title = "" if not defined($title);
  $this->{db}->getRef($lastnode);
  my $lastnodeQuery = "";
  $lastnodeQuery = "?lastnode_id=$$lastnode{node_id}" if $lastnode && UNIVERSAL::isa($lastnode,'HASH');
  $str .= "<a href=\"$href$lastnodeQuery$linkAnchor\" title=\"$linktitle\" "
          .( $isNode ? "class='populated'" : "class='unpopulated'")
         ." >$title</a>";

  return $str;
}

sub getELogName
{
  my ($this) = @_;
  my $basedir = $this->{conf}->logdirectory;
  my $thistime = [gmtime()];
  my $datestr = $thistime->[5]+1900;
  $datestr .= sprintf("%02d",$thistime->[4]+1);
  $datestr .= sprintf("%02d",$thistime->[3]);
  $datestr .= sprintf("%02d",$thistime->[2]);

  return "$basedir/e2app.$datestr.log";
}

#############################################################################
#	Sub
#		printLog
#
#	Purpose
#		Debugging utiltiy that will write the given string to the everything
#		log (aka "elog").  Each entry is prefixed with the time and date
#		to make for easy debugging.
#
#	Parameters
#		entry - the string to print to the log.  No ending carriage return
#			is needed.
#
sub printLog
{
  my ($this, $entry) = @_;

  return $this->genericLog($this->getELogName(), $entry);
}

sub devLog
{
  my ($this, $entry) = @_;

  if($this->inDevEnvironment)
  {
    my $callerinfo = [caller()];
    
    # Check to see if this is a convenience call to the delegation method in Everything::Globals
    if($callerinfo->[0] eq "Moose::Meta::Method::Delegation")
    {
      $callerinfo = [caller(2)];
    }

    return $this->genericLog("/tmp/development.log", join(":",$callerinfo->[0],$callerinfo->[2])." - ".$entry);
  }
  return;
}

sub genericLog
{
  my ($this, $log, $entry) = @_;
  my $time = $this->getTime();
  $entry = "" if not defined $entry;
        
  # prefix the date a time on the log entry.
  $entry = "$time: $entry\n";
 
  my $elog;
  if(open($elog, ">>",$log))
  { 
    print $elog $entry;
    close($elog);
  }else{
    die "Could not open log: '$log': '$!'";
  }

  return 1;
}

#############################################################################
#	Sub
#		getTime
#
#	Purpose
#		Quickie function to get a date and time string in a nice format.
#
sub getTime
{
  my $dt = DateTime->now();
  return $dt->strftime("%a %b %d %R%p");
}

sub commonLogLine
{
  my ($this, $line) = @_;
  chomp $line;
  my $cmd = $0;
  $cmd =~ s/.*\/(.*)/$1/g;
  return "[".localtime()."][$$][$cmd] $line\n";
}

#############################################################################
#	
sub getCallStack
{
  my ($this, $neglect) = @_;
  my @callStack = ();
  $neglect = 2 if not defined $neglect;

  my ($package, $file, $line, $subname, $hashargs);
  my $i = 0;

  while(($package, $file, $line, $subname, $hashargs) = caller($i++))
  {
    my $codeText = "";

    if ($subname eq "Everything::HTML::evalCode")
    {
      my @calledArgs = caller_args($i - 1);
      $codeText = ":" . $calledArgs[0] if (scalar @calledArgs);
    }

    # We unshift it so that we can use "pop" to get them in the
    # desired order.
    unshift @callStack, "$file:$line:$subname$codeText";
  }

  # Get rid of this function and other callers that are part of the reporting.
  # We don't need to see "getCallStack" in the stack.
  while ($neglect--) { pop @callStack; }

  return @callStack;
}

#############################################################################
#	Sub
#		dumpCallStack
#
#	Purpose
#		Debugging utility.  Calling this function will print the current
#		call stack to stdout.  Its useful to see where a function is
#		being called from.
#
sub dumpCallStack
{
  my ($this) = @_;
  my @callStack = ();
  my $func = undef;

  @callStack = $this->getCallStack();
	
  # Pop this function off the stack.  We don't need to see "dumpCallStack"
  # in the stack output.
  pop @callStack;
	
  print "*** Start Call Stack ***\n";
  while($func = pop @callStack)
  {
    print "$func\n";
  }

  print "*** End Call Stack ***\n";
  return;
}

sub pagetitle
{
  my ($this, $node) = @_;
  my $pagetitle = $node->{title};

  if($node->{type}->{title} eq "writeup")
  {
    my $author = $this->{db}->getNodeById($node->{author_user});
    if($author)
    {
      $pagetitle.=" by $$author{title}";
    }
  }
  return $pagetitle;
}

sub basehref
{
  my ($this) = @_;


  if ($ENV{HTTP_HOST} !~ /^m\.everything2/i)
  {
    # This only matters in the development environment
    my ($port) = $ENV{HTTP_HOST} =~ /(:\d+)$/;
    $port ||="";
    return ($this->is_tls()?('https'):('http')).'://'.$this->{conf}->canonical_web_server.$port;
  }
}

#############################################################################
sub parseLinks {
       my ($this, $text, $node, $escapeTags) = @_;

       #Pipelinked external links, if no anchor text in the pipelink,
       #fill the anchor text with the "[link]" text.

       return "" unless defined($text);

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
       $text =~ s!\[([^[\]]*(?:\[[^\]|]*[\]|][^[\]]*)?)]!$this->linkNodeTitle($1, $node,$escapeTags)!egs;
	   # [^\[\]]+ any text in square brackets
	   # ((?:\[[^\]|]* '[' then optionally: nodetype/author also in square brackets
	   # [\]|] tolerate forgetting either closing ']' or pipe
	   # [^[\]]*) then any more text in the brackets
       return $text;
}

sub getRandomNodesMany {
  my ($this, $count) = @_;

  $count = 1 if not defined($count);
  $count = int($count);
  $count = 20 if ($count > 20);

  my $csr = $this->{db}->sqlSelectMany("e2node_id", "e2node", "exists(select 1 from nodegroup where nodegroup_id=e2node_id) order by RAND() limit $count;");

  my $response = [];
  while(my $row = $csr->fetchrow_arrayref)
  {
    my $n = $this->{db}->getNodeById($row->[0]);
    push @$response, $n if defined($n);
  }
  return $response;
}

sub zen_wrap_nodelet {
  my ($this, $title, $nodelet_stuff) = @_;
  my $id = lc($title);
  $id =~ s/\W//g;

  # Handled by React
  if($nodelet_stuff eq "")
  {
    return qq|<div class='nodelet' id='$id'></div>|;
  }else{
    return qq|<div class='nodelet' id='$id'><h2 class="nodelet_title">$title</h2><div class='nodelet_content'>$nodelet_stuff</div></div>|;
  }
}

sub fetch_weblog {
  my ($this, $weblog, $number, $offset) = @_;

    $weblog = $this->{db}->getNodeById($weblog);
    return unless $weblog;

    $number ||= 5;
    $offset ||= 0;

    my $csr = $this->{db}->sqlSelectMany(
    'weblog_id, to_node, linkedby_user, linkedtime' ,
    'weblog' ,
    "weblog_id=$weblog->{node_id} AND removedby_user=0" ,
    "ORDER BY linkedtime DESC LIMIT $number OFFSET $offset" ) ;

    return $csr->fetchall_arrayref({});
}

sub add_notification {
  my ($this, $notification_id, $user_id, $args) = @_;

  # get notification id if we were passed a name:
  $notification_id = $this->{db}->getNode($notification_id, 'notification')->{node_id} if $notification_id =~ /\D/;

  $user_id ||= $notification_id;

  # turn args to string if we were passed a hashref:
  $args = to_json($args) if(UNIVERSAL::isa($args,'HASH'));

  $this->{db}->sqlInsert(
    'notified', {
      notification_id => $notification_id,
      user_id => $user_id,
      args => $args,
      -notified_time => 'now()'
    });

  return 1;
}

sub send_message {
  my ($this, $params) = @_;

  unless(UNIVERSAL::isa($params->{to},'HASH'))
  {
    $params->{to} = $this->{db}->getNodeById($params->{to});
  }

  if(not defined($params->{to}) or ($params->{to}->{type}->{title} ne "user"))
  {
    return {"errors" => 1, "errortext" => "Did not specify a valid user"};
  }

  unless(UNIVERSAL::isa($params->{from}, 'HASH'))
  {
    $params->{from} = $this->{db}->getNodeById($params->{from});
  }

  if(not defined($params->{from}) or ($params->{from}->{type}->{title} ne "user"))
  {
    return {"errors" => 1, "errortext" => "Did not specify a valid sending user"}; 
  }

  my $to = $this->node_by_id($params->{to}->{node_id});
  my $from = $this->node_by_id($params->{from}->{node_id});

  return $to->deliver_message({"from" => $from, "message" => $params->{message}});

}

sub getVars 
{
  my ($this, $N) = @_;
  $this->{db}->getRef($N);
  return if ($N == -1);
  return unless $N;
	
  unless (exists $N->{vars}) {
    $this->printLog("getVars: 'vars' field does not exist for node ".$this->{db}->getId($N)."perhaps it doesn't join on the settings table?\n");
  }

  my %vars = ();
  return {} unless ($N->{vars});

  %vars = $this->getVarHashFromStringFast($N->{vars});
  return \%vars;
}


# TODO: Process to autoclean messages from deleted users and groups

sub get_messages
{
  my ($this, $user, $limit, $offset) = @_;

  $this->{db}->getRef($user);
  return unless defined($user) and defined($user->{node_id});
  
  $limit = int($limit);
  $limit ||= 15;
  $limit = 15 if ($limit < 0);
  $limit = 100 if ($limit > 100);

  $offset = int($offset);
  $offset ||= 0;

  $this->devLog("Getting messages for $user->{title} with limit $limit and offset $offset");

  my $csr = $this->{db}->sqlSelectMany("*","message","for_user=$user->{node_id}", "ORDER BY tstamp DESC LIMIT $limit OFFSET $offset");
  my $records = [];
  while (my $row = $csr->fetchrow_hashref)
  {
    push @$records, $this->message_json_structure($row);
  }
  return $records;
}

sub get_message
{
  my ($this, $message_id) = @_;
  
  my $row = $this->{db}->sqlSelectHashref("*", "message", "message_id=".int($message_id));
  
  if($row->{message_id})
  {
    return $this->message_json_structure($row);
  }

  return;
}

sub message_json_structure
{
  my ($this, $message) = @_;

  my $for_usergroup = {};
  if($message->{for_usergroup})
  {
    $for_usergroup = $this->node_json_reference($message->{for_usergroup});
  }

  my $message_struct = {"message_id" => int($message->{message_id}), author_user => $this->node_json_reference($message->{author_user}), "msgtext" => $message->{msgtext}, for_user => $this->node_json_reference($message->{for_user}), "timestamp" => $this->iso_date_format($message->{tstamp}), "archive" => int($message->{archive})};

  if($message->{for_usergroup})
  {
    $message_struct->{for_usergroup} = $this->node_json_reference($message->{for_usergroup});
  }

  return $message_struct;
}

sub iso_date_format
{
  my ($this, $timestamp) = @_;
  
  return unless $timestamp;
  $timestamp =~ s/ /T/;
  $timestamp.="Z";
  return $timestamp;
}

sub node_json_reference
{
  my ($this, $node_id) = @_;

  my $node = $this->{db}->getNodeById($node_id);

  if($node)
  {
    return {"node_id" => int($node->{node_id}), "title" => $node->{title}, "type" => $node->{type}->{title}};
  }else{
    return {"node_id" => int(0), "title" => "(unknown)", "type" => "(unknown)"};
  }
}

sub can_see_message
{
  my ($this, $user, $message) = @_;

  $this->devLog("Got message: $message->{message_id}");

  if($message->{message_id} and $message->{for_user}->{node_id} == $user->{node_id})
  {
    $this->devLog("User $user->{node_id} can see message $message->{message_id}");
    return 1;
  }
  $this->devLog("User $user->{node_id} can NOT see message $message->{message_id}");
  return 0;
}

sub delete_message
{
  my ($this, $message) = @_;

  $this->devLog("Deleting message: $message->{message_id}");
  
  if($message->{message_id})
  {
    $this->{db}->sqlDelete("message","message_id=$message->{message_id}");
    return $message->{message_id};
  }

  return;
}

sub message_archive_set
{
  my ($this, $message, $value) = @_;

  $this->devLog("Archiving message bit set to $value: $message->{message_id}");

  $this->{db}->sqlUpdate("message",{"archive"=>$value},"message_id=$message->{message_id}");
  return $message->{message_id};
}

sub is_tls
{
  my ($this) = @_;
            
  if(defined $ENV{HTTP_X_FORWARDED_PROTO})
  {
    return ($ENV{HTTP_X_FORWARDED_PROTO} eq "https")?(1):(0); 
  }

  return $ENV{HTTPS};
}

sub get_bookmarks
{
  my ($this, $user) = @_;

  my $user_id = $user->{node_id};
  return [] unless $user_id;

  my $linktype=$this->{db}->getId($this->{db}->getNode('bookmark', 'linktype'));
  my $sqlstring = "from_node=$user_id and linktype=$linktype ORDER BY title";

  my $csr = $this->{db}->sqlSelectMany('to_node, title,
    UNIX_TIMESTAMP(createtime) AS tstamp',
    'links JOIN node ON to_node=node_id',
    $sqlstring);

  my $bookmarks;
  while(my $row = $csr->fetchrow_hashref)
  {
    push @$bookmarks, $this->node_json_reference($row->{to_node});
  }

  return $bookmarks;
}

sub delete_bookmark
{
  my ($this, $user, $link) = @_;

  my $user_id = $user->{node_id};
  my $linktype=$this->{db}->getId($this->{db}->getNode('bookmark', 'linktype'));

  return $this->{db}->sqlDelete('links',
    "from_node=$user_id 
    AND to_node=$$link{node_id}
    AND linktype=$linktype");
}

# These two are wrapper functions to get us to a state where eventually NodeBase will return an object. Once that is the case these
# can be made passthroughs
#
sub node_by_name
{
  my ($this, $title, $type) = @_;

  return unless defined($title) and defined($type);
  return unless $title ne "" and $type ne "";

  my $node = $this->{db}->getNode($title, $type);

  return unless $node;
  return $this->get_blessed_node($node);
}

sub node_by_id
{
  my ($this, $id) = @_;
  my $node = $this->{db}->getNodeById($id);

  return unless $node;
  return $this->get_blessed_node($node);
}

sub get_blessed_node
{
  my ($this, $node) = @_;

  if(my $class = $Everything::FACTORY->{node}->available($node->{type}->{title}))
  {
    return $class->new($node);
  }

  return;
}

sub node_new
{
  my ($this, $type) = @_;
  
  if(my $class = $Everything::FACTORY->{node}->available($type))
  {
    return $class->new({});
  }

  return;
}

# Used in [Recent Registry Entries] and registry_display_page
sub parseAsPlainText{
  my ($this, $text) = @_;
  $text = $this->parseLinks($this->breakTags($this->htmlScreen($text)));
  return $text;
}

# Used by debatecomment_atom_page
sub getCommentChildren
{
  my ($this, @gr) = @_;
  my @comments = ();
  foreach (@gr)
  {
    my $item = $_;
    my $child = $this->{db}->getNodeById($item);
    push (@comments, $item);
    my $group = $$child{'group'};
    my @children = $this->getCommentChildren(@$group);
    foreach (@children)
    {
      push (@comments, $_);
    }
  }
  return @comments;
}

sub plugin_table
{
  my ($this, $plugin_type) = @_;

  my $plugins = {};
  foreach my $plugin (@{$Everything::FACTORY->{lc($plugin_type)}->all})
  {
    $plugins->{$plugin} = $Everything::FACTORY->{lc($plugin_type)}->available($plugin)->new();
  }
  return $plugins;
}

sub newnodes
{
  my ($this, $count, $include_hidden) = @_;

  my $notnew = "";
  $notnew = "notnew=0" unless $include_hidden;
  my $csr = $this->{db}->sqlSelectMany("writeup_id","writeup",$notnew,"ORDER BY publishtime DESC LIMIT $count");

  my $nodes = [];
  while(my $row = $csr->fetchrow_arrayref)
  {
    my $id = $row->[0];
    push @$nodes, $this->node_by_id($id);
  }

  return $nodes;
}

sub can_action
{
  my ($this, $node, $action) = @_;

  my $disallowed = $this->{db}->getNodeParam($node, "disable_$action") || $this->{db}->getNodeParam($node->{type}, "disable_$action") || 0;
  my $overridden = $this->{db}->getNodeParam($node, "override_disable_$action") || 0;

  return 0 if $disallowed and not $overridden;
  return 1;
}

sub can_bookmark
{
  my ($this, $node) = @_;

  return $this->can_action($node, "bookmark");
}

sub can_edcool
{
  my ($this, $node) = @_;
  return $this->can_action($node, "cool");
}

sub can_category_add
{
  my ($this, $node) = @_;
  return $this->can_action($node, "category");
}

sub can_weblog
{
  my ($this, $node) = @_;
  return $this->can_action($node, "weblog");
}

# Originally in [Sign Up]
sub is_username_taken
{
  my ($this, $username) = @_;
  my $blocked_types = ['user', 'usergroup' , 'nodetype', 'fullpage', 'document', 'superdoc', 'superdocnolinks', 'restricted_superdoc'];

  foreach my $type (@$blocked_types)
  {
    my $x = $this->{db}->getNode($username, $type);
    return $x if $x;
  }

  return unless $username =~ /( |_)/;

  my $other = $1 eq ' ' ? '_' : ' ';
  $username =~ s/[ _]/$other/g;

  foreach my $type (@$blocked_types)
  {
    my $x = $this->{db}->getNode($username, $type);
    return $x if $x;
  }

  return;
}

# Originally in [Sign up]
sub is_ip_blacklisted
{
  my ($this, $ip) = @_;

  return $this->{db}->sqlSelect('ipblacklist_ipaddress', 'ipblacklist',
    "ipblacklist_ipaddress = " . $this->{db}->quote($ip) .
    " AND ipblacklist_timestamp > DATE_SUB(NOW(), INTERVAL " . $this->{conf}->blacklist_interval . ")");
}

# Originally in [Sign up]
sub is_email_in_locked_account
{
  my ($this, $email) = @_;
  my $user_id = $this->{db}->sqlSelect("user_id", "user", "email = " . $this->{db}->quote($email) . " AND acctlock != ''");
  return unless $user_id;
  return $this->{db}->getNodeById($user_id);
}

# Originally in [Sign up]
sub create_user
{
  my ($this, $username, $pass, $email) = @_;

  my ($pwhash, $salt) = $this->saltNewPassword($pass);

  my $user = { nick => $username, email => $email, salt => $salt };

  my $validForDays = 10;

  my $params = $this->getTokenLinkParameters($user, $pass, 'activate', time() + $validForDays * 86400);
  my $link = $this->urlGen($params, 'no quotes', $this->{db}->getNode('Confirm password', 'superdoc'));

  # save token & expiry time in case we want to resend link later, and don't let user log on yet
  $user->{passwd} = $$params{token}.'|'.$$params{expiry};

  # create user
  $user = $this->{db}->insertNode($username, 'user', -1, $user);

  return if not defined($user) or "$user" eq "0";


  $this->{db}->getRef($user);
  $user->{author_user} = $user->{node_id};

  ### Save a few initial settings
  my $uservars = $this->getVars($user);
  $$uservars{'showmessages_replylink'} = 1;
  $$uservars{ipaddy} = join ',', $this->getIp();
  $$uservars{preference_last_update_time} = 1;
  $$uservars{coolsafety} = 1;
  Everything::setVars($user, $uservars);

  $this->{db}->updateNode($user, -1);

  # log ip addresses
  foreach my $ip ($this->getIp())
  {
    $this->{db}->sqlInsert("iplog", {iplog_user => $$user{user_id}, iplog_ipaddy => $ip});
  }

  return $user;
}

sub set_spam_threshold
{
  my ($this, $user, $score) = @_;

  my $uservars = $this->getVars($user);
  $uservars->{recaptcha_score} = $score;
  Everything::setVars($user, $uservars);
  
  return $this->{db}->updateNode($user, -1);
}

sub previous_years_nodes
{
  my ($this, $yearsago, $startat) = @_;

  my $limit = 'type_nodetype='.$this->{db}->getId($this->{db}->getType('writeup'))." and createtime > (CURDATE() - INTERVAL $yearsago YEAR) and createtime < ((CURDATE() - INTERVAL $yearsago YEAR) + INTERVAL 1 DAY)";

  my $cnt = $this->{db}->sqlSelect('count(*)', 'node', $limit);
  my $csr = $this->{db}->sqlSelectMany('node_id', 'node', "$limit order by createtime  limit $startat,50");

  my $nodes = [];

  while(my $row = $csr->fetchrow_arrayref())
  {
    my $n = $this->node_by_id($row->[0]);
    next unless $n;

    push @$nodes, $this->node_by_id($row->[0]);
  }

  return {"count" => $cnt, "nodes" => $nodes};
}

sub sns_notify
{
  my ($this, $topicname, $subject, $message) = @_;

  my $sns = Paws->service('SNS', 'region' => $this->{conf}->current_region);

  my $matching_topic_arn;
  foreach my $topic(@{$sns->ListTopics->Topics})
  {
    if($topic->TopicArn =~ /$topicname$/)
    {
      $matching_topic_arn = $topic->TopicArn;
      last;
    }
  }
  return unless defined $matching_topic_arn;
  return $sns->Publish(Message => $message, Subject => $subject, TopicArn => $matching_topic_arn);
}

sub sitemap_batches
{
  my ($this) = @_;

  # All non-empty e2nodes, users who have logged in, and all writeups
  my $csr = $this->{db}->{dbh}->prepare("select node_id from (select e2node_id as node_id from (select e.e2node_id,count(*) as nodecnt from e2node e left join nodegroup n on e.e2node_id=n.nodegroup_id group by node_id) a where nodecnt > 0 UNION DISTINCT select w.writeup_id as node_id from writeup w UNION DISTINCT select u.user_id as node_id from user u where u.lasttime > 0) z order by node_id ASC");

  my $batches = [];
  my $batch;
  my $batch_size = 50000;

  $csr->execute;
  while(my $row = $csr->fetchrow_arrayref)
  {
    push @$batch, $row->[0];
    if(scalar(@$batch) == $batch_size)
    {
      push @$batches, $batch;
      $batch = [];
    }
  }

  return $batches;
}

sub sitemap_batch_xml
{
  my ($this, $batch) = @_;

  my $xg = XML::Generator->new(':pretty');
  my $sitemap_file = qq|<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">|;

  foreach my $node_id (@$batch)
  {
    my $N = $this->{db}->getNodeById($node_id);
    my $edittime;
    next unless defined $N->{type}{title};

    if($N->{type}{title} eq "writeup")
    {
      $edittime = $this->writeup_edittime($N);
    }elsif($N->{type}{title} eq "e2node"){
      my $edittimes = [];
      next unless defined $N->{group};
      next if scalar(@{$N->{group}}) == 0;
      foreach my $writeupnode(@{$N->{group}})
      {
        my $thisnode = $this->{db}->getNodeById($writeupnode);
        next unless $thisnode;
        push @$edittimes, $this->writeup_edittime($thisnode);
        undef $thisnode;
      }

      next unless $edittimes;

      $edittimes = [sort {$b cmp $a} @$edittimes];
      $edittime = $edittimes->[0];
      undef $edittimes;
    }elsif($N->{type}{title} eq "user"){
      $edittime = $N->{lasttime};
      if($edittime =~ /0000-00-00/)
      {
        # User never logged in
        next;
      }
    }

    next unless $edittime;
    # Drop time portion
    $edittime =~ s/ .*//g;
    $sitemap_file .= $xg->url(
      $xg->loc($this->{conf}->site_url.$this->urlGenNoParams( $N , 'noQuotes' )),
      defined($edittime)?($xg->lastmod($edittime)):(undef))."\n";
  }

  $sitemap_file .= "</urlset>";
  return $sitemap_file
}

sub sitemap_index
{
  my ($this, $indexes) = @_;

  my $xg = XML::Generator->new(':pretty');
  my $indexfile = qq|<?xml version="1.0" encoding="UTF-8"?>
<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">|;

  foreach my $index (1..$indexes)
  {
    my $thistime = [localtime()];
    my $thistimestring = ($thistime->[5]+1900)."-".sprintf('%02d',$thistime->[4]+1)."-".sprintf('%02d',$thistime->[3]);
    $indexfile.=$xg->sitemap($xg->loc($this->{conf}->site_url."/sitemap/".($index).".xml"), $xg->lastmod($thistimestring))."\n";
  }

  $indexfile .= "</sitemapindex>";

  return $indexfile;
}

sub writeup_edittime
{
  my ($this, $N) = @_;

  my $edittime = $N->{edittime};
  if($edittime =~ /0000-00-00/)
  {
    $edittime = $N->{createtime};
  }
  return $edittime;
}

sub global_warn_handler
{
  my ($this, $warning) = @_;
  $this->devLog("Sent warning: $warning");
  return $this->send_cloudwatch_event("warning", $warning || "");
}

sub global_die_handler
{
  my ($this, $error) = @_;
  $this->devLog("Sent error: $error");
  return $this->send_cloudwatch_event("error", $error || "");
}

sub send_cloudwatch_event
{
  my ($this, $eventtype, $eventdetail) = @_;

  if($this->{conf}->is_production)
  {
    my $events = Paws->service('CloudWatchEvents', "region" => $this->{conf}->current_region);
    my $detail = {"type" => $eventtype, "message" => $eventdetail, "callstack" => [$this->getCallStack]};
    if(defined($Everything::HTML::USER))
    {
      $detail->{user} = $Everything::HTML::USER->{title};
    }

    if(defined($Everything::HTML::REQUEST))
    {
      $detail->{url} = $Everything::HTML::REQUEST->url;
      $detail->{request_method} = $Everything::HTML::REQUEST->request_method;
      $detail->{params} = $Everything::HTML::REQUEST->truncated_params;
    }

    if(defined($Everything::HTML::NODE)){
      $detail->{node_id} = $Everything::HTML::NODE->{node_id};
      $detail->{title} = $Everything::HTML::NODE->{title};
    }

    my $eventbus = 'com.everything2.errors';
    $eventbus = 'com.everything2.uninitialized' if $detail->{message} =~ /^Use of uninitialized value/;

    my $resp = $events->PutEvents(Entries => [{
      EventBusName => $eventbus,
      Detail => JSON->new->utf8->encode($detail),
      Source => "e2.webapp",
      DetailType => 'E2 Application Error'
    }]);
    return $resp;
  }
  return;
}

sub chatterbox_cleanup
{
  my ($this) = @_;

  my $expireInSeconds = $this->{conf}->chatterbox_cleanup_threshold;

  my $messageSaveSQL = qq|
    INSERT INTO publicmessages
    (message_id, msgtext, tstamp, author_user)
    SELECT message_id, msgtext, tstamp, author_user
      FROM message
      WHERE TIMESTAMPADD(SECOND, -$expireInSeconds, NOW()) > tstamp
        AND for_user = 0
      ORDER BY tstamp ASC
    ON DUPLICATE KEY UPDATE
      publicmessages.tstamp = message.tstamp|;

  $this->{db}->{dbh}->do($messageSaveSQL);

  return $this->{db}->sqlDelete("message", "for_user=0 AND TIMESTAMPADD(SECOND, -$expireInSeconds, NOW()) > tstamp");

}

sub level_factor_recalculate
{
  my ($this) = @_;

  my $hrstats = $this->{db}->getNode("hrstats", "setting");
  my $hrv = Everything::getVars($hrstats);
  $$hrv{mean} =sprintf("%.4f", $this->{db}->sqlSelect("AVG(merit)", "user", "numwriteups>=25"));
  $$hrv{stddev} = sprintf("%.4f",$this->{db}->sqlSelect("STD(merit)","user", "numwriteups>=25"));
  Everything::setVars($hrstats, $hrv);
  return $this->{db}->updateNode($hrstats, -1);
}

sub global_iqm_recalculate
{
  my ($this) = @_;
  my $csr = $this->{db}->sqlSelectMany("node_id, reputation, author_user", "node", "type_nodetype=".$this->{db}->getId($this->{db}->getType('writeup')));
  my $root = $this->{db}->getNode("root","user");

  my $reps = undef;
  my $totalwus = $this->{db}->sqlSelect("count(*)", "node", "type_nodetype=".$this->{db}->getId($this->{db}->getType('writeup')));
  my $totalusrs = $this->{db}->sqlSelect("count(*)", "node", "type_nodetype=".$this->{db}->getId($this->{db}->getType('user')));

  while(my $row = $csr->fetchrow_hashref())
  {
    $$reps{$$row{author_user}}{$$row{reputation}} ||= 0;
    $$reps{$$row{author_user}}{$$row{reputation}}++;
  }

  foreach(keys %$reps)
  {
    my $uid = $this->{db}->getNodeById($_);
    next unless $uid;
    my $temp = $$reps{$$uid{user_id}};
    my %rephash = %$temp;
    my $count = 0;
    $count+= $rephash{$_} foreach(keys %rephash);

    my @replist = sort {$a <=> $b} keys(%rephash);

    my $reptally = 0;
    my $ncount = 0;
    my $cursor = 0;
    #  $skip is the number of nodes (may be fractional) in a quartile.
    my $skip = $count / 4;

    foreach (@replist) {
      if ($cursor >= $skip && $cursor + $rephash{$_} + $skip <= $count) {
        $reptally += $_ * $rephash{$_};
        $ncount += $rephash{$_};
        $cursor += $rephash{$_};
      } elsif ($cursor < $skip) {
        if ($cursor + $rephash{$_} < $skip) {
          $cursor += $rephash{$_};
        } else {
          $reptally += $_ * ($rephash{$_} - ($skip - $cursor));
          $ncount += $rephash{$_} - ($skip - $cursor);
          $cursor += $rephash{$_};
        }
      } elsif ($cursor + $skip < $count) {
        $reptally += $_ * ($count - ($cursor + $skip));
        $ncount += $count - ($cursor + $skip);
        $cursor += $rephash{$_};
      }
    }

    my $IQM = $reptally / $ncount;

    $this->{db}->sqlDelete("newstats", "newstats_id=$$uid{user_id}");
    $this->{db}->sqlInsert("newstats", {'newstats_id' => $$uid{user_id}, 'newstats_iqm' => $IQM});

    $$uid{merit} = $IQM;
    $this->{db}->updateNode($uid, -1);
  }

  return $this->level_factor_recalculate;
}

sub clean_old_rooms
{
  my ($this) = @_;

  my $csr = $this->{db}->sqlSelectMany("roomdata_id", "roomdata", "UNIX_TIMESTAMP(lastused_date) <= ".(time()-$this->{conf}->room_cleanup_threshold));
  my %exceptions = map { $this->{db}->getNode($_, "room")->{node_id} => 1} @{$this->{conf}->always_keep_rooms};

  while(my $row = $csr->fetchrow_hashref)
  {
    my $N = $this->{db}->getNodeById($row->{roomdata_id});
    next unless $N;
    next if $exceptions{$N->{node_id}};

    $this->{db}->nukeNode($N, -1);
  }

  return;
}

sub process_reaper_targets
{
  my ($this) = @_;

  my $ROW = $this->{db}->getNode('node row','superdoc');
  my $csr = $this->{db}->sqlSelectMany("*",'weblog', "weblog_id=".$this->{db}->getId($ROW)." and removedby_user=0");

  my $actions = [];

  while (my $LOG = $csr->fetchrow_hashref) {
    my $U = $this->{db}->getNode($$LOG{linkedby_user});
    my $N = $this->{db}->getNode($$LOG{to_node});
    next unless $N;
    $this->{db}->nukeNode($N, -1);
    $this->{db}->sqlUpdate("tomb", { killa_user => $$U{node_id} }, "node_id=$$N{node_id}");
    push(@$actions, {killer => $U->{node_id}, node => $N->{node_id}});
  }

  $this->{db}->sqlDelete("weblog", "weblog_id=".$this->{db}->getId($ROW)." and UNIX_TIMESTAMP(now())-UNIX_TIMESTAMP(linkedtime) > 24*360"); 
  return $actions;
}

sub obscure_writeups
{
  my ($this) = @_;

  my $definition = $this->{db}->getNode("definition","writeuptype");
  my $webby = $this->{db}->getNode("Webster 1913","user");
  my $csr = $this->{db}->sqlSelectMany("*", "node left join writeup on node_id=writeup_id","type_nodetype=".$this->{db}->getType("writeup")->{node_id}." and reputation=0 and author_user != $webby->{node_id} and wrtype_writeuptype != $definition->{node_id} order by rand() limit 5");

  my $nodes = [];
  while(my $row = $csr->fetchrow_hashref)
  {
    if(my $node = $this->node_by_id($row->{node_id}))
    {
      push @$nodes, $node
    }
  }

  return $nodes;
}

sub get_user_nodeshells
{
  my ($this, $for_user) = @_;

  my $csr = $this->{db}->sqlSelectMany('node_id, title,
    (select count(*) from nodegroup where nodegroup_id = e2node_id limit 1) AS groupcount'
    , 'e2node JOIN node ON e2node_id=node.node_id'
    , 'createdby_user='.$for_user->node_id
    , 'HAVING groupcount = 0',
      'ORDER BY node.title');

  my $nodeshells = [];
  while(my $row = $csr->fetchrow_hashref) {
    push @$nodeshells, $this->node_by_id($row->{node_id});
  }

  return $nodeshells;
}

sub get_user_style
{
  my ($this, $user) = @_;

  my $user_obj = Everything::Node::user->new($user);
  return $user_obj->style->id;
}

sub best_compression_type
{
  my ($this) = @_;

  foreach my $encoding ("br","deflate","gzip")
  {
    if($ENV{HTTP_ACCEPT_ENCODING} and $ENV{HTTP_ACCEPT_ENCODING} =~ /$encoding/)
    {
      return $encoding;
    }
  }

  return;
}

sub optimally_compress_page
{
  my ($this, $page) = @_;

  my $best_compression = $this->best_compression_type;

  $page = Encode::encode("utf8",$page);

  if(defined($best_compression))
  {
    if($best_compression eq "br")
    {
      $page = IO::Compress::Brotli::bro($page);
    }elsif($best_compression eq "deflate") {
      my $outpage = undef;
      $page = IO::Compress::Deflate::deflate(\$page => \$outpage);
      $page = $outpage;
    }elsif($best_compression eq "gzip"){
      $page = Compress::Zlib::memGzip($page);
    }
  }

  return $page;
}

sub asset_uri
{
  my ($this, $asset) = @_;

  if(my ($ext) = $asset =~ /\.(css|js|ico)$/)
  {
    if($Everything::CONF->use_local_assets)
    {
      if($asset =~ /react/)
      {
        return "/$asset";
      }else{
        return "/$ext/$asset";
      }
    }else{
      $asset =~ s/^\/?react\///;
    }
  }

  my $compression = $this->best_compression_type;

  if($compression)
  {
    return $Everything::CONF->assets_location."/$compression/$asset";
  }else{
    return $Everything::CONF->assets_location."/$asset";
  }
}

sub display_preferences
{
  my ($this, $vars) = @_;

  my $nodelet_sections = {"vit" => [qw(nodeinfo maintenance nodeutil list misc)],"edn" => [qw(edev util)]};

  my $prefs = {};
  foreach my $nodelet (keys %$nodelet_sections)
  {
    foreach my $var (@{$nodelet_sections->{$nodelet}})
    {
      my $prefname = $nodelet."_hide$var";
      $prefs->{$prefname} = $vars->{$nodelet."_hide$var"} || 0;
    }
  }

  $prefs->{num_newwus} = $vars->{num_newwus} || 20;
  $prefs->{nw_nojunk} = ($vars->{nw_nojunk})?(\1):(\0);

  return $prefs;
}

sub weblogs_structure
{
  my ($this, $weblogid) = @_;

  my $csr = $this->{db}->sqlSelectMany("*", "weblog","weblog_id=".int($weblogid)." and removedby_user=0 order by linkedtime DESC limit 10");
  my $structure = [];

  while(my $row = $csr->fetchrow_hashref)
  {
    my $linker_user = $this->{db}->getNode($row->{linkedby_user});
    my $linker_user_struct = {"node_id" => 0, "title" => "Deleted user", "type" => "deleteduser"};
    if($linker_user)
    {
      $linker_user_struct = {"node_id" => $linker_user->{node_id}, "title" => $linker_user->{title}, "type" => $linker_user->{type}->{title}};
    }

    my $weblogged_node = $this->{db}->getNode($row->{to_node});
    next unless $weblogged_node;

    push @$structure, {node_id => $row->{to_node}, linkedtime => $row->{linkedtime}, linkedby_user => $linker_user_struct, title => $weblogged_node->{title}, type => $weblogged_node->{type}->{title}};
  }

  return $structure;
}

sub filtered_newwriteups
{
  my ($this, $USER) = @_;

  my $limit = 40;

  my $iseditor = $this->isEditor($USER);
  my $isguest = $this->isGuest($USER);

  my $writeupsdata = $this->{db}->stashData("newwriteups");
  $writeupsdata = [] unless(defined($writeupsdata) and UNIVERSAL::isa($writeupsdata,"ARRAY"));

  my $filteredwriteups = [];
  my $count = 0;

  while($count < $limit and $count < scalar(@$writeupsdata))
  {
    my $wu = $writeupsdata->[$count];

    if($iseditor or (not $wu->{notnew} and not $wu->{is_junk}))
    {
      foreach my $key (qw(is_junk notnew is_log))
      {
        if($wu->{$key})
        {
          $wu->{$key} = \1;
        }else{
          $wu->{$key} = \0;
        }
      }

      if(not $isguest)
      {
        $wu->{hasvoted} = ($this->hasVoted($wu->{node_id},$USER))?(\1):(\0);
      }

      push(@$filteredwriteups, $wu);
    }

    $count++;
  }

  return $filteredwriteups;
}

sub updateNewWriteups
{
  my ($this) = @_;

  my $datastash = Everything::DataStash::newwriteups->new(APP => $this, CONF => $this->{conf}, DB => $this->{db});
  return $datastash->generate();
}

sub buildNodeInfoStructure
{
  my ($this, $NODE, $USER, $VARS, $query) = @_;

  my $e2 = {};
  $e2->{node_id} = $$NODE{node_id};
  $e2->{title} = $$NODE{title};
  $e2->{guest} = ($this->isGuest($USER))?(1):(0);

  $e2->{noquickvote} = 1 if($VARS->{noquickvote});
  $e2->{nonodeletcollapser} = 1 if($VARS->{nonodeletcollapser});
  $e2->{use_local_assets} = $this->{conf}->use_local_assets;

  if($e2->{use_local_assets} == 0)
  {
    $e2->{assets_location} = $this->{conf}->assets_location;
  }else{
    $e2->{assets_location} = "";
  }

  $e2->{display_prefs} = $this->display_preferences($VARS);

  $e2->{user} ||= {};
  $e2->{user}->{node_id} = $USER->{node_id};
  $e2->{user}->{title} = $USER->{title};
  $e2->{user}->{admin} = $this->isAdmin($USER)?(\1):(\0);
  $e2->{user}->{editor} = $this->isEditor($USER)?(\1):(\0);
  $e2->{user}->{developer} = $this->isDeveloper($USER)?(\1):(\1);
  $e2->{user}->{guest} = $this->isGuest($USER)?(\1):(\0);

  $e2->{node} ||= {};
  $e2->{node}->{title} = $NODE->{title};
  $e2->{node}->{type} = $NODE->{type}->{title};
  $e2->{node}->{node_id} = $NODE->{node_id};
  $e2->{node}->{createtime} = $this->convertDateToEpoch($NODE->{createtime});

  $e2->{lastCommit} = $this->{conf}->last_commit;
  $e2->{architecture} = $this->{conf}->architecture;

  $e2->{nodetype} = $NODE->{type}->{title};
  $e2->{developerNodelet} = {};

  $e2->{newWriteups} = [];

  my $nodelets = $VARS->{nodelets};
  $nodelets = "" unless defined($nodelets);

  # Cover for display on nodelet pages
  $nodelets .= ",$NODE->{node_id}";

  # New Writeups or New Logs
  if($this->isGuest($USER) or $nodelets =~ /263/ or $nodelets =~ /1923735/)
  {
    $e2->{newWriteups} = $this->filtered_newwriteups($USER)
  }

  # The second half of New Logs
  if($nodelets =~ /1923735/)
  {
    $e2->{daylogLinks} = $this->{db}->stashData("dayloglinks");
  }

  # Recommended Reading
  if($this->isGuest($USER) or $nodelets =~ /2027508/)
  {
    foreach my $section (qw/coolnodes staffpicks/)
    {
      my $section_data = $this->{db}->stashData($section);
      $section_data = [] unless(defined($section_data) and UNIVERSAL::isa($section_data,"ARRAY"));

      my $final_section_data = [];

      for my $i (0..scalar(@$section_data)-1)
      {
        if($section_data->[$i] =~ /^\d+$/)
        {
          my $n = $this->{db}->getNodeById($section_data->[$i]);
          if($n)
          {
            push @$final_section_data, {"node_id" => $n->{node_id}, "title" => $n->{title}, "type" => $n->{type}{title}};
          }
        }else{
          push @$final_section_data, $section_data->[$i];
        }
      }
      $e2->{$section} = $final_section_data;
    }
  }

  # Random Nodes
  if($nodelets =~ /457857/)
  {
    $e2->{randomNodes} = $this->{db}->stashData("randomnodes");
  }

  # Neglected Drafts
  if($nodelets =~ /2051342/)
  {
    $e2->{neglectedDrafts} = $this->{db}->stashData("neglecteddrafts");
  }

  # Quick Reference
  if($nodelets =~ /2146276/)
  {
    # What topic to link
    my $lookfor = $NODE->{title};
    if ($$NODE{type}{title} eq 'writeup') {
      # Instead of writeup title w/ type annotation, use the e2node title
      $lookfor = $this->{db}->getNodeById($NODE->{parent_e2node})->{title} ;
    }else{
       if (($NODE->{title} eq 'Findings:') || ($NODE->{title} eq 'Nothing Found')) {
       # Special case findings to look up what was searched
       $lookfor = $query->param('node');
     }
    }
    $e2->{quickRefSearchTerm} = $lookfor;
  }

  return $e2;
}

sub author_link
{
  my ($this, $authornode) = @_;

  return $this->linkNode($authornode, undef, {-class => 'author'});
}

sub title_link
{
  my ($this, $node) = @_;

  return $this->linkNode($node, undef, {-class => 'title'});
}

sub parenttitle_link
{
  my ($this, $node, $author) = @_;

    # Not getting a real node here, likely a hash of values
    my $parent = $this->{db}->getNodeById($node->{parent_e2node},'light'); 

    if(not defined($parent))
    {
      return qq|<span class="title noparent">(No parent node) |.$this->title_link($node).qq|</span>|;
    }

    return $this->linkNode($parent, undef, {-class => 'title', '#' => $author->{title}, author_id => $author->{node_id}});
}

sub writeuptype_link
{
  my ($this, $node) = @_;

  my $writeuptype = $this->{db}->getNodeById($node->{wrtype_writeuptype});
  my $writeuptypetitle = "broken type";

  if(defined($writeuptype))
  {
    $writeuptypetitle = $writeuptype->{title};
  }

  my $writeuplink = $this->linkNode($node, $writeuptypetitle);

  return qq|<span class="type">($writeuplink)</span>|;
}

sub cool_archive_row
{
  my ($this, $row, $oddrow) = @_;

  my $rowclass = "contentinfo";
  $rowclass .= " oddrow" if $oddrow;

  my $rownode = $this->{db}->getNodeById($row->{node_id});

  my $authornode = $this->{db}->getNodeById($row->{author_user});
  my $authorlink = $this->author_link($authornode);


  my $cooledby = $this->linkNode($row->{cooledby_user});
  my $parenttitle = $this->parenttitle_link($row, $authornode);
  my $wutypelink = $this->writeuptype_link($rownode);

  return qq|<tr class="$rowclass"><td>$parenttitle $wutypelink</td><td>$authorlink</td><td>$cooledby</td></tr>|;

}

# localTimeUse
sub timestamp_preferences
{
  my ($this, $vars, $other_prefs) = @_;
  
  my $translate = {
    "localTimeUse" => "use_local_time",
    "localTimeOffset" => "local_time_offset",
    "localTimeDST" => "local_time_dst",
    "localTime12hr" => "local_time_12hr"};
  
  my $flags = {};
  foreach my $pref (@$other_prefs)
  {
    $flags->{$pref} = 1;
  }

  foreach my $key (%$translate)
  {
    $flags->{$translate->{$key}} = $vars->{$key} if defined($vars->{$key});
  }

  return $flags;
}


#	 hide_time / 1 / hide time (only show the date)
#	 hide_date / 2 / hide date (only show the time)
#	 hide_day_of_week / 4 / hide day of week (only useful if showing date)
#	 show_utc / 8 / show 'UTC' (recommended to show only if also showing time)
#	 show_full_dayname / 16 / show full name of day of week (only useful if showing date)
#	 show_full_month / 32 / show full name of month (only useful if showing date)
#  ignore_local / 64 / ignores user's local time
#	 compact / 128 / compact (yyyy-mm-dd@hh:mm)
#	 hide_seconds / 256 / hide seconds
#	 leading_zeroes / 512 / zero on single-digit hours
#  use_local_time ($VARS->{localTimeUse})
#  local_time_offset ($VARS->{localTimeOffset})
#  local_time_dst ($VARS->{localTimeDST})
#  local_time_12hr ($VARS->{localTime12hr})

sub parse_timestamp
{
  my ($this, $timestamp, $flags) = @_;

  my ($date, $time, $yy, $mm, $dd, $hrs, $min, $sec) = (undef,undef,undef,undef,undef,undef,undef,undef);
 
  if($timestamp =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/)
  {
    ($yy, $mm, $dd, $hrs, $min, $sec) = ($1, $2, $3, $4, $5, $6);
    #let's hear it for fudge:
    $mm-=1;
  }elsif($timestamp =~ / /)
  {
    ($date, $time) = split / /,$timestamp;

    ($hrs, $min, $sec) = split /:/, $time;
    ($yy, $mm, $dd) = split /-/, $date;
    $mm-=1;
  }

  # I repeat: let's hear it for fudge!
  return "<em>never</em>" unless (int($yy)>0 and int($mm)>-1 and int($dd)>0);

  my $epoch_secs = timelocal( $sec, $min, $hrs, $dd, $mm, $yy);

  if(!($flags->{ignore_local}) && $flags->{use_local_time}) {
    $epoch_secs += $flags->{local_time_offset} if exists $flags->{local_time_offset};
    #add 1 hour = 60 min * 60 s/min = 3600 seconds if daylight savings
    $epoch_secs += 3600 if $flags->{local_time_dst};	#maybe later, only add time if also in the time period for that - but is it true that some places have different daylight savings time stuff?
  }

  my $wday = undef;
  ($sec, $min, $hrs, $dd, $mm, $yy, $wday, undef, undef) = localtime($epoch_secs);
  $yy += 1900;	#stupid Perl
  ++$mm;

  my $niceDate='';
  if(!($flags->{hide_date})) {	#show date
    if ($flags->{compact}) { # compact
      $mm = substr('0'.$mm,-2);
      $dd = substr('0'.$dd,-2);
      $niceDate .= $yy. '-' .$mm. '-' .$dd;
    } else {
      if(!($flags->{hide_day_of_week}))
      {	
        #4=hide week day, 0=show week day
        $niceDate .= ($flags->{show_day_of_week})	#16=full day name, 0=short name
          ? (qw(Sunday Monday Tuesday Wednesday Thursday Friday Saturday))[$wday].', '
          : (qw(Sun Mon Tue Wed Thu Fri Sat))[$wday].' ';
      }

      my $fullMonthName = $flags->{show_full_month};
      $niceDate .= ($fullMonthName
        ? (qw(January February March April May June July August September October November December))
        : (qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)))[$mm-1];

      $dd='0'.$dd if length($dd)==1 && !$fullMonthName;
      $niceDate .= ' ' . $dd;
      $niceDate .= ',' if $fullMonthName;
      $niceDate .= ' '.$yy;
    }
  }

  if(!($flags->{hide_time})) {	#show time
    if ($flags->{compact}) { # if compact
      $niceDate .= '@' if length($niceDate);
    } else {
      $niceDate .= ' at ' if length($niceDate);
    }

    my $showAMPM='';
    if($flags->{local_time_12hr}) {
      if($hrs<12) {
        $showAMPM = ' AM';
        $hrs=12 if $hrs==0;
      } else {
        $showAMPM = ' PM';
        $hrs -= 12 unless $hrs==12;
      }
    }

    $hrs = '0'.$hrs if $flags->{leading_zeroes} and length($hrs)==1;
    $min = '0'.$min if length($min)==1;
    $niceDate .= $hrs.':'.$min;
    if (!($flags->{compact} or $flags->{hide_seconds})) { # if no compact show seconds
      $sec = '0'.$sec if length($sec)==1;
      $niceDate .= ':'.$sec;
    }	

    $niceDate .= $showAMPM if length($showAMPM);
  }

  $niceDate .= ' UTC' if length($niceDate) && ($flags->{show_utc});	#show UTC

  return $niceDate;
}

sub writeups_by_type_row
{
  my ($this, $row, $VARS, $oddrow) = @_;

  my $rowclass = "contentrow";
  $rowclass .= " oddrow" if $oddrow;

  my $rownode = $this->{db}->getNodeById($row->{node_id});

  my $authornode = $this->{db}->getNodeById($rownode->{author_user});
  my $parenttitle = $this->parenttitle_link($rownode, $authornode);
  my $wutypelink = $this->writeuptype_link($rownode);
  my $authorlink = $this->author_link($authornode);
  my $timedisplay = $this->parse_timestamp($rownode->{publishtime}, 
    $this->timestamp_preferences($VARS, ['hide_day_of_week','leading_zeroes']));
  return qq|<tr class="$rowclass"><td>$parenttitle $wutypelink</td><td>$authorlink</td><td align="right"><small>$timedisplay</small></tr>|;
}

sub get_html_rules
{
  return {
    'abbr' => {
      'lang' => 1,
      'title' => 1,
      '*' => 0
    },
    'acronym' => {
      'lang' => 1,
      'title' => 1,
      '*' => 0
    },
    'blockquote' => {
      'cite' => 1,
      '*' => 0
    },
    'ol' => {
      'type' => 1,
      'start' => 1,
      '*' => 0
    },
    'p' => {
      'align' => 1,
      '*' => 0
    },
    'q' => {
      'cite' => 1,
      '*' => 0
    },
    'table' => {
      'cellpadding' => 1,
      'border' => 1,
      'cellspacing' => 1,
      'cols' => 1,
      'frame' => 1,
      'width' => 1,
      '*' => 0
    },
    'td' => {
      'rowspan' => 1,
      'colspan' => 1,
      'align' => 1,
      'valign' => 1,
      'height' => 1,
      'width' => 1,
      '*' => 0
    },
    'th' => {
      'rowspan' => 1,
      'colspan' => 1,
      'align' => 1,
      'valign' => 1,
      'height' => 1,
      'width' => 1,
      '*' => 0
    },
    'tr' => {
      'align' => 1,
      'valign' => 1,
      '*' => 0
    },
    'ul' => {
      'type' => 1,
      '*' => 0
    },
    'b' => {
      '*' => 0
    },
    'big' => {
      '*' => 0
    },
    'br' => {
      '*' => 0
    },
    'hr' => {
      'width' => 1,
      '*' => 0
    },
    'caption' => {
      '*' => 0
    },
    'center' => {
      '*' => 0
    },
    'cite' => {
      '*' => 0
    },
   'dd' => {
      '*' => 0
    },
    'del' => {
      '*' => 0
    },
    "dl" => {
      '*' => 0
    },
    "dt" => {
      '*' => 0
    },
    "em" => {
      '*' => 0
    },
    "i" => {
      '*' => 0
    },
    "ins" => {
      '*' => 0
    },
    "kbd" => {
      '*' => 0
    },
    "li" => {
      "*" => 0
    },
    "s" => {
      "*" => 0
    },
    "samp" => {
      "*" => 0
    },
    "pre" => {
      "*" => 0
    },
    "small" => {
      "*" => 0
    },
    "strike" => {
      "*" => 0
    },
    "strong" => {
      "*" => 0
    },
    "sub" => {
      "*" => 0
    },
    "sup" => {
      "*" => 0
    },
    "tbody" => {
      "*" => 0
    },
    "thead" => {
      "*" => 0
    },
    "tt" => {
      "*" => 0
    },
    "u" => {
      "*" => 0
    },
    "var" => {
      "*" => 0
    },
    "h1" => {
      "align" => 1,
      "*" => 0
    },
    "h2" => {
      "align" => 1,
      "*" => 0
    },
    "h3" => {
      "align" => 1,
      "*" => 0
    },
    "h4" => {
      "align" => 1,
      "*" => 0
    },
    "h5" => {
      "align" => 1,
      "*" => 0
    },
    "h6" => {
      "align" => 1,
      "*" => 0
    }
  };
}

sub fisher_yates_shuffle
{
  my ($this, $array) = @_;

    my $i;
    for ($i = @$array; --$i; ) {
        my $j = int rand ($i+1);
        next if $i == $j;
        @$array[$i,$j] = @$array[$j,$i];
    }
    return $array;
}


1;
