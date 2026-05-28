package Everything::API::cool;

use Moose;
extends 'Everything::API';

# API endpoints for cool-related actions
# POST /api/cool/writeup/:id - Award C! to a writeup
# POST /api/cool/edcool/:id - Toggle editor cool (star) on any node (e2node, superdoc, etc)
# POST /api/cool/bookmark/:id - Toggle bookmark on any node (writeup, e2node, superdoc, etc)

sub routes
{
  return {
    "writeup/:id" => "award_cool(:id)",
    "edcool/:id" => "toggle_edcool(:id)",
    "edcool/:id/status" => "edcool_status(:id)",
    "bookmark/:id" => "toggle_bookmark(:id)",
    "bookmark/:id/status" => "bookmark_status(:id)"
  };
}

sub award_cool {
    my ( $self, $REQUEST, $writeup_id ) = @_;

    my $user = $REQUEST->user;

    # Check if user is logged in
    if ( $user->is_guest ) {
        return [$self->HTTP_OK, { success => 0, error => 'You must be logged in to award C!s' }];
    }

    # Check if user has C!s available
    my $cools_left = $user->coolsleft;
    unless ( $cools_left && $cools_left > 0 ) {
        return [$self->HTTP_OK, { success => 0, error => 'You have no C!s remaining' }];
    }

    # Validate inputs
    $writeup_id = int($writeup_id || 0);
    unless ($writeup_id) {
        return [$self->HTTP_OK, { success => 0, error => 'Missing writeup_id' }];
    }

    # Get writeup node
    my $writeup = $self->APP->node_by_id($writeup_id);
    unless ( $writeup && $writeup->type->title eq 'writeup' ) {
        return [$self->HTTP_OK, { success => 0, error => 'Writeup not found' }];
    }

    # Check if user is the author
    if ( $writeup->author_user == $user->node_id ) {
        return [$self->HTTP_OK, { success => 0, error => 'You cannot C! your own writeup' }];
    }

    # Check if user has already cooled this writeup
    my $existing_cool = $self->DB->sqlSelectHashref( '*', 'coolwriteups',
            'cooledby_user='
          . $user->node_id
          . ' AND coolwriteups_id='
          . $writeup_id );

    if ($existing_cool) {
        return [$self->HTTP_OK, { success => 0, error => 'You have already C!\'d this writeup' }];
    }

    # Award the C! - insert into coolwriteups table
    my $new_cools_left;
    my $success = eval {
        $self->DB->sqlInsert('coolwriteups', {
            coolwriteups_id => $writeup_id,
            cooledby_user => $user->node_id
        });

        # Sync the cached cool count from the coolwriteups table. Was a
        # `$cooled++` delta, but historical delta paths accumulated drift
        # (#4011 / cluster #4137). SUM-rebuild matches the reconciliation
        # job at jobs/job_reconcile_rep_and_cools.pl.
        my $WRITEUP = $writeup->NODEDATA;
        $WRITEUP->{cooled} = $self->DB->sqlSelect(
            'COUNT(*)', 'coolwriteups',
            "coolwriteups_id=$writeup_id"
        ) // 0;
        $self->DB->updateNode($WRITEUP, -1);

        # Decrement user's cools remaining and save immediately
        my $USER = $user->NODEDATA;
        my $VARS = $self->APP->getVars($USER);
        $VARS->{cools}-- if $VARS->{cools} && $VARS->{cools} > 0;
        Everything::setVars($USER, $VARS);
        $new_cools_left = int($VARS->{cools} || 0);

        # Grant experience to the writeup author
        $self->APP->adjustExp($writeup->author_user, 20);

        return 1;
    };

    unless ($success) {
        return [$self->HTTP_OK, { success => 0, error => 'Failed to award C!' }];
    }

    # Send Cool Man Eddie message to the writeup author. Two opt-out gates:
    #   1. The author's no_coolnotification user-var (per-author setting —
    #      "don't notify me when my writeups are cooled"). Lives here in the
    #      cool API because it's cool-specific, not a general message rule.
    #   2. message_forward_to / messageignore / etc., handled by
    #      sendPrivateMessage. The previous raw sqlInsert bypassed all of
    #      these and was the root of #4142 — cool notifications addressed to
    #      Decaversal Studios never reached Jet-Poop's forwarded inbox.
    my $eddie = $self->DB->getNode('Cool Man Eddie', 'user');
    my $parent = $writeup->parent;
    if ($eddie && $parent) {
        my $author_vars = $self->APP->getVars(
            $self->DB->getNodeById($writeup->author_user));
        unless ($author_vars && $author_vars->{no_coolnotification}) {
            $self->APP->sendPrivateMessage(
                $eddie,
                $writeup->author_user,
                'Hey, [' . $user->title . '[user]] just cooled [' . $parent->title . '], baby!',
            );
        }
    }

    return [$self->HTTP_OK, {
        success         => 1,
        message         => 'C! awarded successfully',
        writeup_id      => $writeup_id,
        cools_remaining => $new_cools_left
    }];
}

