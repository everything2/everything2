package Everything::Configuration;

use Moose;
use Carp qw(croak);
use JSON;
use namespace::autoclean;

has 'configfile' => (isa => 'Maybe[Str]', is => 'ro');
has 'site_url' => (isa => 'Str', is => 'ro', required => 1);
has 'guest_user' => (isa => 'Int', is => 'ro', required => 1);
has 'basedir' => (isa => 'Str', is => 'ro', default => '/var/everything');

# TODO: Make this an array of ipaddress objects
has 'infected_ips' => (isa => 'ArrayRef', is => 'ro', default => sub { [] });
has 'default_style' => (isa => 'Str', is => 'ro', required => 1);

# Database options
#
# TODO: Rename this to be something that makes it clear that it is the database user
has 'everyuser' => (isa => 'Str', is => 'ro', default => 'everyuser');
# TODO: Rename this to be something that makes it clear that it is the database password
has 'everypass' => (isa => 'Str', is => 'ro', default => '');
has 'everything_dbserv' => (isa => 'Str', is => 'ro', default => 'localhost');
has 'database' => (isa => 'Str', is => 'ro', default => 'everything');

has 'cookiepass' => (isa => 'Str', is => 'ro', default => 'userpass');

has 'canonical_web_server' => (isa => 'Str', is => 'ro', default => 'localhost');

has 'homenode_image_host' => (isa => 'Str', is => 'ro', default => 'localhost');

# SMTP options
has 'smtp_host' => (isa => 'Str', is => 'ro', default => 'localhost');
has 'smtp_use_ssl' => (isa => 'Bool', is => 'ro', default => 1);
has 'smtp_port' => (isa => 'Int', is => 'ro', default => 465);
has 'smtp_user' => (isa => 'Str', is => 'ro', default => '');
has 'smtp_pass' => (isa => 'Str', is => 'ro', default => '');
has 'mail_from' => (isa => 'Str', is => 'ro', default => 'root@localhost');

# Database backup job notification email
has 'notification_email' => (isa => 'Maybe[Str]', is => 'ro');
has 'nodecache_size' => (isa => 'Int', is => 'ro', default => 200);

has 'environment' => (isa => 'Str', is => 'ro', default => 'development');

has 's3' => (isa => 'HashRef', is => 'ro', default => sub { {} });

has 'static_nodetypes' => (isa => 'Bool', is => 'ro', default => 1);

# Unsure of what the suboptions here are; we don't currently use the memcache code in production
has 'memcache' => (isa => 'HashRef', is => 'ro', default => sub { {} });

has 'clean_search_words_aggressively' => (isa => 'Bool', is => 'ro', default => 1);

has 'search_row_limit' => (isa => 'Int', is => 'ro', default => 200);

has 'logdirectory' => (isa => 'Str', is => 'ro', default => '/var/log/everything');

has 'use_local_javascript' => (isa => 'Bool', is => 'ro', default => '0');

# TODO: Get rid of this
has 'system' => (isa => 'HashRef', is => 'ro', default => sub { {} });

has 'permanent_cache' => (isa => 'HashRef', is => 'ro', default => sub { {} });

has 'nosearch_words' => (isa => 'HashRef', is => 'ro', default => sub { {} });

has 'create_room_level' => (isa => 'Int', is => 'ro', default => 1);
has 'stylesheet_fix_level' => (isa => 'Int', is => 'ro', default => 0);
has 'maintenance_mode' => (isa => 'Bool', is => 'ro', default => 0);
has 'writeuplowrepthreshold' => (isa => 'Int', is => 'ro', default => '-8');
has 'google_ads_badnodes' => (isa => 'ArrayRef', is => 'ro', default => sub { [] });
has 'google_ads_badwords' => (isa => 'ArrayRef', is => 'ro', default => sub { [] });

has 'use_controllers' => (isa => 'Bool', is => 'ro', default => 0);

has 's3host' => (isa => 'Str', is => 'ro', default => '');

has 'iam_app_role' => (isa => 'Str', is => 'ro', default => '');

has 'recaptcha_v3_secret_key' => (isa => 'Str', is => 'ro', default => '');
has 'recaptcha_v3_public_key' => (isa => 'Str', is => 'ro', default => '');


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

__PACKAGE__->meta->make_immutable;
1;
