#!/usr/bin/perl -w

use strict;
use lib qw(/var/libraries/lib/perl5);
use lib qw(/var/everything/ecore);
use Everything;

if($Everything::CONF->environment ne "development")
{
	print "Not in the 'development' environment. Exiting\n";
	exit;
}

`echo "drop database everything" | mysql -u root`;
`echo "create database everything DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci" | mysql -u root`;
`/var/everything/ecoretool/ecoretool.pl bootstrap --nodepack=/var/everything/nodepack`;
`/var/everything/tools/seeds.pl`;
`/var/everything/cron/cron_datastash.pl`;
`/var/everything/cron/cron_datastash.pl --lengthy`;
`/etc/init.d/apache2 restart`;
