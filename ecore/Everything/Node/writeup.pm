package Everything::Node::writeup;

use Moose;
extends 'Everything::Node::document';

override 'json_display' => sub
{
  my ($self, $user) = @_;
  my $writeup = $self->single_writeup_display($user);
  my $softlinks = $self->parent->softlinks($user);
  if(scalar(@$softlinks))
  {
    $writeup->{softlinks} = $softlinks;
  }

  return $writeup;
};

sub single_writeup_display
{
  my ($self, $user) = @_;

  my $values = $self->SUPER::json_display;

  my $cools = $self->cools;
  if(scalar(@$cools) > 0)
  {
    $values->{cools} = $cools;
  }

  $values->{writeuptype} = $self->writeuptype;

  # Add author lasttime data for logged-in users
  # Used for "time since author was here" display
  my $author = $self->author;
  if($author && !UNIVERSAL::isa($author, "Everything::Node::null"))
  {
    my $author_vars = $author->VARS || {};

    # Add lasttime (as ISO date)
    if($author->lasttime)
    {
      $values->{author}{lasttime} = $self->APP->iso_date_format($author->lasttime);
    }

    # Add hidelastseen flag so React can respect author's privacy setting
    $values->{author}{hidelastseen} = int($author_vars->{hidelastseen} || 0);

    # Mark if author is a bot (Webster 1913)
    $values->{author}{is_bot} = ($author->title eq 'Webster 1913') ? 1 : 0;
  }

  return $values if $user->is_guest;

  my $vote = $self->user_has_voted($user);

  if($self->author_user == $user->node_id)
  {
    $values->{notnew} = $self->notnew;
  }

  if($vote || $self->author_user == $user->node_id)
  {
    foreach my $key ("reputation","upvotes","downvotes")
    {
      $values->{$key} = int($self->$key);
    }
  }

  if($vote)
  {
    $values->{vote} = $vote->{weight};
  }

  my $parent = $self->parent;
  if($parent && !UNIVERSAL::isa($parent, "Everything::Node::null"))
  {
    $values->{parent} = $parent->json_reference;
    # Add writeup count from parent's group
    my $parent_group = $parent->group || [];
    $values->{parent}{writeup_count} = scalar(@$parent_group);
  }

  # Add insured status for editors
  if($user->is_editor)
  {
    my $insured_status = $self->DB->getNode('insured', 'publication_status');
    if($insured_status)
    {
      my $current_status = $self->DB->sqlSelect('publication_status', 'draft', "draft_id=" . $self->node_id);
      $values->{insured} = ($current_status && $current_status == $insured_status->{node_id}) ? 1 : 0;

      # If insured, get publisher info
      if($values->{insured})
      {
        my $publisher_id = $self->DB->sqlSelect('publisher', 'publish', "publish_id=" . $self->node_id);
        if($publisher_id)
        {
          my $publisher = $self->APP->node_by_id($publisher_id);
          if($publisher && $publisher->type->title eq 'user')
          {
            $values->{insured_by} = {
              node_id => $publisher->node_id,
              title => $publisher->title
            };
          }
        }
      }
    }

    # Check if the parent e2node has an editor cool
    if($parent && !UNIVERSAL::isa($parent, "Everything::Node::null"))
    {
      my $coollink_type = $self->DB->getNode('coollink', 'linktype');
      if($coollink_type)
      {
        my $edcool_link = $self->DB->sqlSelectHashref('to_node', 'links',
          'from_node=' . $parent->node_id . ' AND linktype=' . $coollink_type->{node_id} . ' LIMIT 1');
        $values->{edcooled} = $edcool_link ? 1 : 0;
      }
    }
  }

  # Check if user has bookmarked this writeup
  if(!$user->is_guest)
  {
    my $bookmark_type = $self->DB->getNode('bookmark', 'linktype');
    if($bookmark_type)
    {
      my $bookmark_link = $self->DB->sqlSelectHashref('*', 'links',
        'from_node=' . $user->node_id . ' AND to_node=' . $self->node_id . ' AND linktype=' . $bookmark_type->{node_id});
      $values->{bookmarked} = $bookmark_link ? 1 : 0;
    }

    # Add social sharing information if user hasn't disabled it
    my $user_vars = $user->VARS;
    unless($user_vars->{nosocialbookmarking})
    {
      # Generate short URL for social sharing
      my $short_url = $self->APP->create_short_url($self->NODEDATA);
      my $share_title = $self->title;
      if($parent && !UNIVERSAL::isa($parent, "Everything::Node::null"))
      {
        $share_title = $parent->title;
      }
      $values->{social_share} = {
        short_url => $short_url,
        title => $share_title
      };
    }
  }

  return $values;
}

