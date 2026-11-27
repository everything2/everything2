#!/usr/bin/perl -w
#
# A page request for a node id that isn't a node gets the not-found page, whatever the id:
# -1 (which getNodeById hands back as the superuser placeholder, not a node), other negative
# numbers, and junk. Same answer as for an id that's simply unused, for guests and members (#4753).
#
use strict;
use warnings;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5);
use Test::More;
use URI::Escape qw(uri_escape_utf8);
use Everything;

initEverything 'everything';

my $app = eval { do '/var/everything/app.psgi' };
plan skip_all => "app.psgi unavailable: $@" unless ref $app eq 'CODE';
require Plack::Test;
require HTTP::Request::Common;
my $test = Plack::Test->create($app);

sub cookie_for {
    my ($name) = @_;
    return unless $name;
    my $user = $DB->getNode( $name, 'user' ) or return;
    return $Everything::CONF->cookiepass . '=' . uri_escape_utf8("$user->{title}|$user->{passwd}");
}

sub get {
    my ( $as, $path ) = @_;
    my $req = HTTP::Request::Common::GET($path);
    my $cookie = cookie_for($as);
    $req->header( Cookie => $cookie ) if $cookie;
    return $test->request($req);
}

# The answer for an id nothing has.
my $unused = 1 + ( $DB->sqlSelect( 'MAX(node_id)', 'node' ) || 0 ) + 1000000;
my %baseline = map { my $r = get( $_, "/?node_id=$unused" ); ( $_ // 'guest' ) => $r } ( undef, 'normaluser1' );
for my $who ( sort keys %baseline ) {
    isnt( $baseline{$who}->code, 500, "an unused node id: $who gets a page" );
}

for my $as ( undef, 'normaluser1' ) {
    my $who  = $as // 'guest';
    my $base = $baseline{$who};
    for my $path ( '/?node_id=-1', '/node/-1', '/?node_id=-2', '/?node_id=-1.5', '/?node_id=abc' ) {
        my $res = get( $as, $path );
        isnt( $res->code, 500, "$path: $who gets a page, not an error" );
        is( $res->code, $base->code, "$path: $who gets the same status as for an unused id" );
    }
}

my $guest = $DB->getNodeById( $Everything::CONF->guest_user );
is( $DB->canReadNode( $guest, -1 ), 0, 'canReadNode: the -1 placeholder is not a node anyone can read' );
ok( $DB->canReadNode( $guest, $DB->getNode( 'root', 'user' ) ), 'canReadNode: a real node still reads as before' );

done_testing();
