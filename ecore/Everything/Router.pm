package Everything::Router;

use diagnostics;
use Moose;
use namespace::autoclean;
use Everything;
use Everything::Request;
use Everything::Response;

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

# Build the (\%headers, $body_bytes) for an [$status, $data, \%headers] controller
# result -- the pure, I/O-free half of response emission. Both emission paths share
# it: the page path (output, below) prints these into the STDOUT capture; the API
# path (Everything::APIRouter::output) hands them to Everything::Response->from_cgi_parts
# and RETURNS the response for app.psgi to finalize (no capture). Sharing the builder
# keeps the two paths byte-equivalent. $body is undef for a header-only response.
sub _build_response_parts
{
  my ($self, $output) = @_;

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

  my $body;
  if($data)
  {
    if($headers->{type} eq "application/json")
    {
      $body = $self->APP->optimally_compress_page($self->JSON->encode($data));
    }else{
      $body = $self->APP->optimally_compress_page($data);
    }
  }

  return ($headers, $body);
}

sub output
{
  my ($self, $REQUEST, $output) = @_;

  my ($headers, $body) = $self->_build_response_parts($output);

  # Return-based page path (#4483, Step 1b): stash the Response on the request instead of
  # printing header+body into the STDOUT capture. This is the single main-body emission point
  # for every page controller (route_node -> output). We pair the SAME ($headers, $body) with
  # Everything::Response->from_cgi_parts that the API path already returns -- byte-equivalent by
  # construction (t/131) -- so mod_perlInit returns it and app.psgi finalizes directly, immune
  # to the #4237 capture-poisoning class. Unconverted sites still print -> app.psgi falls through.
  $REQUEST->response(Everything::Response->from_cgi_parts($headers, $body));

  return 1; # Indicate success for callers checking result
}

__PACKAGE__->meta->make_immutable;
1;
