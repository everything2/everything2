package Everything::MAIL;

############################################################
#
#	Everything::MAIL.pm
#
############################################################

use strict;
use Everything;

sub BEGIN {
	use Exporter ();
	use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@ISA=qw(Exporter);
	@EXPORT=qw(node2mail);
}


sub node2mail
{
	$APP->node2mail(@_);
}

1;
