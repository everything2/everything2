package Everything::Postmaster;

use Moose;

has 'APP' => (isa => 'Everything::Application', is => 'ro');
has 'DB' => (isa => 'Everything::NodeBase', is => 'ro');
has 'msgtypes' => (isa => 'HASHREF', is => 'ro', default => sub { return 
  {
    "me" => 0,
  }});


