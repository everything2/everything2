package Everything::Delegation::opcode;

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
  *stripCode = *Everything::HTML::stripCode;
} 

sub publishdraft
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;
  # turn a draft into a writeup and pass it on for insertion into an e2node

  my $e2node = $query -> param('writeup_parent_e2node');

  my $draft = $query -> param('draft_id');
  getRef $draft;

  return unless $draft and $$draft{doctext} and $$draft{type}{title} eq 'draft' and
    $$USER{node_id} == $$draft{author_user} || $APP->isEditor($USER);

  my $publishAs = $query -> param('publishas');
  if ($publishAs){
    return if htmlcode('nopublishreason', $USER) || htmlcode('canpublishas', $publishAs) != 1;
    $publishAs = getNode($publishAs, 'user');
  }

    if ($e2node =~ /\D/){
      # not a node_id: new node
      my $title = cleanNodeName($query -> param('title'));
      return unless $title;
      $query -> param('e2node_createdby_user', $$publishAs{node_id}) if $publishAs;
      $e2node = $DB -> insertNode($title, 'e2node', $USER);
      $query -> param('writeup_parent_e2node', $e2node);
    }

    # Modify the current global here
    $NODE = getNodeById($e2node);
    return unless $NODE and $$NODE{type}{title} eq 'e2node';

    return if htmlcode('nopublishreason', $publishAs || $USER, $thisnode);
	
    my $wu = $$draft{node_id};
	
    return unless $DB -> sqlUpdate('node, draft', {
      type_nodetype => getType('writeup') -> {node_id},
      publication_status => 0
      },
      "node_id=$wu AND draft_id=$wu"
    );
	
    # remove any old attachment:
    my $linktype = getId(getNode 'parent_node', 'linktype');
    $DB -> sqlDelete('links', "from_node=$$draft{node_id} AND linktype=$linktype");
	
    $DB -> sqlInsert('writeup', {
      writeup_id => $wu,
      parent_e2node => $e2node,
      cooled => $DB->sqlSelect('count(*)', 'coolwriteups', "coolwriteups_id=$wu"),
      notnew => $query -> param('writeup_notnew') || 0
    });
	
    $DB -> sqlUpdate('hits', {hits => 0}, "node_id=$wu");
	
    $DB -> {cache} -> incrementGlobalVersion($draft); # tell other processes this has changed...
    $DB -> {cache} -> removeNode($draft); # and it's in the wrong typecache, so remove it
	
    # if it has a history, note publication
    htmlcode('addNodenote', $wu, 'Published') if $DB -> sqlSelect('nodenote_id', 'nodenote', "nodenote_nodeid=$wu and noter_user=0");
	
    getRef $wu;
    $query -> param('node_id', $e2node);
	
    $$wu{author_user} = getId($publishAs) if $publishAs;
    htmlcode('publishwriteup', $wu, $NODE);

}

1;
