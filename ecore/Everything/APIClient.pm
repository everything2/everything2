package Everything::APIClient;

use Moose;
use LWP::UserAgent;
use HTTP::Cookies;
use HTTP::Request;
use namespace::autoclean;
use JSON;

with 'Everything::HTTP';

has 'ua' => (is => 'ro', isa => 'LWP::UserAgent', lazy => 1, builder => "_build_ua");
has 'session' => (is => 'rw', isa => 'HashRef', lazy => 1, builder => "_build_session");
has 'endpoint' => (is => 'ro', required => 1, default => "https://everything2.com/api");
has 'json' => (is => 'ro', lazy => 1, builder => "_build_json");

sub username
{
  my ($self) = @_;
  return $self->session->{username};
}

sub _build_json
{
  my ($self) = @_;
  return JSON->new();
}

sub _build_ua
{
  my ($self) = @_;
  my $cookies = HTTP::Cookies->new();
  my $ua = LWP::UserAgent->new();
  $ua->cookie_jar($cookies);

  return $ua;
}

sub _build_session
{
  my ($self) = @_;
  my $response = $self->ua->get($self->endpoint."/sessions");
  if($response->code == $self->HTTP_OK)
  {
    $self->session($self->json->decode($response->content));
  }
}

sub login
{
  my ($self, $username, $passwd) = @_;

  if($username and $passwd)
  {
    my $request = HTTP::Request->new("POST", $self->endpoint."/sessions/create");
    $request->header('Content-Type' => 'application/json');
    $request->content($self->json->encode({"username" => $username, "passwd" => $passwd}));
    my $response = $self->ua->request($request);
 
    if($response->code == $self->HTTP_OK)
    {
      $self->session($self->json->decode($response->content));
    }

    return $respose->code;
  }else{
    return;
  }
}

1;
