package Everything::Router;

use diagnostics;
use Moose;
use namespace::autoclean;
use Everything;
use Everything::Request;

with 'Everything::Globals';
with 'Everything::HTTP';

has 'CONTROLLER_TABLE' => (isa => "HashRef", is => "ro", builder => "_build_controller_table", lazy => 1);
has 'CONTROLLER_TYPE' => (is => 'ro', isa => 'Str', default => 'Controller');

sub _build_controller_table
{
  my ($self, $plugin_type) = @_;
  return $self->APP->plugin_table($plugin_type || $self->CONTROLLER_TYPE);
}

sub dispatcher
{
  my ($self) = @_;
  my $REQUEST = Everything::Request->new; 
  return $self->output($REQUEST, [$self->HTTP_UNIMPLEMENTED]);
}

sub output
{
  my ($self, $REQUEST, $output) = @_;

  my $response_code = $output->[0];
  my $data = $output->[1];
  my $headers = $output->[2] || {};

  $headers->{status} ||= $response_code;
  $headers->{charset} ||= "utf-8";
  $headers->{type} ||= "text/html";

  if($self->CONF->environment eq "development")
  {
    $headers->{'-Access-Control-Allow-Origin'} = '*';
  }

  if($data)
  {
    if(my $best_compression = $self->APP->compress_response_body)
    {
      $headers->{content_encoding} = $best_compression;
    }
  }

  # Handle cookies passed from API handlers in $output->[2]->{cookie}
  # NOTE: Do NOT use $Everything::HTML::USER->{cookie} here - that's a stale global
  # from HTML page requests that persists across mod_perl requests, causing random
  # logouts when a logout cookie from one user's session gets sent to another user's
  # API request that happens to land on the same Apache worker.
  if ($headers->{cookie}) {
    # Cookie was explicitly set by the API handler - ensure response isn't cached
    $headers->{'Cache-Control'} = "private, no-cache, no-store, must-revalidate";
  }

  print $REQUEST->header($headers);
  if($data)
  {
    if($headers->{type} eq "application/json")
    {
      print $self->APP->optimally_compress_page($self->JSON->encode($data));
    }else{
      print $self->APP->optimally_compress_page($data);
    }
  }

  return 1; # Indicate success for callers checking route result
}

__PACKAGE__->meta->make_immutable;
1;
