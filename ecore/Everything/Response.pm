package Everything::Response;

use Moose;
use Mason;
use CGI;

has "PAGEDATA" => (isa => "HashRef", is => "rw", default => sub { {} });
has "HEADERS" => (isa => "HashRef", is => "rw", default => sub { {} });
has "CGI" => (isa => "CGI", is => "ro", default => sub { return CGI->new() });

has "USER" => (isa => "HashRef", is => "ro", required => 1);
has "VARS" => (isa => "HashRef", is => "ro", required => 1);
has "NODE" => (isa => "HashRef", is => "ro", required => 1);

has 'mason' => (is => "ro", isa => 'Mason::Interp', builder => "mason_init", lazy => 1);

# TODO: implement notemplate.mc
has 'template' => (is => "rw", isa => 'Str', default => "notemplate.mc");
has 'mime_type' => (is => "rw", isa => 'Str', default => "text/html");
has 'return_code' => (is => "rw", isa => 'Str', default => "500"); 

sub mason_init
{
  my ($this) = @_;
  return Mason->new(
    comp_root => $this->CONF->{basedir}."/template",
    data_dir => $this->CONF->{basedir}."/compile",
  );
}

has "APP" => (isa => "Everything::Application", is => "ro", required => 1);
has "CONF" => (isa => "HashRef", is => "ro", required => 1);

sub render
{
  my ($this) = @_;
  #TODO: Auto-prepend / if it doesn't exist

  return $this->mason->run("/".$this->template, %{$this->build_mason_args})->output();
}

sub build_mason_args
{
  my ($this) = @_;
  return { %{$this->PAGEDATA}, "NODE" => $this->NODE, "USER" => $this->USER};
}

sub make_block
{
  my ($this, $template, $properties) = @_;

  #TODO: Auto-prepend / if it doesn't exist
  return $this->mason->run("/".$template, {%$properties, "NODE" => $this->NODE, "USER" => $this->USER})->output();
}

1;
