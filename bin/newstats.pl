#!/usr/bin/perl -w -I /var/everything/ecore

use strict;
use Everything;
use Everything::HTML;
initEverything 'everything';


my $csr = $DB->sqlSelectMany("node_id, reputation, author_user", 
"node", "type_nodetype=".getId(getType('writeup')));

my $root = getNode("root","user");

my $reps;
my $cnt = 0;
my $totalwus = $DB->sqlSelect("count(*)", "node", 
"type_nodetype=".getId(getType('writeup')));
my $totalusrs = $DB->sqlSelect("count(*)", "node",
"type_nodetype=".getId(getType('user')));



while(my $row = $csr->fetchrow_hashref())
{
  $$reps{$$row{author_user}}{$$row{reputation}} ||= 0;
  $$reps{$$row{author_user}}{$$row{reputation}}++;
  #print "Indexing: ".sprintf("%.2lf", ($cnt*100)/$totalwus)."%\n" 
  #  if(($cnt % 100) == 0);
  $cnt++;
}

foreach(keys %$reps)
{
  $cnt = 0;
  my $uid = getNodeById($_);
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
      $reptally += $_ * ($count - ($cursor + $skip)) ;
      $ncount += $count - ($cursor + $skip) ;    
      $cursor += $rephash{$_};
    }
  }
  $cnt++;
  my $IQM = $reptally / $ncount;

  $DB->sqlDelete("newstats", "newstats_id=$$uid{user_id}");
  $DB->sqlInsert("newstats", {'newstats_id' => $$uid{user_id}, 
'newstats_iqm' => $IQM});
  
  $$uid{merit} = $IQM;
  updateNode($uid, -1) or print "*** UPDATE FAILED ***\n";

  print "$$uid{title} - $IQM\n";

 # my $v = getVars($uid);
 # $$v{IQM} = $IQM;
 # setVars($uid, $v);


  #print "Calculating: ".sprintf("%.2lf", ($cnt*100)/$totalusrs)."%\n" 
  #  if(($cnt % 100) == 0);
  sleep(2) if(($cnt % 100) == 0);
  #print $$uid{title}." $IQM - count: $ncount\n";
}

`/usr/local/everything/bin/lfcalc.pl`;
