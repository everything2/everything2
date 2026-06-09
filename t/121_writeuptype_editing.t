#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching RequireDotMatchAnything)
## no critic (ValuesAndExpressions ProhibitInterpolationOfLiterals ProhibitMagicNumbers)

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use JSON;
use Everything;
use Everything::Application;
use Everything::API::writeups;
use Everything::API::drafts;
use MockRequest;

our ($APP, $DB);

# Suppress expected dev-log warnings
$SIG{__WARN__} = sub {
  my $w = shift;
  warn $w unless $w =~ /Could not open log/ || $w =~ /Use of uninitialized value/;
};

initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

#############################################################################
# Feature: in-place writeup type editing (issue #4224)
#
# 'definition' and 'lede' are editor-only writeuptypes. A non-editor may keep a
# restricted type a writeup already has (so pre-existing ledes survive an edit
# -- the inverse of the #3396 clobber bug) but may not newly set one or switch
# between the two. Webster 1913 / Virgil bots may set restricted types.
#############################################################################

#############################################################################
# Part A: Application::can_set_writeuptype decision matrix (pure logic)
#############################################################################

subtest 'can_set_writeuptype decision matrix' => sub {
    # Non-restricted types: anyone, anytime
    ok( $APP->can_set_writeuptype({ is_editor => 0, username => 'normaluser1', new_type => 'thing' }),
        'non-editor may set a non-restricted type (thing)' );
    ok( $APP->can_set_writeuptype({ is_editor => 0, username => 'normaluser1', new_type => 'idea' }),
        'non-editor may set a non-restricted type (idea)' );

    # Restricted types: non-editor, no current type -> denied
    ok( !$APP->can_set_writeuptype({ is_editor => 0, username => 'normaluser1', new_type => 'definition' }),
        'non-editor may NOT set definition' );
    ok( !$APP->can_set_writeuptype({ is_editor => 0, username => 'normaluser1', new_type => 'lede' }),
        'non-editor may NOT set lede' );

    # Restricted types: editor -> allowed
    ok( $APP->can_set_writeuptype({ is_editor => 1, username => 'someeditor', new_type => 'definition' }),
        'editor may set definition' );
    ok( $APP->can_set_writeuptype({ is_editor => 1, username => 'someeditor', new_type => 'lede' }),
        'editor may set lede' );

    # Bot accounts may set restricted types without being editors
    ok( $APP->can_set_writeuptype({ is_editor => 0, username => 'Webster 1913', new_type => 'definition' }),
        'Webster 1913 may set definition' );
    ok( $APP->can_set_writeuptype({ is_editor => 0, username => 'Virgil', new_type => 'lede' }),
        'Virgil may set lede' );

    # Keep-if-current: non-editor keeping a restricted type the writeup already has
    ok( $APP->can_set_writeuptype({ is_editor => 0, username => 'normaluser1', new_type => 'lede', current_type => 'lede' }),
        'non-editor may KEEP an existing lede' );
    ok( $APP->can_set_writeuptype({ is_editor => 0, username => 'normaluser1', new_type => 'definition', current_type => 'definition' }),
        'non-editor may KEEP an existing definition' );

    # ...but may not switch BETWEEN restricted types
    ok( !$APP->can_set_writeuptype({ is_editor => 0, username => 'normaluser1', new_type => 'definition', current_type => 'lede' }),
        'non-editor may NOT switch lede -> definition' );

    # Downgrading away from a restricted type to a normal one is fine
    ok( $APP->can_set_writeuptype({ is_editor => 0, username => 'normaluser1', new_type => 'thing', current_type => 'lede' }),
        'non-editor may move lede -> thing' );

    # Case-insensitive on both the new and current type
    ok( !$APP->can_set_writeuptype({ is_editor => 0, username => 'normaluser1', new_type => 'Definition' }),
        'restriction is case-insensitive on new_type' );
    ok( $APP->can_set_writeuptype({ is_editor => 0, username => 'normaluser1', new_type => 'LEDE', current_type => 'Lede' }),
        'keep-if-current is case-insensitive on both sides' );

    is_deeply( $APP->restricted_writeuptypes, { definition => 1, lede => 1 },
        'restricted_writeuptypes is exactly {definition, lede}' );
};

