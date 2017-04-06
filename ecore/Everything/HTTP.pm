package Everything::HTTP;
use Moose::Role;

has 'HTTP_OK' => (is => "ro", isa => "Int", default => 200);
has 'HTTP_BAD_REQUEST' => (is => "ro", isa => "Int", default => 400);
has 'HTTP_UNAUTHORIZED' => (is => "ro", isa => "Int", default => 401);
has 'HTTP_FORBIDDEN' => (is => "ro", isa => "Int", default => 403);
has 'HTTP_UNIMPLEMENTED' => (is => "ro", isa => "Int", default => 405);
has 'HTTP_GONE' => (is => "ro", isa => "Int", default => 410);
1;

