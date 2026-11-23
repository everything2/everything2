#!/usr/bin/perl -w
#
# A worker's cached copy of a node is stamped with the node's version, and served as current while
# the version table still says that version. So the stamp must never be newer than the contents.
# Each case here lands a change from another worker at the exact moment between this worker
# reading a node and stamping it, then checks that this worker's next request sees the change
# instead of serving its old copy as current:
#   - loading a node by id, and by title, on a cache miss (the rows, then the version);
#   - saving a node with updateNode (write, bump, re-cache);
#   - a signed-in request recording "last seen" (Everything::Request).
#
# "Another worker" is a second NodeBase with its own cache. The change lands through a one-shot
# hook on this worker's own read or version bump; every hook is local to its subtest.
#
use strict;
use warnings;
use lib qw(/var/everything/ecore /var/libraries/lib/perl5 /var/everything/t/lib);
use Test::More;
use URI::Escape qw(uri_escape);
use Everything;
use Everything::Request;
use TestSeed;

initEverything 'everything';
my $DB  = $Everything::DB;
my $APP = $Everything::APP;

my @planted;
END {
    for my $id (@planted) {
        if (my $n = $DB->getNodeById($id, 'force')) { $DB->nukeNode($n, -1, 1) }
        $DB->sqlDelete('tomb', "node_id=$id");
    }
    TestSeed::cleanup($DB);
}

my $root  = $DB->getNode('root', 'user');
my $other = Everything::NodeBase->new;
ok($other && $other->{cache} != $DB->{cache}, 'a second worker with its own cache');

sub plant_document {
    my ($label) = @_;
    my $id = $DB->insertNode("Cache stamp $label $$", 'document', $root, { doctext => 'first' }, 'skip maintenance');
    push @planted, $id;
    return $id;
}

# The other worker changes a field of the node and saves it (a proper save: it bumps the version).
sub other_worker_sets {
    my ($id, $field, $value) = @_;
    my $copy = $other->getNodeById($id, 'force');
    $copy->{$field} = $value;
    $other->updateNode($copy, -1);
}

# What this worker serves on its next request.
sub next_request { $DB->{cache}->resetCache; return $DB->getNodeById($_[0]) }

subtest 'a change landing while a node is loaded by id' => sub {
    my $id = plant_document('by id');
    $DB->{cache}->removeNode($DB->getNodeById($id));

    my $fired = 0;
    my $orig  = \&Everything::NodeBase::constructNode;
    no warnings 'redefine';
    local *Everything::NodeBase::constructNode = sub {
        my ($this, $NODE) = @_;
        my @r = $orig->(@_);
        if (!$fired && $this == $DB && $NODE->{node_id} == $id) {
            $fired = 1;
            other_worker_sets($id, 'doctext', 'second');
        }
        return @r;
    };
    use warnings 'redefine';

    $DB->{cache}->resetCache;
    is($DB->getNodeById($id)->{doctext}, 'first', 'this load read the rows before the change');
    ok($fired, 'the change landed mid-load');
    is(next_request($id)->{doctext}, 'second', 'the next request sees the change');
};

subtest 'a change landing while a node is loaded by title' => sub {
    my $id = plant_document('by title');
    my $title = $DB->getNodeById($id)->{title};
    $DB->{cache}->removeNode($DB->getNodeById($id));

    my $fired = 0;
    my $orig  = \&Everything::NodeBase::getNodeWhere;
    no warnings 'redefine';
    local *Everything::NodeBase::getNodeWhere = sub {
        my ($this) = @_;
        my @r = $orig->(@_);
        if (!$fired && $this == $DB && @r && $r[0]{node_id} == $id) {
            $fired = 1;
            other_worker_sets($id, 'doctext', 'second');
        }
        return @r;
    };
    use warnings 'redefine';

    $DB->{cache}->resetCache;
    is($DB->getNode($title, 'document')->{doctext}, 'first', 'this load read the rows before the change');
    ok($fired, 'the change landed mid-load');
    is(next_request($id)->{doctext}, 'second', 'the next request sees the change');
    $DB->{cache}->resetCache;
    is($DB->getNode($title, 'document')->{doctext}, 'second', 'and so does a lookup by title');
};

