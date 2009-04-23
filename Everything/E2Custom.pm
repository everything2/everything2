
#
#	A module to enhance functionality of Everything2	
#
#	Kyle Hale 2007
###########################################################################

use strict;
use Everything;

sub BEGIN
{
	use Exporter ();
	use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@ISA=qw(Exporter);
	@EXPORT=qw(
		onNodeRow
	);

}

#######################################################################
#
#	isEditor
#
#	given a user, return whether they are an editor
#

sub onNodeRow {
return 0;
}

sub linkNode2 {
my ($NODE, $title) = @_;
getRef($NODE);
my $nType = $$NODE{type}{title};
my $nTitle = $$NODE{title}; 

"<a href='./$nType/$nTitle'>$title</a>";

}


sub linkNodeTitle2 {
        my ($nodename, $lastnode, $title) = @_;
        ($nodename, $title) = split /\|/, $nodename;
        $title ||= $nodename;
        $nodename =~ s/\s+/ /gs;
        my $tip = $nodename;
        $tip =~ s/"/''/g;

my $exists = getNodeWhere({title => $nodename});

        my $urlnode = CGI::escape($nodename);
        my $str = "";
        $str .= "<a title=\"$tip\" href=\"$ENV{SCRIPT_NAME}?node=$urlnode";
        if ($lastnode) { $str .= "&amp;lastnode_id=" . getId($lastnode);}
        $str .= ( $exists ? "" : "class='unpopulated'" ) ."\">$title</a>";

        $str;
}


1;
