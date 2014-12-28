package Everything::Delegation::maintenance;

# We have to assume that this module is subservient to Everything::HTML
#  and that the symbols are always available

# TODO: use strict
# TODO: use warnings
BEGIN {
  *getNode = *Everything::HTML::getNode;
  *getNodeById = *Everything::HTML::getNodeById;
  *getVars = *Everything::HTML::getVars;
  *getId = *Everything::HTML::getId;
  *urlGen = *Everything::HTML::urlGen;
  *linkNode = *Everything::HTML::linkNode;
  *htmlcode = *Everything::HTML::htmlcode;
  *parseCode = *Everything::HTML::parseCode;
  *parseLinks = *Everything::HTML::parseLinks;
  *isNodetype = *Everything::HTML::isNodetype;
  *isGod = *Everything::HTML::isGod;
  *getRef = *Everything::HTML::getRef;
  *insertNodelet = *Everything::HTML::insertNodelet;
  *getType = *Everything::HTML::getType;
  *updateNode = *Everything::HTML::updateNode;
  *setVars = *Everything::HTML::setVars;
  *getNodeWhere = *Everything::HTML::getNodeWhere;
  *insertIntoNodegroup = *Everything::HTML::insertIntoNodegroup;
  *linkNodeTitle = *Everything::HTML::linkNodeTitle;
  *removeFromNodegroup = *Everything::HTML::removeFromNodegroup;
  *canUpdateNode = *Everything::HTML::canUpdateNode;
  *updateLinks = *Everything::HTML::updateLinks;
  *isMobile = *Everything::HTML::isMobile;
  *canReadNode = *Everything::HTML::canReadNode;
  *canDeleteNode = *Everything::HTML::canDeleteNode;
  *evalCode = *Everything::HTML::evalCode;
  *getPageForType = *Everything::HTML::getPageForType;
  *opLogin = *Everything::HTML::opLogin;
  *replaceNodegroup = *Everything::HTML::replaceNodegroup; 
} 

# Used by writeup_create
use JSON;

sub room_create
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($N) = @_;

  my $canCreate = ($APP->getLevel($USER) >= $Everything::CONF->create_room_level or isGod($USER));
  $canCreate = 0 if $APP->isSuspended($USER, 'room');

  if (!$canCreate) {
    nukeNode($N, -1);
    return;
  }

  $DB->getRef($N);
  $$N{criteria} = "1;";
  $$N{author_user} = getId(getNode('gods', 'usergroup'));
  updateNode($N, -1);
}

sub dbtable_create
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # This gets called for each new dbtable node.  We
  # want to create the associated table here.
  my ($thisnode) = @_;

  $DB->getRef($thisnode);
  $DB->createNodeTable($thisnode->{title});
}

sub dbtable_delete
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;
  # This gets called each time a dbtable node gets deleted.
  # We want to delete the associated table here.
  my ($thisnode) = @_;

  $DB->getRef($thisnode);
  $DB->dropNodeTable($$thisnode{title});
}

sub writeup_create
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($WRITEUP) = @_;
  $DB->getRef($WRITEUP);

  # This is an odd consession for the time being so that maintenance functions can properly
  # bomb out if there isn't a CGI object in place
  return unless $query;

  my $E2NODE = $query->param('writeup_parent_e2node');
  $DB->getRef($E2NODE);

  # we need an e2node to insert the writeup into,
  # and the writeup must have some text:
  my $problem = (!$E2NODE or $query->param("writeup_doctext") eq '');

  # the user must be allowed to publish, the node must not be locked,
  # and the user must not have a writeup there already:
  $problem ||= htmlcode('nopublishreason', $USER, $E2NODE);

  # if no problem, attach writeup to node:
  return htmlcode('publishwriteup', $WRITEUP, $E2NODE) unless $problem;

  # otherwise, we don't want it:
  nukeNode($WRITEUP, -1, 1);

  return unless UNIVERSAL::isa($problem,'HASH');

  # user already has a writeup in this E2node: update it
  $$problem{doctext} = $query->param("writeup_doctext");
  $$problem{wrtype_writeuptype} = $query -> param('writeup_wrtype_writeuptype') if $query -> param('writeup_wrtype_writeuptype');
  updateNode($problem, $USER);

  # redirect to the updated writeup
  $Everything::HTML::HEADER_PARAMS{-status} = 303;
  $Everything::HTML::HEADER_PARAMS{-location} = htmlcode('urlToNode', $problem);

}

sub e2node_create
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($E2NODE) = @_;
  $DB->getRef($E2NODE);

  $$E2NODE{createdby_user} = $$E2NODE{author_user} || $DB->getId($USER);
  $$E2NODE{author_user} = $DB->getId($DB->getNode('Content Editors', 'usergroup')); # Content Editors can update it; author can't

  $DB->updateNode($E2NODE, -1);
}

sub e2node_update
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($E2NODE) = @_;
  $DB->getRef($E2NODE);

  my $CE = $DB->getId($DB->getNode('Content Editors', 'usergroup'));

  if ($$E2NODE{author_user} != $CE) {
    $$E2NODE{createdby_user} = $$E2NODE{author_user};
    $$E2NODE{author_user} = $CE; # Content Editors can update node, creator cannot
    $DB->updateNode($E2NODE, -1);
  }

  $APP->repairE2Node($E2NODE, "no reorder");

}