#############################################################################
# Part B: writeups API in-place update enforcement (integration)
#############################################################################

my $writeups_api = Everything::API::writeups->new();
ok($writeups_api, "Created writeups API instance");

my $author    = $DB->getNode('normaluser1', 'user');   # non-editor, owns the fixtures
my $other     = $DB->getNode('normaluser2', 'user');   # non-editor, no rights
my $editor    = $DB->getNode('genericeditor', 'user'); # real Content Editors member
ok($author && $other && $editor, "Got test users");

# Faithfulness: the seeded users must actually match the roles we assert with
# (isEditor takes the raw user hashref, which getNode returns)
ok( !$APP->isEditor($author), "normaluser1 is not a Content Editor" );
ok(  $APP->isEditor($editor), "genericeditor is a real Content Editor" );

my $writeup_type     = $DB->getType('writeup');
my $thing_wt         = $DB->getNode('thing', 'writeuptype');
my $idea_wt          = $DB->getNode('idea', 'writeuptype');
my $definition_wt    = $DB->getNode('definition', 'writeuptype');
my $lede_wt          = $DB->getNode('lede', 'writeuptype');
ok($thing_wt && $idea_wt && $definition_wt && $lede_wt, "Got writeuptype nodes");

my @cleanup;
sub make_writeup {
    my ($title, $owner, $wrtype) = @_;
    my $parent_title = "WT Edit Parent " . $title . " " . time() . int(rand(100000));
    my $parent_id = $DB->insertNode($parent_title, 'e2node', $editor, {});
    my $wid = $DB->insertNode($title . " " . time() . int(rand(100000)), $writeup_type, $editor, {
        doctext       => "original body",
        parent_e2node => $parent_id,
    });
    # Set ownership + type directly so the fixture is exactly as described, then
    # force the node cache to re-read from the DB -- insertNode cached the node
    # with author_user = creator ($editor), and the API's permission check reads
    # through that cache, so without the refresh an owner edit would 403.
    $DB->sqlUpdate('node', { author_user => $owner->{node_id} }, "node_id = $wid");
    $DB->sqlUpdate('writeup', { wrtype_writeuptype => $wrtype->{node_id} }, "writeup_id = $wid");
    $DB->getNodeById($wid, 'force');
    push @cleanup, $wid, $parent_id;
    return $wid;
}

sub req {
    my (%a) = @_;  # user => node, is_editor => 0/1, post => hashref
    return MockRequest->new(
        node_id        => $a{user}->{node_id},
        title          => $a{user}->{title},
        is_guest_flag  => 0,
        is_editor_flag => $a{is_editor},
        nodedata       => $a{user},
        request_method => 'POST',
        postdata       => $a{post},
    );
}

sub wrtype_of {
    my ($wid) = @_;
    my $row = $DB->sqlSelectHashref('wrtype_writeuptype', 'writeup', "writeup_id = $wid");
    my $t = $DB->getNodeById($row->{wrtype_writeuptype});
    return $t->{title};
}

subtest 'author (non-editor) edits body only, no type field -> succeeds' => sub {
    my $wid = make_writeup('NoTypeField', $author, $thing_wt);
    my $r = req(user => $author, is_editor => 0, post => { doctext => 'edited body' });
    my $res = $writeups_api->update($r, $wid);
    is($res->[0], $writeups_api->HTTP_OK, 'HTTP_OK');
    ok(defined($res->[1]{node_id}), 'returns the node (success)');
    is(wrtype_of($wid), 'thing', 'type unchanged');
};

