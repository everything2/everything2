package Everything::Node::e2node;

use Moose;
extends 'Everything::Node';

with 'Everything::Node::helper::group';

override 'json_display' => sub
{
  my ($self, $user) = @_;
  my $values = super();

  my $group = [];
  my $createdby = $self->APP->node_by_id($self->createdby_user || 0);
  if($createdby)
  {
    $values->{createdby} = $createdby->json_reference;
  }

  # Check if node is locked (prevents new writeups)
  my $lock = $self->DB->sqlSelectHashref('*', 'nodelock', 'nodelock_node=' . $self->node_id);
  if ($lock) {
    $values->{locked} = 1;
    $values->{lock_reason} = $lock->{nodelock_reason};
    $values->{lock_user_id} = $lock->{nodelock_user};
    # Resolve lock user to title for display
    my $lock_user = $self->APP->node_by_id($lock->{nodelock_user});
    $values->{lock_user_title} = $lock_user ? $lock_user->title : undef;
  } else {
    $values->{locked} = 0;
  }

  # Include orderlock_user so editors can see if writeup ordering is locked
  $values->{orderlock_user} = $self->NODEDATA->{orderlock_user} || 0;

  foreach my $writeup (@{$self->group || []})
  {
    push @$group, $writeup->single_writeup_display($user);
  }

  if(scalar(@$group) > 0)
  {
    $values->{group} = $group;
  }

  my $softlinks = $self->softlinks($user);

  if(scalar(@$softlinks) > 0)
  {
    $values->{softlinks} = $softlinks;
  }

  my $firmlinks = $self->firmlinks();

  if(scalar(@$firmlinks) > 0)
  {
    my $firmlinks_data = [];
    foreach my $firmlink (@$firmlinks)
    {
      my $ref = $firmlink->json_reference;
      # Include note text if present
      $ref->{note_text} = $firmlink->{firmlink_note_text} if $firmlink->{firmlink_note_text};
      push @$firmlinks_data, $ref;
    }
    $values->{firmlinks} = $firmlinks_data;
  }
  return $values;
};

sub createdby_user
{
  my ($self) = @_;
  return $self->NODEDATA->{createdby_user};
}

sub firmlinks
{
  my ($self) = @_;
  my $linktype = $self->APP->node_by_name("firmlink","linktype");

  my $links = [];
  my $csr = $self->DB->sqlSelectMany(
    'links.to_node, note.firmlink_note_text',
    'links
    LEFT JOIN firmlink_note AS note
      ON note.from_node = links.from_node
      AND note.to_node = links.to_node',
    "links.linktype=".$linktype->node_id." AND links.from_node=".$self->node_id);

  while(my $row = $csr->fetchrow_hashref)
  {
    my $link = $self->APP->node_by_id($row->{to_node});
    if(defined($link)) {
      # Store note text as a property on the blessed node object
      $link->{firmlink_note_text} = $row->{firmlink_note_text} || '';
      push @$links, $link;
    }
  }

  return $links;
}

sub softlinks
{
  my ($self, $user) = @_;

  # Check if user has disabled softlinks via preference
  unless ($user->is_guest) {
    my $user_vars = $user->VARS;
    return [] if $user_vars->{noSoftLinks};
  }

  my $limit = 48;
  $limit = 24 if $user->is_guest;
  $limit = 46 if $user->is_editor;

  my $csr = $self->DB->{dbh}->prepare('select node.type_nodetype, node.title, links.hits, links.to_node from links use index (linktype_fromnode_hits), node where links.from_node='.$self->node_id.' and links.to_node = node.node_id and links.linktype=0 order by links.hits desc limit '.$limit);

  $csr->execute;
  my $softlinks = [];
  my @node_ids;
  while (my $link = $csr->fetchrow_hashref)
  {
    push @$softlinks, {"node_id" => int($link->{to_node}), "title" => $link->{title}, "type" => "e2node", "hits" => int($link->{hits})};
    push @node_ids, $link->{to_node};
  }

  # Determine which nodes are "filled" (have writeups in nodegroup)
  # A nodeshell is an e2node with no writeups - shown in red to logged-in users
  if (@node_ids) {
    my $placeholders = join(',', ('?') x scalar(@node_ids));
    my $filled_ids = $self->DB->{dbh}->selectcol_arrayref(
      "SELECT DISTINCT nodegroup_id FROM nodegroup WHERE nodegroup_id IN ($placeholders)",
      {},
      @node_ids
    );
    my %filled_hash = map { $_ => 1 } @$filled_ids;

    foreach my $link (@$softlinks) {
      $link->{filled} = exists $filled_hash{$link->{node_id}} ? \1 : \0;
    }
  }

  return $softlinks;
}

sub metadescription
{
  my ($self) = @_;

  # Get the highest-rated writeup from this e2node
  my $group = $self->group || [];
  return $self->SUPER::metadescription unless scalar(@$group) > 0;

  # Find the writeup with the highest reputation
  my $best_writeup;
  my $best_rep = -999999;

  foreach my $writeup (@$group) {
    my $rep = $writeup->reputation || 0;
    if ($rep > $best_rep) {
      $best_rep = $rep;
      $best_writeup = $writeup;
    }
  }

  return $self->SUPER::metadescription unless $best_writeup;

  # Use the writeup's metadescription
  return $best_writeup->metadescription;
}

sub publishtime
{
  my ($self) = @_;

  # Get the most recent publishtime across all writeups in this e2node
  my $group = $self->group || [];
  return unless scalar(@$group) > 0;

  my $most_recent;

  foreach my $writeup (@$group) {
    my $pt = $writeup->publishtime;
    next unless $pt && $pt ne '0000-00-00 00:00:00';

    if (!$most_recent || $pt gt $most_recent) {
      $most_recent = $pt;
    }
  }

  return $most_recent;
}

around 'insert' => sub {
 my ($orig, $self, $user, $data) = @_;

 my $newnode = $self->$orig($user, $data);
 return unless $newnode;  # Parent insert failed
 $newnode->update($user, {"author_user" => $self->APP->node_by_name("Content Editors","usergroup")->node_id});
 return $newnode;
};

__PACKAGE__->meta->make_immutable;
1;
