#!/usr/bin/perl -w
#
# Regression net for Everything::Application->securityLog (#4272).
# Pins the writer behavior after the caller conversion: securityLog takes a SECLOG_*
# event id (0..65535) and writes seclog_event + seclog_subject. An undef event logs
# nothing. (The legacy node-arg path -- map-by-title / bare-node-id -- was removed once
# every caller passed a SECLOG_* constant directly.)
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
ok( $root, 'got root user' );

my $marker = 't147-seclog-writer';
my @cleanup;

sub fetch_last {
    my ($details) = @_;
    return $DB->sqlSelectHashref( '*', 'seclog',
        "seclog_details = " . $DB->{dbh}->quote($details),
        'ORDER BY seclog_id DESC LIMIT 1' );
}

subtest 'writes a row from a SECLOG_* event id' => sub {
    my $d  = "$marker basic";
    my $id = $APP->securityLog( SECLOG_MASSACRE, $root, $d );
    ok( $id, 'returns an inserted seclog_id' );
    push @cleanup, $id if $id;
    my $row = fetch_last($d);
    ok( $row, 'row exists' );
    is( $row->{seclog_user},    $root->{node_id}, 'seclog_user = actor id' );
    is( $row->{seclog_details}, $d,               'details stored verbatim' );
    is( $row->{seclog_event},   SECLOG_MASSACRE,  'seclog_event = the SECLOG_* id' );
};

subtest 'subject node is stored' => sub {
    my $d  = "$marker subject";
    my $id = $APP->securityLog( SECLOG_WRITEUP_REPARENT, $root, $d, $root );
    ok( $id, 'inserted' );
    push @cleanup, $id if $id;
    my $row = fetch_last($d);
    is( $row->{seclog_event},   SECLOG_WRITEUP_REPARENT, 'event from the SECLOG_* id' );
    is( $row->{seclog_subject}, $root->{node_id},        'seclog_subject = the affected node id' );
};

subtest 'user -1 resolves to root' => sub {
    my $d  = "$marker rootuser";
    my $id = $APP->securityLog( SECLOG_MASSACRE, -1, $d );
    ok( $id, 'inserted' );
    push @cleanup, $id if $id;
    my $row = fetch_last($d);
    is( $row->{seclog_user}, $root->{node_id}, 'actor defaulted to root' );
};

subtest 'undef event logs nothing' => sub {
    my $before = $DB->sqlSelect( 'COUNT(*)', 'seclog' );
    $APP->securityLog( undef, $root, "$marker shouldnotappear" );
    my $after = $DB->sqlSelect( 'COUNT(*)', 'seclog' );
    is( $after, $before, 'no row inserted for undef event' );
    ok( !fetch_last("$marker shouldnotappear"), 'no row with that marker' );
};

# cleanup -- remove anything this test inserted
$DB->sqlDelete( 'seclog', "seclog_id = $_" ) for grep { $_ } @cleanup;
$DB->sqlDelete( 'seclog', "seclog_details LIKE " . $DB->{dbh}->quote("$marker%") );

done_testing();