subtest 'author (non-editor) cannot change thing -> definition' => sub {
    my $wid = make_writeup('ThingToDef', $author, $thing_wt);
    my $r = req(user => $author, is_editor => 0,
                post => { doctext => 'edited', wrtype_writeuptype => $definition_wt->{node_id} });
    my $res = $writeups_api->update($r, $wid);
    is($res->[0], $writeups_api->HTTP_OK, 'HTTP_OK (never a 4xx, per JSON contract)');
    is($res->[1]{success}, 0, 'success=0');
    is($res->[1]{error}, 'writeuptype_not_allowed', 'error=writeuptype_not_allowed');
    is(wrtype_of($wid), 'thing', 'type NOT changed in DB');
};

subtest 'author (non-editor) may KEEP an existing lede while editing body' => sub {
    my $wid = make_writeup('KeepLede', $author, $lede_wt);
    my $r = req(user => $author, is_editor => 0,
                post => { doctext => 'fixed a typo', wrtype_writeuptype => $lede_wt->{node_id} });
    my $res = $writeups_api->update($r, $wid);
    is($res->[0], $writeups_api->HTTP_OK, 'HTTP_OK');
    ok(defined($res->[1]{node_id}), 'succeeds (keep-if-current)');
    is(wrtype_of($wid), 'lede', 'lede preserved -- the #3396 clobber does not happen');
};

subtest 'author (non-editor) cannot switch lede -> definition' => sub {
    my $wid = make_writeup('LedeToDef', $author, $lede_wt);
    my $r = req(user => $author, is_editor => 0,
                post => { doctext => 'x', wrtype_writeuptype => $definition_wt->{node_id} });
    my $res = $writeups_api->update($r, $wid);
    is($res->[1]{error}, 'writeuptype_not_allowed', 'blocked from switching between restricted types');
    is(wrtype_of($wid), 'lede', 'still lede');
};

subtest 'author (non-editor) may downgrade lede -> thing' => sub {
    my $wid = make_writeup('LedeToThing', $author, $lede_wt);
    my $r = req(user => $author, is_editor => 0,
                post => { doctext => 'x', wrtype_writeuptype => $thing_wt->{node_id} });
    my $res = $writeups_api->update($r, $wid);
    ok(defined($res->[1]{node_id}), 'succeeds');
    is(wrtype_of($wid), 'thing', 'moved to thing');
};

subtest 'editor may set a restricted type (thing -> definition)' => sub {
    my $wid = make_writeup('EditorSetsDef', $author, $thing_wt);
    my $r = req(user => $editor, is_editor => 1,
                post => { doctext => 'x', wrtype_writeuptype => $definition_wt->{node_id} });
    my $res = $writeups_api->update($r, $wid);
    is($res->[0], $writeups_api->HTTP_OK, 'HTTP_OK');
    ok(defined($res->[1]{node_id}), 'editor edit succeeds');
    is(wrtype_of($wid), 'definition', 'type changed to definition');
};

subtest 'invalid writeuptype id is rejected' => sub {
    my $wid = make_writeup('BadType', $author, $thing_wt);
    my $r = req(user => $author, is_editor => 0,
                post => { doctext => 'x', wrtype_writeuptype => 999999999 });
    my $res = $writeups_api->update($r, $wid);
    is($res->[1]{error}, 'invalid_writeuptype', 'error=invalid_writeuptype');
    is(wrtype_of($wid), 'thing', 'type unchanged');
};

subtest 'permission wrapper still enforced (around did not shadow it)' => sub {
    # A non-author non-editor must be forbidden -- proves our `around 'update'`
    # composes with the inherited `_can_update_okay`, not replaces it.
    my $wid = make_writeup('NotYours', $author, $thing_wt);
    my $r = req(user => $other, is_editor => 0,
                post => { doctext => 'sneaky', wrtype_writeuptype => $thing_wt->{node_id} });
    my $res = $writeups_api->update($r, $wid);
    is($res->[0], $writeups_api->HTTP_FORBIDDEN, 'non-author is FORBIDDEN by the permission wrapper');
};

