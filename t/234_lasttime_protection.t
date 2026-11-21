#!/usr/bin/perl -w
#
# user.lasttime ("last seen") has one writer: Everything::Request, when a signed-in user makes a
# request. Old accounts keep it as a memorial, so no ordinary save may change it: a profile save,
# a GP change, an admin edit, a save from a copy of the user loaded earlier in the request (#4709).
#
# Part 1 drives NodeBase directly; part 2 sends real requests through app.psgi.
# Every account here is a TestSeed throwaway, except Guest User, which is only read.
#
use strict;
use warnings;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5 /var/everything/t/lib);
use Test::More;
use JSON;
use URI::Escape qw(uri_escape_utf8);
use Everything;
use TestSeed;

initEverything 'everything';

my @inserted;    # nodes made with insertNode directly (TestSeed cleans up its own)
END {
    for my $id (@inserted) {
        my $n = $DB->getNodeById( $id, 'force' );
        $DB->nukeNode( $n, -1, 0, 1 ) if $n;
        $DB->sqlDelete( 'user', "user_id=$id" );
    }
    TestSeed::cleanup($DB);
}

# The column as stored, straight from the database ('' never comes back: NULL stays undef).
sub db_lasttime {
    my ($id) = @_;
    return scalar $DB->{dbh}->selectrow_array( 'SELECT CAST(lasttime AS CHAR) FROM user WHERE user_id = ?', undef, $id );
}
sub db_col {
    my ( $col, $table, $id ) = @_;
    return scalar $DB->{dbh}->selectrow_array( "SELECT $col FROM $table WHERE ${table}_id = ?", undef, $id );
}
sub set_lasttime {
    my ( $id, $value ) = @_;
    $DB->{dbh}->do( 'UPDATE user SET lasttime = ? WHERE user_id = ?', undef, $value, $id );
}
# The database clock, and whether a user's stored lasttime falls between two readings of it.
sub db_now { return scalar $DB->{dbh}->selectrow_array('SELECT CAST(NOW() AS CHAR)'); }
sub seen_between {
    my ( $id, $from, $to, $name ) = @_;
    my $in = $DB->{dbh}->selectrow_array( 'SELECT lasttime BETWEEN ? AND ? FROM user WHERE user_id = ?', undef, $from, $to, $id );
    ok( $in, $name ) or diag 'lasttime ' . ( db_lasttime($id) // 'NULL' ) . ", request ran $from .. $to";
}

my $MEMORIAL = '2004-02-29 08:00:00';

###########################################################################
# Part 1: NodeBase
###########################################################################

subtest 'a save from a copy holding an older lasttime leaves the stored one alone' => sub {
    my $u  = TestSeed::make_user( $DB, $APP, label => 'lt-stale', lasttime => $MEMORIAL, GP => 5 );
    my $id = $u->{node_id};

    my $copy = $DB->getNodeById( $id, 'force' );
    $copy->{lasttime} = '2001-01-01 00:00:00';    # what a copy loaded long ago might hold
    $copy->{GP}       = 6;
    $copy->{realname} = 'Stale Copy';
    ok( $DB->updateNode( $copy, -1 ), 'updateNode succeeds' );

    is( db_lasttime($id),                $MEMORIAL,    'lasttime unchanged in the database' );
    is( db_col( 'GP', 'user', $id ),     6,            'the other changes are saved (GP)' );
    is( db_col( 'realname', 'user', $id ), 'Stale Copy', 'the other changes are saved (realname)' );
    is( $copy->{lasttime},               $MEMORIAL,    'the copy now holds the stored lasttime' );
};

subtest 'a newer lasttime written meanwhile survives a save from the earlier copy' => sub {
    my $u  = TestSeed::make_user( $DB, $APP, label => 'lt-race', lasttime => $MEMORIAL );
    my $id = $u->{node_id};

    my $copy = $DB->getNodeById( $id, 'force' );     # loaded before the sign-in below
    set_lasttime( $id, '2026-02-02 02:02:02' );      # the sign-in, written by Request's own UPDATE
    $copy->{realname} = 'Later Save';
    ok( $DB->updateNode( $copy, -1 ), 'updateNode succeeds' );

    is( db_lasttime($id), '2026-02-02 02:02:02', 'the newer lasttime is kept, not rolled back' );
    is( $copy->{lasttime}, '2026-02-02 02:02:02', 'the copy is brought up to date' );
};

subtest 'a never-signed-in user can be saved, and stays never-signed-in' => sub {
    my $u  = TestSeed::make_user( $DB, $APP, label => 'lt-never' );
    my $id = $u->{node_id};
    ok( !defined db_lasttime($id), 'starts NULL' );

    my $copy = $DB->getNodeById( $id, 'force' );
    is( $copy->{lasttime} // '', '', 'loads as empty' );
    $copy->{realname} = 'Never Signed In';
    my $ok = eval { $DB->updateNode( $copy, -1 ) };
    ok( $ok, 'updateNode succeeds (no "Incorrect datetime value")' ) or diag $@;
    is( db_col( 'realname', 'user', $id ), 'Never Signed In', 'the change is saved' );
    ok( !defined db_lasttime($id), 'lasttime is still NULL (not a zero date)' );
};

subtest 'setting lasttime on a copy and saving it does not change the stored value' => sub {
    my $u  = TestSeed::make_user( $DB, $APP, label => 'lt-direct', lasttime => $MEMORIAL );
    my $id = $u->{node_id};

    for my $attempt ( '2030-01-01 00:00:00', '', '0000-00-00 00:00:00' ) {
        my $copy = $DB->getNodeById( $id, 'force' );
        $copy->{lasttime} = $attempt;
        eval { $DB->updateNode( $copy, -1 ) };
        is( db_lasttime($id), $MEMORIAL, "lasttime unchanged after saving '$attempt'" );
    }

    # The same through the user object (what APIs and the admin edit form hold).
    my $obj = $APP->node_by_id($id);
    $obj->NODEDATA->{lasttime} = '2031-01-01 00:00:00';
    $obj->NODEDATA->{realname} = 'object save';
    $DB->updateNode( $obj->NODEDATA, -1 );
    is( db_lasttime($id),               $MEMORIAL,     'lasttime unchanged after a save through the user object' );
    is( db_col( 'realname', 'user', $id ), 'object save', 'and that save went through' );
};

subtest 'GP changes leave lasttime alone' => sub {
    my $u  = TestSeed::make_user( $DB, $APP, label => 'lt-gp', lasttime => $MEMORIAL, GP => 10 );
    my $id = $u->{node_id};

    my $copy = $DB->getNodeById( $id, 'force' );
    $copy->{lasttime} = '';    # as a never-refreshed copy might hold
    my $ok = eval { $APP->adjustGP( $copy, 3 ); 1 };
    ok( $ok, 'adjustGP succeeds (no "Incorrect datetime value")' ) or diag $@;
    is( db_col( 'GP', 'user', $id ), 13,        'GP adjusted' );
    is( db_lasttime($id),            $MEMORIAL, 'lasttime unchanged' );
};

subtest 'insertNode still sets lasttime on a brand-new user' => sub {
    my $with = "e2eseed-lt-ins-$$-a";
    my $id   = $DB->insertNode( $with, 'user', -1, { lasttime => $MEMORIAL, realname => 'Inserted' } );
    ok( $id, 'inserted with a lasttime' );
    push @inserted, $id if $id;
    is( db_lasttime($id),                  $MEMORIAL,  'lasttime set' );
    is( db_col( 'realname', 'user', $id ), 'Inserted', 'other fields set' );

    my $without = "e2eseed-lt-ins-$$-b";
    my $id2     = $DB->insertNode( $without, 'user', -1, { realname => 'No lasttime' } );
    ok( $id2, 'inserted without a lasttime' );
    push @inserted, $id2 if $id2;
    ok( !defined db_lasttime($id2), 'lasttime NULL (never signed in)' );
};

subtest 'only user.lasttime is guarded' => sub {
    no warnings 'once';
    is_deeply( \%Everything::NodeBase::UPDATE_NEVER_WRITES, { user => { lasttime => 1 } }, 'the guarded list is exactly user.lasttime' );
};

###########################################################################
# Part 2: real requests
###########################################################################

my $app = eval { do '/var/everything/app.psgi' };
SKIP: {
    skip "app.psgi unavailable: $@", 1 unless ref $app eq 'CODE';
    require Plack::Test;
    require HTTP::Request::Common;
    my $test        = Plack::Test->create($app);
    my $cookie_name = $Everything::CONF->cookiepass;
    my $cookie_for  = sub { my ($u) = @_; return "$cookie_name=" . uri_escape_utf8("$u->{title}|$u->{passwd}"); };
    my $edit        = sub {
        my ( $u, $fields ) = @_;
        my $res = $test->request( HTTP::Request::Common::POST(
            '/api/user/edit',
            Cookie         => $cookie_for->($u),
            'User-Agent'   => 't/234',
            'Content-Type' => 'application/json',
            Content        => encode_json( { node_id => $u->{node_id}, %$fields } ),
        ) );
        return eval { decode_json( $res->content ) } || {};
    };

    subtest 'a request from a signed-in user records the time' => sub {
        my $u  = TestSeed::make_user( $DB, $APP, label => 'lt-req', password => 'blah', lasttime => $MEMORIAL );
        my $id = $u->{node_id};
        my $from = db_now();
        my $res  = $test->request( HTTP::Request::Common::GET( '/api/sessions', Cookie => $cookie_for->($u), 'User-Agent' => 't/234' ) );
        my $to   = db_now();
        my $s    = eval { decode_json( $res->content ) } || {};
        is( $s->{user} && $s->{user}{title}, $u->{title}, 'signed in' );
        seen_between( $id, $from, $to, 'lasttime is the time of the request' );
    };

    subtest 'other workers learn their cached copy of the user is out of date' => sub {
        my $u  = TestSeed::make_user( $DB, $APP, label => 'lt-ver', password => 'blah', lasttime => $MEMORIAL );
        my $id = $u->{node_id};
        $DB->getNodeById( $id, 'force' );    # cached, as every worker that served this user holds it
        my $before = db_col( 'version', 'version', $id ) // 0;
        $test->request( HTTP::Request::Common::GET( '/api/sessions', Cookie => $cookie_for->($u), 'User-Agent' => 't/234' ) );
        my $after = db_col( 'version', 'version', $id ) // 0;
        cmp_ok( $after, '>', $before, 'the node version moved, so a copy cached before the request reloads' )
            or diag "version $before -> $after";
        my $mine = $DB->getNodeById($id);
        is( $mine->{lasttime}, db_lasttime($id), 'and the copy this worker cached holds the stored time' );
    };

    subtest 'a profile save keeps the time the request recorded' => sub {
        my $u  = TestSeed::make_user( $DB, $APP, label => 'lt-save', password => 'blah', lasttime => $MEMORIAL );
        my $id = $u->{node_id};
        $DB->getNodeById( $id, 'force' );    # this process's cached copy now holds the old time

        my $from = db_now();
        my $json = $edit->( $u, { realname => 'Saved Name', motto => 'still here' } );
        my $to   = db_now();
        is( $json->{success}, 1, 'profile save accepted' ) or diag explain $json;
        is( db_col( 'realname', 'user', $id ), 'Saved Name', 'realname saved' );
        seen_between( $id, $from, $to, 'lasttime is the time of this request, not rolled back' );
        isnt( db_lasttime($id), $MEMORIAL, 'and not the old value from the cached copy' );
    };

    subtest 'a first-ever request that saves the profile works and records the time' => sub {
        my $u  = TestSeed::make_user( $DB, $APP, label => 'lt-first', password => 'blah' );    # lasttime NULL
        my $id = $u->{node_id};
        my $from = db_now();
        my $json = $edit->( $u, { realname => 'First Visit' } );
        my $to   = db_now();
        is( $json->{success}, 1, 'profile save accepted' ) or diag explain $json;
        is( db_col( 'realname', 'user', $id ), 'First Visit', 'realname saved' );
        seen_between( $id, $from, $to, 'lasttime is the time of this request (not NULL, empty or a zero date)' );
    };

    subtest 'idle background requests do not count as being seen' => sub {
        my $u  = TestSeed::make_user( $DB, $APP, label => 'lt-idle', password => 'blah', lasttime => $MEMORIAL );
        my $id = $u->{node_id};
        my $ver = db_col( 'version', 'version', $id ) // 0;
        $test->request( HTTP::Request::Common::GET( '/api/sessions', Cookie => $cookie_for->($u), 'X-Ajax-Idle' => 1 ) );
        $test->request( HTTP::Request::Common::GET( '/api/sessions?ajaxIdle=1', Cookie => $cookie_for->($u) ) );
        is( db_lasttime($id), $MEMORIAL, 'lasttime unchanged' );
        is( db_col( 'version', 'version', $id ) // 0, $ver, 'and nothing was invalidated' );
    };

    subtest 'a wrong password does not count as being seen' => sub {
        my $u  = TestSeed::make_user( $DB, $APP, label => 'lt-badpw', password => 'blah', lasttime => $MEMORIAL );
        my $id = $u->{node_id};
        $test->request( HTTP::Request::Common::GET( '/api/sessions',
            Cookie => "$cookie_name=" . uri_escape_utf8("$u->{title}|not-the-password") ) );
        is( db_lasttime($id), $MEMORIAL, 'lasttime unchanged' );
    };

    subtest 'guest requests leave Guest User alone' => sub {
        my $guest_id = $Everything::CONF->guest_user;
        my $before   = db_lasttime($guest_id);
        $test->request( HTTP::Request::Common::GET( '/api/sessions', 'User-Agent' => 't/234' ) );
        $test->request( HTTP::Request::Common::GET( '/title/Everything2' ) );
        is( db_lasttime($guest_id), $before, 'Guest User lasttime unchanged' );
    };
}

done_testing();
