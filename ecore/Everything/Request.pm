package Everything::Request;

use strict;
use Moose;
use CGI;

has 'cgi' => (lazy => 1, builder => _build_cgi, isa => "CGI", handles => ["param", "header", "cookie"])
has 'USER' => (lazy => 1, builder => _build_user, isa => "HASHREF");
has 'VARS' => (lazy => 1, builder => _build_vars, isa => "HASHREF");
has 'CONF' => (isa => "HASHREF");
has 'DB' => (isa => "Everything::NodeBase");
has 'APP' => (isa => "Everything::Application");

sub _build_user
{
  my $self = shift;
}

sub _build_vars
{
  my $self = shift;
}

sub _build_cgi
{
  my $self = shift;

  my $cgi;
	
  if ($ENV{SCRIPT_NAME}) { 
    $cgi = new CGI;
  } else {
    $cgi = new CGI(\*STDIN);
  }

  if (not defined ($cgi->param("op")))
  {
    $cgi->param("op", "");
  }

  return $cgi;
}

1;
