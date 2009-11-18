#!/usr/local/bin/perl -w

use strict;
use Everything;
use Everything::HTML;
initEverything 'everything';


my $hrstats = getNode("hrstats", "setting");
my $hrv = getVars($hrstats);
$$hrv{mean} =sprintf("%.4f", $DB->sqlSelect("AVG(merit)", "user", "numwriteups>=25"));
$$hrv{stddev} = sprintf("%.4f",$DB->sqlSelect("STD(merit)","user", "numwriteups>=25"));
setVars($hrstats, $hrv);
updateNode($hrstats, -1);
