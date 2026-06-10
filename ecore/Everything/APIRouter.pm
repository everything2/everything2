package Everything::APIRouter;

use diagnostics;
use Moose;
use Scalar::Util qw(blessed);
use Everything::Response;
extends 'Everything::Router';

has 'CONTROLLER_TYPE' => (is => 'ro', isa => 'Str', default => 'API');

sub dispatcher
{
  my ($self) = @_;
  my $REQUEST = Everything::Request->new;
  my $urlform = $REQUEST->url(-absolute=>1);
  my $method = lc($REQUEST->request_method());

  if(not grep {$method} ("get","put","post","delete","patch"))
  {
    return $self->output($REQUEST, [$self->HTTP_METHOD_NOT_ALLOWED]);
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
