package Everything::Timestamp;

use Moose;
use Time::Local;
use POSIX;
use namespace::autoclean;

has 'timestamp' => (isa => 'Str', is => 'ro', required => 1);
has 'unixtime' => (isa => 'Int', is => 'ro', lazy => 1, builder => '_build_unixtime');

sub _build_unixtime
{
  my ($self) = @_;
  if(my ($year, $mon, $day, $hour, $min, $sec) = $self->timestamp =~ /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})/)
  {
    return Time::Local::timegm($sec, $min, $hour, $day, $mon-1, $year-1900);
  }
}

sub compact
{
  my ($self) = @_;
  return POSIX::strftime("%F@%R",gmtime($self->unixtime));
}


__PACKAGE__->meta->make_immutable();
1;
