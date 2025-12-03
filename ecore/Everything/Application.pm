package Everything::Application;
use strict;
use warnings;

use Everything;
use Everything::S3;
use Everything::Delegation::room;

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
use IO::Compress::Zstd;
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
		'cancloak' =>
		{
			'on' => ['user'],
			'description' => 'Grants the user a courtesy chatterbox cloaking utility',
			'assignable' => ['admin'],
			'validate' => 'set_only',
		},

		# Tested in 000_test_cloaking.t
		'level_override' =>
		{
			'on' => ['user'],
			'description' => 'Hard sets a level on a user',
			'assignable' => ['admin'],
			'validate' => 'integer',
		},
		# TODO: Add test
		'hide_chatterbox_staff_symbol' =>
		{
			'on' => ['user'],
			'description' => q{Hides the '@' or '$' symbol in the Other Users nodelet},
			'assignable' => ['admin'],
			'validate' => 'set_only',
		},

		'prevent_nuke' =>
		{
			'description' => 'Prevent the node from being nuked, via the Nuke node key',
			'assignable' => ['admin'],
			'validate' => 'set_only',
		},

		#TODO: Add test
		'allow_message_archive' =>
		{
			'on' => ['usergroup'],
			'description' => 'On usergroups, allow the messages to be archived',
			'assignable' => ['admin'],
			'validate' => 'set_only',
		},

		#TODO: Add test
		'usergroup_owner' =>
		{
			'on' => ['usergroup'],
			'description' => 'On usergroups, set the owner',
			'assignable' => ['admin'],
			'validate' => 'integer',
		},

		'prevent_vote' =>
		{
			'on' => ['e2node', 'writeup'],
			'description' => 'On e2nodes, writeups contained therein are no longer votable. On writeups, that writeup is unvotable',
			'assignable' => ['admin'],
			'validate' => 'set_only',
		},

		'allow_book_parameters' =>
		{
			'on' => ['writeup'],
			'description' => 'Mark this writeup as being about a book, allowing other parameters',
			'assignable' => ['admin'],
			'validate' => 'set_only',
		},

		# TODO: Write a validator for book isbns
		'book_isbn' =>
		{
			'on' => ['writeup'],
			'description' => 'Mark this writeup as referring to a particular book isbn-10 or isbn-13',
			'assignable' => ['admin'],
			'validate' => 'isbn',
		},

		'book_edition' =>
		{
			'on' => ['writeup'],
			'description' => 'Mark this as being about a book of a particular edition',
			'assignable' => ['admin'],
		},

		'book_numpages' =>
		{
			'on' => ['writeup'],
			'description' => 'Mark this as being about a book with a particular number of pages',
			'assignable' => ['admin'],
			'validate' => 'integer',
		},

		'book_author' =>
		{
			'on' => ['writeup'],
			'description' => 'Mark this as being about a book with this author',
			'assignable' => ['admin'],
		},
		'supported_sheet' =>
		{
			'on' => ['stylesheet'],
			'description' => 'Supported for general use',
			'assignable' => ['admin'],
			'validate' => 'integer',
		},
		'depended_upon_sheet' =>
		{
			'on' => ['stylesheet'],
			'description' => 'Sheet is protected as it is required by a supported sheet',
			'assignable' => ['admin'],
			'validate' => 'integer',
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
    # Process E2 soft links: [target|display text] -> display text
    $writeuptext =~ s/\[[^\[\]\|]+\|([^\[\]]+)\]/$1/g;
    # Remove remaining simple links: [link] -> link
    $writeuptext =~ s/\[([^\[\]]+)\]/$1/g;
    # Strip HTML tags
    $writeuptext =~ s/\<.*?\>//g;
    # Collapse whitespace
    $writeuptext =~ s/\s+/ /g;
    $writeuptext = $this->encodeHTML($writeuptext);

    # Truncate to 155 characters at word boundary
    if (length($writeuptext) > 155) {
      $writeuptext = substr($writeuptext, 0, 155);
      # Truncate at last space to avoid cutting mid-word
      $writeuptext =~ s/\s+\S*$//;
      $writeuptext .= '...';
    }
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
  return 0 unless $usergroup;
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

	# Return empty hash if varString is undefined or empty
	return () unless defined($varString) && length($varString) > 0;

	my @parts = split(/[=&]/, $varString);

	# If odd number of elements (malformed string), discard the last orphan element
	# This handles cases like "key1=value1&key2" by keeping key1=value1 and discarding key2
	pop @parts if (@parts % 2 != 0);

	my %vars = @parts;
	foreach (keys %vars) {
		# Set undefined values to empty string (handles "&var=&var2=1" -> var='', var2='1')
		$vars{$_} = '' unless defined($vars{$_});
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

sub canEnterRoom {
  my ($this, $NODE, $USER, $VARS) = @_;

  # Admins can always enter any room (including locked rooms)
  return 1 if $this->isAdmin($USER);

  # Check if room is locked
  return 0 if $NODE->{roomlocked};

  my $room_node = undef;
  my $func_name = undef;

  $room_node = $NODE;

  # Convert room title to function name (same pattern as document.pm)
  $func_name = lc( $room_node->{title} );
  $func_name =~ s/[^a-z0-9]+/_/g;
  $func_name =~ s/^_+|_+$//g;    # Remove leading/trailing underscores

  # Check if delegation exists and call it
  if ( my $delegation = Everything::Delegation::room->can($func_name) )
  {
    return $delegation->( $USER, $VARS, $this );
  }

  # Default: allow entry for rooms without delegation
  return 1;
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

sub getRoomData {
  my ($this, $room_id) = @_;

  my $room_data = {};

  # Get room name
  if ($room_id == 0) {
    $room_data->{roomName} = 'outside';
  } else {
    my $room = $this->{db}->getNodeById($room_id);
    $room_data->{roomName} = $room->{title} if $room;
  }

  # Get room topic from Room Topics setting node
  my $settingsnode = $this->{db}->getNode('Room Topics', 'setting');
  if ($settingsnode) {
    my $topics = $this->getVars($settingsnode);
    if ($topics && defined $topics->{$room_id}) {
      $room_data->{roomTopic} = $topics->{$room_id};
    }
  }

  return $room_data;
}

sub logUserIp {
  my ($this, $user, $vars) = @_;
  return if $this->isGuest($user);

  my @addrs = $this->getIp();
  my $addr = join ',', @addrs;
  return unless $addr;

  return if (defined($vars->{ipaddy}) and $vars->{ipaddy} eq $addr);
  $vars->{ipaddy} = $addr;

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
    return 0;
  }

  unless($user->{acctlock} == 0)
  {
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

sub getNodeNotes
{
  my ($this, $node) = @_;
  my $DB = $this->{db};

  return [] unless $node;

  my $notelist = undef;
  my $node_type = $$node{type}{title};

  if ($node_type eq 'writeup')
  {
    # Include e2node & other writeups
    $notelist = $DB->sqlSelectMany(
      'nodenote.notetext, nodenote.nodenote_id, nodenote.nodenote_nodeid, nodenote.noter_user, nodenote.timestamp'
      , 'nodenote'
      , "(nodenote_nodeid = $$node{node_id}"
      . " OR nodenote_nodeid = $$node{parent_e2node})"
      . " ORDER BY nodenote_nodeid, timestamp");
  }
  elsif ($node_type eq 'e2node')
  {
    # Include writeups
    $notelist = $DB->sqlSelectMany(
      'nodenote.notetext, nodenote.nodenote_id, nodenote.nodenote_nodeid, nodenote.noter_user, nodenote.timestamp, node.author_user'
      , 'nodenote'
      . " LEFT OUTER JOIN writeup ON writeup.writeup_id = nodenote_nodeid"
      . " LEFT OUTER JOIN node ON node.node_id = writeup.writeup_id"
      , "(nodenote_nodeid = $$node{node_id}"
      . " OR writeup.parent_e2node = $$node{node_id})"
      . " ORDER BY nodenote_nodeid, timestamp");
  }
  else
  {
    $notelist = $DB->sqlSelectMany(
      'nodenote.notetext, nodenote.nodenote_id, nodenote.nodenote_nodeid, nodenote.noter_user, nodenote.timestamp'
      , 'nodenote'
      , "nodenote_nodeid = $$node{node_id}"
      . " ORDER BY timestamp");
  }

  my @notes = ();
  return \@notes unless $notelist;

  while (my $note = $notelist->fetchrow_hashref)
  {
    # Legacy format check: noter_user = 1 means author was encoded in notetext
    if ($note->{noter_user} && $note->{noter_user} == 1) {
      # Legacy format: author is embedded in notetext, mark as version 1
      $note->{legacy_format} = 1;
    } elsif ($note->{noter_user}) {
      # Modern format: look up noter username (0 = system note, no username)
      my $noter = $DB->getNodeById($note->{noter_user});
      $note->{noter_username} = $noter->{title} if $noter;
    }
    push @notes, $note;
  }

  return \@notes;
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
	my $class = $1 || '';

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

    if($callerinfo->[0] =~ /^Eval::Closure::Sandbox/)
    {
      $callerinfo = [caller(1)];
    }

    my $logfile = $ENV{E2_DEV_LOG} || "/tmp/development.log";
    return $this->genericLog($logfile, join(":",$callerinfo->[0],$callerinfo->[2])." - ".$entry);
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
    # We unshift it so that we can use "pop" to get them in the
    # desired order.
    unshift @callStack, "$file:$line:$subname";
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

# Check achievements by type for a user
# This is a port of htmlcode::achievementsByType to Application.pm
# so it can be called from API classes without symbol table pollution
sub checkAchievementsByType {
  my ($this, $aType, $user_id) = @_;
  return unless $aType;

  my $db = $this->{db};

  # Parse optional user_id from comma-separated aType (e.g., "miscellaneous,12345")
  if ($aType =~ /,/) {
    ($aType, $user_id) = split(/,/, $aType, 2);
  }

  my @achList = $db->getNodeWhere({achievement_type => $aType}, 'achievement', 'subtype, title ASC');
  return unless @achList;

  my $finishedgroup = '';

  foreach my $a (@achList) {
    # Skip achievements in groups we've already failed
    next if $a->{subtype} && $a->{subtype} eq $finishedgroup;

    my $result = $this->hasAchieved($a, $user_id);
    $finishedgroup = ($a->{subtype} || '') unless $result;
  }

  return;
}

# Check if user has achieved a specific achievement
# This is a port of htmlcode::hasAchieved to Application.pm
sub hasAchieved {
  my ($this, $ACH, $user_id, $force) = @_;

  my $db = $this->{db};

  # Get achievement node if passed as ID
  $db->getRef($ACH);
  return 0 unless $ACH;

  return 0 unless $user_id;
  my $target_user = $db->getNodeById($user_id);
  return 0 unless $target_user && $target_user->{type}{title} eq 'user';

  $force = undef unless (defined($force) && ($force == 1));

  # Check if already achieved
  return 1 if $db->sqlSelect('count(*)',
    'achieved',
    "achieved_user=$user_id AND achieved_achievement=$ACH->{node_id} LIMIT 1");

  return 0 unless $ACH->{achievement_still_available};

  # Check for delegation function
  my $achtitle = $ACH->{title};
  $achtitle =~ s/[\s-]/_/g;
  $achtitle =~ s/[^A-Za-z0-9_]/_/g;
  $achtitle = lc($achtitle);

  my $result;
  if (my $delegation = Everything::Delegation::achievement->can($achtitle)) {
    $result = $force || $delegation->($db, $this, $user_id);
  } else {
    # Achievement not migrated to delegation
    return 0;
  }

  if ($result == 1) {
    $db->sqlInsert("achieved", {
      achieved_user => $user_id,
      achieved_achievement => $ACH->{node_id}
    });

    # Add notification if user has subscribed
    my $target_VARS = $this->getVars($target_user);
    my $notification = $db->getNode("achievement", "notification");
    if ($notification && $target_VARS->{settings}) {
      my $settings = from_json($target_VARS->{settings});
      if ($settings && $settings->{notifications} && $settings->{notifications}{$notification->{node_id}}) {
        $this->add_notification($notification->{node_id}, $user_id, {achievement_id => $ACH->{node_id}});
      }
    }
  }

  return $result;
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
  my ($this, $user, $limit, $offset, $archive, $for_usergroup_id) = @_;

  $this->{db}->getRef($user);
  return unless defined($user) and defined($user->{node_id});

  $limit = int($limit);
  $limit ||= 15;
  $limit = 15 if ($limit < 0);
  $limit = 100 if ($limit > 100);

  $offset = int($offset // 0);
  $offset ||= 0;

  $archive = int($archive // 0);

  my $where = "for_user=$user->{node_id} AND archive=$archive";

  # Filter by usergroup if specified
  if (defined($for_usergroup_id) && $for_usergroup_id ne '') {
    $for_usergroup_id = int($for_usergroup_id);
    $where .= " AND for_usergroup=$for_usergroup_id";
  }

  my $csr = $this->{db}->sqlSelectMany("*","message", $where, "ORDER BY tstamp DESC LIMIT $limit OFFSET $offset");
  my $records = [];
  while (my $row = $csr->fetchrow_hashref)
  {
    push @$records, $this->message_json_structure($row);
  }
  return $records;
}

sub get_sent_messages
{
  my ($this, $user, $limit, $offset, $archive) = @_;

  $this->{db}->getRef($user);
  return unless defined($user) and defined($user->{node_id});

  $limit = int($limit);
  $limit ||= 15;
  $limit = 15 if ($limit < 0);
  $limit = 100 if ($limit > 100);

  $offset = int($offset // 0);
  $offset ||= 0;

  $archive = int($archive // 0);

  # Query message_outbox table (legacy behavior)
  # Outbox messages are stored separately from inbox messages
  my $where = "author_user=$user->{node_id} AND archive=$archive";
  my $csr = $this->{db}->sqlSelectMany("*","message_outbox", $where, "ORDER BY tstamp DESC LIMIT $limit OFFSET $offset");
  my $records = [];
  while (my $row = $csr->fetchrow_hashref)
  {
    # message_outbox doesn't have for_user or for_usergroup fields
    # Add them as 0 for compatibility with message_json_structure
    $row->{for_user} = 0;
    $row->{for_usergroup} = 0;
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

  if($message->{message_id} and $message->{for_user}->{node_id} == $user->{node_id})
  {
    return 1;
  }
  return 0;
}

sub delete_message
{
  my ($this, $message) = @_;

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

  $this->{db}->sqlUpdate("message",{"archive"=>$value},"message_id=$message->{message_id}");
  return $message->{message_id};
}

sub get_message_count
{
  my ($this, $user, $box_type, $archive, $for_usergroup_id) = @_;

  $this->{db}->getRef($user);
  return 0 unless defined($user) and defined($user->{node_id});

  $archive = int($archive // 0);

  my $where;
  if ($box_type eq 'outbox') {
    $where = "author_user=$user->{node_id} AND archive=$archive";
    return int($this->{db}->sqlSelect("count(*)", "message_outbox", $where) // 0);
  } else {
    # Default to inbox
    $where = "for_user=$user->{node_id} AND archive=$archive";

    # Filter by usergroup if specified
    if (defined($for_usergroup_id) && $for_usergroup_id ne '') {
      $for_usergroup_id = int($for_usergroup_id);
      $where .= " AND for_usergroup=$for_usergroup_id";
    }

    return int($this->{db}->sqlSelect("count(*)", "message", $where) // 0);
  }
}

sub sendPublicChatter
{
  my ($this, $user, $message, $vars) = @_;

  # Validate inputs
  return unless defined $user && defined $message && defined $vars;
  return unless $user->{user_id};

  # Check if user has public chatter disabled
  return if $vars->{publicchatteroff};

  # Truncate to 512 chars for public chatter
  $message = substr($message, 0, 512);

  # Check for duplicate message within time window
  my $messageInterval = 480;
  my $wherestr = "for_user=0 and tstamp >= date_sub(now(), interval $messageInterval second)";
  $wherestr .= ' and author_user='.$user->{user_id};

  my $lastmessage = $this->{db}->sqlSelect('trim(msgtext)', 'message', $wherestr." order by message_id desc limit 1");
  my $trimmedMessage = $message;
  $trimmedMessage =~ s/^\s+//;
  $trimmedMessage =~ s/\s+$//;
  if ($lastmessage eq $trimmedMessage)
  {
    return;
  }

  # Check if user is suspended from chat
  return if ($this->isSuspended($user,"chat"));

  # Check if user is infected (borged)
  return if (defined($vars->{infected}) and $vars->{infected} == 1);

  # Insert public chatter message
  $this->{db}->sqlInsert('message', {
    msgtext => $message,
    author_user => $user->{user_id},
    for_user => 0,
    room => $user->{in_room}
  });

  return 1;
}

sub processMessageCommand
{
  my ($this, $user, $message, $vars) = @_;

  # Validate inputs
  return unless defined $user && defined $message && defined $vars;
  return unless $user->{user_id};

  # Trim whitespace
  $message =~ s/^\s+|\s+$//g;
  return unless $message ne '';

  # Check if borged or suspended
  return if $vars->{borged};
  return if $this->isSuspended($user, 'chat');

  # Normalize command synonyms
  $message =~ s/^\/(small|aside|ooc|whispers?|monologue)\b/\/whisper/i;
  $message =~ s/^\/(aria|chant|song|rap|gregorianchant)\b/\/sing/i;
  $message =~ s/^\/(tomb|sepulchral|doom|reaper)\b/\/death/i;
  $message =~ s/^\/(conflagrate|immolate|singe|explode|limn)\b/\/fireball/i;
  $message =~ s/^\/my/\/me\'s/i;

  # /flip → /roll 1d2
  if ($message =~ /^\/(flip|coinflip)\s*$/i) {
    $message = "/rolls 1d2";
  }

  # Route commands
  my $result;

  if ($message =~ /^\/msg\s+(.+)/i || $message =~ /^\/tell\s+(.+)/i) {
    $result = $this->handlePrivateMessageCommand($user, $1, $vars);
  }
  elsif ($message =~ /^\/me\s+(.+)/i || $message =~ /^\/me\'s\s+(.+)/i) {
    $result = $this->handleMeCommand($user, $message, $vars);
  }
  elsif ($message =~ /^\/rolls?\s+(.*)$/i) {
    $result = $this->handleRollCommand($user, $1, $vars);
  }
  elsif ($message =~ /^\/fireball\s+(.+)/i) {
    $result = $this->handleFireballCommand($user, $1, $vars);
  }
  elsif ($message =~ /^\/sanctify\s+(.+)/i) {
    $result = $this->handleSanctifyCommand($user, $1, $vars);
  }
  elsif ($message =~ /^\/invite\s+(\S+)/i) {
    $result = $this->handleInviteCommand($user, $1, $vars);
  }
  elsif ($message =~ /^\/chatteroff/i) {
    $result = $this->handleChatterOffCommand($user, $vars);
  }
  elsif ($message =~ /^\/chatteron/i) {
    $result = $this->handleChatterOnCommand($user, $vars);
  }
  elsif ($message =~ /^\/borg\s+(\S+)/i) {
    $result = $this->handleBorgCommand($user, $message, $vars);
  }
  elsif ($message =~ /^\/help\s*(.*)$/i) {
    $result = $this->handleHelpCommand($user, $1, $vars);
  }
  elsif ($message =~ /^\/(whisper|sing|death|sings|me\'s)\s+/i) {
    # Commands that display in showchatter with special formatting
    $result = $this->sendPublicChatter($user, $message, $vars);
  }
  elsif ($message =~ /^\//) {
    # Unknown command - check easter eggs
    $result = $this->handleEasterEggCommand($user, $message, $vars);
  }
  else {
    # Plain chatter
    $result = $this->sendPublicChatter($user, $message, $vars);
  }

  # Handle responses from command handlers
  if (ref($result) eq 'HASH' && exists $result->{success}) {
    # Pass through structured responses (success, error, warning, etc.)
    return $result;
  }

  # Convert truthy/falsy to success response for legacy handlers
  return $result ? { success => 1 } : { success => 0, error => 'Message not posted' };
}

sub handleMeCommand
{
  my ($this, $user, $message, $vars) = @_;

  # /me action → plain action text
  # /me's action → same
  # Just send the command as-is, showchatter will parse it
  return $this->sendPublicChatter($user, $message, $vars);
}

sub handleRollCommand
{
  my ($this, $user, $roll_spec, $vars) = @_;

  my $result = $this->processDiceRoll($roll_spec);

  if ($result->{success}) {
    return $this->sendPublicChatter($user, $result->{message}, $vars);
  }

  # Error message
  my $error_msg = $result->{message} || "/rolls poorly, format: 3d6[+1]";
  return $this->sendPublicChatter($user, $error_msg, $vars);
}

sub handlePrivateMessageCommand
{
  my ($this, $user, $rest, $vars) = @_;

  # Parse: /msg user message or /msg {user1 user2} message
  # ONO (online-only) indicated by ? suffix: /msg? user message

  my $is_ono = 0;
  my @recipients;
  my $message_text;

  # Check for ONO marker in command or recipients
  if ($rest =~ /^\?\s*(.+)$/) {
    $is_ono = 1;
    $rest = $1;
  }

  # Parse recipients and message
  if ($rest =~ /^\{(.+?)\}\??\s+(.+)$/s) {
    # Multiple recipients: /msg {user1 user2} message
    @recipients = split(/\s+/, $1);
    $message_text = $2;
    $is_ono = 1 if $rest =~ /\}\?/;
  }
  elsif ($rest =~ /^(\S+)\??\s+(.+)$/s) {
    # Single recipient: /msg user message
    @recipients = ($1);
    $message_text = $2;
    $is_ono = 1 if $1 =~ /\?$/;
    $recipients[0] =~ s/\?$//;
  }
  else {
    # Invalid format
    return;
  }

  return unless $message_text && $message_text =~ /\S/;

  # Send via sendPrivateMessage
  my $result = $this->sendPrivateMessage(
    $user,
    \@recipients,
    $message_text,
    { online_only => $is_ono }
  );

  # Check if any users blocked the message
  if ($result->{errors} && @{$result->{errors}}) {
    # Check if message was sent to anyone (partial success for usergroup)
    if ($result->{sent_to} && @{$result->{sent_to}}) {
      # Partial success - some members blocked, but message delivered to others
      my $blocked_count = scalar @{$result->{errors}};
      my $warning_msg = $blocked_count == 1
        ? "Message sent, but 1 user is blocking you"
        : "Message sent, but $blocked_count users are blocking you";
      return { success => 1, warning => $warning_msg };
    } else {
      # Complete failure - all recipients blocked (direct message)
      my $error_msg = join(', ', @{$result->{errors}});
      return { success => 0, error => $error_msg };
    }
  }

  return $result->{success} ? { success => 1 } : { success => 0, error => 'Message not sent' };
}

sub handleHelpCommand
{
  my ($this, $user, $topic, $vars) = @_;

  # Load help topics setting node
  my $help_topics_node = $this->{db}->getNode('help topics', 'setting');
  unless ($help_topics_node) {
    return { success => 0, error => 'Help system unavailable' };
  }

  my $help_vars = $this->getVars($help_topics_node);
  unless ($help_vars) {
    return { success => 0, error => 'Help system unavailable' };
  }

  # Clean up topic (trim whitespace, convert spaces to underscores, lowercase)
  $topic =~ s/^\s+|\s+$//g;
  $topic =~ s/\s+/_/g;
  $topic = lc($topic);

  # If no topic specified, show general help
  $topic = 'help' unless $topic;

  # Look up topic
  my $help_text = $help_vars->{$topic};
  unless ($help_text) {
    return { success => 0, error => "Unknown help topic: $topic. Try /help for a list of topics." };
  }

  # Handle alias redirects (topics that start with "/help other_topic")
  if ($help_text =~ /^\/help\s+(.+)$/i) {
    # This is an alias, recursively look up the real topic
    my $redirect_topic = $1;
    return $this->handleHelpCommand($user, $redirect_topic, $vars);
  }

  # Decode HTML entities in help text
  # Help topics are stored with HTML entities like &lt; &gt; &amp;
  # We need to decode them so they display correctly in React
  use HTML::Entities;
  $help_text = decode_entities($help_text);

  # Send help message from Virgil
  my $virgil = $this->{db}->getNode('Virgil', 'user');
  unless ($virgil) {
    return { success => 0, error => 'Help system unavailable (Virgil not found)' };
  }

  # Send as private message from Virgil to the user
  my $result = $this->sendPrivateMessage($virgil, $user, $help_text);

  if ($result->{success}) {
    # Return success with flag to trigger immediate message poll
    return { success => 1, poll_messages => 1 };
  } else {
    return { success => 0, error => "Could not send help message: $result->{error}" };
  }
}

sub handleFireballCommand
{
  my ($this, $user, $target_name, $vars) = @_;

  my $minLvl = 15;
  my $is_admin = $this->isAdmin($user);
  my $user_level = $this->getLevel($user);

  # Check authorization
  unless ($user_level >= $minLvl || $is_admin) {
    return { success => 0, error => "You must be level $minLvl or higher to use /fireball" };
  }

  # Check easter eggs (admins bypass this check)
  unless ($is_admin || ($vars->{easter_eggs} && $vars->{easter_eggs} > 0)) {
    return { success => 0, error => "You need easter eggs to use /fireball" };
  }

  # Find recipient
  my $recipient = $this->{db}->getNode($target_name, 'user');
  unless ($recipient) {
    $target_name =~ s/_/ /g;
    $recipient = $this->{db}->getNode($target_name, 'user');
  }

  unless ($recipient) {
    return { success => 0, error => "User '$target_name' not found" };
  }

  # Can't fireball yourself
  if ($recipient->{user_id} == $user->{user_id}) {
    return { success => 0, error => "You cannot fireball yourself" };
  }

  # Consume egg and award GP (only consume egg if not admin)
  unless ($is_admin) {
    $vars->{easter_eggs}--;
    Everything::setVars($user, $vars);
  }
  $this->adjustGP($recipient, 5);

  # Send chatter message
  my $message = "/fireballs $target_name!";
  return $this->sendPublicChatter($user, $message, $vars);
}

sub handleSanctifyCommand
{
  my ($this, $user, $target_name, $vars) = @_;

  my $minLvl = 15;
  my $is_admin = $this->isAdmin($user);
  my $user_level = $this->getLevel($user);

  # Check authorization
  unless ($user_level >= $minLvl || $is_admin) {
    return { success => 0, error => "You must be level $minLvl or higher to use /sanctify" };
  }

  # Check easter eggs (admins bypass this check)
  unless ($is_admin || ($vars->{easter_eggs} && $vars->{easter_eggs} > 0)) {
    return { success => 0, error => "You need easter eggs to use /sanctify" };
  }

  # Find recipient
  my $recipient = $this->{db}->getNode($target_name, 'user');
  unless ($recipient) {
    $target_name =~ s/_/ /g;
    $recipient = $this->{db}->getNode($target_name, 'user');
  }

  unless ($recipient) {
    return { success => 0, error => "User '$target_name' not found" };
  }

  # Can't sanctify yourself
  if ($recipient->{user_id} == $user->{user_id}) {
    return { success => 0, error => "You cannot sanctify yourself" };
  }

  # Consume egg and award GP (only consume egg if not admin)
  unless ($is_admin) {
    $vars->{easter_eggs}--;
    Everything::setVars($user, $vars);
  }
  $this->adjustGP($recipient, 5);

  # Send chatter message
  my $message = "/sanctifies $target_name!";
  return $this->sendPublicChatter($user, $message, $vars);
}

sub handleInviteCommand
{
  my ($this, $user, $target_name, $vars) = @_;

  my $room_text;
  if ($user->{in_room}) {
    my $room = $this->{db}->getNodeById($user->{in_room});
    $room_text = $room ? $room->{title} : 'my room';
  } else {
    $room_text = 'outside';
  }

  # Convert to private message
  my $message = "come join me in [$room_text]";
  if ($user->{in_room}) {
    $message = "come join me in [$room_text]";
  } else {
    $message = "come join me outside";
  }

  return $this->sendPrivateMessage($user, $target_name, $message, {});
}

sub handleChatterOffCommand
{
  my ($this, $user, $vars) = @_;

  # Set publicchatteroff preference
  $vars->{publicchatteroff} = 1;
  Everything::setVars($user, $vars);

  return 1;
}

sub handleChatterOnCommand
{
  my ($this, $user, $vars) = @_;

  # Remove publicchatteroff preference
  delete $vars->{publicchatteroff};
  Everything::setVars($user, $vars);

  return 1;
}

sub handleBorgCommand
{
  my ($this, $user, $message, $vars) = @_;

  # Only chanops and admins can borg
  my $is_chanop = $this->isChanop($user, "nogods");
  my $is_admin = $this->isAdmin($user);

  unless ($is_chanop || $is_admin) {
    return { success => 0, error => "You must be a chanop or administrator to use /borg" };
  }

  # Parse: /borg username [reason]
  my ($target_name, $reason);
  if ($message =~ /^\/borg\s+(\S+)\s+(.+?)$/i) {
    $target_name = $1;
    $reason = $2;
  } elsif ($message =~ /^\/borg\s+(\S+)/i) {
    $target_name = $1;
  } else {
    return { success => 0, error => "Usage: /borg username [reason]" };
  }

  # Get target user (handle underscores)
  my $target = $this->{db}->getNode($target_name, 'user');
  $target_name =~ s/_/ /g;
  $target = $this->{db}->getNode($target_name, 'user') unless $target;

  # Get EDB (borgbot)
  my $borg = $this->{db}->getNode('EDB', 'user');

  unless ($target) {
    # Send error message via EDB (borgbot) for legacy compatibility
    $this->{db}->sqlInsert('message', {
      msgtext => "Can't borg 'em, $target_name doesn't exist on this system!",
      author_user => $borg->{node_id},
      for_user => $user->{user_id}
    });
    return { success => 0, error => "User '$target_name' not found" };
  }

  $target_name = $target->{title}; # Ensure proper case

  # Send message to target
  my $send_message = '[' . $user->{title} . '] instructed me to eat you';
  if ($reason) {
    $send_message .= ': ' . $reason;
  }

  $this->{db}->sqlInsert('message', {
    msgtext => $send_message,
    author_user => $borg->{node_id},
    for_user => $target->{node_id}
  });

  # Send confirmation to borger
  my $confirm_message = 'you instructed me to eat [' . $target_name . '] (' . $target->{node_id} . ')';
  if ($reason) {
    $confirm_message .= ': ' . $reason;
  }

  $this->{db}->sqlInsert('message', {
    msgtext => $confirm_message,
    author_user => $borg->{node_id},
    for_user => $user->{user_id}
  });

  # Set borged flag in target's vars
  my $target_vars = $this->getVars($target);
  $target_vars->{borged} = 1;
  Everything::setVars($target, $target_vars);

  # Public announcement
  my $announcement = '/me has swallowed [' . $target_name . ']. ';

  # Random borg message
  my @borg_bursts = (
    '*BURP*',
    'Mmmm...',
    '[' . $target_name . '] is good food!',
    '[' . $target_name . '] was tasty!',
    'keep \'em coming!',
    '[' . $target_name . '] yummy! More!',
    '[EDB] needed that!',
    '*GULP*',
    'moist noder flesh',
    '*B R A P *'
  );
  $announcement .= $borg_bursts[int(rand(@borg_bursts))];

  $this->{db}->sqlInsert('message', {
    msgtext => $announcement,
    author_user => $borg->{node_id},
    for_user => 0,
    room => $user->{in_room}
  });

  return 1;
}

sub handleEasterEggCommand
{
  my ($this, $user, $message, $vars) = @_;

  # Check if this is a valid easter egg command
  my $egg_commands = $this->{db}->getNode('egg commands', 'setting');
  return unless $egg_commands;

  my $egg_vars = $this->getVars($egg_commands);
  return unless $egg_vars;

  # Parse command: /command target
  if ($message =~ /^\/(\S+)\s+(.+?)\s*$/) {
    my $phrase = $1;
    my $target_name = $2;

    # Try without last character if not found (plurals)
    my $phrase_key = $phrase;
    $phrase_key = substr($phrase, 0, -1) unless $egg_vars->{$phrase};

    if ($egg_vars->{$phrase_key}) {
      # Valid easter egg command

      # Check easter eggs
      unless ($vars->{easter_eggs} && $vars->{easter_eggs} > 0) {
        return;
      }

      # Find recipient
      my $recipient = $this->{db}->getNode($target_name, 'user');
      unless ($recipient) {
        $target_name =~ s/_/ /g;
        $recipient = $this->{db}->getNode($target_name, 'user');
      }

      return unless $recipient;

      # Can't use on yourself
      return if $recipient->{user_id} == $user->{user_id};

      # Consume egg and award GP
      $vars->{easter_eggs}--;
      $this->adjustGP($recipient, 3);

      # Send chatter message
      my $msg = "/$phrase_key $target_name";
      return $this->sendPublicChatter($user, $msg, $vars);
    }
  }

  # Not a valid command - silently fail
  return;
}

sub getRecentChatter
{
  my ($this, $params) = @_;

  # Extract parameters with defaults
  my $limit = int($params->{limit} || 30);
  my $offset = int($params->{offset} || 0);
  my $room = int($params->{room} || 0);
  my $since = $params->{since}; # Optional timestamp for incremental updates
  my $user = $params->{user}; # Optional user for filtering blocked authors

  # Enforce limits
  $limit = 30 if ($limit < 1);
  $limit = 100 if ($limit > 100);
  $offset = 0 if ($offset < 0);

  # Build where clause
  my $where = "for_user=0";
  # Always filter by room (including room=0 for "outside")
  $where .= " and room=$room";

  # ALWAYS filter by time window (consistency between initial load and API refresh)
  # If 'since' parameter provided, use that; otherwise use configured time window
  if ($since) {
    # since should be ISO timestamp like "2025-11-24T12:00:00Z"
    $since =~ s/T/ /;
    $since =~ s/Z$//;
    $where .= " and tstamp > '$since'";
  } else {
    # Default: use configured chatter time window (default 5 minutes)
    my $window_minutes = $this->{conf}->chatter_time_window_minutes;
    my $time_ago = $this->{db}->sqlSelect("DATE_SUB(NOW(), INTERVAL $window_minutes MINUTE)");
    $where .= " and tstamp > '$time_ago'";
  }

  # Fetch recent chatter
  my $csr = $this->{db}->sqlSelectMany("*", "message", $where, "ORDER BY tstamp DESC LIMIT $limit OFFSET $offset");
  my $records = [];

  # Get list of users this user has blocked (if user provided)
  my %blocked_users = ();
  if ($user && $user->{user_id}) {
    my $block_csr = $this->{db}->sqlSelectMany(
      'ignore_node',
      'messageignore',
      'messageignore_id=' . int($user->{user_id})
    );
    while (my ($blocked_id) = $block_csr->fetchrow) {
      $blocked_users{$blocked_id} = 1;
    }
    $block_csr->finish;
  }

  while (my $row = $csr->fetchrow_hashref)
  {
    # Skip messages from blocked users
    next if $blocked_users{$row->{author_user}};

    push @$records, $this->message_json_structure($row);
  }

  return $records;
}

sub sendPrivateMessage
{
  my ($this, $author, $recipients, $message, $options) = @_;

  $options ||= {};

  # Validate inputs
  return {success => 0, error => 'No message provided'} unless defined $message && length($message);
  return {success => 0, error => 'No author provided'} unless defined $author && $author->{user_id};
  return {success => 0, error => 'No recipients provided'} unless defined $recipients;

  # Clean message whitespace
  $message = $this->messageCleanWhitespace($message);
  return {success => 0, error => 'Message only contains whitespace'} unless length($message);

  # Normalize recipients to array
  my @recipient_list = ();
  if (ref($recipients) eq 'ARRAY') {
    @recipient_list = @$recipients;
  } else {
    @recipient_list = ($recipients);
  }

  my @sent_to = ();
  my @errors = ();

  foreach my $recip (@recipient_list) {
    # Get recipient node if string provided
    my $recipient_node = $recip;
    if (!ref($recip)) {
      my $name = $recip;
      my $name_with_spaces = $name;
      $name_with_spaces =~ s/_/ /g;

      # Try lookups in order: user (original), user (with spaces), usergroup (original), usergroup (with spaces)
      $recipient_node = $this->{db}->getNode($name, 'user');
      $recipient_node = $this->{db}->getNode($name_with_spaces, 'user') unless $recipient_node;
      $recipient_node = $this->{db}->getNode($name, 'usergroup') unless $recipient_node;
      $recipient_node = $this->{db}->getNode($name_with_spaces, 'usergroup') unless $recipient_node;

      unless ($recipient_node) {
        push @errors, "Recipient not found: $recip";
        next;
      }
    }

    # Check message forwarding
    if ($recipient_node->{message_forward_to}) {
      $recipient_node = $this->{db}->getNodeById($recipient_node->{message_forward_to});
      unless ($recipient_node) {
        push @errors, "Forward target not found for $recip";
        next;
      }
    }

    # Handle usergroup messages
    if ($recipient_node->{type}{title} eq 'usergroup') {
      my $result = $this->sendUsergroupMessage($author, $recipient_node, $message, $options);
      if ($result->{success}) {
        push @sent_to, @{$result->{sent_to}};
        # Track users who blocked the sender within the usergroup
        if ($result->{blocked_by} && @{$result->{blocked_by}}) {
          foreach my $blocked_user (@{$result->{blocked_by}}) {
            push @errors, "$blocked_user is ignoring you";
          }
        }
      } else {
        push @errors, $result->{error};
      }
      next;
    }

    # Check if recipient is ignoring sender
    if ($this->userIgnoresMessagesFrom($recipient_node->{user_id}, $author->{user_id})) {
      push @errors, "$recipient_node->{title} is ignoring you";
      next;
    }

    # Check online-only restriction
    if ($options->{online_only}) {
      my $is_online = $this->{db}->sqlSelect('COUNT(*)', 'room', "member_user=$recipient_node->{user_id}");
      unless ($is_online) {
        # Check if they want offline ONO messages
        my $recip_vars = $this->getVars($recipient_node);
        unless ($recip_vars->{getofflinemsgs}) {
          next; # Skip this recipient
        }
      }
    }

    # Prepare message text
    my $msgtext = $message;
    if ($options->{online_only}) {
      $msgtext = "OnO: $msgtext";
    }
    if ($options->{about_node}) {
      $msgtext = "re [$options->{about_node}]: $msgtext";
    }

    # Insert inbox message (for recipient)
    $this->{db}->sqlInsert('message', {
      msgtext => $msgtext,
      author_user => $author->{user_id},
      for_user => $recipient_node->{user_id},
      for_usergroup => $options->{for_usergroup} || 0,
      archive => 0
    });

    # Insert outbox message (for sender) into message_outbox table
    # This matches the legacy behavior from Everything::Delegation::htmlcode
    $this->{db}->sqlInsert('message_outbox', {
      msgtext => $msgtext,
      author_user => $author->{user_id},
      archive => 0
    });

    push @sent_to, $recipient_node->{title};
  }

  if (@sent_to) {
    return {
      success => 1,
      sent_to => \@sent_to,
      errors => (@errors ? \@errors : undef)
    };
  } else {
    return {
      success => 0,
      error => 'No messages sent',
      errors => \@errors
    };
  }
}

sub sendUsergroupMessage
{
  my ($this, $author, $usergroup, $message, $options) = @_;

  $options ||= {};

  # Check if author is member of usergroup
  unless ($this->inUsergroup($author, $usergroup)) {
    return {success => 0, error => "You are not a member of $usergroup->{title}"};
  }

  # Get all members of usergroup
  my @members = @{$this->{db}->selectNodegroupFlat($usergroup)};

  # Get list of users ignoring this usergroup
  my $csr = $this->{db}->sqlSelectMany('messageignore_id', 'messageignore',
    'ignore_node='.$usergroup->{node_id});
  my %ignores = ();
  while (my ($ig) = $csr->fetchrow) {
    $ignores{$ig} = 1;
  }
  $csr->finish;

  # Filter out users who are ignoring the usergroup
  @members = grep { !exists($ignores{$_->{user_id}}) } @members;

  # Check for users who are ignoring the author individually (for usergroup messages)
  my @blocked_by_members = ();
  my @unblocked_members = ();
  foreach my $member (@members) {
    if ($this->userIgnoresMessagesFrom($member->{user_id}, $author->{user_id})) {
      push @blocked_by_members, $member;
    } else {
      push @unblocked_members, $member;
    }
  }
  @members = @unblocked_members;

  # Handle online-only restriction
  if ($options->{online_only}) {
    my %onlines = ();
    my $room_csr = $this->{db}->sqlSelectMany('member_user', 'room', '', '');
    while (my ($user_id) = $room_csr->fetchrow) {
      $onlines{$user_id} = 1;
    }
    $room_csr->finish;

    @members = grep {
      my $is_online = $onlines{$_->{user_id}};
      if (!$is_online) {
        my $vars = $this->getVars($_);
        $is_online = $vars->{getofflinemsgs};
      }
      $is_online;
    } @members;
  }

  # Prepare message text
  my $msgtext = $message;
  if ($options->{online_only}) {
    $msgtext = "OnO: $msgtext";
  }

  # Send to all members (deduplicate by user_id)
  my %sent = ();
  my @sent_to = ();
  foreach my $member (@members) {
    next if $sent{$member->{user_id}};

    $this->{db}->sqlInsert('message', {
      msgtext => $msgtext,
      author_user => $author->{user_id},
      for_user => $member->{user_id},
      for_usergroup => $usergroup->{node_id},
      archive => 0
    });

    $sent{$member->{user_id}} = 1;
    push @sent_to, $member->{title};
  }

  # Check if usergroup itself should get archive copy
  if ($this->getParameter($usergroup->{node_id}, 'allow_message_archive')) {
    $this->{db}->sqlInsert('message', {
      msgtext => $msgtext,
      author_user => $author->{user_id},
      for_user => $usergroup->{node_id},
      for_usergroup => $usergroup->{node_id},
      archive => 0
    });
  }

  # Insert outbox message (one entry for all recipients)
  # This matches the legacy behavior from Everything::Delegation::htmlcode
  if (@sent_to) {
    $this->{db}->sqlInsert('message_outbox', {
      msgtext => $msgtext,
      author_user => $author->{user_id},
      archive => 0
    });
  }

  return {
    success => 1,
    sent_to => \@sent_to,
    blocked_by => [map { $_->{title} } @blocked_by_members]
  };
}

sub processDiceRoll
{
  my ($this, $roll_string) = @_;

  return {success => 0, error => 'No dice roll specified'} unless defined $roll_string && length($roll_string);

  # Remove spaces from roll string
  $roll_string =~ s/\s//g;

  # Parse dice notation: XdY[+/-Z][keepN]
  # Examples: 3d6, 2d20+5, 4d6keep3, 1d100-10
  unless ($roll_string =~ m/((\d+)d(-?\d+)(([\+-])(\d+))?(keep(\d+))?)/i) {
    return {
      success => 0,
      error => 'Invalid format',
      message => '/rolls poorly, format: 3d6&#91;+1&#93;'
    };
  }

  my $dice_count = int($2);
  my $dice_sides = int($3);
  my $modifier_sign = $5;  # + or -
  my $modifier_value = $6;
  my $dice_kept = int($8 || 0);

  # Validate dice count
  if ($dice_count > 1000) {
    return {
      success => 0,
      error => 'Too many dice',
      message => '/rolls too many dice and makes a mess.'
    };
  }

  # Validate dice sides
  if ($dice_sides < 0) {
    return {
      success => 0,
      error => 'Negative dice sides',
      message => '/rolls anti-dice, keep them away from the normal dice please.'
    };
  }

  # If no "keep" specified or invalid keep value, keep all dice
  if ($dice_kept <= 0 || $dice_kept > $dice_count) {
    $dice_kept = $dice_count;
  }

  my @dice = ();
  my $total = 0;

  # Roll the dice (unless zero-sided dice)
  unless ($dice_sides == 0) {
    for (my $i = 0; $i < $dice_count; $i++) {
      push @dice, int(rand($dice_sides)) + 1;
    }

    # Sort dice in descending order (for "keep highest" mechanics)
    @dice = reverse sort { $a <=> $b } @dice;

    # Sum the kept dice
    for (my $i = 0; $i < $dice_kept; $i++) {
      $total += $dice[$i];
    }
  }

  # Apply modifier
  if (defined $modifier_sign && defined $modifier_value) {
    if ($modifier_sign eq '+') {
      $total += $modifier_value;
    } elsif ($modifier_sign eq '-') {
      $total -= $modifier_value;
    }
  }

  return {
    success => 1,
    roll_notation => $1,  # Original matched notation
    total => $total,
    dice => \@dice,
    message => "/rolls $1 &rarr; $total"
  };
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

  my $ROW = $this->{db}->getNode('node row','oppressor_superdoc');
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
    push @$nodeshells, {
      node_id => $row->{node_id},
      title => $row->{title}
    };
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

  foreach my $encoding ("zstd","br","deflate","gzip")
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
    if($best_compression eq "zstd")
    {
      my $outpage = undef;
      IO::Compress::Zstd::zstd(\$page => \$outpage);
      $page = $outpage;
    }elsif($best_compression eq "br")
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
  my ($this, $USER, $limit) = @_;

  $limit ||= 40;

  my $iseditor = $this->isEditor($USER);
  my $isguest = $this->isGuest($USER);

  # Get list of unfavorite user IDs for filtering (users whose writeups should be hidden)
  my %unfavorite_users;
  if(not $isguest)
  {
    my $VARS = Everything::getVars($USER);
    if($VARS->{unfavoriteusers})
    {
      my @unfavorites = split(/,/, $VARS->{unfavoriteusers});
      foreach my $uid (@unfavorites)
      {
        $uid =~ s/^\s+|\s+$//g; # trim whitespace
        $unfavorite_users{$uid} = 1 if $uid =~ /^\d+$/;
      }
    }
  }

  my $writeupsdata = $this->{db}->stashData("newwriteups");
  $writeupsdata = [] unless(defined($writeupsdata) and UNIVERSAL::isa($writeupsdata,"ARRAY"));

  my $filteredwriteups = [];
  my $count = 0;

  while($count < $limit and $count < scalar(@$writeupsdata))
  {
    my $wu = $writeupsdata->[$count];

    # Skip writeups from unfavorite users
    if(not $isguest and $wu->{author} and $unfavorite_users{$wu->{author}{node_id}})
    {
      $count++;
      next;
    }

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

=head2 buildOtherUsersData

Build the data structure for the Other Users nodelet / chatroom user list.
Returns a hashref with user list, room info, permissions, etc.

Parameters:
  $USER - The user node for whom to build the data

Returns:
  Hashref with structure:
    userCount, currentRoom, currentRoomId, rooms, availableRooms,
    canCloak, isCloaked, suspension, canCreateRoom, createRoomSuspended

=cut

sub buildOtherUsersData
{
  my ($this, $USER) = @_;

  my $current_room_id = $USER->{in_room} || 0;
  my $user_is_editor = $this->isEditor($USER);
  my $user_is_chanop = $this->isChanop($USER);
  my $uservars = $this->getVars($USER);
  my $infravision = $uservars->{infravision} || 0;

  # Random user actions (from original implementation)
  my @doVerbs = ('eating', 'watching', 'stalking', 'filing',
                'noding', 'amazed by', 'tired of', 'crying for',
                'thinking of', 'fighting', 'bouncing towards',
                'fleeing from', 'diving into', 'wishing for',
                'skating towards', 'playing with',
                'upvoting', 'learning of', 'teaching',
                'getting friendly with', 'frowned upon by',
                'sleeping on', 'getting hungry for', 'touching',
                'beating up', 'spying on', 'rubbing', 'caressing',
                '');  # Blank - sometimes omit verb entirely
  my @doNouns = ('a carrot', 'some money', 'EDB', 'nails', 'some feet',
                'a balloon', 'wheels', 'soy', 'a monkey', 'a smurf',
                'an onion', 'smoke', 'the birds', 'you!', 'a flashlight',
                'hash', 'your speaker', 'an idiot', 'an expert', 'an AI',
                'the human genome', 'upvotes', 'downvotes',
                'their pants', 'smelly cheese', 'a pink elephant',
                'teeth', 'a hippopotamus', 'noders', 'a scarf',
                'your ear', 'killer bees', 'an angst sandwich',
                'Butterfinger McFlurry');

  # Get ignore list for current user
  my $user_is_admin = $this->isAdmin($USER);
  my %ignoring = ();
  my $ignore_csr = $this->{db}->sqlSelectMany(
    'ignore_node',
    'messageignore',
    'messageignore_id=' . $USER->{node_id}
  );
  while(my ($ignore_id) = $ignore_csr->fetchrow_array()) {
    $ignoring{$ignore_id} = 1;
  }

  # Get all users - including current user for multi-room support
  my $wherestr = '1=1';  # Include all users

  # Editors/chanops/infravision can see invisible users
  unless($user_is_editor || $user_is_chanop || $infravision) {
    $wherestr .= ' AND r.visible=0';
  }

  my $csr = $this->{db}->sqlSelectMany(
    'r.member_user, r.room_id, r.visible, r.borgd, r.experience',
    'room r',
    $wherestr
  );

  my @noderlist = ();

  while(my $row = $csr->fetchrow_hashref()) {
    my $user = $this->{db}->getNodeById($row->{member_user});
    next unless $user;

    # Skip ignored users (unless admin)
    next if $ignoring{$user->{node_id}} && !$user_is_admin;

    my $other_uservars = $this->getVars($user);

    # Get last node info from user VARS
    my $jointime = $this->convertDateToEpoch($user->{createtime});
    my ($lastnode, $lastnodetime, $lastnodehidden);
    my $lastnodeid = $other_uservars->{lastnoded};

    if($lastnodeid) {
      $lastnode = $this->{db}->getNodeById($lastnodeid);
      if($lastnode) {
        $lastnodetime = $lastnode->{publishtime};
        $lastnodehidden = $lastnode->{notnew};
        # Nuked writeups can mess this up, so check there really is a lastnodetime
        $lastnodetime = $this->convertDateToEpoch($lastnodetime) if $lastnodetime;
      }
    }

    # Haven't been here for a month or haven't noded? Reset to 0
    if(time() - $jointime < 2592000 || !$lastnodetime) {
      $lastnodetime = 0;
    }

    # Active days from votesrefreshed VARS (votes refresh when user logs in)
    my $activeDays = $other_uservars->{votesrefreshed} || 0;

    push @noderlist, {
      user => $user,
      uservars => $other_uservars,
      roomId => $row->{room_id},
      visible => $row->{visible},
      borgd => $row->{borgd},
      experience => $row->{experience},
      lastNodeTime => $lastnodetime,
      lastNodeId => $lastnodeid,
      lastNode => $lastnode,
      lastNodeHidden => $lastnodehidden,
      activeDays => $activeDays
    };
  }

  # Sort by room (current room first), then by last node time, then by active days
  @noderlist = sort {
    ($b->{roomId} == $current_room_id) <=> ($a->{roomId} == $current_room_id)
    || $b->{roomId} <=> $a->{roomId}
    || $b->{lastNodeTime} <=> $a->{lastNodeTime}
    || $b->{activeDays} <=> $a->{activeDays}
  } @noderlist;

  # Build user display list
  my %room_users = ();
  my $userCount = 0;
  my $showActions = $uservars->{showuseractions} ? 1 : 0;

  foreach my $noder (@noderlist) {
    my $user = $noder->{user};
    my $other_uservars = $noder->{uservars};
    my $roomId = $noder->{roomId};

    # Skip current user if they're in a different room (prevents stale room table entries)
    if($user->{node_id} == $USER->{node_id} && $roomId != $current_room_id) {
      next;
    }

    # Check for Halloween costume
    my $displayUser = $user;
    my $costume_id = $other_uservars->{e2_hc_costume};
    if($costume_id && $this->inHalloweenPeriod()) {
      my $costume = $this->{db}->getNodeById($costume_id);
      $displayUser = $costume if $costume;
    }

    # Check if same user
    my $sameUser = ($user->{node_id} == $USER->{node_id});

    # Calculate account age
    my $jointime = $this->convertDateToEpoch($user->{createtime});
    my $accountage = time() - $jointime;
    my $getTime = int($accountage / (24*60*60));

    # Build flags array (structured data, not HTML)
    my @flags = ();

    # New user indicator (only visible to admins/editors)
    my $newbielook = $user_is_admin || $user_is_editor;
    if($newbielook && $getTime <= 30) {
      push @flags, {
        type => 'newuser',
        days => $getTime,
        veryNew => ($getTime <= 3) ? 1 : 0
      };
    }

    # Staff indicators (only if user is not hiding their own symbols)
    my $hideSymbols = $this->getParameter($user, 'hide_chatterbox_staff_symbol');
    if($this->isAdmin($user) && !$hideSymbols) {
      push @flags, { type => 'god' };
    }
    if($this->isEditor($user, 'nogods') && !$this->isAdmin($user) && !$hideSymbols) {
      push @flags, { type => 'editor' };
    }
    my $thisChanop = $this->isChanop($user, 'nogods');
    if($thisChanop) {
      push @flags, { type => 'chanop' };
    }

    # Borged indicator (for editors/chanops)
    if(($user_is_editor || $user_is_chanop) && $noder->{borgd}) {
      push @flags, { type => 'borged' };
    }

    # Invisibility indicator (for editors/chanops/infravision)
    if(($user_is_editor || $user_is_chanop || $infravision) && $noder->{visible} == 1) {
      push @flags, { type => 'invisible' };
    }

    # Room indicator - show if user is in different room and viewer is Outside
    if($roomId != 0 && $current_room_id == 0) {
      my $rm = $this->{db}->getNodeById($roomId);
      if($rm) {
        push @flags, {
          type => 'room',
          roomId => $roomId,
          roomTitle => $rm->{title}
        };
      }
    }

    # User action or recent noding
    my $action = undef;

    # Add user actions (2% chance, not for same user)
    if($showActions && !$sameUser && (0.02 > rand())) {
      $action = {
        type => 'action',
        verb => $doVerbs[int(rand(@doVerbs))],
        noun => $doNouns[int(rand(@doNouns))]
      };
    }

    # Add recent noding link (2% chance, replaces action if triggered)
    # Check: noded in last week AND writeup not hidden
    if($showActions && (0.02 > rand())) {
      if((time() - $noder->{lastNodeTime}) < 604800 && !$noder->{lastNodeHidden}) {
        if($noder->{lastNode}) {
          my $lastnodeparent = $this->{db}->getNodeById($noder->{lastNode}->{parent_e2node});
          $action = {
            type => 'recent',
            nodeId => $noder->{lastNode}->{node_id},
            nodeTitle => $noder->{lastNode}->{title},
            parentTitle => $lastnodeparent ? $lastnodeparent->{title} : ''
          };
        }
      }
    }

    # Build structured user data
    my $userData = {
      userId => $user->{node_id},
      username => $user->{title},
      displayName => $displayUser->{title},
      isCurrentUser => $sameUser ? 1 : 0,
      flags => \@flags
    };
    $userData->{action} = $action if $action;

    # Add to room's user list
    push @{$room_users{$roomId}}, $userData;
    $userCount++;
  }

  # Build rooms array with headers
  my @rooms = ();
  foreach my $roomId (sort { ($b == $current_room_id) <=> ($a == $current_room_id) || $b <=> $a } keys %room_users) {
    my $roomTitle = '';

    # Only show room header if not current room or if multiple rooms
    if(scalar(keys %room_users) > 1) {
      if($roomId == 0) {
        $roomTitle = 'Outside';
      } else {
        my $room = $this->{db}->getNodeById($roomId);
        $roomTitle = ($room && $room->{type}{title} eq 'room') ? $room->{title} : 'Unknown Room';
      }
    }

    push @rooms, {
      title => $roomTitle,
      users => $room_users{$roomId}
    };
  }

  # Get current room name
  my $room_node = $this->{db}->getNodeById($current_room_id);
  my $currentRoom = $room_node ? $room_node->{title} : '';

  # Get available rooms for dropdown
  my @available_rooms = ();

  # First, get system rooms from 'e2 rooms' nodegroup
  my $rooms_group = $this->{db}->getNode('e2 rooms', 'nodegroup');
  if ($rooms_group && $rooms_group->{group}) {
    foreach my $room_id (@{$rooms_group->{group}}) {
      my $room = $this->{db}->getNodeById($room_id);
      next unless $room;
      next unless $this->canEnterRoom($room, $USER, $uservars);

      push @available_rooms, {
        room_id => int($room->{node_id}),
        title => $room->{title}
      };
    }
  }

  # Second, get user-created rooms from roomdata table
  my $room_csr = $this->{db}->sqlSelectMany('roomdata_id', 'roomdata', '', 'roomdata_id');
  if ($room_csr) {
    while (my ($room_id) = $room_csr->fetchrow_array()) {
      my $room = $this->{db}->getNodeById($room_id);
      next unless $room;
      next unless $room->{type}{title} eq 'room';
      next unless $this->canEnterRoom($room, $USER, $uservars);

      # Check if already added from nodegroup (avoid duplicates)
      next if grep { $_->{room_id} == $room_id } @available_rooms;

      push @available_rooms, {
        room_id => int($room->{node_id}),
        title => $room->{title}
      };
    }
    $room_csr->finish();
  }

  # Add "outside" option
  push @available_rooms, {
    room_id => 0,
    title => 'outside'
  };

  # Check cloak permissions
  my $can_cloak = $this->userCanCloak($USER) ? 1 : 0;
  my $is_cloaked = $uservars->{visible} ? 1 : 0;

  # Check room change suspension
  my $suspension_info = $this->isSuspended($USER, 'changeroom');
  my $suspension = undef;
  if ($suspension_info) {
    if (defined($suspension_info->{ends}) && $suspension_info->{ends} != 0) {
      my $seconds_remaining = $this->convertDateToEpoch($suspension_info->{ends}) - time();
      $suspension = {
        type => 'temporary',
        seconds_remaining => int($seconds_remaining)
      };
    } else {
      $suspension = {
        type => 'indefinite'
      };
    }
  }

  # Check room creation permissions
  my $is_chanop = $this->isChanop($USER);
  my $user_level = $this->getLevel($USER);
  my $required_level = $Everything::CONF->create_room_level || 0;
  my $can_create_room = ($user_level >= $required_level || $this->isAdmin($USER) || $is_chanop) ? 1 : 0;
  my $create_room_suspended = $this->isSuspended($USER, 'room') ? 1 : 0;

  return {
    userCount => $userCount,
    currentRoom => $currentRoom,
    currentRoomId => int($current_room_id),
    rooms => \@rooms,
    availableRooms => \@available_rooms,
    canCloak => $can_cloak,
    isCloaked => $is_cloaked,
    suspension => $suspension,
    canCreateRoom => $can_create_room,
    createRoomSuspended => $create_room_suspended
  };
}

sub buildNodeInfoStructure
{
  my ($this, $NODE, $USER, $VARS, $query, $REQUEST) = @_;

  # Convert USER hashref to blessed object for use throughout this function
  my $user_node = $this->node_by_id($USER->{node_id});

  my $e2 = {};
  $e2->{node_id} = $$NODE{node_id};
  $e2->{title} = $$NODE{title};
  $e2->{guest} = ($this->isGuest($USER))?(1):(0);

  # Derive messages nodelet presence from user's nodelet configuration
  # Messages nodelet node_id is 2044453
  $e2->{hasMessagesNodelet} = (($VARS->{nodelets} || '') =~ /2044453/) ? 1 : 0;

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
  $e2->{user}->{chanop} = $this->isChanop($USER)?(\1):(\0);
  $e2->{user}->{developer} = $this->isDeveloper($USER)?(\1):(\1);
  $e2->{user}->{guest} = $this->isGuest($USER)?(\1):(\0);
  $e2->{user}->{in_room} = $USER->{in_room};

  # Core user properties (always available, not nodelet-specific)
  unless($this->isGuest($USER)) {
    $e2->{user}->{gp} = $USER->{GP} || 0;
    $e2->{user}->{gpOptOut} = $VARS->{GPoptout} ? \1 : \0;
    $e2->{user}->{experience} = $USER->{experience} || 0;
    $e2->{user}->{level} = $this->getLevel($USER);
  }

  # Chatterbox data - room topic and initial messages for current room
  $e2->{chatterbox} ||= {};
  if (defined $USER->{in_room}) {
    # Get room name
    if ($USER->{in_room} == 0) {
      $e2->{chatterbox}->{roomName} = 'outside';
    } else {
      my $room = $this->{db}->getNodeById($USER->{in_room});
      $e2->{chatterbox}->{roomName} = $room->{title} if $room;
    }

    # Get room topic
    my $settingsnode = $this->{db}->getNode('Room Topics', 'setting');
    if ($settingsnode) {
      my $topics = $this->getVars($settingsnode);
      if ($topics && defined $topics->{$USER->{in_room}}) {
        $e2->{chatterbox}->{roomTopic} = $topics->{$USER->{in_room}};
      }
    }

    # Get initial chatter messages for the room (prevents redundant API call on page load)
    # Use configured time window (default 5 minutes)
    my $window_minutes = $this->{conf}->chatter_time_window_minutes;
    my $time_ago = $this->{db}->sqlSelect("DATE_SUB(NOW(), INTERVAL $window_minutes MINUTE)");
    my $initialChatter = $this->getRecentChatter({
      room => $USER->{in_room},
      limit => 30,
      since => $time_ago,
      user => $USER
    });
    $e2->{chatterbox}->{messages} = $initialChatter || [];

    # If Messages nodelet is not in sidebar, show mini-messages in Chatterbox
    # Check if hasMessagesNodelet flag was set by Controller
    if (!$e2->{hasMessagesNodelet}) {
      $e2->{chatterbox}->{showMessagesInChatterbox} = 1;

      # Load last 5 private messages for mini-messages display
      my $mini_messages = $this->get_messages($USER, 5, 0); # limit 5, archive 0 (pass hashref not blessed)
      $e2->{chatterbox}->{miniMessages} = $mini_messages || [];
    } else {
      $e2->{chatterbox}->{showMessagesInChatterbox} = 0;
    }
  }

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

  # Recommended Reading or ReadThis
  if($this->isGuest($USER) or $nodelets =~ /2027508/ or $nodelets =~ /1157024/)
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

  # ReadThis news section - uses frontpagenews datastash (weblog entries from "News" usergroup)
  if($nodelets =~ /1157024/)
  {
    my $fpnews = $this->{db}->stashData("frontpagenews");
    $fpnews = [] unless(defined($fpnews) and UNIVERSAL::isa($fpnews,"ARRAY"));

    my $final_news = [];
    foreach my $entry (@$fpnews)
    {
      my $n = $this->{db}->getNodeById($entry->{to_node});
      # Skip removed nodes and drafts (same logic as htmlcode show_content_frontpage)
      if($n && $n->{type}{title} ne 'draft')
      {
        push @$final_news, {"node_id" => $n->{node_id}, "title" => $n->{title}};
      }
    }
    $e2->{news} = $final_news;
  }

  # Epicenter nodelet
  # Note: user fields (gp, experience, level, gpOptOut, node_id, title, guest)
  # are available globally on e2.user - no need to duplicate here
  if($nodelets =~ /262/ and not $this->isGuest($USER))
  {
    $e2->{epicenter} = {};
    $e2->{epicenter}->{votesLeft} = $USER->{votesleft} || 0;
    $e2->{epicenter}->{cools} = $VARS->{cools} || 0;
    $e2->{epicenter}->{localTimeUse} = $VARS->{localTimeUse} ? \1 : \0;
    $e2->{epicenter}->{userSettingsId} = $this->{conf}->user_settings;

    # Determine help page based on level (use global e2.user.level)
    $e2->{epicenter}->{helpPage} = ($e2->{user}->{level} < 2) ? 'E2 Quick Start' : 'Everything2 Help';

    # Borgcheck data (React component will handle rendering)
    if($VARS->{borged}) {
      $e2->{epicenter}->{borgcheck} = {
        borged => $VARS->{borged},
        numborged => $VARS->{numborged} || 1,
        currentTime => time
      };
    }

    # Experience change data (React component will handle rendering)
    # Initialize oldexp on first visit (use defined() and numeric check)
    # Reset if oldexp is non-numeric (handles garbage data from legacy code)
    $VARS->{oldexp} = $USER->{experience} unless (defined $VARS->{oldexp} && $VARS->{oldexp} =~ /^\d+$/);
    my $expChange = $USER->{experience} - $VARS->{oldexp};
    if($expChange > 0) {
      $e2->{epicenter}->{experienceGain} = $expChange;
    }
    # Always update oldexp to current experience (not just on positive gains)
    # This ensures oldexp stays in sync even when XP is reset/decreased
    $VARS->{oldexp} = $USER->{experience};

    # GP change data (React component will handle rendering)
    unless($VARS->{GPoptout}) {
      # Initialize oldGP on first visit (use defined() and numeric check)
      # Reset if oldGP is non-numeric (handles garbage data from legacy code)
      $VARS->{oldGP} = $USER->{GP} unless (defined $VARS->{oldGP} && $VARS->{oldGP} =~ /^\d+$/);
      my $gpChange = $USER->{GP} - $VARS->{oldGP};

      if($gpChange > 0) {
        $e2->{epicenter}->{gpGain} = $gpChange;
      }

      # Always update oldGP to current GP (not just on positive gains)
      # This ensures oldGP stays in sync even when GP is reset/decreased
      $VARS->{oldGP} = $USER->{GP};
    }

    # Random node link data
    $e2->{epicenter}->{randomNodeUrl} = '/index.pl?op=randomnode&garbage=' . int(rand(100000));

    # Server time data (formatted strings for React component)
    my $NOW = time;
    $e2->{epicenter}->{serverTime} = Everything::HTML::htmlcode('DateTimeLocal', "$NOW,1");
    if($VARS->{localTimeUse}) {
      $e2->{epicenter}->{localTime} = Everything::HTML::htmlcode('DateTimeLocal', $NOW);
    }
  }

  # Epicenter for guests (borgcheck only)
  if($nodelets =~ /262/ and $this->isGuest($USER))
  {
    $e2->{epicenter} = {};
    if($VARS->{borged}) {
      $e2->{epicenter}->{borgcheck} = {
        borged => $VARS->{borged},
        numborged => $VARS->{numborged} || 1,
        currentTime => time
      };
    }
  }

  # Master Control - load for editors/admins (htmlcode will add nodelet to list)
  # Note: isEditor and isAdmin already set globally on e2.user.editor and e2.user.admin
  if($this->isEditor($USER) || $this->isAdmin($USER))
  {
    $e2->{masterControl} = {};

    if($this->isEditor($USER))
    {
      # Admin search form data (React component will handle rendering)
      $e2->{masterControl}->{adminSearchForm} = {
        nodeId => $$NODE{node_id} || '',
        nodeType => $$NODE{type}{title},
        nodeTitle => $$NODE{title},
        serverName => $Everything::CONF->server_hostname,
        scriptName => $query->script_name
      };

      # CE Section data (React component will handle rendering)
      my (undef,undef,undef,$mday,$mon,$year) = localtime(time);
      $year += 1900;
      $e2->{masterControl}->{ceSection} = {
        currentMonth => $mon,
        currentYear => $year,
        isUserNode => ($$NODE{type}{title} eq 'user'),
        nodeId => $$NODE{node_id},
        nodeTitle => $$NODE{title},
        showSection => (($VARS->{epi_hideces} // 0) != 1)
      };

      # NodeNote - Get notes data and pass structured data to React
      my $notes = $this->getNodeNotes($NODE);
      $e2->{masterControl}->{nodeNotesData} = {
        node_id => $NODE->{node_id},
        node_title => $NODE->{title},
        node_type => $NODE->{type}{title},
        notes => $notes,
        count => scalar(@$notes),
      };
      $e2->{currentUserId} = $USER->{node_id};

      if($this->isAdmin($USER))
      {
        # Node Toolset data (React component with nuke confirmation modal)
        my $currentDisplay = $query->param("displaytype") || "display";
        my $nodeType = $NODE->{type}{title};
        my $canDelete = Everything::canDeleteNode($USER, $NODE) && $nodeType ne 'draft' && $nodeType ne 'user';
        my $hasHelp = $this->{db}->sqlSelectHashref("*", "nodehelp", "nodehelp_id=$$NODE{node_id}") ? \1 : \0;
        my $preventNuke = $this->getParameter($NODE->{node_id}, "prevent_nuke") ? \1 : \0;

        $e2->{masterControl}->{nodeToolsetData} = {
          nodeId => $NODE->{node_id},
          nodeTitle => $NODE->{title},
          nodeType => $nodeType,
          canDelete => $canDelete ? \1 : \0,
          currentDisplay => $currentDisplay,
          hasHelp => $hasHelp,
          isWriteup => ($nodeType eq 'writeup') ? \1 : \0,
          preventNuke => $preventNuke,
        };

        # Admin Section data (React component will handle rendering)
        $e2->{masterControl}->{adminSection} = {
          isBorged => $$VARS{borged} ? \1 : \0,
          showSection => (($VARS->{epi_hideadmins} // 0) != 1)
        };
      }
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

  # Statistics
  if($nodelets =~ /838296/ and not $this->isGuest($USER))
  {
    $e2->{statistics} = {};

    # Personal section
    my $numwriteups = $VARS->{numwriteups} || 0;
    my $xp = $USER->{experience} || 0;
    my $lvl = $this->getLevel($USER) + 1;
    my $LVLS = Everything::getVars(Everything::getNode('level experience', 'setting'));
    my $WRPS = Everything::getVars(Everything::getNode('level writeups', 'setting'));

    my $expleft = 0;
    $expleft = $$LVLS{$lvl} - $xp if exists $$LVLS{$lvl};
    my $wrpleft = 0;
    $wrpleft = $$WRPS{$lvl} - $numwriteups if exists $$WRPS{$lvl};

    $e2->{statistics}->{personal} = {
      xp => $xp,
      writeups => $numwriteups,
      level => $this->getLevel($USER),
      xpNeeded => $expleft > 0 ? $expleft : undef,
      wusNeeded => ($expleft <= 0 && $wrpleft) ? $wrpleft : undef,
      gp => $USER->{GP} || 0,
      gpOptout => $VARS->{GPoptout} ? 1 : 0
    };

    # Fun Stats section
    my $nodeFu = ($numwriteups > 0) ? sprintf('%.1f', $xp/$numwriteups) : '0.0';
    $e2->{statistics}->{fun} = {
      nodeFu => $nodeFu,
      goldenTrinkets => $USER->{karma} || 0,
      silverTrinkets => $USER->{sanctity} || 0,
      stars => $USER->{stars} || 0,
      easterEggs => $VARS->{easter_eggs} || 0,
      tokens => $VARS->{tokens} || 0
    };

    # Old Merit System (advancement) section
    my $hv = Everything::getVars(Everything::getNode("hrstats", "setting"));
    my $merit = ($USER->{merit}) ? $USER->{merit} : 0;
    my $lf = $this->getHRLF($USER) || 0;
    my $devotion = int(($numwriteups * $merit) + .5);

    $e2->{statistics}->{advancement} = {
      merit => sprintf('%.2f', $merit),
      lf => sprintf('%.4f', $lf),
      devotion => $devotion,
      meritMean => $$hv{mean} || 0,
      meritStddev => $$hv{stddev} || 0
    };
  }

  # Notelet
  if($nodelets =~ /1290534/ and not $this->isGuest($USER))
  {
    my $isLocked = (exists $VARS->{lockCustomHTML}) || (exists $VARS->{noteletLocked});
    my $hasContent = (exists $VARS->{'noteletRaw'}) && length($VARS->{'noteletRaw'});
    my $content = '';

    if ($hasContent) {
      # Call screenNotelet if needed
      unless(exists $VARS->{'noteletScreened'}) {
        Everything::Delegation::htmlcode::screenNotelet(
          $this->{db},
          $query,
          $NODE,
          $USER,
          $VARS,
          undef,  # $PAGELOAD
          $this   # $APP
        );
      }
      $content = $VARS->{'noteletScreened'} || '';
    }

    $e2->{noteletData} = {
      isLocked => $isLocked ? 1 : 0,
      hasContent => $hasContent ? 1 : 0,
      content => $content,
      isGuest => $this->isGuest($USER) ? 1 : 0
    };
  }

  # Categories
  if($nodelets =~ /1935779/ and not $this->isGuest($USER))
  {
    my $GU = $Everything::CONF->guest_user;
    my $uid = $USER->{user_id};

    # Get all usergroups the user is in
    my $sql = "SELECT DISTINCT ug.node_id
      FROM node ug, nodegroup ng
      WHERE ng.nodegroup_id=ug.node_id AND ng.node_id=$uid";

    my $ds = $this->{db}->{dbh}->prepare($sql);
    $ds->execute();
    my $inClause = $uid.','.$GU;
    while(my $n = $ds->fetchrow_hashref)
    {
      $inClause .= ','.$n->{node_id};
    }

    # Get all categories the user can edit
    $sql = "SELECT n.node_id, n.title, n.author_user, u.title AS author_username
      FROM node n
      LEFT JOIN node u ON n.author_user = u.node_id
      WHERE n.author_user IN ($inClause)
      AND n.type_nodetype=1522375
      AND n.node_id NOT IN (SELECT to_node AS node_id FROM links WHERE from_node=n.node_id)
      ORDER BY n.title";

    $ds = $this->{db}->{dbh}->prepare($sql);
    $ds->execute();
    my @categories = ();
    while(my $n = $ds->fetchrow_hashref)
    {
      push @categories, {
        node_id => $n->{node_id},
        title => $n->{title},
        author_user => $n->{author_user},
        author_username => $n->{author_username}
      };
    }

    $e2->{categories} = \@categories;
    $e2->{currentNodeId} = $NODE->{node_id};
  }

  # Most Wanted
  if($nodelets =~ /1986723/)
  {
    my $REQ = Everything::getVars(Everything::getNode('bounty order','setting'));
    my $OUT = Everything::getVars(Everything::getNode('outlaws', 'setting'));
    my $REW = Everything::getVars(Everything::getNode('bounties', 'setting'));
    my $HIGH = Everything::getVars(Everything::getNode('bounty number', 'setting'));
    my $MAX = 5;

    my $bountyTot = $$HIGH{1};
    my $numberShown = 0;
    my @bounties = ();

    for(my $i = $bountyTot; $numberShown < $MAX; $i--)
    {
      if (exists $$REQ{$i})
      {
        $numberShown++;
        my $requesterName = $$REQ{$i};
        my $requesterNode = $this->{db}->getNode($requesterName, 'user');
        my $outlawStr = $$OUT{$requesterName} || '';
        my $reward = $$REW{$requesterName} || '';

        push @bounties, {
          requester_id => $requesterNode->{node_id},
          requester_name => $requesterName,
          outlaw_nodeshell => $outlawStr,
          reward => $reward
        };
      }
    }

    $e2->{bounties} = \@bounties;
  }

  # Recent Nodes
  if($nodelets =~ /1322699/)
  {
    $VARS->{nodetrail} ||= "";
    my @trail_ids = split(",", $VARS->{nodetrail});

    # Add current node to beginning of trail for next page load
    $VARS->{nodetrail} = $NODE->{node_id} . ',';

    my @recent_nodes = ();
    my $count = 0;

    foreach my $nid (@trail_ids)
    {
      next unless $nid;
      # Skip if already in our updated trail (avoids dupes)
      next if $VARS->{nodetrail} =~ /\b$nid\b/;

      my $node = $this->{db}->getNodeById($nid);
      if($node && $node->{node_id})
      {
        push @recent_nodes, {
          node_id => $node->{node_id},
          title => $node->{title}
        };

        $VARS->{nodetrail} .= $nid . ',';
        $count++;
        last if $count > 8;
      }
    }

    $e2->{recentNodes} = \@recent_nodes;
  }

  # Favorite Noders
  if($nodelets =~ /1876005/ and not $this->isGuest($USER))
  {
    my $wuLimit = int($VARS->{favorite_limit}) || 15;
    $wuLimit = 50 if ($wuLimit > 50 || $wuLimit < 1);

    my $linktypeFavorite = Everything::getNode('favorite', 'linktype');
    if($linktypeFavorite)
    {
      my $linktypeIdFavorite = $linktypeFavorite->{node_id};
      my $typeIdWriteup = Everything::getType('writeup')->{node_id};

      my $sql = "SELECT node.node_id, node.author_user
        FROM links
        JOIN node ON links.to_node = node.author_user
        WHERE links.linktype = $linktypeIdFavorite
          AND links.from_node = $USER->{user_id}
          AND node.type_nodetype = $typeIdWriteup
        ORDER BY node.node_id DESC
        LIMIT $wuLimit";

      my $writeuplist = $this->{db}->{dbh}->selectall_arrayref($sql);
      my @fav_writeups = ();

      foreach my $row (@$writeuplist)
      {
        my $node = $this->{db}->getNodeById($row->[0]);
        if($node && $node->{node_id})
        {
          my $author = $this->{db}->getNodeById($node->{author_user});
          push @fav_writeups, {
            node_id => $node->{node_id},
            title => $node->{title},
            author_id => $node->{author_user},
            author_name => $author ? $author->{title} : 'Unknown'
          };
        }
      }

      $e2->{favoriteWriteups} = \@fav_writeups;
      $e2->{favoriteLimit} = $wuLimit;
    }
  }

  # Personal Links
  if($nodelets =~ /174581/ and not $this->isGuest($USER))
  {
    my $item_limit = 20;
    my $char_limit = 1000;

    my $personal_nodelet_str = $VARS->{personal_nodelet} || '';
    my @nodes = split('<br>', $personal_nodelet_str);
    my @links = ();
    my $total_chars = 0;

    foreach my $title (@nodes)
    {
      next unless $title && $title !~ /^\s*$/;
      my $title_length = length($title);

      # Stop if we would exceed either limit
      last if scalar(@links) >= $item_limit;
      last if ($total_chars + $title_length) > $char_limit;

      push @links, $title;
      $total_chars += $title_length;
    }

    # Just pass the current node title - React will calculate if it can be added
    my $current_title = $NODE->{title};
    $current_title =~ s/(\S{16})/$1 /g;

    $e2->{personalLinks} = \@links;
    $e2->{currentNodeTitle} = $current_title;
    $e2->{currentNodeId} = $NODE->{node_id};
  }

  # Current User Poll
  if($nodelets =~ /1689202/)
  {
    my @POLL = $this->{db}->getNodeWhere({poll_status => 'current'}, 'e2poll');
    if(@POLL)
    {
      my $POLL = $POLL[0];
      my $vote = ($this->{db}->sqlSelect(
        'choice',
        'pollvote',
        "voter_user=".$USER->{node_id}." AND pollvote_id=".$POLL->{node_id}))[0];

      $vote = -1 unless defined $vote;

      # Parse options from doctext
      my @options = split /\s*\n\s*/, $POLL->{doctext};

      # Parse results
      my @results = split ',', $POLL->{e2poll_results} || '';

      # Get author info
      my $author = $this->{db}->getNodeById($POLL->{poll_author});
      my $author_name = $author ? $author->{title} : 'Unknown';

      $e2->{currentPoll} = {
        node_id => $POLL->{node_id},
        title => $POLL->{title},
        poll_author => $POLL->{poll_author},
        author_name => $author_name,
        question => $POLL->{question},
        options => \@options,
        poll_status => $POLL->{poll_status},
        e2poll_results => \@results,
        totalvotes => $POLL->{totalvotes} || 0,
        userVote => $vote
      };
    }
  }

  # Usergroup Writeups
  if($nodelets =~ /1924754/)
  {
    my $isEd = $this->isEditor($USER);

    # Get user's available weblog groups first
    my $can_weblog = $VARS->{can_weblog} || '';
    my @groupids = split(',', $can_weblog);

    # If can_weblog is empty, get all usergroups the user is a member of
    unless (@groupids && $groupids[0]) {
      my $membership_csr = $this->{db}->sqlSelectMany(
        'DISTINCT nodegroup_id',
        'nodegroup',
        "node_id=$$USER{node_id}"
      );
      while (my $row = $membership_csr->fetchrow_hashref()) {
        push @groupids, $row->{nodegroup_id};
      }
    }

    # Default to first available group, or fallback if none
    my $default_group_title = 'edev';  # Fallback for dev environment
    if(@groupids && $groupids[0]) {
      my $first_group = $this->{db}->getNodeById($groupids[0], 'light');
      $default_group_title = $first_group->{title} if $first_group;
    }

    my $ug_title = $VARS->{nodeletusergroup} || $default_group_title;
    my $ug = $this->{db}->getNode($ug_title, 'usergroup');

    if($ug)
    {
      my $view_weblog = $ug->{node_id};
      my $isRestricted = ($view_weblog == 114 || $view_weblog == 923653);

      # Get writeups from this usergroup's weblog
      my @writeups = ();
      my $wclause = "weblog_id='$view_weblog' AND removedby_user=''";
      my $csr = $this->{db}->sqlSelectMany('*','weblog',$wclause,'order by tstamp desc');
      my $counter = 0;
      my $limit = 14;
      while(($counter <= $limit) && (my $ref = $csr->fetchrow_hashref()))
      {
        my $N = $this->{db}->getNodeById($ref->{to_node});
        next unless $N;
        push @writeups, {
          node_id => $N->{node_id},
          title => $N->{title}
        };
        $counter++;
      }

      # Build available usergroups for dropdown (reuse groupids from above)
      my @availableGroups = ();
      my %seen = ();  # Track which groups we've already added

      foreach my $gid (@groupids)
      {
        my $g = $this->{db}->getNodeById($gid, 'light');
        if ($g) {
          push @availableGroups, {
            node_id => $g->{node_id},
            title => $g->{title}
          };
          $seen{$g->{node_id}} = 1;
        }
      }

      # Ensure current group is always in the list (even if not in can_weblog)
      unless ($seen{$ug->{node_id}}) {
        unshift @availableGroups, {
          node_id => $ug->{node_id},
          title => $ug->{title}
        };
      }

      $e2->{usergroupData} = {
        currentGroup => {
          node_id => $ug->{node_id},
          title => $ug->{title}
        },
        writeups => \@writeups,
        availableGroups => \@availableGroups,
        isRestricted => $isRestricted,
        isEditor => $isEd
      };
    }
  }

  # Other Users - Real-time user tracking
  if($nodelets =~ /91/)
  {
    # Use helper method to build the complete data structure
    $e2->{otherUsersData} = $this->buildOtherUsersData($USER);
  }

  # Messages - Private message inbox
  if($nodelets =~ /2044453/)
  {
    # Load initial messages (limit 10 for performance)
    $e2->{messagesData} = $this->get_messages($USER, 10, 0);
  }

  # Notifications - User notification system
  if($nodelets =~ /1930708/)
  {
    $e2->{notificationsData} = $this->buildNotificationsData($NODE, $USER, $VARS, $query);
  }

  # ForReview - Editor draft review queue
  if($nodelets =~ /1930900/)
  {
    $e2->{forReviewData} = $this->buildForReviewData($USER);
  }

  # Phase 4a: React-rendered documents
  # Check if this node type has a Page class that provides React data
  # Supported types: superdoc, superdocnolinks, fullpage, restricted_superdoc, maintenance, nodelet
  my $nodetype = $NODE->{type}->{title};
  my @react_enabled_types = qw(superdoc superdocnolinks fullpage restricted_superdoc maintenance nodelet);
  if ((grep { $nodetype eq $_ } @react_enabled_types) && $user_node) {
    my $page_name = $NODE->{title};
    $page_name = lc($page_name);  # Lowercase first
    $page_name =~ s/[\s\/\:\?\']/_/g;  # Convert special chars to underscores (matches Controller.pm)
    $page_name =~ s/_+/_/g;           # Collapse multiple underscores to single
    $page_name =~ s/_$//g;            # Remove trailing underscore

    my $page_class = "Everything::Page::$page_name";
    my $page_file = "Everything/Page/$page_name.pm";

    # Try to load the Page class if not already loaded
    # Use require which caches results in %INC
    my $page_loaded = 1;
    if (!exists $INC{$page_file}) {
      # Attempt to load - return value indicates success
      $page_loaded = eval { require $page_file; 1; } || 0;
    }

    # Check if Page class exists and has buildReactData method
    if ($page_loaded && $page_class->can('new') && $page_class->can('buildReactData')) {
      # Use real REQUEST object if available (passed from Controller),
      # otherwise create minimal REQUEST object for buildReactData
      my $request_obj = $REQUEST;
      if (!$request_obj) {
        # Create minimal REQUEST with user and node
        my $node_obj = $this->node_by_id($NODE->{node_id});
        $request_obj = Everything::Request->new(user => $user_node, node => $node_obj);
      }

      # Reuse existing page_class_instance from REQUEST if available
      # This is critical for form-processing pages like Sign Up that cache state
      # between display() and buildReactData() calls
      my $page_instance = ($request_obj && $request_obj->can('page_class_instance') && $request_obj->page_class_instance)
        ? $request_obj->page_class_instance
        : $page_class->new();

      my $page_data = $page_instance->buildReactData($request_obj);

      # Automatically enable React page mode for all pages with buildReactData()
      # Both superdoc and fullpage types use PageLayout for content rendering
      $e2->{reactPageMode} = \1;

      # Wrap page data in contentData structure and add type automatically
      # The type is derived from the page name (e.g., "wheel_of_surprise")
      $e2->{contentData} = {
        type => $page_name,
        %{$page_data || {}}  # Spread page data into contentData
      };

      # Build nodelet data for pages with pagenodelets array (fullpage and superdoc)
      # This handles pages like chatterlight (fullpage) and chatterlighter (superdoc)
      if ($page_data->{pagenodelets}) {
        my @pagenodelets = @{$page_data->{pagenodelets}};

        # Check for Notifications nodelet (1930708)
        if (grep { $_ == 1930708 } @pagenodelets) {
          $e2->{notificationsData} = $this->buildNotificationsData($NODE, $USER, $VARS, $query);
        }

        # Check for Other Users nodelet (1969174)
        if (grep { $_ == 1969174 } @pagenodelets) {
          $e2->{otherUsersData} = $this->buildOtherUsersData($USER);
        }

        # Check for Messages nodelet (2044453)
        if (grep { $_ == 2044453 } @pagenodelets) {
          $e2->{messagesData} = $this->get_messages($USER, 10, 0);
        }

        # Check for New Writeups nodelet (263)
        if (grep { $_ == 263 } @pagenodelets) {
          $e2->{newWriteups} = $this->filtered_newwriteups($USER);
        }
      }
    } elsif ($nodetype eq 'maintenance' || $nodetype eq 'nodelet') {
      # Maintenance and nodelet nodes use generic system_node display
      # They don't have individual Page classes - all nodes of these types
      # share the same SystemNode React component
      $e2->{reactPageMode} = \1;
      $e2->{contentData} = {
        type => 'system_node',
        nodeType => $nodetype,
        nodeTitle => $NODE->{title},
        nodeId => $NODE->{node_id},
        sourceMap => $this->buildSourceMap($NODE, undef)
      };
    }
  }

  # NOTE: VARS persistence happens in Controller.pm layout() method
  # (for React flow) or HTML.pm (for legacy flow) at END of request
  # NOT here in buildNodeInfoStructure - we want VARS changes to persist
  # across all page loads in the request, then save at the end

  return $e2;
}

sub buildSourceMap
{
  my ($this, $NODE, $page) = @_;

  my $sourceMap = {
    githubRepo => 'https://github.com/everything2/everything2',
    branch => 'master',
    commitHash => $this->{conf}->last_commit || 'master',
    components => []
  };

  my $nodetype = $NODE->{type}->{title};
  my $nodetitle = $NODE->{title};

  # Detect nodelets
  if ($nodetype eq 'nodelet') {
    my $component_name = $this->titleToComponentName($nodetitle);

    push @{$sourceMap->{components}}, {
      type => 'react_component',
      name => $component_name,
      path => "react/components/Nodelets/$component_name.js",
      description => 'React component'
    };

    push @{$sourceMap->{components}}, {
      type => 'test',
      name => "$component_name.test.js",
      path => "react/components/Nodelets/$component_name.test.js",
      description => 'Component tests'
    };
  }
  # Detect React documents (superdocs with buildReactData)
  elsif ($nodetype =~ /^(superdoc|superdocnolinks|restricted_superdoc|oppressor_superdoc|fullpage)$/) {
    my $page_name = $this->titleToPageFile($nodetitle);
    my $is_react_page = 0;

    # Check if page class exists and has buildReactData
    if ($page_name) {
      my $page_class = "Everything::Page::$page_name";
      my $page_file = "Everything/Page/$page_name.pm";

      # Check if already loaded or can be loaded
      if (exists $INC{$page_file} || eval { require $page_file; 1; }) {
        $is_react_page = $page_class->can('buildReactData');
      }

      if ($is_react_page) {
        # React page - show Page class and React component
        push @{$sourceMap->{components}}, {
          type => 'page_class',
          name => $page_name,
          path => "ecore/Everything/Page/$page_name.pm",
          description => 'Page class (buildReactData)'
        };

        # Check for React document component
        my $doc_component = $this->titleToComponentName($nodetitle);
        push @{$sourceMap->{components}}, {
          type => 'react_document',
          name => $doc_component,
          path => "react/components/Documents/$doc_component.js",
          description => 'React document component'
        };
      }
    }

    # Legacy page - show document.pm delegation and htmlpage
    if (!$is_react_page) {
      # Find the subroutine name in document.pm
      my $sub_name = $nodetitle;
      $sub_name =~ s/\s+/_/g;
      $sub_name =~ s/[^\w]//g;
      $sub_name = lc($sub_name);

      push @{$sourceMap->{components}}, {
        type => 'delegation',
        name => 'document.pm',
        path => 'ecore/Everything/Delegation/document.pm',
        description => "Document delegation (sub $sub_name)"
      };

      # Add htmlpage delegation if page exists
      # Note: $page comes from Everything::HTML::getPage() call
      # For superdocnolinks and some superdocs, this may be undef or empty
      if ($page && ref($page) eq 'HASH' && $page->{title}) {
        my $htmlpage_name = $page->{title};
        $htmlpage_name =~ s/\s+/_/g;

        push @{$sourceMap->{components}}, {
          type => 'delegation',
          name => 'htmlpage.pm',
          path => 'ecore/Everything/Delegation/htmlpage.pm',
          description => "HTML page delegation (sub $htmlpage_name)"
        };
      }
    }
  }
  # Handle maintenance, nodelet and other system node types
  elsif ($nodetype eq 'maintenance' || $nodetype eq 'nodelet' || $nodetype eq 'htmlcode' || $nodetype eq 'htmlpage') {
    # Show controller for this node type
    my $controller_class = "Everything::Controller::$nodetype";
    push @{$sourceMap->{components}}, {
      type => 'controller',
      name => $controller_class,
      path => "ecore/Everything/Controller/$nodetype.pm",
      description => 'Controller class'
    };

    # Show React component for system nodes
    push @{$sourceMap->{components}}, {
      type => 'react_component',
      name => 'SystemNode',
      path => 'react/components/Documents/SystemNode.js',
      description => 'Generic system node display component'
    };

    # Show node type table(s) if it has one (sqltable can be comma-separated)
    if ($NODE->{type}->{sqltable}) {
      my @tables = split(/,/, $NODE->{type}->{sqltable});
      for my $table_name (@tables) {
        push @{$sourceMap->{components}}, {
          type => 'database_table',
          name => $table_name,
          path => "nodepack/dbtable/$table_name.xml",
          description => 'Node type table: ' . $table_name
        };
      }
    }
  }

  return $sourceMap;
}

sub titleToComponentName
{
  my ($this, $title) = @_;

  # Convert title to PascalCase component name
  # Examples:
  #   "chatterbox" -> "Chatterbox"
  #   "other users" -> "OtherUsers"
  #   "wheel of surprise" -> "WheelOfSurprise"

  $title =~ s/[^\w\s]//g;  # Remove non-word chars except spaces
  my @words = split(/\s+/, $title);
  my $component_name = join('', map { ucfirst(lc($_)) } @words);

  return $component_name;
}

sub titleToPageFile
{
  my ($this, $title) = @_;

  # Convert title to snake_case page file name
  # Examples:
  #   "Wheel of Surprise" -> "wheel_of_surprise"
  #   "Silver Trinkets" -> "silver_trinkets"

  my $filename = lc($title);
  $filename =~ s/[^\w\s]//g;  # Remove non-word chars except spaces
  $filename =~ s/\s+/_/g;     # Replace spaces with underscores

  return $filename;
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
    },
    "code" => {
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


sub buildNotificationsData
{
  my ($this, $NODE, $USER, $VARS, $query) = @_;

  my $showSettings = !$$VARS{settings} && !($$NODE{title} eq 'Nodelet Settings' && $$NODE{type}{title} eq 'superdoc');

  # Get rendered notifications (pure data, no HTML)
  my $notifications = $this->getRenderedNotifications($USER, $VARS);

  return {
    notifications => $notifications,
    showSettings => $showSettings ? 1 : 0
  };
}

#############################################################################
# Helper method: Check if user can see a notification type
# Takes explicit $USER parameter instead of relying on global $USER
# This is used by getRenderedNotifications to avoid global state dependency
#############################################################################
sub _canseeNotification
{
  my ($this, $notification_id, $USER) = @_;

  my $notification = $this->{db}->getNodeById($notification_id);
  return 0 unless $notification;

  my $uid = $$USER{node_id} || $$USER{user_id};
  my $isCE = $this->isEditor($USER);
  my $isCoder = $this->inUsergroup($uid, "edev", "nogods") || $this->inUsergroup($uid, 'e2coders', "nogods");
  my $isChanop = $this->isChanop($uid, "nogods");

  return 0 if (!$isCE && ($$notification{description} =~ /node note/));
  return 0 if (!$isCE && ($$notification{description} =~ /new user/));
  return 0 if (!$isCE && ($$notification{description} =~ /(?:blanks|removes) a writeup/));
  return 0 if (!$isCE && ($$notification{description} =~ /review of a draft/));
  return 0 if (!$isChanop && ($$notification{description} =~ /chanop/));

  return 1;
}

sub getRenderedNotifications
{
  my ($this, $USER, $VARS) = @_;

  # Get user's notification subscriptions
  my $otherNotifications = "0";
  my $notificationList;

  if ($$VARS{settings})
  {
    my $settings = JSON::from_json($$VARS{settings});
    $notificationList = $settings->{notifications} if $settings;
    my @notify = ( );

    if ($notificationList && ref($notificationList) eq 'HASH')
    {
      for (keys %{$notificationList})
      {
        # Check if user can see this notification type
        # Use local method instead of htmlcode to avoid global $USER dependency
        next if !$this->_canseeNotification($_, $USER);
        push @notify, $_;
      }

      $otherNotifications = join(",",@notify) if scalar @notify;
    }
  }

  # Query notifications from database
  my $limit = 10;
  my $currentTime = time;
  my $sqlString = qq|
    SELECT notified.notification_id, notified.args, notified.notified_id
    , UNIX_TIMESTAMP(notified.notified_time) 'notified_time'
    , (hourLimit * 3600 - $currentTime + UNIX_TIMESTAMP(notified.notified_time)) AS timeLimit
    FROM notified
    INNER JOIN notification
    ON notification.notification_id = notified.notification_id
    LEFT OUTER JOIN notified AS reference
    ON reference.user_id = $$USER{user_id}
    AND reference.reference_notified_id = notified.notified_id
    AND reference.is_seen = 1
    WHERE
    (
      notified.user_id = $$USER{user_id}
      AND notified.is_seen = 0
    ) OR (
      notified.user_id IN ($otherNotifications)
      AND reference.is_seen IS NULL
    )
    HAVING (timeLimit > 0)
    ORDER BY notified_id DESC
    LIMIT $limit|;

  my $dbh = $this->{db}->getDatabaseHandle();
  my $db_notifieds = $dbh->selectall_arrayref($sqlString, {Slice => {}} );

  # Render each notification
  my @notifications = ();

  foreach my $notify (@$db_notifieds)
  {
    my $notification = $this->{db}->getNodeById($$notify{notification_id});
    my $argJSON = $$notify{args};
    $argJSON =~ s/'/\'/g;

    # Parse JSON args
    my $args = {};
    local $SIG{__DIE__} = sub { };
    my $eval_ok = eval { $args = JSON::from_json($argJSON); 1; };
    $args = {} unless $eval_ok;

    # Convert notification title to delegation function name
    my $notificationTitle = $notification->{title};
    $notificationTitle =~ s/[\s\-]/_/g;  # Replace spaces and hyphens with underscores
    $notificationTitle = lc($notificationTitle);

    # Look up delegation function
    my $renderNotification = Everything::Delegation::notification->can($notificationTitle);

    if (!$renderNotification)
    {
      # No delegation found - log error and skip
      $this->devLog("ERROR: Notification '$notification->{title}' (expected: $notificationTitle) has no delegation function");
      next;
    }

    # Render notification using delegation - returns plain text
    my $displayText = $renderNotification->($this->{db}, $this, $args);

    # Return structured data (no HTML rendering - pure React)
    push @notifications, {
      notified_id => $$notify{notified_id},
      text => $displayText,  # Plain text with [bracket] links
      timestamp => $$notify{notified_time}
    };
  }

  return \@notifications;
}

#############################################################################
# Helper method to generate bracket link from node_id
# Used by notification delegation functions
# Returns: "[Node Title]" for ParseLinks to convert to HTML link
#############################################################################

sub bracketLink
{
  my ($this, $node_id) = @_;
  return '' unless $node_id;

  my $node = $this->{db}->getNodeById($node_id);
  return $node ? "[$node->{title}]" : '';
}

sub buildForReviewData
{
  my ($this, $USER) = @_;

  # Only show to editors
  my $isEditor = $this->isEditor($USER);
  return { isEditor => 0 } unless $isEditor;

  # Get drafts from DataStash (already JSON-safe)
  my $drafts = $this->{db}->stashData("reviewdrafts");

  # Return structured data for React (no HTML generation)
  return {
    isEditor => 1,
    drafts => $drafts
  };
}

1;
