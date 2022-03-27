#!/usr/bin/env perl

use strict;
use lib qw(/var/libraries/lib/perl5);
use lib qw(/var/everything/ecore);

use Everything;
initEverything 'everything';


foreach my $item (qw(configfile configdir site_url guest_user infected_ips default_style everyuser everypass everything_dbserv database cookiepass canonical_web_server homenode_image_host mail_from nodecache_size environment s3 static_nodetypes clean_search_words_aggressively search_row_limit logdirectory use_local_javascript site_name create_new_user default_guest_node maintenance_nodes permanent_cache nosearch_words recaptcha_v3_public_key google_ads_badwords google_ads_badnodes))
{
  if(UNIVERSAL::isa($Everything::CONF->$item,"ARRAY"))
  {
    print "$item: ARRAY ";
    print "[".join(",",@{$Everything::CONF->$item})."]\n";
  }elsif(UNIVERSAL::isa($Everything::CONF->$item,"HASH")){
    print "$item: HASH ";
    print "{".join(",",(map {"$_ => ".$Everything::CONF->$item->{$_}} keys %{$Everything::CONF->$item}))."}\n";
  }else{
    print "$item: ".$Everything::CONF->$item."\n";
  }
}
