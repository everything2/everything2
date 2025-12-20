#!/usr/bin/perl -w

use strict;
use warnings;

package Everything::Delegation::achievement;

#############################################################################
#
# Everything::Delegation::achievement
#
# Achievement checking delegation functions
#
# This module contains delegated achievement checking logic that was
# previously stored in achievement nodes' {code} field and evaluated
# via eval(). Each function represents an achievement condition check.
#
# Function naming convention:
#   - Lowercase achievement title
#   - Spaces and hyphens replaced with underscores
#   - Non-alphanumeric characters replaced with underscores
#
# Function signature:
#   sub achievement_name {
#     my ($DB, $APP, $user_id) = @_;
#     # Check achievement condition
#     return 1; # Achievement earned
#     return 0; # Not yet earned
#   }
#
# Note: These functions are called from Everything::Delegation::htmlcode::hasAchieved
#
#############################################################################

use Everything::Globals;

BEGIN {
    *getNodeById     = *Everything::HTML::getNodeById;
    *getVars         = *Everything::HTML::getVars;
    *htmlcode        = *Everything::HTML::htmlcode;
}

#############################################################################
# Test achievement delegation
# This is a real achievement migrated for testing the delegation mechanism
#############################################################################

sub cooled050
{
    my ($DB, $APP, $user_id) = @_;

    my $coolCount = $DB->sqlSelect("count(*)","coolwriteups","cooledby_user=$user_id");

    return 1 if $coolCount >= 50;
    return 0;
}

sub cooled100
{
    my ($DB, $APP, $user_id) = @_;

    my $coolCount = $DB->sqlSelect("count(*)","coolwriteups","cooledby_user=$user_id");

    return 1 if $coolCount >=100;
    return 0;
}

sub coolnode05
{
    my ($DB, $APP, $user_id) = @_;

    my $coolCount = $DB->sqlSelect("max(cooled)","writeup","writeup_id in (select node_id from node where author_user=$user_id and type_nodetype=117)");

    return 1 if $coolCount >=5;
    return 0;
}

sub coolnode10
{
    my ($DB, $APP, $user_id) = @_;

    my $coolCount = $DB->sqlSelect("max(cooled)","writeup","writeup_id in (select node_id from node where author_user=$user_id and type_nodetype=117)");

    return 1 if $coolCount >=10;
    return 0;
}

sub coolnode20
{
    my ($DB, $APP, $user_id) = @_;

    my $coolCount = $DB->sqlSelect("max(cooled)","writeup","writeup_id in (select node_id from node where author_user=$user_id and type_nodetype=117)");

    return 1 if $coolCount >=20;
    return 0;
}

sub cools050
{
    my ($DB, $APP, $user_id) = @_;

    my $coolCount = htmlcode('coolcount', $user_id);
    return 1 if $coolCount >=50;
    return 0;
}

sub cools100
{
    my ($DB, $APP, $user_id) = @_;

    my $coolCount = htmlcode('coolcount', $user_id);
    return 1 if $coolCount >=100;
    return 0;
}

sub cools200
{
    my ($DB, $APP, $user_id) = @_;

    my $coolCount = htmlcode('coolcount', $user_id);
    return 1 if $coolCount >=200;
    return 0;
}

sub cools500
{
    my ($DB, $APP, $user_id) = @_;

    my $coolCount = htmlcode('coolcount', $user_id);
    return 1 if $coolCount >=500;
    return 0;
}

sub eggs100
{
    my ($DB, $APP, $user_id) = @_;

    my $uVars = getVars(getNodeById($user_id));
    return 1 if $$uVars{easter_eggs_bought} >=100;
    return 0;
}

sub experience_1
{
    my ($DB, $APP, $user_id) = @_;

    my $xpCount = $DB->sqlSelect("experience","user","user_id=$user_id");
    return 1 if $xpCount < 0;
    return 0;
}

sub experience01000
{
    my ($DB, $APP, $user_id) = @_;

    my $xpCount = $DB->sqlSelect("experience","user","user_id=$user_id");
    return 1 if $xpCount >= 1000;
    return 0;
}

sub experience10000
{
    my ($DB, $APP, $user_id) = @_;

    my $xpCount = $DB->sqlSelect("experience","user","user_id=$user_id");
    return 1 if $xpCount >= 10000;
    return 0;
}

