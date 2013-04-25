#!/usr/bin/perl -w -I /var/everything/ecore

use Everything;
initEverything 'everything';
use Everything::HTML;
use CGI;
use strict;

#globals for the current user, and their system vars
my $USER;
my $VARS;
my $TODAYSTATS;
my $YESTERSTATS;
my $NEWSMAIL;
my %htmlletter;
my %nomlletter;
my %titleletter;
my $E2NTYPE=getNode('e2node','nodetype');
my $WRTYPE= getNode('writeup', 'nodetype');


sub makeEmailUrl {
  my ($NODE) = @_;
  return if $$VARS{emailNohtml} == 2;
  getRef $NODE;
  my $url = "http://everything2.com/?";

  if ($$NODE{type_nodetype} == getId($E2NTYPE)) {
    my $title=CGI::escape($$NODE{title});
    $title =~ s/\%20/\+/gs;

    return $url."node=".$title."&type=e2node";
  } else {
    return $url."node_id=".getId($NODE);
  }
} 


#sometimes we want HTML, sometimes we want just straight links
sub genLinks {
  my (@nodes) = @_;
  my $str;

  foreach my $N (@nodes) {
    return "" unless $N;
    getRef $N;

    if ($$VARS{emailNohtml}) {  
      $str.="\n\[$$N{title}\]\n\t".makeEmailUrl($N);
    } else {
      #jb says patched this here to quote the URLS
      #as I think it was breaking some mail clients
      $str.="<a href=\"".makeEmailUrl($N)."\">$$N{title}</a>\n";
    }
  }
  
  $str;
}


sub genLinkTitle {
        my ($nodename, $title) = @_;

        ($nodename, $title) = split /\|/, $nodename;
        $title ||= $nodename;
        $nodename =~ s/\s+/ /gs;

        my $urlnode = CGI::escape($nodename);
        my $str = "";
        $str .= "<a href=\"http://everything2.com/?node=$urlnode";
        $str .= "\">$title</a>";

        $str;
}

sub genNodes {
  my @nodes = @_;

  my $str;

  foreach my $NODE (@nodes) {
    getRef $NODE;
    
    my $text = $$NODE{doctext};
    if ($$VARS{emailNohtml}) {
      $text =~ s/\<br\>/\n/gsi;
      $text =~ s/\<p.*?\>/\n\t/gsi;   
      $text =~ s/\<li\>/\t/gsi;  #this isn't correct, but may work for us
      $text = Everything::HTML::htmlScreen($text);
      use Text::Wrap qw(wrap $columns);
      $columns = 75;
      $text = wrap('', '', $text);
    } else {
      $text =~ s/\[(.*?)\]/genLinkTitle($1)/egs; 
    }
    $str.="-" x 40 . "\n" if $str;
    $str.="\t$$NODE{title}\n\n$text\n\n";
  }
  $str;
}

#generate the header for a section
sub genHeader {
	my ($title) = @_;
 	$title ||= "";

	$title = "\t$title" if $title;
                 "$title\n    *"
		."-" x 63
		."*\n";
}

sub genNews {
  my $csr= $DB->sqlSelectMany("to_node", "weblog", 
    "to_days(now())-to_days(linkedtime) <= 1 and weblog_id=165580", "order by linkedtime");

  my @newsies;
  while (my ($id) = $csr->fetchrow()) {
    push @newsies, $id;
  }
  $csr->finish;

  return "" unless @newsies;

  my $str = genHeader("Everything System News");
  $str.= genNodes(@newsies);
  $str;
}

#makes it slightly easier to get differences
sub statDiff {
  my ($field) = @_;
  nicenum(int($$TODAYSTATS{$field})-int($$YESTERSTATS{$field}));
}

#danke, tom christiansen
sub nicenum {
    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text;
}

sub genStat {
  my ($FIELDS, $ORDER) = @_;

  my $str;
  foreach (@$ORDER) {
    my $val = $$FIELDS{$_};
    $str.="$_ total: ".nicenum($$TODAYSTATS{$val});

    $str.=" (".statDiff($val)." since Yesterday)" if statDiff($val);
    $str.="\n";
  }
  $str;
}
sub genStats {
  my $str;

  $str.=genHeader("Everything2 Statistics as of $$TODAYSTATS{stattime}");
  $str.=genStat({E2Nodes => 'nume2nodes', 
	Writeups => 'numwriteups',
	Users => 'numusers',
	Links => 'numlinks',
	Experience => 'xpsum',
	"Votes cast" => 'numvotes',
	"Nodeviews" => 'nodehits'},
	['E2Nodes','Writeups', 'Users', 'Links', 'Votes cast', 'Experience', 'Nodeviews']);
 
  $str;
}

