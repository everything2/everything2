package Everything::Configuration;

use Moose;
use Everything::S3::BucketConfig;
use Everything::Constants;
use Carp qw(croak);
use Paws;
use LWP::UserAgent;
use JSON;
use namespace::autoclean;
use Config;
use Sys::Hostname;

has 'configfile' => (isa => 'Maybe[Str]', is => 'ro');
has 'configdir' => (isa => 'Str', is => 'ro', default => '/etc/everything');
has 'site_url' => (isa => 'Str', is => 'ro', required => 1, default => 'https://everything2.com');
has 'guest_user' => (isa => 'Int', is => 'ro', required => 1, default => Everything::Constants->GUEST_USER);

has 'infected_ips' => (isa => 'ArrayRef', is => 'ro', builder => '_build_infected', lazy => 1);
has 'default_style' => (isa => 'Str', is => 'ro', default => 'Kernel Blue');

# Database options
# TODO: Rename this to be something that makes it clear that it is the database user
has 'everyuser' => (isa => 'Str', is => 'ro', default => 'everyuser');
# TODO: Rename this to be something that makes it clear that it is the database password
has 'everypass' => (isa => 'Str', is => 'ro', builder => '_build_everypass', lazy => 1);
has 'everything_dbserv' => (isa => 'Str', is => 'ro', default => sub { $ENV{E2_DBSERV} || 'localhost' });
has 'everything_dbport' => (isa => 'Int', is => 'ro', default => 3306);

has 'database' => (isa => 'Str', is => 'ro', default => 'everything');

has 'cookiepass' => (isa => 'Str', is => 'ro', default => 'userpass');

has 'canonical_web_server' => (isa => 'Str', is => 'ro', default => 'localhost');

has 'homenode_image_host' => (isa => 'Str', is => 'ro', default => 'hnimagew.everything2.com');

# SMTP options
has 'mail_from' => (isa => 'Str', is => 'ro', default => 'accounthelp@everything2.com');

has 'nodecache_size' => (isa => 'Int', is => 'ro', default => 1000);

has 'environment' => (isa => 'Str', is => 'ro', default => 'development');

has 's3' => (isa => 'HashRef', is => 'ro', default => sub { {
  "homenodeimages" => Everything::S3::BucketConfig->new("bucket" => "hnimagew.everything2.com"),
  "deployedassets" => Everything::S3::BucketConfig->new("bucket" => "deployed.everything2.com"),
  "nodebackup" => Everything::S3::BucketConfig->new("bucket" => "nodebackup.everything2.com"),
  "sitemap" => Everything::S3::BucketConfig->new("bucket" => "sitemap.everything2.com"),
  "writeup_export" => Everything::S3::BucketConfig->new("bucket" => "e2-writeup-exports") }});

has 'assets_location' => (isa => 'Str', is => 'ro', builder => '_build_assets_location', lazy => 1);

has 'current_region' => (isa => 'Maybe[Str]', is => 'ro', builder => '_build_current_region', lazy => 1);

has 'static_nodetypes' => (isa => 'Bool', is => 'ro', default => 1);

has 'clean_search_words_aggressively' => (isa => 'Bool', is => 'ro', default => 1);

has 'search_row_limit' => (isa => 'Int', is => 'ro', default => 200);

has 'chatter_time_window_minutes' => (isa => 'Int', is => 'ro', default => 5);

has 'logdirectory' => (isa => 'Str', is => 'ro', default => '/var/log/everything');

has 'use_local_assets' => (isa => 'Bool', is => 'ro', default => '0');

# Halloween mode testing - set to 1 to force Halloween features (costumes, etc.) regardless of date
# Note: 'rw' allows tests to enable this temporarily
has 'force_halloween_mode' => (isa => 'Bool', is => 'rw', default => 0);

has 'github_url' => (isa => 'Str', is => 'ro', default => 'https://github.com/everything2/everything2');
has 'last_commit' => (isa => 'Str', is => 'ro', builder => '_build_last_commit', lazy => 1);

# Root directory of the Everything2 application
has 'everything_root' => (isa => 'Str', is => 'ro', default => '/var/everything');

# static_cache: Types that NEVER need version checks - only change via deployment.
# These are "code nodes" where the database row identifies which Perl module to run.
# Changes to these require an ECS task restart to take effect.
has 'static_cache' => (isa => 'HashRef', is => 'ro', default => sub { {
  # Core type definitions
  "nodetype" => 1,
  "writeuptype" => 1,
  "linktype" => 1,
  "sustype" => 1,

  # Structural/template types
  "nodelet" => 1,
  "container" => 1,
  "theme" => 1,

  # Code-backed types (delegation modules)
  "htmlcode" => 1,
  "htmlpage" => 1,
  "maintenance" => 1,

  # Code-backed document types (Page/Controller classes)
  "fullpage" => 1,
  "superdoc" => 1,
  "superdocnolinks" => 1,
  "restricted_superdoc" => 1,
  "oppressor_superdoc" => 1,
  "ticker" => 1,
  "jsonexport" => 1,

  # Other code-controlled types
  "achievement" => 1,
  "opcode" => 1,
} });

