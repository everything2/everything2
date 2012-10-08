package Everything::Search;

#############################################################################
#       Everything::Search
#               Searching functionality for Everything.
#
#				Implements the searchwords table to facilitate indexed
#				lookups of search terms.  Soundex comparison and
#				'any/all' matching are available options.
#
#		Revision History
#			00Jan31		jpt@mindless.com	Created. Version 0.1.
#			00Mar20		nate@oostendorp.net	Modified for everything2.com
#
#       Format: tabs = 4 spaces
#
#############################################################################

use strict;
use Everything;

sub BEGIN
{
	use Exporter ();
	use vars	   qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@ISA=qw(Exporter);
	@EXPORT=qw(
		makeClean
		makeCleanWords
		cleanWordAggressive
		searchNodeName
		regenSearchwords
		insertSearchWord
		removeSearchWord
        );
 }

sub cleanWordAggressive
{
	return $APP->cleanWordAggressive(@_);
}

sub makeClean
{
	return $APP->makeClean(@_);
}

sub makeCleanWords
{
	return $APP->makeCleanWords(@_);
}
sub searchNodeName {
	return $APP->searchNodeName(@_);
}

sub insertSearchWord {
	return $APP->insertSearchWord(@_);
}

sub removeSearchWord {
	return $APP->removeSearchWord(@_);
}

sub regenSearchwords
{
	return $APP->regenSearchwords(@_);
}

#############################################################################
# end of package
#############################################################################

1;