#this is really kludgy, but it gets the job done
sub genEditorCools {
  return "" unless statDiff('numedcools') > 0;
  my $count = statDiff('numedcools');
  my $str;
  my $COOLNODES = getNode 'coolnodes', 'nodegroup';
  my $COOLLINKS = getNode 'coollink', 'linktype';
  my $cn = $$COOLNODES{group};
  my $clink = getId $COOLLINKS;
  foreach (reverse @$cn) {
	  last if $count ==0; 
	  $count--;
	  my $csr = $dbh->prepare("select * from links where from_node=".getId($_)." and linktype=$clink");
	  $csr->execute;
	  my $link = $csr->fetchrow_hashref;
	  $csr->finish; 

    	  my $COOLER = getNodeById($$link{to_node});
	  $str.= genLinks($_);
	  if ($link) {
		  $str.="\tcooled by $$COOLER{title}\n\n"   
	  } 
	  
  }
  genHeader("The Latest in Cool E2Nodes").$str;
}

sub genPersonalStats {
  my $str;
  

  my %stats;
  $stats{nodecount} = $DB->sqlSelect("count(*)", "node", "author_user=".getId($USER)." and type_nodetype=".getId($WRTYPE));
  $stats{experience} = $$USER{experience};

  if ($stats{nodecount}) { 
  	$stats{experienceratio} = sprintf("%.2f", $stats{experience}/$stats{nodecount});
  } else {
  	$stats{experienceratio} = 'undefined'; 
  }
  $stats{nodeshare} = sprintf("%.3f", 100*$stats{nodecount}/$$TODAYSTATS{numwriteups}) . "\%";
  $stats{xpshare} = sprintf("%.3f", 100*$stats{experience}/$$TODAYSTATS{xpsum})."\%";

  $str .= genHeader($$USER{title}."'s personal statistics");
  $str .= "Your node count: $stats{nodecount}\n";
  $str .= "Your experience: $stats{experience}\n";
  $str .= "Your experience to node ratio: $stats{experienceratio}\n";
  $str .= "Your nodeshare: $stats{nodeshare}\n";
  $str .= "Your xpshare: $stats{xpshare}\n"; 
 


}

