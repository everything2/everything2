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
  *listCode = *Everything::HTML::listCode;
  *isGod = *Everything::HTML::isGod;
  *getRef = *Everything::HTML::getRef;
  *urlGen = *Everything::HTML::urlGen;
  *urlGenNoParams = *Everything::HTML::urlGenNoParams;
  *insertNodelet = *Everything::HTML::insertNodelet;
  *breakTags = *Everything::HTML::breakTags;
  *screenTable = *Everything::HTML::screenTable;
  *encodeHTML = *Everything::HTML::encodeHTML;
  *cleanupHTML = *Everything::HTML::cleanupHTML;
  *getType = *Everything::HTML::getType;
  *htmlScreen = *Everything::HTML::htmlScreen;
  *updateNode = *Everything::HTML::updateNode;
  *rewriteCleanEscape = *Everything::HTML::rewriteCleanEscape;
  *setVars = *Everything::HTML::setVars;
  *cleanNodeName = *Everything::HTML::cleanNodeName;
  *getNodeWhere = *Everything::HTML::getNodeWhere;
  *insertIntoNodegroup = *Everything::HTML::insertIntoNodegroup;
  *recordUserAction = *Everything::HTML::recordUserAction;
  *linkNodeTitle = *Everything::HTML::linkNodeTitle;
  *confirmUser = *Everything::HTML::confirmUser;
  *removeFromNodegroup = *Everything::HTML::removeFromNodegroup;
  *canUpdateNode = *Everything::HTML::canUpdateNode;
  *updateLinks = *Everything::HTML::updateLinks;
  *changeRoom = *Everything::HTML::changeRoom;
  *cloak = *Everything::HTML::cloak;
  *uncloak = *Everything::HTML::uncloak;
  *isMobile = *Everything::HTML::isMobile;
  *isSuspended = *Everything::HTML::isSuspended;
  *escapeAngleBrackets = *Everything::HTML::escapeAngleBrackets;
  *canReadNode = *Everything::HTML::canReadNode;
  *canDeleteNode = *Everything::HTML::canDeleteNode;
  *hasVoted = *Everything::HTML::hasVoted;
  *getHRLF = *Everything::HTML::getHRLF;
  *evalCode = *Everything::HTML::evalCode;
  *getCompiledCode = *Everything::HTML::getCompiledCode;
  *getPageForType = *Everything::HTML::getPageForType;
  *castVote = *Everything::HTML::castVote;
  *adjustGP = *Everything::HTML::adjustGP;
  *adjustExp = *Everything::HTML::adjustExp;
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
  $canCreate = 0 if isSuspended($USER, 'room');

  if (!$canCreate) {
    nukeNode($N, -1);
    return;
  }

  getRef($N);
  $$N{criteria} = "1;";
  $$N{author_user} = getId(getNode('gods', 'usergroup'));
  updateNode($N, -1);
}

1;
