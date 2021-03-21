#!/usr/bin/perl -w

use strict;
use lib qw(/var/libraries/lib/perl5);
use lib qw(/home/ubuntu/everything2/ecore);
use Paws;
use Data::Dumper;
use JSON;

my $service = Paws->service('SecretsManager', region => 'us-west-2');
foreach my $secret(@{$service->ListSecrets->SecretList})
{
  if($secret->Name eq "E2DBMasterPassword")
  {
    my $secret = from_json($service->GetSecretValue(SecretId => $secret->ARN)->SecretString);
    #print Data::Dumper->Dump([$secret]);
    exec("mysql --user=\"$secret->{username}\" --password=\"$secret->{password}\" --host=\"$secret->{host}\" everything");
  }
}

