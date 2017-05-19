#!/usr/bin/perl -w

use strict;
use lib qw(/var/paws/lib /var/paws/auto-lib /var/MooseX-ClassAttribute/lib /var/Scalar-List-Utils/lib/ /var/Scalar-List-Utils/blib/arch/ /var/JSON-MaybeXS/lib /var/p5-url-encode/lib/ /var/Net-Amazon-Signature-S4/lib /var/everything/ecore);
use Paws;
use Everything;
use MIME::Base64;

$ENV{AWS_ACCESS_KEY} = $Everything::CONF->certificate_manager->{access_key_id};
$ENV{AWS_SECRET_KEY} = $Everything::CONF->certificate_manager->{secret_access_key};

my $acm = Paws->service('ACM', 'region' => 'us-west-2');

my $dir = "/etc/dehydrated/certs/everything2.com";
my $files = {"Certificate" => "cert.pem", "PrivateKey" => "privkey.pem", "CertificateChain" => "chain.pem"};

foreach my $file (keys %$files)
{
  local $/ = undef;
  my $fileh;
  print "Slurping: "."$dir/".$files->{$file}."\n";
  open $fileh, "$dir/".$files->{$file};
  my $filedata = <$fileh>;
  chomp $filedata;
  $files->{$file} = encode_base64($filedata);
  close $fileh;
}

my $response = $acm->ImportCertificate(Certificate => $files->{Certificate}, PrivateKey => $files->{PrivateKey}, CertificateChain => $files->{CertificateChain}, CertificateArn => $Everything::CONF->certificate_manager->{certificate_arn});

print "ARN: ".$response->CertificateArn."\n";

