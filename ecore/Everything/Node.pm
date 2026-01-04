package Everything::Node;

use Moose;
use CGI qw(-utf8);
use URI::Escape;
use Everything::Link;
use Everything::Node::null;
use XML::Generator;

with 'Everything::Globals';

## no critic (ProhibitBuiltinHomonyms)

has 'NODEDATA' => (isa => "HashRef", required => 1, is => "rw");
has 'author' => (is => "ro", lazy => 1, builder => "_build_author");
has 'is_group' => (is => "ro", default => 0);
has 'notes' => (is => "ro", isa => "ArrayRef", lazy => 1, builder => "_build_notes");

sub id
{
  my $self = shift;
  return $self->NODEDATA->{node_id};
}

sub node_id
{
  my $self = shift;
  return $self->NODEDATA->{node_id};
}

sub title
{
  my $self = shift;
  return $self->NODEDATA->{title};
}

sub type
{
  my $self = shift;
  my $type_nodetype = $self->NODEDATA->{type_nodetype};

  # Handle self-referential nodetype (e.g., nodetype nodetype where type_nodetype == node_id)
  # This avoids cache issues with node_by_id for node 1
  if ($type_nodetype == $self->NODEDATA->{node_id}) {
    return $self;
  }

  return $self->APP->node_by_id($type_nodetype);
}

sub author_user
{
  my $self = shift;
  return $self->NODEDATA->{author_user};
}

sub _build_author
{
  my $self = shift;
  return $self->APP->node_by_id($self->author_user) || Everything::Node::null->new;
}

around 'BUILDARGS' => sub {
  my $orig = shift;
  my $class = shift;
  my $NODEDATA = shift;

  return $class->$orig("NODEDATA" => $NODEDATA);
};

sub can_read_node
{
  my ($self, $user) = @_;

  return $self->DB->canReadNode($user->NODEDATA, $self->NODEDATA);
}

sub can_update_node
{
  my ($self, $user) = @_;
  return $self->DB->canUpdateNode($user->NODEDATA, $self->NODEDATA);
}

sub can_delete_node
{
  my ($self, $user) = @_;
  return $self->DB->canDeleteNode($user->NODEDATA, $self->NODEDATA);
}

sub json_reference
{
  my ($self) = @_;
  return $self->APP->node_json_reference($self->NODEDATA);
}

sub json_display
{
  my $self = shift;
  my $values = $self->json_reference(@_);

  # Handle missing/deleted authors gracefully
  my $author = $self->author;
  if ($author && $author->can('json_reference')) {
    $values->{author} = $author->json_reference;
  } else {
    $values->{author} = undef;
  }

  $values->{createtime} = $self->APP->iso_date_format($self->createtime);

  return $values;
}

sub insert
{
  my ($self, $user, $data) = @_;

  my $title = $data->{title};
  unless(defined $title)
  {
    # Everything::Node::insert: Didn't get a title in the data hash, returning
    return;
  }

  delete $data->{title};

  my $new_node_id = $self->DB->insertNode($title, $self->typeclass, $user->NODEDATA,$data, "skip maintenances");
  unless($new_node_id)
  {
    # Did not get good node_id back from insertNode. Returning
    return;
  }

  $self->NODEDATA($self->DB->getNodeById($new_node_id));
  return $self;
}

sub can_create_type
{
  my ($self, $user) = @_;

  return $self->DB->canCreateNode($user->NODEDATA, $self->DB->getType($self->typeclass));
}

sub typeclass
{
  my ($self) = @_;
  my $string = ref($self);
  $string =~ s/.*:://g;
  return $string;
}


sub createtime
{
  my ($self) = @_;
  return $self->NODEDATA->{createtime};
}

sub update
{
  my ($self, $user, $data) = @_;

  my $updater_title = undef;
  my $user_struct = undef;
  if($user and $user eq '-1')
  {
    $updater_title = 'root';
    $user_struct = -1;
  }else{
    $updater_title = $user->title;
    $user_struct = $user->NODEDATA;
  }

  my $NODEDATA = $self->NODEDATA;
  foreach my $key (keys %$data)
  {
    $NODEDATA->{$key} = $data->{$key};
  }
  $self->NODEDATA($NODEDATA);
  if($self->DB->updateNode($self->NODEDATA, $user_struct, undef, "skip maintenance"))
  {
    my $newnode = $self->APP->node_by_id($self->node_id);
    return $newnode;
  }else{
    return;
  }
}