sub writeup_update
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($WRITEUP) = @_;
  $DB->getRef($WRITEUP);
  return unless $WRITEUP;
  my $E2NODE = $DB->getNodeById($$WRITEUP{parent_e2node});

  return unless $E2NODE;

  # avoid duplicate draft/writeup titles
  foreach ($DB->getNodeWhere({ # should be at most one, but if not, we fix that, too:
    title => $$E2NODE{title}, author_user => $$WRITEUP{author_user}}, 'draft')){
      $DB->updateNode($_, -1);
  }

  $DB->{cache}->incrementGlobalVersion($E2NODE);

  # Also, if run as a script, we don't have $query
  if($query)
  {
    # Make a notification if someone's about to blank a writeup
    if(defined($query->param('writeup_doctext')))
    {
      my $trimmedNewText = $query->param('writeup_doctext');
      $trimmedNewText =~ s/^\s+|\s$//;
  
      return htmlcode('unpublishwriteup', $WRITEUP, 'blanked') unless $trimmedNewText;

      htmlcode('addNotification', 'blankedwriteup', 0, {
        writeup_id => getId($WRITEUP)
        , author_id => $$USER{user_id}
      }) if length $trimmedNewText < 20;
    }

    htmlcode('update New Writeups data') unless $query -> param('op') and $query -> param('op') eq 'vote' || $query -> param('op') eq 'cool';

    if($query->param('writeup_wrtype_writeuptype'))
    {
      my $WRTYPE=getNode($$WRITEUP{wrtype_writeuptype});
      if ($$WRTYPE{type}{title} ne 'writeuptype' or 
        ($$WRTYPE{title} eq 'definition' || $$WRTYPE{title} eq 'lede' and
        not Everything::isApproved($USER, getNode('Content Editors','usergroup'))
        and $$USER{title} ne 'Webster 1913'
        and $$USER{title} ne 'Virgil'))
      {
        $WRTYPE=getNode('thing','writeuptype'); 
        $$WRITEUP{wrtype_writeuptype} = getId($WRTYPE);
      }
      my $title = "$$E2NODE{title} ($$WRTYPE{title})";
      return if $$WRITEUP{title} eq $title;
      #only YOU can prevent deep recursion...

      $APP->repairE2Node($E2NODE);

      $$WRITEUP{title} = $title;
      $DB->updateNode($WRITEUP, -1);
    }

  }

}

sub draft_create
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($D) = @_;
  $DB->getRef($D);

  # make sure it has a publication status
  $$D{publication_status} = ($query && $query->param('draft_publication_status') )|| $DB->getNode('private', 'publication_status')->{node_id};

  # if draft has just been created from an e2node
  # doctext parameter would be ignored because of wrong nodetype prefix
  $$D{doctext} = $query->param('writeup_doctext') if $query && $query->param('writeup_doctext');

  if($USER) #Keep in mind that we're running this in an odd hybrid mode, both as a script where there is no HTML context, and inside of mod_perl
  {
    $DB->updateNode($D, $USER);
  }else{
    $DB->updateNode($D, -1);
  }
}

sub draft_update
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($N) = @_;
  $DB->getRef($N);

  # validate new publication_status. Make 'private' if invalid.
  # notify editor(s) if status changed to review:
  if ($query and $query->param('draft_publication_status') and $query->param('old_publication_status') != $$N{publication_status})
  {
    my $status = getNodeById($$N{publication_status});
    unless ($status && $$status{type}{title} eq 'publication_status')
    {
      $$N{publication_status} = getId(getNode('private', 'publication_status'));
      return $DB->updateNode($N, $USER) if $$N{publication_status};
    }elsif($$status{title} eq 'review'){
      my $editor = $DB->sqlSelect(
        'nodelock_user'
        , 'nodelock'
        , "nodelock_node=$$N{author_user}");

      $editor ||= $DB->sqlSelect(
        'suspendedby_user'
        , 'suspension'
        , "suspension_user=$$N{author_user}
        AND suspension_sustype=".getId(getNode('writeup', 'sustype')));

      # record event in node history:
      my $note = ' (while suspended by '.linkNode($editor).') ' if $editor;
      my $nodenote_id = htmlcode('addNodenote', $$N{node_id}, "author requested review$note");

      # Notify. If no $editor, everyone gets it:
      htmlcode('addNotification', 'draft for review', $editor, {draft_id => $$N{node_id}, nodenote_id => $nodenote_id});

    }
  }

  # avoid empty names/duplicate names for writeups/drafts by same user:
  my $title = my $urTitle = $APP->cleanNodeName($$N{title}) || 'untitled draft';
  my $count = 1;

  while(
    $DB->sqlSelect(
      'node_id',
      'node',
      'title='.$DB->quote($title)."
        AND type_nodetype=$$N{type_nodetype}
        AND author_user=$$N{author_user}
	AND node_id!=$$N{node_id}")
    or $DB -> sqlSelect(
      'writeup_id',
      'node e2 JOIN writeup ON e2.node_id=parent_e2node
        JOIN node wu ON wu.node_id=writeup_id',
      'e2.title='.$DB->quote($title)."
        AND wu.author_user=$$N{author_user}")
  )
  {
    $title = "$urTitle ($count)";
    $count++;
  }

  return if $title eq $$N{title};

  $$N{title} = $title;
  $DB->updateNode($N, $USER);

}

1;
