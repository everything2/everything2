package Everything::Request;

use strict;
use Moose;
use namespace::autoclean;
use CGI;

has 'cgi' => (lazy => 1, builder => "_build_cgi", isa => "CGI", handles => ["param", "header", "cookie"], is => "rw");
has 'USER' => (lazy => 1, builder => "_build_user", isa => "HASHREF", is => "rw");
has 'VARS' => (lazy => 1, builder => "_build_vars", isa => "HASHREF", is => "rw");
has 'CONF' => (isa => "HASHREF", is => "rw");
has 'DB' => (isa => "Everything::NodeBase", is => "rw");
has 'APP' => (isa => "Everything::Application", is => "ro");

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

__PACKAGE__->meta->make_immutable;

1;
