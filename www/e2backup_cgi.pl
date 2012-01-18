#!/usr/bin/perl -w
# e2backup_cgi.pl - gathers user nodes from everything2.com and lets 
# users download it from a server.
# Portions Copyright (C) 2000,2001 Will Woods <wwoods AT cowofdoom.com>
# Portions Copyright (C) 2001,2002,2003 Arthur Shipkowski aka "sleeping wolf" 
#                             <Art_Kowolf AT yahoo.com>
# Portions Copyright (C) 2003 J. Chatterton <cee aitch ay tee tee jay AT gmail>
# Distributed under the terms of the GNU General Public License,
# included here by reference.
#
# This program is being maintained by J. Chatterton, please email him
# at the address above with any questions, patches, etcetera.

use Archive::Zip; # This will itself require Compress::Zlib.
use LWP::UserAgent; # these are both part of libwww-perl, available
use CGI qw/unescapeHTML/; # The CGI package should be available at your friendly local CPAN mirror, too.
use HTTP::Request;

my $query = new CGI;
my $username = $query->param('username');
$username = lc($username);
my $singleFileMode = $query->param('singleFileMode');
my $sysdate = localtime;
my $baseurl = "http://www.everything2.com/index.pl";
my $ua = LWP::UserAgent->new(agent => "e2backup_cgi");
$ua->env_proxy();
# get the User Search XML page, and array-ify it
my @data = split(/\n/,&getusernameXMLTicker) or die "failed ($!)";
my $outputfilename = "../e2generated/".$username."_index.html";
my $zipfilename = "../e2generated/".$username."_index.zip";
if ($singleFileMode) {
    $outputfilename = "../e2generated/".$username.".html";
    $zipfilename = "../e2generated/".$username.".zip";
} 
sleep(3);
## Begin CGI output,
print "Content-type: text/html\n\n";
if (-e $zipfilename) { 
    ## put out a link to the already-generated content.
    if ($singleFileMode) {
        print "Content has already been generated in the past 24 hours. Right click and 
save it <a href=\"../e2generated/$username.zip\">here</a>.\n";
    } else {
        print "Content has already been generated in the past 24 hours. Right click and 
save it <a href=\"../e2generated/$username"."_index.zip\">here</a>.\n";
    }
    print "</body></html>\n";
    exit 1;
} else {
    ## New search. Create main file.
    open(NODEFILE, ">$outputfilename");
    print NODEFILE htmlheader();
    print NODEFILE "<center><big>Writeups by $username</big><br>Snapshot taken: $sysdate</center><br><br>\n";
    close(NODEFILE);
}

my $writeupcount = scalar(@data);
if ($writeupcount <= 1) {
    print "<p><b>E2 server error</b>, unable to get content for $username!</p>\n";
    print "<p>Check that the username is correct and try again in ten minutes.</p>\n";
    print "</body></html>\n";
    exit;
}
print "<p>Checking $writeupcount lines, please stand by until complete:</p>\n<p>\n";
$writeupcount = 0;
my %nodelist;
# Read the info out of the User Search page.
foreach (@data) { # loop over each line in the page
    $writeupcount++;
    print " $writeupcount "; 
    $| = 1; # Flush output to browser.
    if (/^<writeup/g) { # if this line is about a writeup..
        ## Put line's info into hash.
        while (/ (\w+)=\"(.*?)\"/gc) {
            $n{$1}=$2; 
        } 
        # get node info

        ($name, $type) = />(.*) \(([a-z]+)\)<\/writeup>/gc;
        $type =~ s///; ## I am tired of looking at the warning.
        $title = substr($name.' 'x59,0,59);
        $title =~ s/(.*)\w*?/$1/;
        my $createtime = $n{createtime};
        my $nodeid = $n{node_id};
        my $nodecontent = &getXMLwu($nodeid);
        if (!($nodecontent =~ m{<doctext>(\C*)</doctext>}is )) {
            print "<b>E2 server error</b>, unable to get content for $name";
        }
        $nodecontent = &unescapeHTML($1);
        ## Create a friendly html-ish formatted writeup.
        my $htmlformat = "";
        if (!($singleFileMode)) {
            $htmlformat .= htmlheader();
        }
        $htmlformat .= "<!-- Below is e2 node #$nodeid -->\n";
        $htmlformat .= '<table border="3" bordercolor="000000"><tr><td>'."\n";
        $htmlformat .= "<b>Node title:</b> <a href=\"http://www.everything2.com/index.pl?node_id=$nodeid\">$name</a> <br> \n";
        $htmlformat .= "<b>Submit date:</b> $createtime\n";
        $htmlformat .= "</td></tr></table>\n";
        $htmlformat .= $nodecontent . "\n";
        $htmlformat .= "<br><br><br>\n";
        ## Open whatever should be open. 
        if($singleFileMode) {
            open(NODEFILE, ">>$outputfilename");
        } else {
            ## Relies on nodeid being unique.
            open(IDXFILE, ">>$outputfilename");
            print IDXFILE "<a href=\"$nodeid.html\">$name</a><br>\n";
            $nodelist{$nodeid} = 1;
            close(IDXFILE);
            my $singlefilename = "../e2generated/".$nodeid.".html";
            open(NODEFILE, ">$singlefilename");
        }
        ## Add the content.
        print NODEFILE $htmlformat;
        close(NODEFILE);
    }
    sleep(3);
}
print "<b>Done!</b></p>\n";
## Archive and delete downloaded data.
my $zip = Archive::Zip->new();
my $zname = "$username.zip";
if ($singleFileMode) {
    $zip->addFile($outputfilename, "$username.html");
    $zip->writeToFileNamed("../e2generated/$username.zip");
    
} else {
    my @keys = keys %nodelist;
    $zip->addFile($outputfilename, "$username\_index.html");
    foreach $nodeid (@keys) {
        $zip->addFile("../e2generated/$nodeid.html", "$nodeid.html");
    }
    $zip->writeToFileNamed("../e2generated/$username\_index.zip");
    foreach $nodeid (@keys) {
        unlink("../e2generated/$nodeid.html");
    }
    $zname = "$username\_index.zip";
}
unlink($outputfilename);
print "<p>Right click and save this zip file: <a href=\"$zipfilename\">$zname</a></p>\n";
print "</body></html>\n";

########## Subs are delicious. ##########

## Gets the node list for a given username. Seems to be
## case-insensitive, at the discretion of everything2.
sub getusernameXMLTicker {
    # 762826 = User Search XML Ticker
    my $req = HTTP::Request->new('GET', "$baseurl?node_id=762826&usersearch=$username");
    return ($ua->request($req)->content());
}
# takes one argument: $node_id
# assumes that $ua is a valid HTTP::UserAgent object
# returns the contents of the XML writeup page in a scalar variable
sub getXMLwu {
    my $req = HTTP::Request->new('GET', "$baseurl?node_id=$_[0]&displaytype=xmltrue");
    return($ua->request($req)->content());
}
## Returns a valid html header. Prettier code than having it above.
sub htmlheader {
    my $header = '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">'."\n";
    $header .= "<html><head></head><body>\n";
    return $header;
}
