package Everything::Configuration;

use Moose;
use Everything::S3::BucketConfig;
use Carp qw(croak);
use Paws;
use LWP::UserAgent;
use JSON;
use namespace::autoclean;

has 'configfile' => (isa => 'Maybe[Str]', is => 'ro');
has 'configdir' => (isa => 'Str', is => 'ro', default => '/etc/everything');
has 'site_url' => (isa => 'Str', is => 'ro', required => 1, default => 'https://everything2.com');
has 'guest_user' => (isa => 'Int', is => 'ro', required => 1, default => '779713');

has 'infected_ips' => (isa => 'ArrayRef', is => 'ro', builder => '_build_infected', lazy => 1);
has 'default_style' => (isa => 'Str', is => 'ro', default => 'Kernel Blue');

# Database options
# TODO: Rename this to be something that makes it clear that it is the database user
has 'everyuser' => (isa => 'Str', is => 'ro', default => 'everyuser');
# TODO: Rename this to be something that makes it clear that it is the database password
has 'everypass' => (isa => 'Str', is => 'ro', builder => '_build_everypass', lazy => 1);
has 'everything_dbserv' => (isa => 'Str', is => 'ro', default => 'localhost');
has 'everything_dbport' => (isa => 'Int', is => 'ro', default => 3306);

has 'database' => (isa => 'Str', is => 'ro', default => 'everything');

has 'cookiepass' => (isa => 'Str', is => 'ro', default => 'userpass');

has 'canonical_web_server' => (isa => 'Str', is => 'ro', default => 'localhost');

has 'homenode_image_host' => (isa => 'Str', is => 'ro', default => 'hnimagew.everything2.com');

# SMTP options
has 'mail_from' => (isa => 'Str', is => 'ro', default => 'accounthelp@everything2.com');

has 'nodecache_size' => (isa => 'Int', is => 'ro', default => 600);

has 'environment' => (isa => 'Str', is => 'ro', default => 'development');

has 's3' => (isa => 'HashRef', is => 'ro', default => sub { {
  "homenodeimages" => Everything::S3::BucketConfig->new("bucket" => "hnimagew.everything2.com"),
  "nodebackup" => Everything::S3::BucketConfig->new("bucket" => "nodebackup.everything2.com"),
  "sitemap" => Everything::S3::BucketConfig->new("bucket" => "sitemap.everything2.com"),
  "sitemapdispatch" => Everything::S3::BucketConfig->new("bucket" => "sitemapdispatch.everything2.com"),
  "jscss" => Everything::S3::BucketConfig->new("bucket" => "jscssw.everything2.com") }});

has 'current_region' => (isa => 'Maybe[Str]', is => 'ro', builder => '_build_current_region', lazy => 1);

has 'static_nodetypes' => (isa => 'Bool', is => 'ro', default => 1);

has 'clean_search_words_aggressively' => (isa => 'Bool', is => 'ro', default => 1);

has 'search_row_limit' => (isa => 'Int', is => 'ro', default => 200);

has 'logdirectory' => (isa => 'Str', is => 'ro', default => '/var/log/everything');

has 'use_local_javascript' => (isa => 'Bool', is => 'ro', default => '0');

has 'permanent_cache' => (isa => 'HashRef', is => 'ro', default => sub { {
  "usergroup" => 1,
  "container" => 1,
  "htmlcode" => 1,
  "maintenance" => 1,
  "setting" => 1,
  "fullpage" => 1,
  "nodetype" => 1,
  "writeuptype" => 1,
  "linktype" => 1,
  "sustype" => 1,
  "nodelet" => 1,
  "datastash" => 1,
  "theme" => 1
} });

has 'nosearch_words' => (isa => 'HashRef', is => 'ro', default => sub { {
  "a" => 1,
  "an" => 1,
  "and" => 1,
  "are" => 1,
  "at" => 1,
  "definition" => 1,
  "everything" => 1,
  "for" => 1,
  "if" => 1,
  "in" => 1,
  "is" => 1,
  "it" => 1,
  "my" => 1,
  "new" => 1,
  "node" => 1,
  "not" => 1,
  "of" => 1,
  "on" => 1,
  "that" => 1,
  "the" => 1,
  "thing" => 1,
  "this" => 1,
  "to" => 1,
  "we" => 1,
  "what" => 1,
  "why" => 1,
  "with" => 1,
  "writeup" => 1,
  "you" => 1,
  "your" => 1
} });

has 'create_room_level' => (isa => 'Int', is => 'ro', default => 5);
has 'stylesheet_fix_level' => (isa => 'Int', is => 'ro', default => 2);
has 'maintenance_mode' => (isa => 'Bool', is => 'ro', default => 0);
has 'writeuplowrepthreshold' => (isa => 'Int', is => 'ro', default => '-8');
has 'google_ads_badnodes' => (isa => 'ArrayRef', is => 'ro', default => sub { [] });
has 'google_ads_badwords' => (isa => 'ArrayRef', is => 'ro', default => sub { [
  "pussy",
  "fleshlight",
  "thrush",
  "hentai",
  "heroin",
  "kike",
  "vibrator",
  "boob",
  "breast",
  "butt",
  "ass",
  "lesbian",
  "cock",
  "dick",
  "penis",
  "sex",
  "oral",
  "anal",
  "drug",
  "pot",
  "weed",
  "crack",
  "cocaine",
  "fuck",
  "wank",
  "whore",
  "vagina",
  "vaginal",
  "vag",
  "cunt",
  "tits",
  "titty",
  "twat",
  "shit",
  "slut",
  "snatch",
  "queef",
  "queer",
  "poon",
  "prick",
  "puss",
  "orgasm",
  "nigg",
  "nuts",
  "muff",
  "motherfuck",
  "jizz",
  "hell",
  "homo",
  "handjob",
  "fag",
  "dildo",
  "dick",
  "clit",
  "cum",
  "bitch",
  "rape",
  "ejaculate",
  "bsdm",
  "fisting",
  "balling",
  "pornography",
  "blowjob",
  "masturbation",
  "fetish",
  "suicide",
  "cunnilingus"
] });