# permanent_cache: Types that are cached permanently (never evicted by LRU)
# but still need version checks because they can change at runtime.
has 'permanent_cache' => (isa => 'HashRef', is => 'ro', default => sub { {
  "usergroup" => 1,
  "setting" => 1,
  "datastash" => 1,
  "room" => 1,
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
has 'maintenance_message' => (isa => 'Str', is => 'ro', default => sub { $ENV{E2_MAINTENANCE_MESSAGE} || "" });
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

# reCAPTCHA Enterprise configuration
# API key for server-side verification (from GCP Console -> APIs & Services -> Credentials)
has 'recaptcha_enterprise_api_key' => (isa => 'Str', is => 'ro', builder => '_build_recaptcha_api_key', lazy => 1);
# GCP Project ID (public, used in API URL)
has 'recaptcha_enterprise_project_id' => (isa => 'Str', is => 'ro', default => 'everything2-production');
# Site key (public, used in browser)
has 'recaptcha_v3_public_key' => (isa => 'Str', is => 'ro', default => '6LeF2BwsAAAAAMrkwFG7CXJmF6p0hV2swBxYfqc2');
# Legacy v3 secret key - kept for backward compatibility but no longer used
has 'recaptcha_v3_secret_key' => (isa => 'Str', is => 'ro', builder => '_build_recaptcha', lazy => 1);

has 'login_location' => (isa => 'Str', is => 'ro', default => '/node/superdoc/login');
has 'permission_denied_location' => (isa => 'Str', is => 'ro', lazy => 1, default => sub {"/node/".$_[0]->permission_denied});


has 'blacklist_interval' => (isa => 'Str', is => 'ro', default => '3 MONTH');

has 'site_description' => (isa => 'Str', is => 'ro', default => 'Everything2 is a collection of user-submitted writings about more or less everything');

has 'site_name' => (isa => 'Str', is => 'ro', default => 'Everything2');
has 'create_new_user' => (isa => 'Int', is => 'ro', default => '2072173');
has 'default_guest_node' => (isa => 'Int', is => 'ro', default => '2030780');

has 'default_nodelets' => (isa => 'ArrayRef[Int]', is => 'ro', default => sub{[
  Everything::Constants->NODELET_EPICENTER,
  Everything::Constants->NODELET_MESSAGES,
  Everything::Constants->NODELET_CHATTERBOX,
  Everything::Constants->NODELET_OTHERUSERS,
  Everything::Constants->NODELET_NEWWRITEUPS,
  Everything::Constants->NODELET_READTHIS,
  Everything::Constants->NODELET_VITALS,
  Everything::Constants->NODELET_CURRENTUSERPOLL
]});

has 'supported_nodelets' => (isa => 'ArrayRef[Int]', is => 'ro', default => sub{[
  Everything::Constants->NODELET_FORREVIEW,
  Everything::Constants->NODELET_MESSAGES,
  Everything::Constants->NODELET_MOSTWANTED,
  Everything::Constants->NODELET_NOTIFICATIONS,
  Everything::Constants->NODELET_USERGROUPWRITEUPS,
  Everything::Constants->NODELET_NEWLOGS,
  Everything::Constants->NODELET_CURRENTUSERPOLL,
  Everything::Constants->NODELET_NOTELET,
  Everything::Constants->NODELET_RECENTNODES,
  Everything::Constants->NODELET_READTHIS,
  Everything::Constants->NODELET_STATISTICS,
  Everything::Constants->NODELET_EVERYTHINGDEVELOPER,
  Everything::Constants->NODELET_PERSONALLINKS,
  Everything::Constants->NODELET_VITALS,
  Everything::Constants->NODELET_NEWWRITEUPS,
  Everything::Constants->NODELET_RANDOMNODES,
  Everything::Constants->NODELET_CHATTERBOX,
  Everything::Constants->NODELET_OTHERUSERS,
  Everything::Constants->NODELET_EPICENTER,
  Everything::Constants->NODELET_QUICKREFERENCE,
  Everything::Constants->NODELET_FAVORITENODERS,
  Everything::Constants->NODELET_CATEGORIES,
  Everything::Constants->NODELET_NEGLECTEDDRAFTS
]});

has 'guest_nodelets' => (isa => 'ArrayRef[Int]', is => 'ro', default => sub {[
  Everything::Constants->NODELET_SIGNIN,
  Everything::Constants->NODELET_RECOMMENDEDREADING,
  Everything::Constants->NODELET_NEWWRITEUPS
]});

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

has 'architecture' => (isa => 'Str', is => 'ro', builder => '_build_architecture');

has 'server_hostname' => (isa => 'Str', is => 'ro', builder => '_build_server_hostname', lazy => 1);

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
  if(defined($ENV{'E2_DOCKER'}) and $ENV{'E2_DOCKER'} eq 'development')
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

sub _build_recaptcha_api_key
{
  my ($self) = @_;
  return $self->_filesystem_default('recaptcha_enterprise_api_key','');
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
  $region = "us-west-2" if(not defined($region));
  return $region;
}

sub _build_last_commit
{
  my ($self) = @_;
  my $commit = undef;
  if(open my $fh, "<", "/etc/everything/last_commit")
  {
    local $/ = undef;
    $commit = <$fh>;
  }
  $commit = "HEAD" if not defined($commit);
  chomp($commit);
  return $commit;
}

sub _build_assets_location
{
  my ($self) = @_;
  return "https://s3-".$self->current_region.".amazonaws.com/".$self->s3->{deployedassets}->bucket."/".$self->last_commit;
}

sub last_commit_short
{
  my ($self) = @_;
  return substr($self->last_commit,0,7);
}

sub is_production
{
  my ($self) = @_;
  return $self->environment eq 'production';
}

sub _build_architecture
{
  my ($self) = @_;

  my $arch = $Config{archname};
  $arch =~ s/-.*//g;
  return $arch;
}

sub _build_server_hostname
{
  my ($self) = @_;
  my $hostname = Sys::Hostname::hostname;
  $hostname =~ s/\..*//;
  return $hostname;
}

__PACKAGE__->meta->make_immutable;
1;
