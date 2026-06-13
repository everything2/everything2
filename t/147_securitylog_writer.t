#!/usr/bin/perl -w
#
# Regression net for Everything::Application->securityLog (#4272).
# Pins the writer behavior after phase 5 (#4280): securityLog writes seclog_event +
# seclog_subject only -- the seclog_node dual-write (and the column) are gone. The
# legacy category-node arg is still accepted and mapped to an event by its title.
#
use strict;
use warnings;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5);
use Test::More;
use Everything;
use Everything::Application;
use Everything::SecurityLog qw(:events);

initEverything 'everything';

ok( $DB,  'DB connected' );
ok( $APP, 'Application object' );

my $root = $DB->getNode( 'root', 'user' );
my $cat  = $DB->getNode( 'massacre', 'opcode' );    # an existing seclog category node
ok( $root, 'got root user' );
ok( $cat,  'got a category node (massacre opcode)' );

my $marker = 't147-seclog-writer';
my @cleanup;

sub fetch_last {
    my ($details) = @_;
    return $DB->sqlSelectHashref( '*', 'seclog',
        "seclog_details = " . $DB->{dbh}->quote($details),
        'ORDER BY seclog_id DESC LIMIT 1' );
}

subtest 'writes a row (hashref args)' => sub {
    my $d  = "$marker basic";
    my $id = $APP->securityLog( $cat, $root, $d );
    ok( $id, 'returns an inserted seclog_id' );
    push @cleanup, $id if $id;
    my $row = fetch_last($d);
    ok( $row, 'row exists' );
    is( $row->{seclog_user},    $root->{node_id}, 'seclog_user = actor id' );
    is( $row->{seclog_details}, $d,               'details stored verbatim' );
    is( $row->{seclog_event},   SECLOG_MASSACRE,  'seclog_event mapped from node title (massacre -> 5)' );
};

subtest 'event-key arg writes seclog_event directly' => sub {
    my $d  = "$marker eventkey";
    my $id = $APP->securityLog( SECLOG_MASSACRE, $root, $d );
    ok( $id, 'inserted' );
    push @cleanup, $id if $id;
    my $row = fetch_last($d);
    is( $row->{seclog_event}, SECLOG_MASSACRE, 'seclog_event set from the SECLOG_* key' );
};

subtest 'subject node is stored' => sub {
    my $d  = "$marker subject";
    my $id = $APP->securityLog( SECLOG_WRITEUP_REPARENT, $root, $d, $cat );
    ok( $id, 'inserted' );
    push @cleanup, $id if $id;
    my $row = fetch_last($d);
    is( $row->{seclog_event},   SECLOG_WRITEUP_REPARENT, 'event from key' );
    is( $row->{seclog_subject}, $cat->{node_id},         'seclog_subject = the affected node id' );
};

subtest 'accepts a node id (getRef resolves it, maps to event)' => sub {
    my $d   = "$marker byid";
    my $nid = $cat->{node_id};               # copy: getRef mutates its arg in place
    my $id  = $APP->securityLog( $nid, $root, $d );
    ok( $id, 'inserted' );
    push @cleanup, $id if $id;
    my $row = fetch_last($d);
    is( $row->{seclog_event}, SECLOG_MASSACRE, 'bare node id resolved -> massacre event' );
};

subtest 'user -1 resolves to root' => sub {
    my $d  = "$marker rootuser";
    my $id = $APP->securityLog( $cat, -1, $d );
    ok( $id, 'inserted' );
    push @cleanup, $id if $id;
    my $row = fetch_last($d);
    is( $row->{seclog_user}, $root->{node_id}, 'actor defaulted to root' );
};

subtest 'undef node logs nothing' => sub {
    my $before = $DB->sqlSelect( 'COUNT(*)', 'seclog' );
    $APP->securityLog( undef, $root, "$marker shouldnotappear" );
    my $after = $DB->sqlSelect( 'COUNT(*)', 'seclog' );
    is( $after, $before, 'no row inserted for undef node' );
    ok( !fetch_last("$marker shouldnotappear"), 'no row with that marker' );
};

# cleanup -- remove anything this test inserted
$DB->sqlDelete( 'seclog', "seclog_id = $_" ) for grep { $_ } @cleanup;
$DB->sqlDelete( 'seclog', "seclog_details LIKE " . $DB->{dbh}->quote("$marker%") );

done_testing();
