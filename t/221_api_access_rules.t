#!/usr/bin/perl -w
#
# Access rules for drafts, autosave, room chatter and writeup edits, through the app.
#
use strict;
use warnings;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5);
use Test::More;
use JSON;
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
    my $user = $DB->getNode( $name, 'user' ) or return;
    return $Everything::CONF->cookiepass . '=' . uri_escape_utf8("$user->{title}|$user->{passwd}");
}

sub call {
    my ( $as, $method, $path, $body ) = @_;
    my @args = ( $path, Cookie => cookie_for($as) );
    my $req = $method eq 'GET'
        ? HTTP::Request::Common::GET(@args)
        : HTTP::Request::Common::POST( @args, 'Content-Type' => 'application/json', Content => encode_json( $body || {} ) );
    my $res = $test->request($req);
    return ( $res->code, ( eval { JSON->new->decode( $res->content ) } // {} ), $res->content );
}

my $root   = $DB->getNode( 'root', 'user' );
my $author = $DB->getNode( 'normaluser1', 'user' );
my $stamp  = time();
my @created;

sub make_draft {
    my ( $status, $text ) = @_;
    my $status_node = $DB->getNode( $status, 'publication_status' ) or return;
    my $id = $DB->insertNode( "access rules draft $status $stamp", 'draft', $author,
        { doctext => $text, publication_status => $status_node->{node_id} } );
    push @created, $id if $id;
    return $id;
}

sub doctext_of { return scalar $DB->{dbh}->selectrow_array( 'SELECT doctext FROM document WHERE document_id = ?', {}, $_[0] ) }

# --- reading drafts: /api/drafts/:id ---------------------------------------------------------
my $private_text = "private draft text $stamp";
my $review_text  = "review draft text $stamp";
my $private = make_draft( 'private', $private_text );
my $review  = make_draft( 'review',  $review_text );

SKIP: {
    skip 'could not create drafts', 1 unless $private && $review;

    my ( undef, $json ) = call( 'normaluser1', 'GET', "/api/drafts/$private" );
    is( $json->{draft} && $json->{draft}{doctext}, $private_text, 'author reads their private draft' );

    for my $as ( 'genericeditor', 'normaluser2' ) {
        my ( undef, $json, $raw ) = call( $as, 'GET', "/api/drafts/$private" );
        ok( !$json->{success}, "$as cannot read someone else's private draft" );
        unlike( $raw, qr/\Q$private_text\E/, "$as gets none of its text" );
    }

    ( undef, $json ) = call( 'genericeditor', 'GET', "/api/drafts/$review" );
    is( $json->{draft} && $json->{draft}{doctext}, $review_text, 'an editor reads a draft in review' );
    my ( undef, $json2, $raw2 ) = call( 'normaluser2', 'GET', "/api/drafts/$review" );
    unlike( $raw2, qr/\Q$review_text\E/, 'a non-editor does not read a draft in review' );
}

# Only drafts come out of the drafts endpoint.
my $gods_doc = $DB->getNode( 'Server Telemetry', 'oppressor_superdoc' ) || $DB->getNode( 'Edit These E2 Titles', 'oppressor_superdoc' );
SKIP: {
    skip 'no oppressor_superdoc seeded', 1 unless $gods_doc;
    my ( undef, $json ) = call( 'genericeditor', 'GET', "/api/drafts/$gods_doc->{node_id}" );
    ok( !$json->{success} && !exists $json->{draft}, 'a non-draft node is not served as a draft' );
}

# --- autosave: /api/autosave ------------------------------------------------------------------
SKIP: {
    skip 'could not create drafts', 1 unless $private;

    my ( undef, $json ) = call( 'genericeditor', 'POST', '/api/autosave', { node_id => $private, doctext => "editor text $stamp" } );
    ok( !$json->{success}, "an editor cannot autosave someone else's draft" );
    is( doctext_of($private), $private_text, 'the draft is unchanged' );

    ( undef, $json ) = call( 'root', 'POST', '/api/autosave', { node_id => $private, doctext => "admin text $stamp" } );
    ok( !$json->{success}, "an admin cannot autosave someone else's draft either" );
    is( doctext_of($private), $private_text, 'still unchanged' );

    ( undef, $json ) = call( 'normaluser1', 'POST', '/api/autosave', { node_id => $private, doctext => "author text $stamp" } );
    ok( $json->{success} && $json->{saved}, 'the author autosaves their draft' );
    is( doctext_of($private), "author text $stamp", 'and it is saved' );
}

# Autosave only writes drafts, even ones you author.
my $own_doc = $DB->insertNode( "access rules document $stamp", 'document', $root, { doctext => "document text $stamp" } );
if ($own_doc) {
    push @created, $own_doc;
    $DB->sqlUpdate( 'node', { author_user => $author->{node_id} }, "node_id = $own_doc" );
}
SKIP: {
    skip 'could not create a document', 1 unless $own_doc;
    my ( undef, $json ) = call( 'normaluser1', 'POST', '/api/autosave', { node_id => $own_doc, doctext => "changed $stamp" } );
    ok( !$json->{success}, 'autosave refuses a node that is not a draft' );
    is( doctext_of($own_doc), "document text $stamp", 'the document is unchanged' );
}

# Restoring a saved version only goes back into a draft you still own.
SKIP: {
    skip 'could not create a document', 1 unless $own_doc;
    $DB->{dbh}->do( "INSERT INTO autosave (author_user, node_id, doctext, createtime, save_type) VALUES (?, ?, ?, NOW(), 'auto')",
        {}, $author->{node_id}, $own_doc, "old version $stamp" );
    my $version = $DB->{dbh}->last_insert_id( undef, undef, 'autosave', 'autosave_id' );
    my ( undef, $json ) = call( 'normaluser1', 'POST', "/api/autosave/$version/restore" );
    ok( !$json->{success}, 'restore refuses a node that is not a draft' );
    is( doctext_of($own_doc), "document text $stamp", 'the document is unchanged' );
    $DB->{dbh}->do( 'DELETE FROM autosave WHERE autosave_id = ?', {}, $version );
}

# --- room chatter: /api/chatter?room= ---------------------------------------------------------
my $valhalla = $DB->getNode( 'Valhalla', 'room' );
my $asylum   = $DB->getNode( 'Political Asylum', 'room' );
SKIP: {
    skip 'rooms not seeded', 1 unless $valhalla && $asylum;
    my $line = "valhalla chatter $stamp";
    $DB->sqlInsert( 'message', { msgtext => $line, author_user => $root->{node_id}, for_user => 0, room => $valhalla->{node_id} } );
    my $message_id = $DB->{dbh}->last_insert_id( undef, undef, 'message', 'message_id' );

    my ( undef, $json, $raw ) = call( 'normaluser2', 'GET', "/api/chatter?room=$valhalla->{node_id}" );
    unlike( $raw, qr/\Q$line\E/, "a user who can't enter a room doesn't get its chatter" );
    ( undef, undef, $raw ) = call( 'root', 'GET', "/api/chatter?room=$valhalla->{node_id}" );
    like( $raw, qr/\Q$line\E/, 'someone who can enter it does' );

    my ($code, $open) = call( 'normaluser2', 'GET', "/api/chatter?room=$asylum->{node_id}" );
    is( ref $open, 'ARRAY', 'an open room is readable' );

    ( undef, $json ) = call( 'normaluser2', 'GET', "/api/chatter?room=$author->{node_id}" );
    is_deeply( $json, [], 'a node that is not a room has no chatter' );

    # The room you're in stays readable even after it's deleted (old-room cleanup does this).
    my $user2 = $DB->getNode( 'normaluser2', 'user' );
    my $gone_room = 990000000 + ( $$ % 1000000 );
    my $gone_line = "deleted room chatter $stamp";
    $DB->sqlInsert( 'message', { msgtext => $gone_line, author_user => $root->{node_id}, for_user => 0, room => $gone_room } );
    my $gone_id = $DB->{dbh}->last_insert_id( undef, undef, 'message', 'message_id' );
    my $was_in = $user2->{in_room};
    $DB->sqlUpdate( 'user', { in_room => $gone_room }, "user_id = $user2->{node_id}" );
    $APP->node_by_id( $user2->{node_id} )->cache_refresh;
    ( undef, undef, $raw ) = call( 'normaluser2', 'GET', "/api/chatter?room=$gone_room" );
    like( $raw, qr/\Q$gone_line\E/, "the room you're in is readable even if it no longer exists" );

    # Loading a page moves them out of the room that no longer exists.
    call( 'normaluser2', 'GET', '/' );
    is( $DB->sqlSelect( 'in_room', 'user', "user_id = $user2->{node_id}" ), 0, 'loading a page moves them outside' );
    $DB->sqlUpdate( 'user', { in_room => int( $was_in // 0 ) }, "user_id = $user2->{node_id}" );
    $APP->node_by_id( $user2->{node_id} )->cache_refresh;
    $DB->sqlDelete( 'message', 'message_id = ' . int($gone_id) );

    $DB->sqlDelete( 'message', 'message_id = ' . int($message_id) );
}

# Only a timestamp is accepted for `since`.
{
    my $line = "outside chatter $stamp";
    $DB->sqlInsert( 'message', { msgtext => $line, author_user => $root->{node_id}, for_user => 0, room => 0 } );
    my $message_id = $DB->{dbh}->last_insert_id( undef, undef, 'message', 'message_id' );

    my ( $code, $json, $raw ) = call( 'normaluser2', 'GET', '/api/chatter?since=2000-01-01T00:00:00Z' );
    like( $raw, qr/\Q$line\E/, 'a timestamp works' );

    my $n = 0;
    for my $since ( 'yesterday', '2000-01-01 00:00:00 extra', '2000-01-01T00:00:00Zx' ) {
        $n++;
        ( $code, $json ) = call( 'normaluser2', 'GET', '/api/chatter?since=' . uri_escape_utf8($since) );
        is( $code, 200, "non-timestamp since #$n is handled" );
        is( ref $json, 'ARRAY', "non-timestamp since #$n falls back to the default window" );
    }
    $DB->sqlDelete( 'message', 'message_id = ' . int($message_id) );
}

# --- writeup edits: /api/writeups/:id/action/update -------------------------------------------
my ($writeup) = $DB->{dbh}->selectrow_array(
    q{SELECT w.writeup_id FROM writeup w JOIN node n ON n.node_id = w.writeup_id
      JOIN node p ON p.node_id = w.parent_e2node WHERE n.author_user = ? LIMIT 1},
    {}, $DB->getNode( 'normaluser26', 'user' )->{node_id} );
SKIP: {
    skip 'no seeded writeup for normaluser26', 1 unless $writeup;
    my $before = $DB->{dbh}->selectrow_hashref( 'SELECT parent_e2node FROM writeup WHERE writeup_id = ?', {}, $writeup );
    my $elsewhere = $DB->getNode( 'Quick brown fox', 'e2node' ) || $DB->getNode( 'Political Asylum', 'room' );

    my ( undef, $json ) = call( 'normaluser26', 'POST', "/api/writeups/$writeup/action/update", { parent_e2node => $elsewhere->{node_id} } );
    is( $json->{error}, 'parent_change_not_allowed', "the author can't move their writeup by editing it" );
    my $after = $DB->{dbh}->selectrow_hashref( 'SELECT parent_e2node FROM writeup WHERE writeup_id = ?', {}, $writeup );
    is( $after->{parent_e2node}, $before->{parent_e2node}, 'its parent is unchanged' );

    ( undef, $json ) = call( 'normaluser26', 'POST', "/api/writeups/$writeup/action/update",
        { parent_e2node => $before->{parent_e2node}, doctext => doctext_of($writeup) } );
    is( $json->{node_id}, $writeup, 'resending the current parent with an edit is fine' );
}

$DB->nukeNode( $DB->getNodeById($_), $root ) for grep { $DB->getNodeById($_) } reverse @created;

done_testing();
