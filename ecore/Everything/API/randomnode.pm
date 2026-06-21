package Everything::API::randomnode;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

# GET /api/randomnode -> { node_id, title } of a random content node.
# Replaces the legacy op=randomnode mod_perlInit redirect (#4335 Phase 3).
# Reads from the `randomnodes` DataStash (the same set the Random Nodes nodelet
# uses -- 12 nodes, refreshed ~every 60s) so this costs no live query. Falls back
# to a fresh live pick if the stash isn't populated yet (e.g. cron hasn't run).

sub routes
{
  return {
    "/" => "get_random",
  }
}

sub get_random
{
  my ($self, $REQUEST) = @_;

  my $nodes = $self->DB->stashData("randomnodes");
  if (ref $nodes eq 'ARRAY' && @$nodes)
  {
    my $pick = $nodes->[ int(rand(scalar @$nodes)) ];
    return [$self->HTTP_OK, {
      success => 1,
      node_id => int($pick->{node_id}),
      title   => $pick->{title},
    }];
  }

  # Fallback: stash empty (cron hasn't generated it) -> one fresh live pick.
  my $live = $self->APP->getRandomNodesMany(1);
  if (ref $live eq 'ARRAY' && @$live && $live->[0]{node_id})
  {
    return [$self->HTTP_OK, { success => 1, node_id => int($live->[0]{node_id}) }];
  }

  return [$self->HTTP_OK, { success => 0, error => 'No random node available' }];
}

__PACKAGE__->meta->make_immutable;
1;
