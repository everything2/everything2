package Everything::Globals;

use Moose::Role;

has 'CONF' => (isa => "Everything::Configuration", is => "ro", lazy => 1, builder => "_build_CONF");
has 'DB' => (isa => "Everything::NodeBase", is => "ro", lazy => 1, builder => "_build_DB");
has 'APP' => (isa => "Everything::Application", is => "ro", lazy => 1, builder => "_build_APP", handles => ["printLog", "devLog"]);

sub _build_CONF
{
  return $Everything::CONF;
}

sub _build_DB
{
  return $Everything::DB;
}

sub _build_APP
{
  return $Everything::APP;
}

1;
