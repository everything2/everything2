package Everything::PluginFactory;

use Moose;
use namespace::autoclean;
use Try::Tiny;
use Module::Runtime qw(use_module);

with 'Everything::Globals';

has 'PLUGINCLASS' => (isa => 'Str', required => 1, is => 'ro');
has 'plugins' => (isa => 'HashRef', is => 'rw', builder => "_build_plugins");
has 'errors' => (isa => 'HashRef', is => 'rw', default => sub { {} });

around 'BUILDARGS' => sub
{
  my $orig = shift;
  my $class = shift;

  $class->$orig(PLUGINCLASS => $_[0]);
};

sub error_string
{
  my ($self) = @_;
  return unless $self->errors;

  my $string = "";

  foreach my $key (keys %{$self->errors})
  {
    $string .= "$key compilation failed: ".$self->errors->{$key}."\n";
  }

  return $string;
}

sub _build_plugins
{
  my ($self) = @_;

  my $plugins = {};

  my $modulepath = $self->PLUGINCLASS;
  $modulepath =~ s/::/\//g;
  foreach my $path (@INC)
  {
    if(-d "$path/$modulepath/")
    {
       my $dirhandle;
       opendir($dirhandle,"$path/$modulepath");
       foreach my $module(readdir($dirhandle))
       {
         my $fullmodule = "$path/$modulepath/$module";
         next unless -e $fullmodule and -f $fullmodule;
         my ($pluginname) = $module =~ /^([^\.]+)/;
         my $plugin_class = $self->PLUGINCLASS."::$pluginname";

         try {
           use_module($plugin_class);
           $plugins->{"$pluginname"} = $plugin_class;
         } catch {
           $self->errors->{"$plugin_class"} = $_;
         };
       }
       last;
    }
  }

  return $plugins;
}

sub available
{
  my ($self, $pluginname) = @_;

  return $self->plugins->{$pluginname};

}

sub all
{
  my ($self) = @_;
  return [keys %{$self->plugins}];
}

__PACKAGE__->meta->make_immutable;
1;
