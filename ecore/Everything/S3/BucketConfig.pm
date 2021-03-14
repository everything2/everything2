package Everything::S3::BucketConfig;

use Moose;
use namespace::autoclean;

has 'bucket' => (isa => 'Str', is => 'ro', required => 1);
has 'secret_access_key' => (isa => 'Maybe[Str]', is => 'ro');
has 'access_key_id' => (isa => 'Maybe[Str]', is => 'ro');
has 'use_iam_role' => (isa => 'Bool', is => 'ro', default => 1);
has 'host' => (isa => 'Maybe[Str]', is => 'ro');

__PACKAGE__->meta->make_immutable;
1;