sub experience50000
{
    my ($DB, $APP, $user_id) = @_;

    my $xpCount = $DB->sqlSelect("experience","user","user_id=$user_id");
    return 1 if $xpCount >= 50000;
    return 0;
}

sub fool_s_errand
{
    my ($DB, $APP, $user_id) = @_;

    return 1;
}

sub karma20
{
    my ($DB, $APP, $user_id) = @_;

    my $karma = $DB->sqlSelect("karma","user","user_id=$user_id");
    return 1 if $karma >= 20;
    return 0;
}

sub openwindow
{
    my ($DB, $APP, $user_id) = @_;

    #nodetype 117 is writeups, remember.
    my $whereStr = "author_user=$user_id and type_nodetype=117 and UPPER(doctext) like '%DEFENESTRATE%'";

    my $windowCount = $DB->sqlSelect("count(doctext)",
                                     "document join node ON
                                      document.document_id=node.node_id",
                                      $whereStr);

    return 1 if $windowCount >= 15;
    return 0;
}

sub reputation_10
{
    my ($DB, $APP, $user_id) = @_;

    my $zombieNode = $DB->sqlSelect("min(reputation)","node","author_user=$user_id");
    return 1 if $zombieNode <= -10;
    return 0;
}

sub reputation050
{
    my ($DB, $APP, $user_id) = @_;

    my $highRep = $DB->sqlSelect("reputation","node","author_user=$user_id and type_nodetype=117 order by reputation desc limit 1");

    return 1 if $highRep >= 50;
    return 0;

}

sub reputation100
{
    my ($DB, $APP, $user_id) = @_;

    my $highRep = $DB->sqlSelect("reputation","node","author_user=$user_id and type_nodetype=117 order by reputation desc limit 1");

    return 1 if $highRep >= 100;
    return 0;


}

sub reputation200
{
    my ($DB, $APP, $user_id) = @_;

    my $highRep = $DB->sqlSelect("reputation","node","author_user=$user_id and type_nodetype=117 order by reputation desc limit 1");

    return 1 if $highRep >= 200;
    return 0;
}

sub reputationmix
{
    my ($DB, $APP, $user_id) = @_;

    my $controversial = $DB->sqlSelect("count(*)","node", "author_user=$user_id and type_nodetype=117 and (reputation >= -5 and reputation <=10)  and (select count(*) from vote where vote_id=node_id)>=30");
    return 1 if $controversial >= 1;
    return 0;
}

sub tokens100
{
    my ($DB, $APP, $user_id) = @_;

    my $uVars = getVars(getNodeById($user_id));
    return 1 if defined($$uVars{tokens_bought}) && $$uVars{tokens_bought} >= 100;
    return 0;
}

sub totalreputation01000
{
    my ($DB, $APP, $user_id) = @_;

    my $totalRep = $DB->sqlSelect("sum(reputation)","node","author_user=$user_id and type_nodetype=117");

    return 1 if $totalRep >= 1000;
    return 0;
}

sub totalreputation05000
{
    my ($DB, $APP, $user_id) = @_;

    my $totalRep = $DB->sqlSelect("sum(reputation)","node","author_user=$user_id and type_nodetype=117");

    return 1 if $totalRep >= 5000;
    return 0;
}

sub totalreputation10000
{
    my ($DB, $APP, $user_id) = @_;

    my $totalRep = $DB->sqlSelect("sum(reputation)","node","author_user=$user_id and type_nodetype=117");

    return 1 if $totalRep >= 10000;
    return 0;
}

sub usergroupbritnoders
{
    my ($DB, $APP, $user_id) = @_;

    return $APP->inUsergroup($user_id,'britnoders','nogods');
}

sub usergroupedev
{
    my ($DB, $APP, $user_id) = @_;

    return $APP->isDeveloper($user_id, "nogods");
}

sub usergroupgods
{
    my ($DB, $APP, $user_id) = @_;

    return 1 if $APP->isAdmin($user_id);
    return 0;
}

sub usergroupninjagirls
{
    my ($DB, $APP, $user_id) = @_;

    return $APP->inUsergroup($user_id,'ninjagirls','nogods');
}

sub usergroupvalhalla
{
    my ($DB, $APP, $user_id) = @_;

    return $APP->inUsergroup($user_id,'valhalla', "nogods");
}