subtest 'a change landing while this worker saves the node' => sub {
    my $id = plant_document('save');
    my $copy = next_request($id);
    is($copy->{doctext}, 'first', 'this worker has the node cached');

    my $fired = 0;
    my $orig  = \&Everything::NodeCache::incrementGlobalVersion;
    no warnings 'redefine';
    local *Everything::NodeCache::incrementGlobalVersion = sub {
        my ($this, $NODE) = @_;
        if (!$fired && $this == $DB->{cache} && $NODE->{node_id} == $id) {
            $fired = 1;
            other_worker_sets($id, 'doctext', 'second');    # after this worker's write, before its bump
        }
        return $orig->(@_);
    };
    use warnings 'redefine';

    $copy->{title} = "Cache stamp save $$ renamed";
    ok($DB->updateNode($copy, -1), 'this worker saves a new title');
    ok($fired, 'the change landed mid-save');

    my $seen = next_request($id);
    is($seen->{doctext}, 'second', "the next request sees the other worker's change");
    is($seen->{title}, "Cache stamp save $$ renamed", 'and its own');
};

subtest 'saving with nothing else changing keeps the copy cached' => sub {
    my $id = plant_document('quiet save');
    my $copy = next_request($id);
    $copy->{doctext} = 'second';
    ok($DB->updateNode($copy, -1), 'saved');
    ok(defined $DB->{cache}{idCache}{$id}, 'still in the cache');
    $DB->{cache}->resetCache;
    is($DB->{cache}->getCachedNodeById($id), $copy, 'and served from it as current on the next request');
    is($copy->{doctext}, 'second', 'with the change');
};

subtest 'a change landing while a signed-in request records "last seen"' => sub {
    my $u = TestSeed::make_user($DB, $APP, label => 'stamp', password => 'stamp-pass', lasttime => '2020-01-01 00:00:00');
    ok($u, 'a throwaway member');
    my $id = $u->{node_id};
    my $user = next_request($id);    # cached in this worker, as for any signed-in member

    my $fired = 0;
    my $orig  = \&Everything::NodeCache::incrementGlobalVersion;
    no warnings 'redefine';
    local *Everything::NodeCache::incrementGlobalVersion = sub {
        my ($this, $NODE) = @_;
        if (!$fired && $this == $DB->{cache} && $NODE->{node_id} == $id) {
            $fired = 1;
            other_worker_sets($id, 'realname', 'Changed Meanwhile');
        }
        return $orig->(@_);
    };
    use warnings 'redefine';

    open(my $in, '<', \(my $body = '')) or die $!;
    my $cookie = $Everything::CONF->cookiepass . '=' . uri_escape("$user->{title}|$user->{passwd}");
    local $Everything::Request::PSGI_ENV = {
        REQUEST_METHOD => 'GET', QUERY_STRING => '', SERVER_NAME => 'everything2.com', SERVER_PORT => 80,
        HTTP_COOKIE => $cookie, 'psgi.input' => $in, 'psgi.url_scheme' => 'http',
        'psgi.version' => [1, 1], 'psgi.errors' => \*STDERR,
    };
    $DB->{cache}->resetCache;
    my $signed_in = Everything::Request->new->user;
    is($signed_in->node_id, $id, 'the request is signed in as the member');
    ok($fired, 'the change landed while "last seen" was recorded');

    my $seen = next_request($id);
    is($seen->{realname}, 'Changed Meanwhile', 'the next request sees the change');
    my $stored = $DB->sqlSelect('lasttime', 'user', "user_id=$id");
    isnt($stored, '2020-01-01 00:00:00', '"last seen" was recorded');
    is($seen->{lasttime}, $stored, 'and the next request has it as stored');
};

done_testing();
