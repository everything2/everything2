package Everything::S3::BucketConfig;

use Moose;
use namespace::autoclean;

has 'bucket' => (isa => 'Str', is => 'ro', required => 1);

__PACKAGE__->meta->make_immutable;
1;