#############################################################################
# Part C: drafts publish enforcement (no current type to grandfather)
#############################################################################

my $drafts_api = Everything::API::drafts->new();
ok($drafts_api, "Created drafts API instance");

my $draft_type = $DB->getType('draft');

sub make_draft {
    my ($owner) = @_;
    my $did = $DB->insertNode("WT Publish Draft " . time() . int(rand(100000)), $draft_type, $owner, {
        doctext => '<p>draft body</p>',
    });
    $DB->sqlUpdate('node', { author_user => $owner->{node_id} }, "node_id = $did");
    push @cleanup, $did;
    return $did;
}

sub publish_req {
    my (%a) = @_;
    return MockRequest->new(
        node_id        => $a{user}->{node_id},
        title          => $a{user}->{title},
        is_guest_flag  => 0,
        is_editor_flag => $a{is_editor},
        nodedata       => $a{user},
        request_method => 'POST',
        postdata       => $a{post},
    );
}

subtest 'non-editor cannot publish a draft as definition' => sub {
    my $did = make_draft($author);
    my $parent_title = "WT Publish Parent Def " . time() . int(rand(100000));
    my $parent_id = $DB->insertNode($parent_title, 'e2node', $editor, {});
    push @cleanup, $parent_id;
    my $r = publish_req(user => $author, is_editor => 0, post => {
        parent_e2node      => $parent_id,
        wrtype_writeuptype => $definition_wt->{node_id},
    });
    my $res = $drafts_api->publish_draft($r, $did);
    is($res->[0], $drafts_api->HTTP_OK, 'HTTP_OK (clean JSON error)');
    is($res->[1]{success}, 0, 'success=0');
    is($res->[1]{error}, 'writeuptype_not_allowed', 'restricted type blocked on fresh publish');
    # Draft must still be a draft (not converted)
    my $n = $DB->getNodeById($did);
    is($n->{type}{title}, 'draft', 'draft was not published');
};

subtest 'non-editor CAN publish a draft as a normal type (control)' => sub {
    my $did = make_draft($author);
    my $parent_title = "WT Publish Parent Idea " . time() . int(rand(100000));
    my $parent_id = $DB->insertNode($parent_title, 'e2node', $editor, {});
    push @cleanup, $parent_id;
    my $r = publish_req(user => $author, is_editor => 0, post => {
        parent_e2node      => $parent_id,
        wrtype_writeuptype => $idea_wt->{node_id},
    });
    my $res = $drafts_api->publish_draft($r, $did);
    is($res->[0], $drafts_api->HTTP_OK, 'HTTP_OK');
    ok($res->[1]{success}, 'publish succeeds for a non-restricted type');
};

subtest 'editor CAN publish a draft as definition' => sub {
    my $did = make_draft($editor);
    my $parent_title = "WT Publish Parent EdDef " . time() . int(rand(100000));
    my $parent_id = $DB->insertNode($parent_title, 'e2node', $editor, {});
    push @cleanup, $parent_id;
    my $r = publish_req(user => $editor, is_editor => 1, post => {
        parent_e2node      => $parent_id,
        wrtype_writeuptype => $definition_wt->{node_id},
    });
    my $res = $drafts_api->publish_draft($r, $did);
    is($res->[0], $drafts_api->HTTP_OK, 'HTTP_OK');
    ok($res->[1]{success}, 'editor publish as definition succeeds');
};

#############################################################################
# Cleanup
#############################################################################
for my $id (@cleanup) {
    next unless $id;
    $DB->sqlDelete('nodegroup', "nodegroup_id=$id");
    $DB->sqlDelete('writeup',   "writeup_id=$id");
    $DB->sqlDelete('draft',     "draft_id=$id");
    $DB->sqlDelete('newwriteup', "node_id=$id");
    $DB->sqlDelete('publish',   "publish_id=$id");
    $DB->sqlDelete('node',      "node_id=$id");
}

done_testing();