sub delete
{
  my ($self, $user) = @_;

  return $self->DB->nukeNode($self->NODEDATA, $user->NODEDATA, undef, "skip maintenances");
}

sub field_whitelist
{
  my ($self, $user) = @_;

  return [];
}

# TODO: Is this still useful?
sub url_safe_title
{
  my ($self) = @_;

  my $title = $self->title;
  $title = CGI::escape(CGI::escape($title));
  # Make spaces more readable
  # But not for spaces at the start/end or next to other spaces
  $title =~ s/(?<!^)(?<!\%2520)\%2520(?!$)(?!\%2520)/\+/gs;
  return $title;
}

sub uri_safe_title
{
  my ($self) = @_;

  return uri_escape_utf8($self->title);
}

sub canonical_url
{
  my ($self) = @_;
  return "/".join("/","node",$self->type->uri_safe_title,$self->uri_safe_title);
}

sub metadescription
{
  return "Everything2 is a community for fiction, nonfiction, poetry, reviews, and more. Get writing help or enjoy nearly a half million pieces of original writing.";
}

sub ed_cooled
{
  my ($self) = @_;
  my $coollink = $self->APP->node_by_name('coollink','linktype');
  return $coollink->any_link($self);
}

sub can_be_bookmarked
{
  my ($self) = @_;
  return $self->APP->can_bookmark($self->NODEDATA);
}

sub can_be_categoried
{
  my ($self) = @_;
  return $self->APP->can_category_add($self->NODEDATA);
}

sub can_be_weblogged
{
  my ($self) = @_;
  return $self->APP->can_weblog($self->NODEDATA);
}

sub is_null
{
  my ($self) = @_;
  return 0;
}

sub _build_notes
{
  my ($self) = @_;

  my $csr = $self->DB->sqlSelectMany("*", "nodenote", "nodenote_nodeid=".$self->node_id." order by timestamp desc");

  my $outdata = [];
  while(my $row = $csr->fetchrow_hashref)
  {
    push @{$outdata}, $row;
  }

  return $outdata;
}

sub cache_refresh
{
  my ($self) = @_;
  $self->{NODEDATA} = $self->DB->getNodeById($self->node_id,'force');
  return $self->NODEDATA;
}

sub clone
{
  my ($self, $new_title, $user) = @_;

  unless($new_title)
  {
    # Must provide a title for the cloned node
    return;
  }

  unless($user)
  {
    # Must provide a user for the clone operation
    return;
  }

  # Create a copy of the node data
  my %cloned_data = %{$self->NODEDATA};

  # Remove fields that should not be copied to the new node
  delete $cloned_data{node_id};     # New node gets new ID
  delete $cloned_data{type};        # Type is set by insertNode
  delete $cloned_data{group};       # Group should be recalculated
  delete $cloned_data{title};       # Using the new title instead
  delete $cloned_data{_ORIGINAL_VALUES}; # Internal tracking field

  # Insert the cloned node with the new title
  my $new_node_id = $self->DB->insertNode($new_title, $self->type->NODEDATA, $user->NODEDATA, \%cloned_data);

  unless($new_node_id)
  {
    # Failed to create cloned node
    return;
  }

  # Return the new node object
  return $self->APP->node_by_id($new_node_id);
}

