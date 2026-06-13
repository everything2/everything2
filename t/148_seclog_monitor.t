#!/usr/bin/perl -w
#
# Tests for the security-monitor read side (#4272 phase 4):
# Everything::Application->seclog_event_counts / seclog_entries. These key off
# seclog_event via the enum (no node lookups), which is what lets the monitor
# survive opcode-node deletion.
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

#############################################################################
# seclog_event_counts -- one row per registry event, counts from seclog_event
#############################################################################

subtest 'seclog_event_counts' => sub {
    my $counts = $APP->seclog_event_counts;
    is( ref $counts, 'ARRAY', 'returns an arrayref' );
    is( scalar(@$counts), scalar( Everything::SecurityLog->all ),
        'one entry per registry event' );

    for my $c (@$counts) {
        like( $c->{event_id}, qr/^\d+$/, "event_id is an int ($c->{key})" );
        ok( length( $c->{name}  // '' ), "name present ($c->{key})" );
        ok( length( $c->{group} // '' ), "group present ($c->{key})" );
        ok( $c->{count} >= 0,            "count >= 0 ($c->{key})" );
    }

    # MASSACRE is present and correctly keyed. (Count accuracy is exercised
    # race-free in the seclog_entries subtest below via a unique marker --
    # cross-checking against a separate COUNT query here would race other tests
    # writing seclog under -j4.)
    my ($massacre) = grep { $_->{key} eq 'MASSACRE' } @$counts;
    ok( $massacre, 'MASSACRE present in the registry counts' );
    is( $massacre->{event_id}, SECLOG_MASSACRE, 'MASSACRE event_id == 5' );
};

#############################################################################
# seclog_entries -- newest-first, subject resolved from seclog_subject
#############################################################################

subtest 'seclog_entries' => sub {
    my $marker = 't148-monitor-marker';
    $DB->sqlDelete( 'seclog', 'seclog_details = ' . $DB->{dbh}->quote($marker) );  # pre-clean

    # write via the real writer: event=MASSACRE, subject=root, actor=root
    my $id = $APP->securityLog( SECLOG_MASSACRE, $root, $marker, $root );
    ok( $id, 'inserted a test seclog row' );

    my $page = $APP->seclog_entries( SECLOG_MASSACRE, 0, 50 );
    is( ref $page->{entries}, 'ARRAY', 'entries is an arrayref' );
    ok( $page->{total} >= 1, 'total >= 1' );

    my ($row) = grep { ( $_->{details} // '' ) eq $marker } @{ $page->{entries} };
    ok( $row, 'the inserted row comes back' );
    is( $row->{subject_id},    $root->{node_id}, 'subject_id = the subject node id' );
    is( $row->{subject_title}, $root->{title},   'subject_title resolved from seclog_subject' );
    is( $row->{user_id},       $root->{node_id}, 'user_id = the actor' );
    is( $row->{user_title},    $root->{title},   'user_title resolved' );

    $DB->sqlDelete( 'seclog', "seclog_id = $id" ) if $id;
    $DB->sqlDelete( 'seclog', 'seclog_details = ' . $DB->{dbh}->quote($marker) );
};

done_testing();
