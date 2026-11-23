#!/usr/bin/perl -w

# Category edits made through the API are seen by every web worker, not just the one that made them.
# Each worker keeps its own node cache and checks a node's version before reusing it, so an edit has
# to go through updateNode (which bumps the version). "Another worker" here is a second NodeBase with
# its own cache, warmed before the edit, starting a new request (resetCache) after it.

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use JSON;
use Encode;
use Everything;
use Everything::API::category;

initEverything('development-docker');
my $DB  = $Everything::DB;
my $APP = $Everything::APP;

{
    package CategoryTestRequest;
    sub new {
        my ($class, $user, $data) = @_;
        return bless { user => $user, postdata => Encode::encode_utf8(JSON::encode_json($data)) }, $class;
    }
    sub user           { return $_[0]{user} }
    sub is_guest       { return $_[0]{user}->is_guest }
    sub POSTDATA       { return $_[0]{postdata} }
    sub JSON_POSTDATA  { return JSON::decode_json($_[0]{postdata}) }
    sub request_method { return 'POST' }
    sub param          { return }
}

my $root      = $APP->node_by_id($DB->getNode('root', 'user')->{node_id});
my $owner     = $APP->node_by_id($DB->getNode('normaluser9', 'user')->{node_id});
my $new_owner = $APP->node_by_id($DB->getNode('normaluser10', 'user')->{node_id});
ok($root && $root->is_editor && $owner && !$owner->is_editor && $new_owner, 'test users exist');

my $other = Everything::NodeBase->new;
ok($other && $other->{cache} != $DB->{cache}, 'a second worker with its own cache');

my $title = "Worker cache category $$";
my $id = $DB->insertNode($title, 'category', $owner->NODEDATA,
    { author_user => $owner->node_id, doctext => '<p>Old description</p>' }, 'skip maintenance');
END {
    return unless $DB && $id;
    if (my $n = $DB->getNodeById($id, 'force')) { $DB->nukeNode($n, -1, 1) }
    $DB->sqlDelete('tomb', "node_id=$id");
}
ok($id, 'a category owned by a member');

# What the other worker sees on its next request.
sub other_copy { $other->{cache}->resetCache; return $other->getNodeById($id) }

my $api = Everything::API::category->new;

subtest 'editing the description' => sub {
    is(other_copy()->{doctext}, '<p>Old description</p>', 'the other worker has the old description');

    my $r = $api->update_category(CategoryTestRequest->new($owner, { node_id => $id, doctext => '<p>New description</p>' }));
    ok($r->[1]{success}, 'the owner saves a new description') or diag explain $r->[1];

    is($DB->sqlSelect('doctext', 'document', "document_id=$id"), '<p>New description</p>', 'the database has it');
    is(other_copy()->{doctext}, '<p>New description</p>', 'so does the other worker');
    $DB->{cache}->resetCache;
    is($DB->getNodeById($id)->{doctext}, '<p>New description</p>', 'and the worker that made the change');
};

subtest 'changing the title and owner' => sub {
    my $r = $api->update_category_meta(CategoryTestRequest->new($root,
        { node_id => $id, title => "$title renamed", author_user => $new_owner->node_id }));
    ok($r->[1]{success}, 'an editor renames it and hands it to another member') or diag explain $r->[1];
    is($r->[1]{title}, "$title renamed", 'the response has the title as saved, for the edit page to show');

    my $seen = other_copy();
    is($seen->{title}, "$title renamed", 'the other worker has the new title');
    is($seen->{author_user}, $new_owner->node_id, 'and the new owner');
    is($seen->{doctext}, '<p>New description</p>', 'and still the description');

    $DB->{cache}->resetCache;
    my $here = $DB->getNodeById($id);
    is($here->{title}, "$title renamed", 'the worker that made the change has the new title');
    is($here->{author_user}, $new_owner->node_id, 'and the new owner');
};

done_testing();
