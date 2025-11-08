#!/usr/bin/perl -w

use strict;

use LWP::UserAgent;
use HTTP::Request;
use Test::More;
use JSON;

use HTTP::Cookies;

my $json = JSON->new;
my $endpoint = "http://localhost/api/tests";
ok(my $ua = LWP::UserAgent->new, "Make a new LWP::UserAgent object");
ok(my $request = HTTP::Request->new("GET","$endpoint"), "Construct HTTP::Request object");

my $api_versions = {0 => 400, 1 => 410, 2 => 200, 3 => 200};

foreach my $api_version(keys %$api_versions)
{ 
  $request->header('Accept' => 'application/vnd.e2.v'.$api_version);
  ok(my $response = $ua->request($request), "Make the version $api_version request");
  ok($response->code == $api_versions->{$api_version}, "Version $api_version should return ".$api_versions->{$api_version});

  my $testdata;
  if($response->code == 200)
  {
    $testdata = $json->decode($response->content); 
  }

  if($api_version == 2)
  {
    ok($testdata->{v} == 2, "Version 2 testdata is ok");
  }elsif($api_version == 3)
  {
    ok($testdata->{version} == 3, "Version 3 testdata is ok");
  }
}


done_testing();
