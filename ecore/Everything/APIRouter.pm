package Everything::APIRouter;

use Moose;
use Scalar::Util qw(blessed);
use Everything::Response;
extends 'Everything::Router';

has 'CONTROLLER_TYPE' => (is => 'ro', isa => 'Str', default => 'API');

my %ALLOWED_METHODS = map { $_ => 1 } qw(get put post delete patch);

sub dispatcher
{
  my ($self) = @_;
  my $REQUEST = Everything::Request->new;

  # Node maintenance hooks (Everything::Delegation::maintenance, via
  # NodeBase::nodeMaintenance) read the request globals that the page path sets in
  # Everything::HTML::mod_perlInit. Set them for this request: an API call carries no
  # form query, and the acting user is this request's user.
  $Everything::HTML::query = '';
  $Everything::HTML::GNODE = '';
  $Everything::HTML::USER  = $REQUEST->user->NODEDATA;
  $Everything::HTML::VARS  = $REQUEST->user->VARS;

  my $urlform = $REQUEST->url(-absolute=>1);
  my $method = lc($REQUEST->request_method());

  unless($ALLOWED_METHODS{$method})
  {
    return $self->output($REQUEST, [$self->HTTP_UNIMPLEMENTED]);   # 405
  }

  unless($self->is_site_api_request($REQUEST))
  {
    return $self->output($REQUEST, [$self->HTTP_OK, {success => 0, error => 'API requests must be made by the site itself'}]);
  }

  if($self->CONF->maintenance_message)
  {
    return $self->output($REQUEST, $self->CONTROLLER_TABLE->{catchall}->$method($REQUEST));
  }

  if(my ($endpoint, $extra) = $urlform =~ m|^/api/([^/]+)/?(.*)|)
  {
    if(exists $self->CONTROLLER_TABLE->{$endpoint})
    {
      return $self->output($REQUEST, $self->CONTROLLER_TABLE->{$endpoint}->route($REQUEST, $extra));
    }else{
      # Request fell through to catchall after CONTROLLER_TABLE check
      return $self->output($REQUEST, $self->CONTROLLER_TABLE->{catchall}->$method($REQUEST));
    }
  }else{
    # Request fell through to catchall after form check
    return $self->output($REQUEST, $self->CONTROLLER_TABLE->{catchall}->$method($REQUEST));
  }
}

# Browsers label every request with Fetch Metadata (Sec-Fetch-Site/-Mode/-Dest). The site's
# own pages call the API with fetch()/XHR (mode cors or same-origin) or sendBeacon (no-cors,
# dest empty), always from the same origin. Anything else a browser sends here isn't the site
# calling its API: following a link, submitting a form, loading an image or script, or a
# request from another origin, other everything2.com hosts included. Those are refused.
# Requests without Fetch Metadata (scripts, curl, API clients, older browsers) are unaffected.
sub is_site_api_request
{
  my ($self, $REQUEST) = @_;
  my $req  = $REQUEST->req;
  my $site = lc( $req->header('Sec-Fetch-Site') // '' );
  my $mode = lc( $req->header('Sec-Fetch-Mode') // '' );
  my $dest = lc( $req->header('Sec-Fetch-Dest') // '' );

  return 1 unless length $site or length $mode;
  return 0 if length $site and $site ne 'same-origin' and $site ne 'none';
  return 0 if $mode eq 'navigate' or $mode eq 'nested-navigate';
  return 0 if $mode eq 'no-cors' and length $dest and $dest ne 'empty';
  return 1;
}

# Return-based emission (replaces the page path's print-into-capture for the API).
# Every API response is JSON; force type/charset (was the old `around 'output'`),
# build the shared parts, and RETURN an Everything::Response instead of printing.
# app.psgi finalizes it directly -- so the API response never touches the STDOUT
# capture (immune to the #4237 capture-poisoning class). The page path keeps using
# the inherited print-based Everything::Router::output. See docs/api-driven-architecture.md.
sub output
{
  my ($self, $REQUEST, $output) = @_;

  $output->[2] ||= {};
  $output->[2]->{charset} = "utf-8";
  $output->[2]->{type}    = "application/json";

  # Fold in any cookies set as a side effect of the request flow (Everything::Request::login
  # on explicit credential login accumulates the Set-Cookie there instead of relying on the
  # now-bypassed STDOUT capture). Merge with any cookie a handler set explicitly (e.g. the
  # logout delete-cookie). _build_response_parts then pairs them with the no-store Cache-Control.
  if(@{$REQUEST->response_cookies})
  {
    my $existing = $output->[2]->{cookie};
    my @cookies = defined($existing) ? (ref $existing eq 'ARRAY' ? @$existing : $existing) : ();
    push @cookies, @{$REQUEST->response_cookies};
    $output->[2]->{cookie} = \@cookies;
  }

  my ($headers, $body) = $self->_build_response_parts($output);
  return Everything::Response->from_cgi_parts($headers, $body);
}

# True when a dispatcher result is a return-based response app.psgi should finalize
# (vs. the page path's printed-to-capture sentinel). Keeps the app.psgi edge simple.
sub is_response
{
  my ($self, $thing) = @_;
  return blessed($thing) && $thing->isa('Everything::Response');
}

__PACKAGE__->meta->make_immutable;
1;
