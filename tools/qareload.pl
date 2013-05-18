#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Everything;

if(not exists $Everything::CONF->{environment} or $Everything::CONF->{environment} ne "development")
{
	print "Not in the 'development' environment. Exiting\n";
	exit;
}

`echo "drop database everything" | mysql -u root`;
`echo "create database everything" | mysql -u root`;
`/var/everything/ecoretool/ecoretool.pl bootstrap --nodepack=/var/everything/nodepack`;
