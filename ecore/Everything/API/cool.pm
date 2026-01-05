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
    "bookmark/:id" => "toggle_bookmark(:id)"
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

        # Increment the cooled count on the writeup
        my $WRITEUP = $writeup->NODEDATA;
        $WRITEUP->{cooled}++;
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

    # Send Cool Man Eddie message to the writeup author
    my $eddie = $self->DB->getNode('Cool Man Eddie', 'user');
    my $parent = $writeup->parent;
    if ($eddie && $parent) {
        $self->DB->sqlInsert('message', {
            'author_user' => $eddie->{node_id},
            'for_user' => $writeup->author_user,
            'msgtext' => 'Hey, [' . $user->title . '[user]] just cooled [' . $parent->title . '], baby!',
        });
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

    # Send Cool Man Eddie message for writeups (if author hasn't disabled it)
    if ($node->type->title eq 'writeup') {
      my $eddie = $DB->getNode('Cool Man Eddie', 'user');
      my $author = $APP->node_by_id($node->author_user);
      my $author_vars = $author ? $author->VARS : {};

      # Only send if: user isn't bookmarking their own writeup, author hasn't disabled notifications, and Eddie exists
      if ($eddie && $author && $user_id != $node->author_user && !$author_vars->{no_bookmarkinformer}) {
        $DB->sqlInsert('message', {
          'author_user' => $eddie->{node_id},
          'for_user' => $node->author_user,
          'msgtext' => 'Yo, your writeup [' . $node->title . '] was bookmarked. Dig it, baby.',
        });
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

__PACKAGE__->meta->make_immutable;
1;
