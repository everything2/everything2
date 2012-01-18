# MySQL dump 8.16
#
# Host: localhost    Database: everything
#--------------------------------------------------------
# Server version	3.23.42-max-log

#
# Table structure for table 'node'
#

CREATE TABLE node (
  node_id int(11) NOT NULL auto_increment,
  type_nodetype int(11) NOT NULL default '0',
  title char(240) NOT NULL default '',
  author_user int(11) NOT NULL default '0',
  createtime datetime NOT NULL default '0000-00-00 00:00:00',
  hits int(11) default '0',
  reputation int(11) NOT NULL default '0',
  lockedby_user int(11) NOT NULL default '0',
  locktime datetime NOT NULL default '0000-00-00 00:00:00',
  core char(1) default '0',
  package int(11) NOT NULL default '0',
  PRIMARY KEY  (node_id),
  KEY title (title,type_nodetype),
  KEY author (author_user),
  KEY type (type_nodetype),
  KEY createtime (createtime),
  KEY authortype (type_nodetype,author_user)
) TYPE=MyISAM PACK_KEYS=1;