sub toggle_edcool
{
  my ($self, $REQUEST, $node_id) = @_;
  my $user = $REQUEST->user;
  my $APP = $self->APP;
  my $DB = $self->DB;

  # Check if user is an editor
  unless ($user->is_editor) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Editor access required',
      message => 'Only editors can cool nodes'
    }];
  }

  # Get the node
  my $node = $APP->node_by_id($node_id);
  unless ($node) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Node not found',
      message => 'The specified node does not exist'
    }];
  }

  # Check if the node allows editor cooling
  my $NODE = $node->NODEDATA;
  unless ($APP->can_edcool($NODE)) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Cannot cool this node',
      message => 'This node cannot be editor cooled'
    }];
  }

  # Get coollink linktype
  my $coollink_type = $DB->getNode('coollink', 'linktype');
  unless ($coollink_type) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'System error',
      message => 'coollink linktype not found'
    }];
  }

  my $coollink_id = $coollink_type->{node_id};

  # Check if node is already cooled
  my $existing_link = $DB->sqlSelectHashref('*', 'links',
    "from_node=$node_id AND linktype=$coollink_id");

  if ($existing_link) {
    # Remove the cool
    $DB->sqlDelete('links',
      "from_node=$node_id AND linktype=$coollink_id");

    return [$self->HTTP_OK, {
      success => 1,
      action => 'uncooled',
      message => 'Editor cool removed',
      edcooled => 0
    }];
  } else {
    # Add the cool - link from node to coolnodes nodegroup
    my $coolnodes = $DB->getNode('coolnodes', 'nodegroup');
    unless ($coolnodes) {
      return [$self->HTTP_OK, {
        success => 0,
        error => 'System error',
        message => 'coolnodes nodegroup not found'
      }];
    }

    $DB->sqlInsert('links', {
      from_node => $node_id,
      to_node => $coolnodes->{node_id},
      linktype => $coollink_id,
      hits => 0,
      food => 0
    });

    return [$self->HTTP_OK, {
      success => 1,
      action => 'cooled',
      message => 'Editor cool added',
      edcooled => 1,
      edcooled_by => {
        node_id => $user->node_id,
        title => $user->title
      }
    }];
  }
}

