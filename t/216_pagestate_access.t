#!/usr/bin/perl -w
#
# /api/pagestate applies the same access rules as the HTML page path.
#
# Node-level: a node whose type has a readers group renders as Permission Denied for
# users outside it; a draft the user can't see renders as not found. Page-level: when a
# page's controller declines to render (its check_permission redirects), pagestate
# returns { success => 0, redirect => ... } and no page data.
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
    return undef unless $name;
    my $user = $DB->getNode( $name, 'user' ) or return undef;
    return $Everything::CONF->cookiepass . '=' . uri_escape_utf8("$user->{title}|$user->{passwd}");
}

sub pagestate {
    my ( $as, $node_id ) = @_;
    my $req = HTTP::Request::Common::GET("/api/pagestate?node_id=$node_id");
    my $cookie = cookie_for($as);
    $req->header( Cookie => $cookie ) if $cookie;
    my $res = $test->request($req);
    return eval { JSON->new->decode( $res->content ) } || {};
}

sub node_id_of {
    my ( $title, $type ) = @_;
    my $node = $DB->getNode( $title, $type );
    return $node && $node->{node_id};
}

my $permission_denied = $Everything::CONF->permission_denied;
my $not_found         = $Everything::CONF->not_found_node;

# The page that was actually rendered, or 0 when pagestate declined.
sub rendered_id { my ($page) = @_; return ( $page->{node} && $page->{node}{node_id} ) || 0 }

# --- node-level gates: types with a readers group -----------------------------
my @reader_gated = (
    [ 'Server Telemetry', 'oppressor_superdoc', 'genericeditor' ],
    [ 'Fresh blood',      'oppressor_superdoc', 'genericeditor' ],
);
my ($oppressor_doc) = $DB->sqlSelect( 'node_id', 'node', 'type_nodetype=' . $DB->getType('oppressor_document')->{node_id} );
my ($edev_doc)      = $DB->sqlSelect( 'node_id', 'node', 'type_nodetype=' . $DB->getType('edevdoc')->{node_id} );

for my $case (@reader_gated) {
    my ( $title, $type, $allowed ) = @$case;
    my $id = node_id_of( $title, $type ) or next;
    for my $as ( undef, 'normaluser1' ) {
        my $who = $as // 'guest';
        my $page = pagestate( $as, $id );
        is( rendered_id($page), $permission_denied, "$title: $who gets Permission Denied" );
    }
    my $own_type = pagestate( $allowed, $id )->{contentData}{type};
    for my $as ( undef, 'normaluser1' ) {
        my $content = pagestate( $as, $id )->{contentData} || {};
        isnt( $content->{type} // '', $own_type, "$title: " . ( $as // 'guest' ) . " gets none of its content" );
    }
    is( rendered_id( pagestate( $allowed, $id ) ), $id, "$title: $allowed (reader) gets the page" );
}

SKIP: {
    skip 'no oppressor_document in this database', 2 unless $oppressor_doc;
    is( rendered_id( pagestate( undef, $oppressor_doc ) ), $permission_denied, 'oppressor_document: guest gets Permission Denied' );
    is( rendered_id( pagestate( 'genericeditor', $oppressor_doc ) ), $oppressor_doc, 'oppressor_document: editor gets it' );
}
SKIP: {
    skip 'no edevdoc in this database', 2 unless $edev_doc;
    is( rendered_id( pagestate( 'normaluser1', $edev_doc ) ), $permission_denied, 'edevdoc: normal user gets Permission Denied' );
    is( rendered_id( pagestate( 'root', $edev_doc ) ), $edev_doc, 'edevdoc: admin gets it' );
}

# --- page-level gates: restricted_superdoc pages check permission in the controller ----
for my $title ( 'GP Optouts', 'Node Forbiddance', 'Users with Infravision' ) {
    my $id = node_id_of( $title, 'restricted_superdoc' ) or next;
    my $admin_page = pagestate( 'root', $id );
    is( rendered_id($admin_page), $id, "$title: admin gets the page" );
    my $own_type = $admin_page->{contentData}{type};
    for my $as ( undef, 'normaluser1', 'genericeditor' ) {
        my $who  = $as // 'guest';
        my $page = pagestate( $as, $id );
        # Either declined outright or rendered as Permission Denied; never this page's data.
        ok( !$page->{contentData} || rendered_id($page) == $permission_denied,
            "$title: $who gets a refusal or Permission Denied" );
        isnt( ( $page->{contentData} || {} )->{type} // '', $own_type, "$title: $who gets none of its content" );
    }
}

# --- page-level gates: superdocs whose Page class checks permission ----------------
# The controller refuses with a redirect; pagestate must pass that on, not build the page.
for my $case (
    [ 'E2 Collaboration Nodes', [ undef, 'normaluser1' ], 'genericeditor' ],    # StaffOnly
    [ 'Node Tracker',           [undef],                  'normaluser1' ],      # NoGuest
    )
{
    my ( $title, $refused, $allowed ) = @$case;
    my $id = node_id_of( $title, 'superdoc' ) or next;
    for my $as (@$refused) {
        my $who  = $as // 'guest';
        my $page = pagestate( $as, $id );
        is( $page->{success}, 0, "$title: $who is refused" );
        ok( $page->{redirect}, "$title: $who gets the redirect the page would send" );
        ok( !$page->{contentData}, "$title: $who gets no page data" );
    }
    is( rendered_id( pagestate( $allowed, $id ) ), $id, "$title: $allowed gets the page" );
}

# --- drafts --------------------------------------------------------------------
my $author = $DB->getNode( 'normaluser1', 'user' );
my $private = $DB->getNode( 'private', 'publication_status' );
SKIP: {
    skip 'draft prerequisites missing', 3 unless $author && $private;
    my $draft_id = $DB->insertNode( 'pagestate access test draft ' . time(), 'draft', $author,
        { doctext => 'private text', publication_status => $private->{node_id} } );
    skip 'could not create a draft', 3 unless $draft_id;

    is( rendered_id( pagestate( 'normaluser1', $draft_id ) ), $draft_id, 'private draft: its author gets it' );
    my $other = pagestate( 'normaluser2', $draft_id );
    is( rendered_id($other), $not_found, 'private draft: another user gets not found' );
    unlike( JSON->new->encode($other), qr/private text/, 'private draft: no draft text for another user' );

    $DB->nukeNode( $DB->getNodeById($draft_id), -1 );
}

# --- ordinary pages are unaffected ---------------------------------------------
my $default = $Everything::CONF->default_node;
is( rendered_id( pagestate( undef, $default ) ), $default, 'guest still gets the front page' );
ok( pagestate( undef, $default )->{contentData}, 'front page carries its content' );

done_testing();
