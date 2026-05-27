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
print `/var/everything/ecoretool/ecoretool.pl bootstrap --nodepack=/var/everything/nodepack`;
print `/var/everything/tools/seeds.pl`;
print `/var/everything/cron/cron_datastash.pl`;
print `/var/everything/cron/cron_datastash.pl --lengthy`;
# Hard-restart Apache without going through init.d. The stock Debian init
# script wraps the daemon launch with `env -i` (see /etc/init.d/apache2 line
# 39), which strips every container env var except LANG and PATH. That drops
# E2_DBSERV, and Everything::Configuration's lazy default falls back to
# 'localhost' — Apache then tries the local MySQL socket and 500s the next
# request. apachectl -k restart sends SIGHUP to the running master, which
# re-execs itself preserving its own env (which DOES have E2_DBSERV from the
# original `docker run` line). Equivalent reload behavior; env survives.
# Distinct from `apachectl graceful` (banned per CLAUDE.md, doesn't fully
# reset state) — `-k restart` is the hard reset we want.
print `/usr/sbin/apachectl -k restart`;
