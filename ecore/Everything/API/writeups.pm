package Everything::API::writeups;

use Moose;
extends 'Everything::API::nodes';

has 'CREATE_ALLOWED' => (is => 'ro', isa => 'Int', default => 1);

sub translate_create_params
{
  my ($self, $postdata) = @_;

  unless(defined($postdata->{writeuptype}) and defined($postdata->{title}) and defined($postdata->{doctext}))
  {
    # Writeup create API needs writeuptype, title, and doctext; missing at least one
    return;
  }

  my $writeuptype = $self->APP->node_by_name($postdata->{writeuptype},"writeuptype");
  if($writeuptype)
  {
    $postdata->{wrtype_writeuptype} = $writeuptype->node_id
  }else{
    $self->devLog("Invalid writeuptype '".$postdata->{writeuptype}."', returning BAD REQUEST");
    return;
  }

  my $e2node = $self->APP->node_by_name($postdata->{title},"e2node");
  if($e2node)
  {
    $postdata->{parent_e2node} = $e2node->node_id;
  }else{
    $self->devLog("Invalid parent e2node: '".$postdata->{title}."', returning BAD REQUEST");
    return;
  }

  $postdata->{title} = $postdata->{title}." (".$writeuptype->title.")";

  return $postdata;
}

# Gate in-place writeuptype changes (issue #4224) before the inherited
# permission wrapper + generic field whitelist run. This only adds the
# editor-only restriction on 'definition'/'lede'; author/editor edit permission
# is still enforced by the parent's `around 'update' => _can_update_okay`.
#
# It MUST be an `around`, not a plain `sub update` override: a subclass method
# would shadow the parent's wrapped method and silently drop that permission
# check. As the most-derived modifier this runs first, sees the raw ($REQUEST,
# $id) route args, and on success delegates straight through to the permission
# wrapper via $orig.
#
# We pass the writeup's *current* type so a non-editor who already owns a
# restricted-type writeup can keep it while editing the body, and never gets
# silently downgraded -- the #3396 trap. Reject as HTTP 200 + success=0 so the
# JSON client sees a clean error, never mod_perl error HTML.
around 'update' => sub
{
  my ($orig, $self, $REQUEST, $id) = @_;

  my $postdata = $REQUEST->JSON_POSTDATA;
  if(ref($postdata) eq "HASH" and defined($postdata->{wrtype_writeuptype}))
  {
    my $writeup = $self->APP->node_by_id(int($id));

    # Only enforce on an actual writeup; anything else falls through to the
    # inherited wrapper, which returns the right 404/permission response.
    if($writeup and $writeup->type and $writeup->type->title eq "writeup")
    {
      my $new_writeuptype = $self->APP->node_by_id(int($postdata->{wrtype_writeuptype}));
      unless($new_writeuptype and $new_writeuptype->type and $new_writeuptype->type->title eq "writeuptype")
      {
        $self->devLog("writeup update: invalid writeuptype id '".$postdata->{wrtype_writeuptype}."'");
        return [$self->HTTP_OK, {success => 0, error => "invalid_writeuptype", message => "Invalid writeup type."}];
      }

      unless($self->APP->can_set_writeuptype({
        is_editor    => $REQUEST->user->is_editor,
        username     => $REQUEST->user->title,
        new_type     => $new_writeuptype->title,
        current_type => $writeup->writeuptype,
      }))
      {
        $self->devLog("writeup update: ".$REQUEST->user->title." may not set writeuptype '".$new_writeuptype->title."'");
        return [$self->HTTP_OK, {success => 0, error => "writeuptype_not_allowed",
          message => "The '".$new_writeuptype->title."' writeup type can only be set by editors."}];
      }
    }
  }

  return $self->$orig($REQUEST, $id);
};

__PACKAGE__->meta->make_immutable;
1;
