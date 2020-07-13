#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Test::More;
use Test::Deep;

use_ok("Everything::Configuration");

# Use the default, and get the config file from the dev environment
ok(my $CONF = Everything::Configuration->new());
ok($CONF->site_url eq "https://everything2.com");

ok($CONF = Everything::Configuration->new("/etc/everything/everything.conf.json"));
ok($CONF->site_url eq "https://everything2.com");

# Test for this construct
ok($CONF = Everything::Configuration->new("configfile" => "/etc/everything/everything.conf.json"));
ok($CONF->site_url eq "https://everything2.com");

# Read from non-default config
ok($CONF = Everything::Configuration->new("testdata/config_1.json"));
ok($CONF->site_url eq "http://example.com");

# Catch warnings for single file that doesn't exist

my $warn_message = "";

eval {
  local $SIG{__DIE__} = sub {$warn_message = shift};
  $CONF = Everything::Configuration->new("testdata/config_doesntexist.json");
};
ok($! and $warn_message ne "");


# Other format of file that doesn't exist
$warn_message = "";
eval {
  local $SIG{__DIE__} = sub {$warn_message = shift};
  $CONF = Everything::Configuration->new("configfile" => "testdata/config_alsodoesntexist.json");
};
ok($! and $warn_message ne "");

# No config file, read all values from hash
ok($CONF = Everything::Configuration->new("site_url" => "http://everything3.com", "default_style" => "Kernel Bluest", "guest_user" => "202"));
ok($CONF->site_url eq "http://everything3.com");

# Make sure each attribute is accessible
ok($CONF = Everything::Configuration->new("testdata/config_2.json"));

ok($CONF->configfile eq "testdata/config_2.json");
ok($CONF->basedir eq "/var/everything");
ok($CONF->guest_user == 779713);
ok($CONF->site_url eq "http://everything2.com");
ok(cmp_deeply($CONF->infected_ips,["10.10.10.10"])); 
ok($CONF->default_style eq "Kernel Blue");
ok($CONF->everyuser eq "everyuser");
ok($CONF->everypass eq "anotherpass");
ok($CONF->everything_dbserv eq "localhost");
ok($CONF->database eq "everything");
ok($CONF->cookiepass eq "userpass");
ok($CONF->canonical_web_server eq "localhost");
ok($CONF->homenode_image_host eq "hnimagew.everything2.com");
ok($CONF->smtp_host eq "localhost");
ok($CONF->smtp_use_ssl == 1);
ok($CONF->smtp_port == 465);
ok($CONF->mail_from eq 'accounthelp@everything2.com');
ok($CONF->environment eq "development");
ok($CONF->notification_email eq "");
ok($CONF->nodecache_size == 200);
ok(cmp_deeply($CONF->s3, { 
    "homenodeimages" => { "bucket" => "", "secret_access_key" => "", "access_key_id" => "" },
    "nodebackup" => { "bucket" => "", "secret_access_key" => "", "access_key_id" => ""},
    "backup" => { "bucket" => "", "secret_access_key" => "", "access_key_id" => "" },
    "sitemap" => { "bucket" => "", "secret_access_key" => "", "access_key_id" => "" },
    "jscss" => { "bucket" => "", "secret_access_key" => "","access_key_id" => "" } }));
ok($CONF->clean_search_words_aggressively == 1);
ok($CONF->environment eq "development");
ok($CONF->notification_email eq "");
ok($CONF->nodecache_size == 200);
ok($CONF->logdirectory eq "/var/log/everything");
ok(ref $CONF->permanent_cache eq "HASH"); 
ok(ref $CONF->nosearch_words eq "HASH");
ok($CONF->create_room_level == 5);
ok($CONF->stylesheet_fix_level == 2);
ok($CONF->maintenance_mode == 0);
ok($CONF->writeuplowrepthreshold == -8);
ok(ref $CONF->google_ads_badnodes eq "ARRAY");
ok(ref $CONF->google_ads_badwords eq "ARRAY");

# Check for all non-default values
ok($CONF = Everything::Configuration->new("testdata/config_3.json"));
ok($CONF->basedir eq "basedir_value");
ok($CONF->guest_user == 123456);
ok($CONF->site_url eq "site_url");
ok(cmp_deeply($CONF->infected_ips,["1.2.3.4"]));
ok($CONF->default_style eq "Ice Cream!");
ok($CONF->everyuser eq "anotheruser");
ok($CONF->everypass eq "anotherpass");
ok($CONF->everything_dbserv eq "anotherhost");
ok($CONF->database eq "anotherdatabase");
ok($CONF->cookiepass eq "anothercookiepass");
ok($CONF->canonical_web_server eq "anotherwebserver");
ok($CONF->homenode_image_host eq "anotherimagehost");
ok($CONF->smtp_host eq "anothersmtphost");
ok($CONF->smtp_use_ssl == 0);
ok($CONF->smtp_port == 654321);
ok($CONF->mail_from eq "anothermailfrom");
ok($CONF->environment eq "anotherenvironment");
ok($CONF->notification_email eq "anothernotificationemail");
ok($CONF->nodecache_size == 123);
ok(cmp_deeply($CONF->s3,{
  "homenodeimages" => {"bucket" => "s3.homenodeimages.bucket", "secret_access_key" => "s3.homenodeimages.secret_access_key", "access_key_id" => "s3.homenodeimages.access_key_id"},
  "nodebackup" => {"bucket" => "s3.nodebackup.bucket", "secret_access_key" => "s3.nodebackup.secret_access_key", "access_key_id" => "s3.nodebackup.access_key_id"},
  "backup" => {"bucket" => "s3.backup.bucket", "secret_access_key" => "s3.backup.secret_access_key", "access_key_id" => "s3.backup.access_key_id"},
  "sitemap" => {"bucket" => "s3.sitemap.bucket", "secret_access_key" => "s3.sitemap.secret_access_key", "access_key_id" => "s3.sitemap.access_key_id"},
  "jscss" => {"bucket" => "s3.jscss.bucket", "secret_access_key" => "s3.jscss.secret_access_key", "access_key_id" => "s3.jscss.access_key_id"}
  }));

ok($CONF->static_nodetypes == 0);
ok(cmp_deeply($CONF->memcache, {"somevalue" => "here"}));
ok($CONF->clean_search_words_aggressively == 0);
ok($CONF->search_row_limit == 321);
ok($CONF->logdirectory eq "anotherlogdirectory");
ok($CONF->create_room_level == 99);
ok($CONF->stylesheet_fix_level == 98);
ok($CONF->maintenance_mode == 1);
ok($CONF->writeuplowrepthreshold == -97);

done_testing();