sub cools
{
  my ($self) = @_;

  my $csr = $self->DB->sqlSelectMany("*","coolwriteups","coolwriteups_id=".$self->node_id." ORDER BY tstamp");
  my $cools = [];
  while(my $row = $csr->fetchrow_hashref)
  {
    my $cooledby = $self->APP->node_by_id($row->{cooledby_user});
    next unless $cooledby;
    push @$cools, $cooledby->json_reference;
  }

  return $cools;
}

sub user_has_voted
{
  my ($self,$user) = @_;

  my $record = $self->DB->sqlSelectHashref("*","vote","voter_user=".$user->node_id." and vote_id=".$self->node_id);
  if($record)
  {
    return $record;
  }
}

sub reputation
{
  my ($self) = @_;
  return $self->NODEDATA->{reputation};
}

sub downvotes
{
  my ($self) = @_;
  return $self->vote_count(-1);
}

sub upvotes
{
  my ($self) = @_;
  return $self->vote_count(1);
}

sub vote_count
{
  my ($self, $direction) = @_;
  return $self->DB->sqlSelect("count(*)","vote","vote_id=".$self->node_id." and weight=$direction");
}

sub parent
{
  my ($self) = @_;

  return $self->APP->node_by_id($self->NODEDATA->{parent_e2node}) || Everything::Node::null->new;
}

sub writeuptype
{
  my ($self) = @_;

  if(defined($self->NODEDATA->{wrtype_writeuptype}))
  {
    if(my $writeuptype = $self->APP->node_by_id($self->NODEDATA->{wrtype_writeuptype}))
    {
      return $writeuptype->title;
    }
  }
  return;
}

sub publishtime
{
  my ($self) = @_;
  return $self->NODEDATA->{publishtime};
}

sub canonical_url
{
  my ($self) = @_;
  return "/user/".$self->author->uri_safe_title."/writeups/".$self->parent->uri_safe_title;
}

sub notnew
{
  my ($self) = @_;
  return int($self->NODEDATA->{notnew} || 0);
}

sub is_junk
{
  my ($self) = @_;

  return ($self->reputation < $self->CONF->writeuplowrepthreshold) || 0;
}

sub is_log
{
  my ($self) = @_;

  return ($self->title =~ /^((January|February|March|April|May|June|July|August|September|October|November|December) [[:digit:]]{1,2}, [[:digit:]]{4})|(dream|editor|root) Log: /i) || 0;
}

sub field_whitelist
{
  return ["doctext","parent_e2node","wrtype_writeuptype","notnew"];
}

sub new_writeups_reference
{
  my ($self) = @_;

  my $outdata = {};

  foreach my $key (qw|author parent|)
  {
    unless(UNIVERSAL::isa($self->$key, "Everything::Node::null"))
    {
      $outdata->{$key} = $self->$key->json_reference;
    }
  }

  foreach my $key (qw|title notnew node_id is_junk is_log writeuptype|)
  {
    $outdata->{$key} = $self->$key;
  }

  return $outdata;
}

around 'insert' => sub {
 my ($orig, $self, $user, $data) = @_;

 my $newnode = $self->$orig($user, $data);

 # TODO: better superuser insert
 my $root = $self->APP->node_by_name("root","user");
 my $parent = $newnode->parent;
 $parent->group_add([$newnode->node_id], $root);
 $parent->update($root);

 return $newnode;
};

__PACKAGE__->meta->make_immutable;
1;