sub genCools {
#	my ($seconds, $minutes, $hours, $day_of_month, $month, $year,
#			$wday, $yday, $isdst) = localtime(time);
#
#	$year+=1900;
#	$month = sprintf("%02d", ++$month);
#	$day_of_month = sprintf("%02d", $day_of_month);
#	my $todaystamp = $year.$month.$day_of_month. 0 x 6;
#	($seconds, $minutes, $hours, $day_of_month, $month, $year,
#			$wday, $yday, $isdst) = localtime(time-86400);
#	$year+=1900;
#	$month = sprintf("%02d", ++$month);
#	$day_of_month = sprintf("%02d", $day_of_month);
#	my $yesterstamp = $year.$month.$day_of_month. 0 x 6;
#
#
#	my $csr = $DB->sqlSelectMany("*", 
#		"coolwriteups, node ", 
#		"tstamp>$yesterstamp and tstamp<$todaystamp and node_id=coolwriteups_id", 
#		"order by reputation DESC limit 25");
#
	my $csr = $dbh->prepare("select * from node left join writeup on node_id=writeup_id where
 UNIX_TIMESTAMP(createtime) > UNIX_TIMESTAMP(now())-86400 order by cooled desc, reputation desc limit 25");
    $csr->execute;
	
	my $str;
	while (my $N = $csr->fetchrow_hashref) { 
		my $U = getNodeById($$N{cooledby_user}, 'light');
		my $AUTH = getNodeById($$N{author_user}, 'light');
		
		$str.=genLinks($N)." ($$N{cooled}C!) written by $$AUTH{title}\n\n";	
       	}
	$csr->finish;
	genHeader("Top 25 Cool Writeups by Coolness and Rep").$str;
} 

sub genReps {
	"";

}

sub genSubscription {
	return unless $$VARS{emailSubscribedusers};
	my @users = split ",", $$VARS{emailSubscribedusers};

	my $str;
	my @where;
	foreach (@users) {
		push @where,"author_user=".int($_);
	}
	my $wherestr = "type_nodetype=".getId($WRTYPE)." and to_days(now()) - to_days(createtime) = 1 and ("
		.join(" or ",@where).")";

	my $csr = $DB->sqlSelectMany("*", "node", $wherestr, "order by createtime DESC");

	my %scription;
	while (my $N = $csr->fetchrow_hashref) {
		push @{ $scription{$$N{author_user}} }, $N;
	}
	$csr->finish;

	foreach (@users) {
		next unless $scription{$_};
		my $U = getNodeById($_, 'light');

		$str.= "\n\n".genHeader("New nodes by $$U{title}");
		$str.= genLinks(@{ $scription{$_}});	
 	}
	$str;
} 

sub generateMail {
  ($USER) = @_;
  getRef $USER;
  $VARS = getVars($USER);

  my %MAIL = %{ $NEWSMAIL };
  $MAIL{doctext} =~ s/\[user\]/$$USER{title}/gs;
  my $content;
  my $letter;

  if ($$VARS{emailNohtml} == 1) {
    $letter = \%nomlletter;
  } elsif ($$VARS{emailNohtml} == 2) {
    $letter = \%titleletter;
  } else {
    $letter = \%htmlletter;
  }

  
  $content .= $$letter{news} unless $$VARS{emailNonews};
  $content.="<p>" unless $$VARS{emailNohtml};
  $content .= $$letter{stats} unless $$VARS{emailNostats};
  $content.="<p>" unless $$VARS{emailNohtml};
  $content .= "\n\n".genPersonalStats unless $$VARS{emailNostats};
  $content.="<p>" unless $$VARS{emailNohtml};
  $content .= "\n".$$letter{edcools} unless $$VARS{emailNoeditorcools};
  $content.="<p>" unless $$VARS{emailNohtml};
  $content .= $$letter{cools} unless $$VARS{emailNocools};
  $content.="<p>" unless $$VARS{emailNohtml};
#  $content .= genReps unless $$VARS{emailNoreps};
  $content .= genSubscription if ($$VARS{emailSubscribedusers}); 
  $content.="<p>" unless $$VARS{emailNohtml};

  $content.= genHeader();
  $content =~ s/\n/\<br\>\n/gs unless $$VARS{emailNohtml};
  $MAIL{doctext} =~ s/\[content\]/$content/gs;

  my ($day, $month, $year) = (localtime(time))[3,4,5];
  $month++; $year+=1900; #$day--;
  my $daystr = sprintf("%04d-%02d-%02d", $year, $month, $day); 


  $MAIL{doctext} =~ s/\[date\]/$daystr/gs;
  $MAIL{title} = "Everything Daily Report for $daystr";
  
  my $html = 1 unless $$VARS{emailNohtml};

  $APP->node2mail($$USER{email}, \%MAIL, $html);  
  sleep(5);
#  print "mail for $$USER{title} generated\n"; 
}

#the first thing we do is set up a bunch of globals to make assembling
#the emails that much faster
my $csr = $DB->sqlSelectMany("*", "stats", "", "order by stats_id desc limit 2");
$TODAYSTATS = $csr->fetchrow_hashref;
$YESTERSTATS = $csr->fetchrow_hashref;
$csr->finish;


#exit;

$NEWSMAIL = getNode('daily report email','mail');

$htmlletter{news} = genNews;
$htmlletter{stats} = genStats;
$htmlletter{edcools} = genEditorCools;
$htmlletter{cools} = genCools;

$$VARS{emailNohtml} = 1;

$nomlletter{news} = genNews;
$nomlletter{stats} = genStats;
$nomlletter{edcools} = genEditorCools;
$nomlletter{cools} = genCools;

$$VARS{emailNohtml} = 2;

$titleletter{news} = genNews;
$titleletter{stats} = genStats;
$titleletter{edcools} = genEditorCools;
$titleletter{cools} = genCools;


$csr = $DB->sqlSelectMany("user_id", "user", "wantsreport != 0");
#$csr = $DB->sqlSelectMany("user_id", "user", "user_id=459692");

while (my ($U) = $csr->fetchrow) {
	generateMail($U); 
	sleep 1;
}
$csr->finish;
