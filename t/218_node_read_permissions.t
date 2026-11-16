#!/usr/bin/perl -w
#
# Node read permissions for collaborations, discussions and drafts, through the generic
# node API and the collaboration page data. Each node class owns its read rule
# (can_read_node); the controllers and APIs ask the node.
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
    return unless $name;
    my $user = $DB->getNode( $name, 'user' ) or return;
    return $Everything::CONF->cookiepass . '=' . uri_escape_utf8("$user->{title}|$user->{passwd}");
}

sub get_json {
    my ( $as, $path ) = @_;
    my $req = HTTP::Request::Common::GET($path);
    my $cookie = cookie_for($as);
    $req->header( Cookie => $cookie ) if $cookie;
    my $res = $test->request($req);
    return ( $res->code, ( eval { JSON->new->decode( $res->content ) } || {} ), $res->content );
}

my $root   = $DB->getNode( 'root',        'user' );
my $stamp  = time();
my @created;

sub make_node {
    my ( $title, $type, $author, $data ) = @_;
    my $id = $DB->insertNode( $title, $type, $author, $data );
    push @created, $id if $id;
    return $id;
}

my $secret = "private text $stamp";

# --- collaborations --------------------------------------------------------------
my $private_collab = make_node( "perm test private collab $stamp", 'collaboration', $root, { doctext => $secret, public => 0 } );
my $public_collab  = make_node( "perm test public collab $stamp",  'collaboration', $root, { doctext => "public $stamp", public => 1 } );
# (Collaboration membership can't be tested: the collaboration nodetype has no grouptable,
# so insertIntoNodegroup adds nothing. Access comes from admin, editor and crtleads.)

SKIP: {
    skip 'could not create collaborations', 1 unless $private_collab && $public_collab;

    for my $as ( undef, 'normaluser1' ) {
        my $who = $as // 'guest';
        my ( $code, $json, $raw ) = get_json( $as, "/api/nodes/$private_collab" );
        unlike( $raw, qr/\Q$secret\E/, "private collaboration via /api/nodes: $who gets no text" );
        isnt( $code, 200, "private collaboration via /api/nodes: $who is refused" );

        my ( undef, $page, $page_raw ) = get_json( $as, "/api/pagestate?node_id=$private_collab" );
        unlike( $page_raw, qr/\Q$secret\E/, "private collaboration page: $who gets no text" );
    }
    for my $as ( 'genericeditor', 'root' ) {
        my ( $code, undef, $raw ) = get_json( $as, "/api/nodes/$private_collab" );
        is( $code, 200, "private collaboration via /api/nodes: $as (editor/admin) can read it" );
        like( $raw, qr/\Q$secret\E/, "private collaboration via /api/nodes: $as gets the text" );
    }
    my ( $code, undef, $raw ) = get_json( undef, "/api/nodes/$public_collab" );
    is( $code, 200, 'public collaboration: guest can read it' );
    like( $raw, qr/public \Q$stamp\E/, 'public collaboration: guest gets the text' );
    my ( undef, undef, $page_raw ) = get_json( undef, "/api/pagestate?node_id=$public_collab" );
    like( $page_raw, qr/public \Q$stamp\E/, 'public collaboration page: guest gets the text' );
}

# --- discussions restricted to gods ---------------------------------------------------
my $gods = $DB->getNode( 'gods', 'usergroup' );
my $debate_text = "gods only discussion $stamp";
my $debate = make_node( "perm test debate $stamp", 'debatecomment', $root,
    { doctext => $debate_text, restricted => $gods->{node_id}, root_debatecomment => 0, parent_debatecomment => 0 } );

SKIP: {
    skip 'could not create a discussion', 1 unless $debate;
    for my $as ( undef, 'normaluser1', 'genericeditor' ) {
        my $who = $as // 'guest';
        my ( $code, undef, $raw ) = get_json( $as, "/api/nodes/$debate" );
        unlike( $raw, qr/\Q$debate_text\E/, "gods-only discussion via /api/nodes: $who gets no text" );
        isnt( $code, 200, "gods-only discussion via /api/nodes: $who is refused" );
    }
    my ( $code, undef, $raw ) = get_json( 'root', "/api/nodes/$debate" );
    is( $code, 200, 'gods-only discussion: admin can read it' );
    like( $raw, qr/\Q$debate_text\E/, 'gods-only discussion: admin gets the text' );
}

# --- drafts ----------------------------------------------------------------------------
my $author  = $DB->getNode( 'normaluser1', 'user' );
my $private = $DB->getNode( 'private', 'publication_status' );
my $draft_text = "draft text $stamp";
my $draft = make_node( "perm test draft $stamp", 'draft', $author, { doctext => $draft_text, publication_status => $private->{node_id} } );

SKIP: {
    skip 'could not create a draft', 1 unless $draft;
    for my $as ( undef, 'normaluser2' ) {
        my $who = $as // 'guest';
        my ( $code, undef, $raw ) = get_json( $as, "/api/nodes/$draft" );
        unlike( $raw, qr/\Q$draft_text\E/, "private draft via /api/nodes: $who gets no text" );
        isnt( $code, 200, "private draft via /api/nodes: $who is refused" );
    }
    ok( $DB->getNodeById($draft) && Everything::Node::draft->new( $DB->getNodeById($draft) )->can_read_node( $APP->node_by_id( $author->{node_id} ) ),
        'private draft: its author can read it' );
}

# --- ordinary nodes are unaffected ---------------------------------------------------------
my $e2node = $DB->getNode( 'Quick brown fox', 'e2node' );
SKIP: {
    skip 'no seeded e2node', 1 unless $e2node;
    my ( $code ) = get_json( undef, "/api/nodes/$e2node->{node_id}" );
    is( $code, 200, 'guest can still read an ordinary e2node' );
}

$DB->nukeNode( $DB->getNodeById($_), $root ) for grep { $DB->getNodeById($_) } reverse @created;

done_testing();
