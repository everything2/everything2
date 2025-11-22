package Everything::API::nodenotes;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

## no critic (ProhibitBuiltinHomonyms)

sub routes
{
  return {
  ":node_id" => "get_node_notes(:node_id)",
  ":node_id/create" => "add_note(:node_id)",
  ":node_id/:note_id/delete" => "delete_note(:node_id, :note_id)",
  }
}

sub get_node_notes
{
  my ($self, $REQUEST, $node_id) = @_;

  # Validate node_id
  if (!$node_id || $node_id !~ /^\d+$/) {
    return [$self->HTTP_BAD_REQUEST, { error => "Invalid node_id" }];
  }

  # Get the node
  my $node = $self->DB->getNodeById($node_id);
  if (!$node) {
    return [$self->HTTP_NOT_FOUND, { error => "Node not found" }];
  }

  # Get node notes using Application.pm method
  my $notes = $self->APP->getNodeNotes($node);

  # Transform notes data for API response
  my @notes_response = ();
  foreach my $note (@$notes) {
    my $note_data = {
      nodenote_id => $note->{nodenote_id},
      nodenote_nodeid => $note->{nodenote_nodeid},
      notetext => $note->{notetext},
      noter_user => $note->{noter_user},
      timestamp => $note->{timestamp},
    };

    # Legacy format check: noter_user = 1 means author was encoded in notetext
    if ($note->{noter_user} && $note->{noter_user} == 1) {
      # Legacy format: author is embedded in notetext, mark as version 1
      $note_data->{legacy_format} = 1;
    } elsif ($note->{noter_user}) {
      # Modern format: look up noter username (0 = system note, no username)
      my $noter = $self->DB->getNodeById($note->{noter_user});
      $note_data->{noter_username} = $noter->{title} if $noter;
    }

    # Include author_user if present (for e2node queries)
    if (exists $note->{author_user}) {
      $note_data->{author_user} = $note->{author_user};
    }

    # Get node title for cross-references
    if ($note->{nodenote_nodeid} != $node_id) {
      my $ref_node = $self->DB->getNodeById($note->{nodenote_nodeid});
      if ($ref_node) {
        $note_data->{node_title} = $ref_node->{title};
        $note_data->{node_type} = $ref_node->{type}{title};
      }
    }

    push @notes_response, $note_data;
  }

  return [$self->HTTP_OK, {
    node_id => $node_id,
    node_title => $node->{title},
    node_type => $node->{type}{title},
    notes => \@notes_response,
    count => scalar(@notes_response),
  }];
}

sub add_note
{
  my ($self, $REQUEST, $node_id) = @_;

  # Validate node_id
  if (!$node_id || $node_id !~ /^\d+$/) {
    return [$self->HTTP_BAD_REQUEST, { error => "Invalid node_id" }];
  }

  # Get the node
  my $node = $self->DB->getNodeById($node_id);
  if (!$node) {
    return [$self->HTTP_NOT_FOUND, { error => "Node not found" }];
  }

  # Get POST data
  my $data = $REQUEST->JSON_POSTDATA;
  if (!$data || !exists $data->{notetext}) {
    return [$self->HTTP_BAD_REQUEST, { error => "Missing notetext in request body" }];
  }

  my $notetext = $data->{notetext};
  if (!defined($notetext) || length($notetext) == 0) {
    return [$self->HTTP_BAD_REQUEST, { error => "Note text cannot be empty" }];
  }

  # Insert the note
  my $timestamp = $self->DB->sqlSelect("NOW()", "DUAL");
  my $note_id = $self->DB->sqlInsert("nodenote", {
    nodenote_nodeid => $node_id,
    notetext => $notetext,
    noter_user => $REQUEST->user->node_id,
    timestamp => $timestamp,
  });

  if (!$note_id) {
    return [$self->HTTP_INTERNAL_SERVER_ERROR, { error => "Failed to create note" }];
  }

  # Return updated notes list
  return $self->get_node_notes($REQUEST, $node_id);
}

sub delete_note
{
  my ($self, $REQUEST, $node_id, $note_id) = @_;

  # Validate node_id and note_id
  if (!$node_id || $node_id !~ /^\d+$/) {
    return [$self->HTTP_BAD_REQUEST, { error => "Invalid node_id" }];
  }
  if (!$note_id || $note_id !~ /^\d+$/) {
    return [$self->HTTP_BAD_REQUEST, { error => "Invalid note_id" }];
  }

  # Get the node
  my $node = $self->DB->getNodeById($node_id);
  if (!$node) {
    return [$self->HTTP_NOT_FOUND, { error => "Node not found" }];
  }

  # Check if note exists and belongs to this node
  my $note = $self->DB->sqlSelectHashref(
    "nodenote_id, nodenote_nodeid, noter_user",
    "nodenote",
    "nodenote_id=" . $self->DB->quote($note_id)
  );

  if (!$note) {
    return [$self->HTTP_NOT_FOUND, { error => "Note not found" }];
  }

  # Get all notes for this node (including e2node/writeup relationships)
  my $all_notes = $self->APP->getNodeNotes($node);
  my $note_belongs_to_node = 0;
  foreach my $n (@$all_notes) {
    if ($n->{nodenote_id} == $note_id) {
      $note_belongs_to_node = 1;
      last;
    }
  }

  if (!$note_belongs_to_node) {
    return [$self->HTTP_NOT_FOUND, { error => "Note not associated with this node" }];
  }

  # Only allow deleting your own notes unless you're an admin
  if ($note->{noter_user} != $REQUEST->user->node_id && !$REQUEST->user->is_admin) {
    return [$self->HTTP_FORBIDDEN, { error => "You can only delete your own notes" }];
  }

  # Delete the note
  my $deleted = $self->DB->sqlDelete("nodenote", "nodenote_id=" . $self->DB->quote($note_id));
  if (!$deleted) {
    return [$self->HTTP_INTERNAL_SERVER_ERROR, { error => "Failed to delete note" }];
  }

  # Return updated notes list
  return $self->get_node_notes($REQUEST, $node_id);
}

# Require editor privileges for all routes
around ['get_node_notes', 'add_note', 'delete_note'] => \&Everything::API::unauthorized_unless_editor;

__PACKAGE__->meta->make_immutable;
1;
