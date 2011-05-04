drop table cache_store;
drop table stats;

--
-- Table structure for table 'cache_store'
--

CREATE TABLE cache_store (
  cache_store_id int(11) NOT NULL auto_increment,
  page text,
  expired int(11) NOT NULL default '0',
  version int(11) NOT NULL default '0',
  tstamp timestamp,
  PRIMARY KEY  (cache_store_id)
) TYPE=MyISAM;

--
-- Table structure for table 'stats'
--

CREATE TABLE stats (
  stats_id int(11) NOT NULL auto_increment,
  hits int(11) default '0',
  miss int(11) default '0',
  PRIMARY KEY  (stats_id)
) TYPE=MyISAM;