has 'use_controllers' => (isa => 'Bool', is => 'ro', default => 0);

has 's3host' => (isa => 'Str', is => 'ro', default => 's3-us-west-2.amazonaws.com');

has 'iam_app_role' => (isa => 'Str', is => 'ro', default => 'E2-App-Server');

has 'recaptcha_v3_secret_key' => (isa => 'Str', is => 'ro', builder => '_build_recaptcha', lazy => 1);
has 'recaptcha_v3_public_key' => (isa => 'Str', is => 'ro', default => '6LcnVKsUAAAAAEeEGV28mfD3lt_XVpFUkOzifWGo');

has 'login_location' => (isa => 'Str', is => 'ro', default => '/node/superdoc/login');
has 'permission_denied_location' => (isa => 'Str', is => 'ro', lazy => 1, default => sub {"/node/".$_[0]->permission_denied}); 


has 'blacklist_interval' => (isa => 'Str', is => 'ro', default => '3 MONTH');

has 'site_description' => (isa => 'Str', is => 'ro', default => 'Everything2 is a collection of user-submitted writings about more or less everything');

has 'site_name' => (isa => 'Str', is => 'ro', default => 'Everything2');
has 'create_new_user' => (isa => 'Int', is => 'ro', default => '2072173');
has 'default_guest_node' => (isa => 'Int', is => 'ro', default => '2030780');
has 'default_nodeletgroup' => (isa => 'Int', is => 'ro', default => '837990');
has 'default_node' => (isa => 'Int', is => 'ro', default => '124');
has 'default_duplicates_node' => (isa => 'Int', is => 'ro', default => '382987');
has 'not_found_node' => (isa => 'Int', is => 'ro', default => '668164');
has 'search_results' => (isa => 'Int', is => 'ro', default => '1140332');
has 'permission_denied' => (isa => 'Int', is => 'ro', default => '104');
has 'user_settings' => (isa => 'Int', is => 'ro', default => '108');
has 'guest_link' => (isa => 'Int', is => 'ro', default => '2014296');

has 'maintenance_nodes' => (isa => 'ArrayRef[Int]', is => 'ro', default => sub {[379710,364471,596824,171917,368049,174079,1428471]});

has 'logged_in_threshold' => (isa => 'Int', is => 'ro', default => 240);
has 'chatterbox_cleanup_threshold' => (isa => 'Int', is => 'ro', default => 500);
has 'room_cleanup_threshold' => (isa => 'Int', is => 'ro', default => 60*60*24*90);

has 'always_keep_rooms' => (isa => 'ArrayRef[Str]', is => 'ro', default => sub {["Valhalla", "Political Asylum", "M-Noder Washroom", "Noders Nursery", "Debriefing Room"]});


around BUILDARGS => sub
{
  my $orig = shift;
  my $class = shift;

  my $configfile;
  my $args;
  my $config = {}; 

  my $override = "/etc/everything/override_configuration";
  my $environment = "production";
  if(@_ == 0)
  {
    my $currentdir = "";
    foreach my $dir(@INC)
    {
      if(-e "$dir/Everything.pm")
      {
        $currentdir = $dir;
	last;
      }
    }

    if(-e $override)
    {
      my $fh;
      if(open $fh,'<',$override)
      {
        local $/ = undef;
	my $override_data = <$fh>;
	close $fh;

	$environment = $override_data;
      }else{
        croak("Could not open override file: '$override': $!");
      }
    }

  chomp $environment;

  my $variance = '';
  if(defined($ENV{'E2DOCKER'}) and $ENV{'E2DOCKER'} eq 'development')
  {
    $environment = "development";
    $variance = '-docker';
  }
  $configfile = "$currentdir/../etc/$environment$variance.json";
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

  # Stash the environment in
  $config->{environment} = $environment;

  # Temporary workaround until keys work correctly
  delete $config->{s3};

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

  my $pass = $self->_filesystem_default('database_password_secret', '');
  if($pass eq '' and $self->environment eq 'production')
  {
    my $service = Paws->service('SecretsManager', region => $self->current_region);
    foreach my $secret(@{$service->ListSecrets->SecretList})
    {
      if($secret->Name eq "E2DBMasterPassword")
      {
        my $secret = from_json($service->GetSecretValue(SecretId => $secret->ARN)->SecretString);
        $pass = $secret->{password};
      }
    }
  }
  return $pass;
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

# TODO: Make this a mixin
sub _build_current_region
{
  my ($self) = @_;

  my $region = $ENV{'AWS_REGION'} || $ENV{'AWS_DEFAULT_REGION'};
  return $region if(defined($region) and $region ne '');
  my $ua = LWP::UserAgent->new(timeout => 2);
  my $resp = $ua->get('http://169.254.169.254/latest/meta-data/placement/availability-zone');
  if($resp->is_success)
  {
    my $az = $resp->decoded_content;
    $az =~ s/[a-z]$//g;
    $region = $az;
  }

  return $region;
}

sub is_production
{
  my ($self) = @_;
  return $self->environment eq 'production';
}

__PACKAGE__->meta->make_immutable;
1;
