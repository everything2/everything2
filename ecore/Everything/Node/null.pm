package Everything::Node::null;

use Moose;

sub is_null
{
  return 1;
}

sub uri_safe_title
{
  return "(no title)"
}

sub title
{
  return "(no title)"
}

__PACKAGE__->meta->make_immutable;
1;
