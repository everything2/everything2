package Everything::Configuration;

use Moose;
use Carp qw(croak);
use JSON;
use namespace::autoclean;

has 'configfile' => (isa => 'Maybe[Str]', is => 'ro');
has 'configdir' => (isa => 'Str', is => 'ro', default => '/etc/everything');
has 'site_url' => (isa => 'Str', is => 'ro', required => 1, default => 'https://everything2.com');
has 'guest_user' => (isa => 'Int', is => 'ro', required => 1, default => '779713');
has 'basedir' => (isa => 'Str', is => 'ro', default => '/var/everything');

has 'infected_ips' => (isa => 'ArrayRef', is => 'ro', builder => '_build_infected', lazy => 1);
has 'default_style' => (isa => 'Str', is => 'ro', default => 'Kernel Blue');

# Database options
#
# TODO: Rename this to be something that makes it clear that it is the database user
has 'everyuser' => (isa => 'Str', is => 'ro', default => 'everyuser');
# TODO: Rename this to be something that makes it clear that it is the database password
has 'everypass' => (isa => 'Str', is => 'ro', builder => '_build_everypass', lazy => 1);
has 'everything_dbserv' => (isa => 'Str', is => 'ro', default => 'localhost');
has 'database' => (isa => 'Str', is => 'ro', default => 'everything');

has 'cookiepass' => (isa => 'Str', is => 'ro', default => 'userpass');

has 'canonical_web_server' => (isa => 'Str', is => 'ro', default => 'localhost');

has 'homenode_image_host' => (isa => 'Str', is => 'ro', default => 'hnimagew.everything2.com');

# SMTP options
has 'mail_from' => (isa => 'Str', is => 'ro', default => 'accounthelp@everything2.com');

has 'nodecache_size' => (isa => 'Int', is => 'ro', default => 200);

has 'environment' => (isa => 'Str', is => 'ro', default => 'development');

has 's3' => (isa => 'HashRef', is => 'ro', default => sub { {} });

has 'static_nodetypes' => (isa => 'Bool', is => 'ro', default => 1);

has 'clean_search_words_aggressively' => (isa => 'Bool', is => 'ro', default => 1);

has 'search_row_limit' => (isa => 'Int', is => 'ro', default => 200);

has 'logdirectory' => (isa => 'Str', is => 'ro', default => '/var/log/everything');

has 'use_local_javascript' => (isa => 'Bool', is => 'ro', default => '0');

# TODO: Get rid of this
has 'system' => (isa => 'HashRef', is => 'ro', default => sub { {} });

has 'permanent_cache' => (isa => 'HashRef', is => 'ro', default => sub { {} });

has 'nosearch_words' => (isa => 'HashRef', is => 'ro', default => sub { {} });

has 'create_room_level' => (isa => 'Int', is => 'ro', default => 5);
has 'stylesheet_fix_level' => (isa => 'Int', is => 'ro', default => 2);
has 'maintenance_mode' => (isa => 'Bool', is => 'ro', default => 0);
has 'writeuplowrepthreshold' => (isa => 'Int', is => 'ro', default => '-8');
has 'google_ads_badnodes' => (isa => 'ArrayRef', is => 'ro', default => sub { [] });
has 'google_ads_badwords' => (isa => 'ArrayRef', is => 'ro', default => sub { [] });

has 'use_controllers' => (isa => 'Bool', is => 'ro', default => 0);

has 's3host' => (isa => 'Str', is => 'ro', default => 's3-us-west-2.amazonaws.com');

has 'iam_app_role' => (isa => 'Str', is => 'ro', default => '');

has 'recaptcha_v3_secret_key' => (isa => 'Str', is => 'ro', builder => '_build_recaptcha', lazy => 1);
has 'recaptcha_v3_public_key' => (isa => 'Str', is => 'ro', default => '');

has 'login_location' => (isa => 'Str', is => 'ro', default => '/node/superdoc/login');

has 'blacklist_interval' => (isa => 'Str', is => 'ro', default => '3 MONTH');


around BUILDARGS => sub
{
  my $orig = shift;
  my $class = shift;

  my $configfile;
  my $args;
  my $config = {}; 

  if(@_ == 0)
  {
    $configfile = '/etc/everything/everything.conf.json';
  }elsif((@_ == 1) and (!(ref $_[0])))
  {
    # If there is one arg, assume it is the configfile
    $configfile = $_[0];
  }else{
    # Otherwise it is a hashref or more than one arg
    if(!ref $_[0])
    {
      $args = {@_};
    }else{
      $args = $_[0];
    }

    $configfile = $args->{configfile};
  }

  if($configfile)
  {
    my ($json_handle, $json_data);
    if(open $json_handle,'<',$configfile)
    {
      local $/ = undef;
      $json_data = <$json_handle>;
    }else{
      croak("Could not open configuration file '$configfile': $!");
    }

    close $json_handle;
    $config = JSON::from_json($json_data);
    $config->{configfile} = $configfile;

  }
  
  # If alternate keys, overwrite config file keys
  foreach my $arg (keys %$args)
  {
    $config->{$arg} = $args->{$arg};
  }

  return $class->$orig($config);
};

sub _build_everypass
{
  my ($self) = @_;
  return $self->_filesystem_default('database_password_secret', '');
}

sub _build_recaptcha
{
  my ($self) = @_;
  return $self->_filesystem_default('recaptcha_v3_secret','');
}

sub _filesystem_json_default
{
  my ($self, $location, $default) = @_;
  $default = $self->_filesystem_default($location,$default);

  if(not defined $default or $default eq '')
  {
    return [];
  }else{
    return JSON::from_json($default);
  }
}
sub _build_infected
{
  my ($self) = @_;

  return $self->_filesystem_json_default('infected_ips_secret','');
}

sub _filesystem_default
{
  my ($self, $location, $default) = @_;

  my $secretfile = $self->configdir."/$location";

  if(-e $secretfile)
  {
    if(open(my $fh, "<", $secretfile))
    {
      local $/ = undef;
      $default = <$fh>;
      close $fh;
    }else{
      croak("Could not open secret file on disk: $secretfile: $!");
    }
  }
  chomp($default);
  return $default
}

__PACKAGE__->meta->make_immutable;
1;