sub toggle_bookmark
{
  my ($self, $REQUEST, $node_id) = @_;
  my $user = $REQUEST->user;
  my $APP = $self->APP;
  my $DB = $self->DB;

  # Guests cannot bookmark
  if ($user->is_guest) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Login required',
      message => 'You must be logged in to bookmark'
    }];
  }

  # Get the node
  my $node = $APP->node_by_id($node_id);
  unless ($node) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Node not found',
      message => 'The specified node does not exist'
    }];
  }

  # Check if node allows bookmarking
  my $NODE = $node->NODEDATA;
  unless ($APP->can_bookmark($NODE)) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Cannot bookmark',
      message => 'You cannot bookmark this node'
    }];
  }

  # Get bookmark linktype
  my $bookmark_type = $DB->getNode('bookmark', 'linktype');
  unless ($bookmark_type) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'System error',
      message => 'bookmark linktype not found'
    }];
  }

  my $bookmark_id = $bookmark_type->{node_id};
  my $user_id = $user->node_id;

  # Check if already bookmarked
  my $existing_link = $DB->sqlSelectHashref('*', 'links',
    "from_node=$user_id AND to_node=$node_id AND linktype=$bookmark_id");

  if ($existing_link) {
    # Remove the bookmark
    $DB->sqlDelete('links',
      "from_node=$user_id AND to_node=$node_id AND linktype=$bookmark_id");

    return [$self->HTTP_OK, {
      success => 1,
      action => 'unbookmarked',
      message => 'Bookmark removed',
      bookmarked => 0
    }];
  } else {
    # Add the bookmark
    $DB->sqlInsert('links', {
      from_node => $user_id,
      to_node => $node_id,
      linktype => $bookmark_id,
      hits => 0,
      food => 0
    });

    # Send Cool Man Eddie message for writeups. Two opt-out gates, same
    # structure as award_cool above (#4142):
    #   1. no_bookmarkinformer user-var on the author (bookmark-specific
    #      opt-out, stays caller-side because it's bookmark-only logic)
    #   2. message_forward_to / messageignore — handled by sendPrivateMessage
    if ($node->type->title eq 'writeup') {
      my $eddie = $DB->getNode('Cool Man Eddie', 'user');
      my $author = $APP->node_by_id($node->author_user);
      my $author_vars = $author ? $author->VARS : {};

      # Skip if: user is bookmarking own writeup, author opted out, or Eddie missing.
      if ($eddie && $author && $user_id != $node->author_user && !$author_vars->{no_bookmarkinformer}) {
        $APP->sendPrivateMessage(
          $eddie,
          $node->author_user,
          'Yo, your writeup [' . $node->title . '] was bookmarked. Dig it, baby.',
        );
      }
    }

    return [$self->HTTP_OK, {
      success => 1,
      action => 'bookmarked',
      message => 'Bookmark added',
      bookmarked => 1
    }];
  }
}

sub edcool_status
{
  my ($self, $REQUEST, $node_id) = @_;
  my $user = $REQUEST->user;
  my $DB = $self->DB;

  # Editors only
  unless ($user->is_editor) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Editor access required'
    }];
  }

  # Get coollink linktype
  my $coollink_type = $DB->getNode('coollink', 'linktype');
  unless ($coollink_type) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'System error'
    }];
  }

  my $coollink_id = $coollink_type->{node_id};

  # Check if node is editor cooled
  my $existing_link = $DB->sqlSelectHashref('to_node', 'links',
    "from_node=$node_id AND linktype=$coollink_id LIMIT 1");

  return [$self->HTTP_OK, {
    success => 1,
    edcooled => $existing_link ? 1 : 0
  }];
}

sub bookmark_status
{
  my ($self, $REQUEST, $node_id) = @_;
  my $user = $REQUEST->user;
  my $DB = $self->DB;

  # Guests cannot bookmark
  if ($user->is_guest) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Login required'
    }];
  }

  # Get bookmark linktype
  my $bookmark_type = $DB->getNode('bookmark', 'linktype');
  unless ($bookmark_type) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'System error'
    }];
  }

  my $bookmark_id = $bookmark_type->{node_id};
  my $user_id = $user->node_id;

  # Check if bookmarked
  my $existing_link = $DB->sqlSelectHashref('*', 'links',
    "from_node=$user_id AND to_node=$node_id AND linktype=$bookmark_id");

  return [$self->HTTP_OK, {
    success => 1,
    bookmarked => $existing_link ? 1 : 0
  }];
}

__PACKAGE__->meta->make_immutable;
1;
