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
  *screenTable = *Everything::HTML::screenTable;
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

  my $canCreate = ($APP->getLevel($USER) >= $Everything::CONF->{create_room_level} or isGod($USER));
  $canCreate = 0 if $APP->isSuspended($USER, 'room');

  if (!$canCreate) {
    nukeNode($N, -1);
    return;
  }

  getRef($N);
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

  getRef($thisnode);
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

  getRef($thisnode);
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
  getRef($WRITEUP);

  my $E2NODE = $query->param('writeup_parent_e2node');
  getRef($E2NODE);

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

1;
