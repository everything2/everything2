--
-- Table structure for table 'cache_store'
--

CREATE TABLE IF NOT EXISTS cache_store (
  cache_store_id int(11) NOT NULL auto_increment,
  page text,
  expired int(11) NOT NULL default '0',
  version int(11) NOT NULL default '0',
  tstamp timestamp,
  INDEX tstamp (tstamp),
  PRIMARY KEY  (cache_store_id)
) TYPE=MyISAM;

--
-- Table structure for table 'stats'
--

CREATE TABLE IF NOT EXISTS stats (
  stats_id int(11) NOT NULL auto_increment,
  hits int(11) default '0',
  miss int(11) default '0',
  PRIMARY KEY  (stats_id)
) TYPE=MyISAM;

DELETE
  cache_store, stats
  FROM cache_store JOIN stats
  ON cache_store_id = stats_id
  WHERE cache_store.tstamp < DATE_SUB(NOW(), INTERVAL 60 MINUTE)

