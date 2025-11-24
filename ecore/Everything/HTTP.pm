package Everything::HTTP;
use Moose::Role;

has 'HTTP_OK' => (is => "ro", isa => "Int", default => 200);
has 'HTTP_FOUND' => (is => "ro", isa => "Int", default => 302);
has 'HTTP_BAD_REQUEST' => (is => "ro", isa => "Int", default => 400);
has 'HTTP_UNAUTHORIZED' => (is => "ro", isa => "Int", default => 401);
has 'HTTP_FORBIDDEN' => (is => "ro", isa => "Int", default => 403);
has 'HTTP_NOT_FOUND' => (is => "ro", isa => "Int", default => 404);
has 'HTTP_UNIMPLEMENTED' => (is => "ro", isa => "Int", default => 405);
has 'HTTP_CONFLICT' => (is => "ro", isa => "Int", default => 409);
has 'HTTP_GONE' => (is => "ro", isa => "Int", default => 410);
has 'HTTP_OVER_RATE_LIMIT' => (is => "ro", isa => "Int", default => 429);
has 'HTTP_INTERNAL_SERVER_ERROR' => (is => "ro", isa => "Int", default => 500);
has 'HTTP_UNAVAILABLE' => (is => "ro", isa => "Int", default => 503);

1;