sub usernate
{
    my ($DB, $APP, $user_id) = @_;

    return 1 if $user_id == 220;
    return 0;
}

sub votes01000
{
    my ($DB, $APP, $user_id) = @_;

    my $voteCount = $DB->sqlSelect("count(*)","vote","voter_user=$user_id");

    return 1 if $voteCount >= 1000;
    return 0;
}

sub votes05000
{
    my ($DB, $APP, $user_id) = @_;

    my $voteCount = $DB->sqlSelect("count(*)","vote","voter_user=$user_id");

    return 1 if $voteCount >= 5000;
    return 0;
}

sub votes10000
{
    my ($DB, $APP, $user_id) = @_;

    my $voteCount = $DB->sqlSelect("count(*)","vote","voter_user=$user_id");

    return 1 if $voteCount >= 10000;
    return 0;
}

sub votes50000
{
    my ($DB, $APP, $user_id) = @_;

    my $voteCount = $DB->sqlSelect("count(*)","vote","voter_user=$user_id");

    return 1 if $voteCount >= 50000;
    return 0;
}

sub wheelspin1000
{
    my ($DB, $APP, $user_id) = @_;

    my $uVars = getVars(getNodeById($user_id));
    return 1 if $$uVars{spin_wheel} >=1000;
    return 0;
}

sub writeups0100
{
    my ($DB, $APP, $user_id) = @_;

    my $writeupCount = $DB->sqlSelect("count(*)","node","author_user=$user_id and type_nodetype=117");
    return 1 if $writeupCount >= 100;
    return 0;
}

sub writeups0500
{
    my ($DB, $APP, $user_id) = @_;

    my $writeupCount = $DB->sqlSelect("count(*)","node","author_user=$user_id and type_nodetype=117");
    return 1 if $writeupCount >= 500;
    return 0;
}

sub writeups1000
{
    my ($DB, $APP, $user_id) = @_;

    my $writeupCount = $DB->sqlSelect("count(*)","node","author_user=$user_id and type_nodetype=117");
    return 1 if $writeupCount >= 1000;
    return 0;
}

sub writeupsmonth10
{
    my ($DB, $APP, $user_id) = @_;

    my $maxWusInAMonth = $DB->sqlSelect(
	"nwus",
	"(SELECT Year(publishtime) AS year,
			Month(publishtime) AS month,
			count(*) AS nwus
		FROM node JOIN writeup ON node_id=writeup_id
		WHERE type_nodetype=117
			AND author_user=$user_id
		GROUP BY year,month
		ORDER BY nwus desc limit 1) AS maxnwus"
	);
    return 1 if $maxWusInAMonth >= 10;
    return 0;
}

sub writeupsmonth20
{
    my ($DB, $APP, $user_id) = @_;

    my $maxWusInAMonth = $DB->sqlSelect(
	"nwus",
	"(SELECT Year(publishtime) AS year,
			Month(publishtime) AS month,
			count(*) AS nwus
		FROM node JOIN writeup ON node_id=writeup_id
		WHERE type_nodetype=117
			AND author_user=$user_id
		GROUP BY year,month
		ORDER BY nwus desc limit 1) AS maxnwus"
	);
    return 1 if $maxWusInAMonth >= 20;
    return 0;
}

sub writeupsmonth30
{
    my ($DB, $APP, $user_id) = @_;

    my $maxWusInAMonth = $DB->sqlSelect(
	"nwus",
	"(SELECT Year(publishtime) AS year,
			Month(publishtime) AS month,
			count(*) AS nwus
		FROM node JOIN writeup ON node_id=writeup_id
		WHERE type_nodetype=117
			AND author_user=$user_id
		GROUP BY year,month
		ORDER BY nwus desc limit 1) AS maxnwus"
	);
    return 1 if $maxWusInAMonth >= 30;
    return 0;
}

sub writeupsmonthmost
{
    my ($DB, $APP, $user_id) = @_;

    return 0;
}

sub writeupsnuked100
{
    my ($DB, $APP, $user_id) = @_;

    my $heavenCount =
      $DB->sqlSelect(
        "count(*)"
        , "heaven JOIN node AS type ON type.node_id = heaven.type_nodetype AND type.title = 'writeup'"
        , "heaven.author_user=$user_id"
      );

    return 1 if $heavenCount >=100;
    return 0;
}

1;