sub to_xml
{
  my ($self, $except) = @_;

  $except ||= [];
  my $NODE = $self->NODEDATA;

  # Create a copy of the node so we can modify it
  my %newhash = %$NODE;
  my $N = \%newhash;

  # Fields to exclude from XML export
  my @NOFIELDS = ('hits',
    'createtime',
    'table',
    'type',
    'lasttime',
    'lockedby_user',
    'locktime',
    'tableArray',
    'resolvedInheritance', 'passwd', 'nltext', 'sqltablelist');

  push @NOFIELDS, @$except if $except;

  # Remove excluded fields
  foreach (@NOFIELDS) {
    delete $N->{$_} if exists $N->{$_};
  }

  # Remove all fields ending in _id (node references stored as IDs)
  foreach (keys %$N) {
    delete $N->{$_} if /_id$/;
  }

  my $XMLGEN = XML::Generator->new();
  my $str = "";
  $str .= $XMLGEN->INFO('rendered by Everything::Node->to_xml()') . "\n";

  # Get table information for field attributes
  my @tables = Everything::getTables($NODE);
  push @tables, 'node';

  my %fieldtable;
  foreach my $table (@tables) {
    my @fields = $self->DB->getFields($table);
    foreach (@fields) {
      $fieldtable{$_} = $table if (exists $N->{$_});
    }
  }

  # Generate XML for each field
  my @keys = sort {$a cmp $b} (keys %$N);
  foreach my $field (@keys) {
    my %attr = (table => $fieldtable{$field});
    $str .= "\t";

    if (ref $N->{$field} eq "ARRAY") {
      # Handle group fields (arrays of node references)
      delete $attr{table};
      $str .= $self->_group_to_xml($field, $N->{$field}, \%attr, $XMLGEN);
    } elsif ($field eq 'vars') {
      # Handle vars hash
      $str .= $self->_vars_to_xml($field, Everything::getVars($N), \%attr, $XMLGEN);
    } elsif ($field =~ /_\w+$/ and defined($N->{$field}) and $N->{$field} =~ /^\d+$/) {
      # Handle node references (fields ending with underscore+word that contain numeric IDs)
      $str .= $self->_noderef_to_xml($field, $N->{$field}, \%attr, $XMLGEN);
    } else {
      # Regular field
      $str .= $self->_gen_tag($field, $N->{$field}, \%attr, 0, $XMLGEN);
    }
  }

  return $XMLGEN->NODE($str);
}

sub _gen_tag
{
  my ($self, $tag, $content, $PARAMS, $embedXML, $XMLGEN) = @_;
  return unless $tag;
  $PARAMS ||= {};

  if (defined($content)) {
    unless ($embedXML) {
      $content = $self->APP->xml_escape($content);
    }
  }

  return $XMLGEN->$tag($PARAMS, $content) . "\n";
}

sub _vars_to_xml
{
  my ($self, $tag, $VARS, $PARAMS, $XMLGEN) = @_;
  $PARAMS ||= {};
  my $varstr = "";

  foreach my $key (keys %$VARS) {
    $varstr .= "\t\t";
    if ($key =~ /_(\w+)$/ and $VARS->{$key} =~ /^\d+$/) {
      # This is a node reference
      $varstr .= $self->_noderef_to_xml($key, $VARS->{$key}, {}, $XMLGEN);
    } else {
      $varstr .= $self->_gen_tag($key, $VARS->{$key}, {}, 0, $XMLGEN);
    }
  }

  return $self->_gen_tag($tag, "\n" . $varstr . "\t", $PARAMS, 1, $XMLGEN);
}

sub _group_to_xml
{
  my ($self, $tag, $group, $PARAMS, $XMLGEN) = @_;
  $PARAMS ||= {};
  my $ingroup = "";
  my $count = 1;

  foreach (@$group) {
    my $localtag = "groupnode" . $count++;
    $ingroup .= "\t\t" . $self->_noderef_to_xml($localtag, $_, {table => 'nodegroup'}, $XMLGEN);
  }

  return $self->_gen_tag($tag, "\n" . $ingroup . "\t", $PARAMS, 1, $XMLGEN);
}

sub _noderef_to_xml
{
  my ($self, $tag, $node_id, $PARAMS, $XMLGEN) = @_;
  $PARAMS ||= {};

  my $POINTED_TO = $self->DB->getNodeById($node_id);
  my ($title, $typetitle);

  if (keys %$POINTED_TO) {
    $title = $POINTED_TO->{title};
    $typetitle = $POINTED_TO->{type}{title};
  } else {
    # This can happen with the '-1' field values when nodetypes are inherited
    $title = $node_id;
    $typetitle = "literal_value";
  }

  $PARAMS->{type} = $typetitle;
  return $self->_gen_tag($tag, $title, $PARAMS, 0, $XMLGEN);
}

__PACKAGE__->meta->make_immutable;
1;
