#!/usr/bin/perl -w

use strict;
package Everything::Application;
use Everything;
use Everything::S3;

use DateTime;
use DateTime::Format::Strptime;

# For node2mail
use Email::Sender::Simple qw(try_to_sendmail);
use Email::Simple;
use Email::Simple::Creator;
use Email::Sender::Transport::SMTP;

# For convertDateToEpoch
use Date::Calc;

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
		
		"production_version" =>
		{
			"on" => ["stylesheet","jscript"],
			"description" => "Mark a particular version of an s3 object as being in production",
			"assignable" => ["admin"],
			"validate" => "integer",
		},
		"fix_level" => 
		{
			"on" => ["stylesheet"],
			"description" => "Level of fix automatically applied to other stylesheets",
			"assignable" => ["admin"],
			"validate" => "integer",
		},
		"supported_sheet" => 
		{
			"on" => ["stylesheet"],
			"description" => "Supported for general use",
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

	($user -> {passwd}, $user -> {salt}) = $this -> saltNewPassword($pass);
	return $this -> {db} -> updateNode($user, $user);
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

	my $token = $this -> hashString("$action$pass$expiry", $user -> {salt});
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

	my $action = $query -> param('action');
	my $expiry = $query -> param('expiry');

	return if ($expiry && time() > $expiry)
		or ($action ne 'activate' && $action ne 'reset')
		or $this -> getToken($user, $query -> param('passwd')
			, $action, $expiry) ne $query -> param('token');

	$this -> updatePassword($user, $query -> param('passwd'));
	$this -> securityLog($this->{db}->getNode($action eq 'activate' ? 'Sign up' : 'Reset password', 'superdoc')
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

	return 0 if substr($query -> param('passwd'), 0, 10) ne $user -> {passwd}
		&& $this->urlDecode($cookie) ne $user -> {title}.'|'.crypt($user -> {passwd}, $user -> {title});

	$this -> updatePassword($user, $user -> {passwd});

	# set new login cookie, unless we're going to anyway (and avoid infinite loop)
	Everything::HTML::oplogin() unless $query -> param('op') eq 'login';
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
	
	$word;

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

	$text;
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
#				if $this->{conf}->{clean_search_words_aggressively} is also set.
#
#	Returns
#		The array of words extracted from $text.
#
############################################################################
sub makeCleanWords
{
    my ($this, $text, $harder) = @_;
    $text = $this->makeClean($text);
	$harder &&= $this->{conf}->{clean_search_words_aggressively};
	
	my @words = ();
	if ($text) {
		@words = map( substr($_, 0, 20), split(/\s/, $text) );
		
		if ($harder && @words)
		{
			@words = map( $this->cleanWordAggressive($_), @words);
		}
	}
	
	@words;
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
#		$this->{conf}->{clean_search_words_aggressively}	1=try to trim plural, 'ed' suffixes from words
#		$this->{conf}->{search_row_limit}			maximum number of rows to return from a search.
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
			push(@words, $_) unless (exists $this->{conf}->{nosearch_words}->{$_} or length($_) < 2);
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
		
		if ($this->{conf}->{clean_search_words_aggressively})
		{
			@words = map($this->cleanWordAggressive($_), @words);
		}

    	@words = map($this->{db}->{dbh}->quote($_), @words);

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
	my $searchRowLimit = $this->{conf}->{search_row_limit};

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
	1;
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

	$this->{db}->sqlDelete("searchwords", "node_id=".$this->{db}->getId($NODE));
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
	$|=1;
	
	print "Regenerating searchwords, this could take a while...<br><br>\n";

	print 	"Will be cleaning words " .
			(($this->{conf}->{clean_search_words_aggressively}) ? "" : "non-") .
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
	$sigils .= '@' if $this->isAdmin($user) and !$this->getParameter($user,"hide_chatterbox_staff_symbol");
	$sigils .= '$' if !$this->isAdmin($user) and $this->isEditor($user, "nogods") and !$this->getParameter($user,"hide_chatterbox_staff_symbol");
	$sigils .= '+' if $this->isChanop($user, "nogods") and !$this->getParameter($user,"hide_chatterbox_staff_symbol");
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

        $level;
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

sub getAllNodesWithParameter
{
  my ($this, $parameter, $value) = @_;
  
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
  $this->{db}->sqlInsert('seclog', { 'seclog_node' => $$node{node_id}, 'seclog_user'=>$$user{node_id}, 'seclog_details'=>$details});
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

  return ($this->{conf}->{system}->{guest_user} == $userid);
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
	return $this->{conf}->{environment} eq "development";
}

sub node2mail {
	my ($this, $addr, $node, $html) = @_;
	my @addresses = (ref $addr eq "ARRAY") ? @$addr:($addr);
	my ($user) = $this->{db}->getNodeWhere({node_id => $$node{author_user}},$this->{db}->getType("user"));
	my $subject = $$node{title};
	my $body = $$node{doctext};

	my $from = $this->{conf}->{mail_from};
	my $transport = Email::Sender::Transport::SMTP->new(
  	{ "host" => $this->{conf}->{smtp_host},
    	  "port" => $this->{conf}->{smtp_port},
    	  "ssl" => $this->{conf}->{smtp_use_ssl},
    	  "sasl_username" => $this->{conf}->{smtp_user},
    	  "sasl_password" => $this->{conf}->{smtp_pass},
  	});

	my $email = Email::Simple->create(
  	"header" => [
     		"To"		=> $addr,
     		"From"		=> $from,
     		"Subject"	=> $subject,
		"Content-Type"	=> 'text/html; charset="utf-8"',
  	],
  	"body" => $body
	);

	try_to_sendmail($email, { "transport" => $transport });
}

sub stripNodelet {
	my ($this, $user, $nodelet) = @_;

	my $nodelet_id = undef;
	if(ref $nodelet ne "") 
	{
		$nodelet_id = $nodelet->{node_id};
	}else{
		$nodelet_id = $nodelet;
	}

	my $vars = Everything::getVars($user);
	my $nodeletstring = $vars->{nodelets};
	return unless defined($nodeletstring) and $nodeletstring =~ /\S/;
	my $nodelets = [split(",",$nodeletstring)];
	$nodelets = [grep {$_ != $nodelet_id} @$nodelets];
	$nodeletstring = join(",",@$nodelets);
	if($nodeletstring ne $vars->{nodelets})
	{
		$vars->{nodelets} = $nodeletstring;
		Everything::setVars($user, $vars);
		$this->{db}->updateNode($user, -1);
		return $nodelet_id;
	}
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

	return unless $node;
	return unless $node->{type}->{title} eq "e2node" or $node->{type}->{title} eq "writeup";

	my $maintenance_nodes = [values %{$this->{conf}->{system}->{maintenance_nodes}}];

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
	foreach my $val (values %{$Everything::CONF->{system}->{maintenance_nodes}} )
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
	return 0 if $status eq 'private' and !$$draft{collaborators} || $disposition eq "edit";

	# locked users' drafts are private, except removed drafts for editors
	return 0 if (!$isEditor || $$STATUS{title} ne 'removed') and $this->{db}->sqlSelect('acctlock', 'user', "user_id=$$draft{author_user}");

	return 1 if($status eq 'public' and $disposition ne "edit");
	return 1 if($status eq 'findable' and $disposition eq "find");;

	# shared draft or edit check. Check if this user can see/edit
	my @collab_names = split ',', $$draft{collaborators};
	my $UG = undef;

	foreach (@collab_names){
		$_ =~ s/^\s*|\s*$//g;
		return 1 if lc($_) eq lc($$user{title}) or lc($_) eq 'everybody';
		if ($UG = $this->{db}->getNode($_, 'usergroup')){
			my $collab_ids = { map $_->{node_id}, @{$this->{db}->selectNodegroupFlat($UG)} };
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

sub fixStylesheet
{
	my ($this, $node, $saveold) = @_;

	my $howfixed = $this->getParameter($node, 'fix_level'); $howfixed ||= 0;
	my %replace = ();
	my @disable = ();
	my $addstyles = undef;

	unless ( $howfixed >= 1 ) {
		%replace = (
		qr'\.cup_more's										=>	\"#cooluserpicks .morelink" ,
		qr'(?:#creamofthecool([^,]*?))?\.cotc_info's		=>	\"#creamofthecool $1.contentinfo" ,
		qr'(?:#creamofthecool([^,]*?))?\.cotc_title's		=>	\"#creamofthecool $1.title" ,
		qr'(?:#creamofthecool([^,]*?))?\.cotc_author's		=>	\"#creamofthecool $1.author" ,
		qr'(?:#creamofthecool([^,]*?))?\.cotc_text's		=>	\"#creamofthecool $1.content" ,
		qr'(?:#creamofthecool([^,]*?))?\.cotc_entry's		=>	\"#creamofthecool $1.item" ,
		qr'(?:#creamofthecool([^,]*?))?\.cotc_more's		=>	\"#creamofthecool $1.morelink" ,
		qr'weblog_item' 									=>	\"weblog .item" ,
		qr'(?:\.weblog(?:_| \.)item([^,]*?))?\.wl_title([^,]*?a)?'s	=>	\".weblog .item $1.title" ,
		qr'(?:\.weblog(?:_| \.)item([^,]*?))?\.wl_author:'s	=>	\".weblog .item $1.author:" ,
		qr'(?:\.weblog(?:_| \.)item([^,]*?))?\.wl_author's	=>	\".weblog .item .contentinfo cite" ,
		qr'(?:\.weblog(?:_| \.)item([^,]*?))?\.wl_date's	=>	\".weblog .item $1.date" ,
		qr'(?:\.weblog(?:_| \.)item([^,]*?))?\.wl_text's	=>	\".weblog .item $1.content" ,
		qr'(?:\.weblog(?:_| \.)item([^,]*?))?\.wl_remove's	=>	\".weblog .item $1.remove" ,
		qr'(?:\.weblog(?:_| \.)item([^,]*?))?\.wl_linkedby's	=>	\".weblog .item $1.linkedby" ,
		qr'(div)?\.wl_links's								=>	\".weblog .morelink" ,
		qr'\.wl_linkedby's									=>	\".linkedby" ,
		qr'\.wl_remove's									=>	\".remove" ,
		qr'(#frontpage_news\s+)\.wl_links's					=>	\"#frontpage_news .morelink" ,
		qr'(?:#newwriteups([^,]*?))?#writeup_list's			=>	\".nodelet $1.infolist" ,
		qr'(?:(\.infolist|#writeup_list)[^,]*?)?\.writeupmeta's	=>	\".infolist .contentinfo" ,
		qr'\.writeup_text's									=>	\".writeup .content" ,
		qr'#newWriteupsMore's								=>	\".nodelet .morelink" ,
		qr'#log_list's										=>	\"#logs .infolist" ,
		qr'(?:div)?\.writeup\b's							=>	\".writeuppage .item"
		) unless $howfixed > 0 ;
	
		@disable = (
		'(\.nodelet \.infolist|#newwriteups)([^,]*)(author|type|title)' ,
		'author:before'
		) ;

		$addstyles = '.weblog .title,.weblog .date,.weblog .contentinfo cite,.nodelet .title {display: block;}
.weblog .title {margin-bottom:0.5em;font-weight:bold;font-size:107%;}
.weblog .title, .nodelet .title {font-weight: bold;}';
	}

	unless ( $howfixed >= 2 ) {
		%replace = (
			qr'\.writeup_title's	=>	\".writeuppage .contentheader" ,
			qr'h2\.topic'			=>	\"#pageheader .topic" ,
		%replace ) ;
		$addstyles .= '.actions , .actions li {display:inline;margin:0;padding:0 0.5em 0 0;}
.actions { display: block ; }';
	}

	$addstyles = "/*= autofix added rules. adjust to taste: */\n$addstyles/*= end autofix added rules */\n\n"  if $addstyles ;

	my $idfunction = sub {
		my ( $this, $selectid , $nodeid ) = @_ ;
		next unless defined($this);
		next unless defined($nodeid);
		my $n = $this->{db}->getNodeById( $nodeid );
		return unless $n;
		my $str = lc( $n->{title} ) ;
		$str =~ s/\W//g ;
		return '#'.$str if $selectid ;
		'.'.$str ;
	} ;

	my @input = split( '(\s*(?:\{[^}]*\}|/\*(?:[^*]|\*[^/])*\*/)\s*)' , $$node{ doctext } ) ;
	my $output = undef; $output = "/*= Comments containing old/disabled rules start with = for easy finding */\n" if $saveold ;
	my $fixwasneeded = undef;

	foreach ( @input ) {
		my $chunk = $_ ;
		my $old = undef; $old = "/*=$chunk*/\n" if $saveold ;
		unless ( $chunk =~ '^(/\*|\{)' ) {
			$chunk =~ s/(?:\.nodetype_|(\.node_id|#nodelet_))(\d+)/&$idfunction( $this, $1 , $2 )/eg ;
			foreach ( keys %replace ) {
				$chunk =~ s/$_/${$replace{ $_ }}/g ;
			}
			unless ( $chunk eq $_ ) {
				$output .= $old ;
				$fixwasneeded = 1 ;
  			}
			foreach ( @disable ) {
				$chunk =~ s!([^,]*$_[^,]*)! DISABLED /*= $1 */ !sg unless $chunk =~ 'DISABLED /\*=' ;
			}
		}
		$output .= $chunk ;
	}

	#unless ( $fixwasneeded ) {
	#	$this->setParameter($node, -1, 'fix_level', $Everything::CONF->{stylesheet_fix_level});
	#}

	$output = $addstyles.$output if $fixwasneeded ;

	return $output ;
}

sub uploadS3Content
{
	my ($this, $node) = @_;
	
	if(ref $node eq "")
	{
		$node = $this->{db}->getNodeById($node);
	}

	my $s3bucket = $node->{s3bucket};
	if(not defined $s3bucket or $s3bucket eq '')
	{
		if($node->{type}->{title} eq "jscript" or $node->{type}->{title} eq "stylesheet")
		{
			$s3bucket = "jscss";
		}
	}

	my $extension = undef; #mod_perl safety exercise

	if($node->{type}->{title} eq "stylesheet")
	{
		$extension = "css";
	}elsif($node->{type}->{title} eq "jscript")
	{
		$extension = "js";
	}

	my $tmpdir = "/tmp/s3upload.$$";
	`mkdir -p $tmpdir`;
	chdir $tmpdir;

	my $s3 = Everything::S3->new($s3bucket);
	my $to_upload = [];
	my $filehandle = undef;
	my $content = undef;

	if($extension eq "css")
	{
		$content = $this->fixStylesheet($node,0);
	}elsif($extension eq "js"){
		$content = $node->{doctext};
	}

	my $filebase = "$$node{node_id}.$$node{contentversion}";
	open $filehandle,">$filebase.$extension";
	print $filehandle $content;
	close $filehandle;
	
	push @$to_upload, ["$filebase.$extension",0];

	`yui-compressor $filebase.$extension > $filebase.min.$extension`;
	push @$to_upload, ["$filebase.min.$extension",0];

	`gzip --best -c $filebase.$extension > $filebase.gzip.$extension`;
	push @$to_upload, ["$filebase.gzip.$extension",1];

	`gzip --best -c $filebase.min.$extension > $filebase.min.gzip.$extension`;
	push @$to_upload, ["$filebase.min.gzip.$extension",1];
	

	my $modifiedTimeFormat = '%a, %d %b %Y %T %Z'; # format for HTML header
	my $dateOutputer = new DateTime::Format::Strptime(
		pattern     => $modifiedTimeFormat,
		locale      => 'en_US'
	);

	foreach my $filespec (@$to_upload)
	{
		my $properties = {};
		my $content_type = undef;
		if($extension eq "js")
		{
			$content_type = "application/javascript";
		}elsif($extension eq "css")
		{
			$content_type = "text/css";
		}
		
		$properties->{content_type} = $content_type;

		if($filespec->[1]) #gzipped
		{
			$properties->{content_encoding} = 'gzip';			
		}

		$properties->{expires} = $dateOutputer->format_datetime(DateTime->from_epoch(epoch => time()+60*60*24*365*10)); #10 years

		$s3->upload_file($filespec->[0], $filespec->[0], $properties);
	}

	chdir("/tmp");
	`rm -rf $tmpdir`;
}

# Originally in the htmlcode 'get ips'. Taken unmodified.

sub intFromAddr
{
	my ($this, $addr) = @_;
	return undef unless $addr =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
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
		grep { $this->isIpRoutable($_) } # ignore our Pound server
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
	return scalar(grep {$_ eq $ip} @{$Everything::CONF->{infected_ips}} );
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
	
	1;
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
		join("&", map( $_."=".$this->escape($$varHash{$_}), sort keys %$varHash) );
	return $varStr
}

sub cloak {
  my ($this, $user, $vars) = @_;
  my $setvarflag = undef;
  $setvarflag = 1 unless $vars; 
  $vars ||= getVars $user;
  
  $$vars{visible}=1;
  Everything::setVars($user, $vars) if $setvarflag;
  $this->{db}->sqlUpdate('room', {visible => 1}, "member_user=".$this->{db}->getId($user));
}

sub uncloak {
  my ($this, $user, $vars) = @_;
  my $setvarflag = undef;
  $setvarflag = 1 unless $vars; 
  $vars ||= getVars $user;
  
  $$vars{visible}=0;
  Everything::setVars($user, $vars) if $setvarflag;
  $this->{db}->sqlUpdate('room', {visible => 0}, "member_user=".$this->{db}->getId($user));
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

  $this->{db}->sqlInsert("room"
    , {
            room_id => $room_id,
            member_user => $user_id,
            nick => $$U{title},
            borgd => $borgd,
            experience => $$U{experience},
            visible => $vis,
            op => $this->isAdmin($U)
    }
    , {
            nick => $$U{title},
            borgd => $borgd,
            experience => $$U{experience},
            visible => $vis,
            op => $this->isAdmin($U)
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
    
  $this->insertIntoRoom($ROOM, $user);

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
  my $ipquery = qq|;
    SELECT DISTINCT iplog_ipaddy
    FROM iplog 
    WHERE iplog_user = $$user{user_id}
    AND iplog_time > DATE_SUB(NOW(), INTERVAL $hour_limit HOUR)|;

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
  return 0 unless $user && $user -> {acctlock} == 0;

  unless ($cookie)
  {
    # login with plaintext password. May reset password or activate account first:
    $this->checkToken($user, $query) if $query->param('token');
    $pass = $this->hashString($pass, $user->{salt});
  }

  return $user if $pass eq $user->{passwd};
  return 0 if $user->{salt};

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

  return undef unless $usr and $sustype;

  if(!UNIVERSAL::isa($sustype, "HASH"))
  {
    $sustype = $this->{db}->getNode($sustype, "sustype");
    return unless $sustype;
  }

  my $suspension_info = $this->{db}->sqlSelectHashref("*", "suspension", "suspension_user=$$usr{node_id} and suspension_sustype=$$sustype{node_id}");
 
  return unless $suspension_info->{suspension_id};
 
  # Because the "ends" behavior was added well after the other suspension code was in place, we're going to assume that
  # the old behavior of '0' means never ends
  if(!defined($suspension_info->{ends}) or $this->convertDateToEpoch($suspension_info->{ends}) == 0 )
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
  return undef unless $usr and $sustype;

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
  return undef unless $usr and $sustype;

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

 if (!$this->isGuest($user)
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

	1;
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
	$VOTE;
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
	$$node{totalvotes} += $voteChange;
	$this->{db}->updateNode($node, -1);
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

    my ($user, $node, $AUTHOR) = @_;

    #return if they don't have any votes left today
    return unless $$user{votesleft};

    #jb says: Allow for $VSETTINGS to be specified. This will save
    # us a few cycles in castVote
    $VSETTINGS ||= Everything::getVars($this->{db}->getNode('vote settings', 'setting'));
    my @votetypes = split /\s*\,\s*/, $$VSETTINGS{validTypes};

    #if no types are specified, the user can vote on anything
    #otherwise, they can only vote on "validTypes"
    return if (@votetypes and not grep(/^$$node{type}{title}$/, @votetypes));

    my $prevweight;
    $prevweight  = $this->{db}->sqlSelect('weight',
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

      $this->insertVote($node, $user, $weight);

      if ($$node{type}{title} eq 'poll') {
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

    $this->adjustRepAndVoteCount($node, $weight-$prevweight, $voteCountChange);

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
      $this->adjustGP($user, 1) unless($noxp);
      #jb says this is for decline vote XP option
      #we pass this $noxp if we want to skip the XP option
    }

    $$user{votesleft}-- unless ($alreadyvoted and $weight==$prevweight);

  };

  my $superUser = -1;
  $this->{db}->updateLockedNode(
    [ $$user{user_id}, $$node{node_id}, $$node{author_user} ]
    , $superUser
    , $voteWrap
  );

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
	my ($this, $node, $user) = @_;

	return $this->hasVoted($node, $user) if $user;

	my $csr = $this->{db}->sqlSelectMany("*", "vote", "vote_id=".getId($node));
	my @votes;

	while (my $VOTE = $csr->fetchrow_hashref()) {
		push @votes, $VOTE;
	}
	
	@votes;
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
        1;
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
	1;
}

sub use_bootstrap {
  my ($this) = @_;
  return $Everything::HTML::VARS->{use_bootstrap};
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
#
sub showPartialDiff {
  my ($this, $codeOrig, $codeNew) = @_;

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
#

sub showCompleteDiff{
  my ($this, $codeOrig,$codeNew) = @_;
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

sub urlDecode
{
  my $this = shift;

  foreach my $arg (@_)
  {
    tr/+/ / if $_;
    $arg =~ s/\%(..)/chr(hex($1))/ge;
  }

  $_[0];
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
    '<'.$close.$tag.'>' ;
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
	    my $closing;
	    my @popped;
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
	my ($this, $text, $APPROVED) = @_;
	$APPROVED ||= {};

	$text = $this->cleanupHTML($text, $APPROVED);
	$text;
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


1;
