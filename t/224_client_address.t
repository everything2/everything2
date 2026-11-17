#!/usr/bin/perl -w
#
# Application::getIp resolves the single client address from X-Forwarded-For + REMOTE_ADDR:
# the rightmost address that isn't one of our own hops (load balancer, Docker, localhost).
# Addresses below are from the documentation ranges (192.0.2.0/24, 198.51.100.0/24,
# 203.0.113.0/24, 2001:db8::/32).
#
use strict;
use warnings;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5);
use Test::More;
use Everything;

initEverything 'everything';

sub client {
  my ($forwarded, $remote) = @_;
  local $ENV{HTTP_X_FORWARDED_FOR} = $forwarded;
  local $ENV{REMOTE_ADDR} = $remote;
  my $scalar = $APP->getIp;
  my @list = $APP->getIp;
  return ($scalar, \@list);
}

subtest 'behind the load balancer and Apache' => sub {
  my ($ip, $list) = client('203.0.113.7', '127.0.0.1');
  is($ip, '203.0.113.7', 'client is the address the load balancer saw');
  is_deeply($list, ['203.0.113.7'], 'list context returns just that address');

  ($ip) = client('198.51.100.1, 192.0.2.44, 203.0.113.7', '127.0.0.1');
  is($ip, '203.0.113.7', 'earlier entries in the header are not the client');

  ($ip) = client('203.0.113.7, 10.0.4.12', '127.0.0.1');
  is($ip, '203.0.113.7', 'private hops to the right are skipped');

  ($ip) = client('203.0.113.7,172.17.0.1', '172.17.0.1');
  is($ip, '203.0.113.7', 'docker hops are skipped, no spaces needed');

  ($ip) = client('  203.0.113.7  ,  10.0.0.9 ', '127.0.0.1');
  is($ip, '203.0.113.7', 'whitespace around entries is ignored');
};

subtest 'IPv6' => sub {
  my ($ip) = client('2001:db8::1', '127.0.0.1');
  is($ip, '2001:db8::1', 'IPv6 client address');

  ($ip) = client('198.51.100.1, 2001:db8::1', '::1');
  is($ip, '2001:db8::1', 'IPv6 loopback is a hop');

  ($ip) = client('2001:db8::1, fd12:3456::1, fe80::1', '127.0.0.1');
  is($ip, '2001:db8::1', 'unique-local and link-local addresses are hops');

  ($ip) = client('203.0.113.7, ::ffff:10.0.0.5', '127.0.0.1');
  is($ip, '203.0.113.7', 'IPv4-mapped private address is a hop');
};

subtest 'direct connections and local development' => sub {
  my ($ip) = client(undef, '203.0.113.9');
  is($ip, '203.0.113.9', 'no header: the connecting address');

  ($ip) = client('', '198.51.100.20');
  is($ip, '198.51.100.20', 'empty header: the connecting address');

  ($ip) = client('192.168.65.1, 172.17.0.1', '127.0.0.1');
  is($ip, '192.168.65.1', 'all addresses are local: the leftmost');

  ($ip) = client(undef, '127.0.0.1');
  is($ip, '127.0.0.1', 'only localhost: localhost');

  my ($none, $list) = client(undef, undef);
  is($none, '', 'no addresses: empty string');
  is_deeply($list, [], 'no addresses: empty list');
};

subtest 'is_proxy_hop' => sub {
  ok($APP->is_proxy_hop($_), "$_ is a hop") for qw(10.1.2.3 172.16.0.1 172.31.255.255 192.168.1.1 127.0.0.1 169.254.169.254 ::1 fd00::1 fe80::1 ::ffff:192.168.0.1);
  ok(!$APP->is_proxy_hop($_), "$_ is not a hop") for qw(203.0.113.7 172.32.0.1 8.8.8.8 2001:db8::1 ::ffff:203.0.113.7);
  ok(!$APP->is_proxy_hop(''), 'empty is not a hop');
  ok(!$APP->is_proxy_hop(undef), 'undef is not a hop');
};

done_testing();
