#!/usr/bin/perl -w
# Everything::API::markdiscussionsread -- POST /api/markdiscussionsread/{ce,admin}
# (#4410). The CE/admin "mark all debates read" actions used to write
# lastreaddebate as a side effect in mark_all_discussions_as_read's buildReactData
# (GET ?mark_ce_read / ?mark_admin_read). Now editor/admin-gated API. Tests the
# gates and the actual mark write against temp debates (self-cleaning; a fake
# caller uid isolates the lastreaddebate rows for teardown).
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::API::markdiscussionsread;
use MockRequest;

initEverything('development-docker');
ok($DB,  'Database connection established');
ok($APP, 'Application object created');

my $api = Everything::API::markdiscussionsread->new();
ok($api, 'Created markdiscussionsread API instance');
is_deeply($api->routes, { 'ce' => 'mark_ce', 'admin' => 'mark_admin' },
    'routes: ce -> mark_ce, admin -> mark_admin');

#############################################################################
# Gates
#############################################################################
my $r = $api->mark_ce(MockRequest->new(node_id => 999999, is_editor_flag => 0, is_admin_flag => 0));
is($r->[1]{success}, 0, 'non-editor/non-admin cannot mark CE');
like($r->[1]{error}, qr/editor or admin/i, 'CE gate error');

$r = $api->mark_admin(MockRequest->new(node_id => 999999, is_admin_flag => 0));
is($r->[1]{success}, 0, 'non-admin cannot mark admin');
like($r->[1]{error}, qr/admin/i, 'admin gate error');

#############################################################################
# Mark writes lastreaddebate (temp debates, fake caller for clean teardown)
#############################################################################
my $ce   = $DB->getNode('Content Editors', 'usergroup');
my $gods = $DB->getNode('gods', 'usergroup');
my $UID     = 99999999;   # fake caller -- isolates lastreaddebate rows
my $CEDEB   = 99990001;
my $GODSDEB = 99990002;

SKIP: {
    skip 'Content Editors / gods group not present', 6 unless ($ce && $gods);

    for my $d ([$CEDEB, $ce->{node_id}], [$GODSDEB, $gods->{node_id}]) {
        $DB->sqlDelete('debatecomment', "debatecomment_id=$d->[0]");
        $DB->sqlInsert('debatecomment', {
            debatecomment_id     => $d->[0],
            root_debatecomment   => $d->[0],
            parent_debatecomment => 0,
            restricted           => $d->[1],
            doctext              => 'test debate',
        });
    }

    $r = $api->mark_ce(MockRequest->new(node_id => $UID, is_editor_flag => 1));
    is($r->[1]{success}, 1, 'editor mark_ce succeeds');
    ok($r->[1]{count} >= 1, 'CE count includes the temp debate');
    ok($DB->sqlSelect('dateread', 'lastreaddebate', "user_id=$UID AND debateroot_id=$CEDEB"),
        'CE debate marked read in lastreaddebate');

    $r = $api->mark_admin(MockRequest->new(node_id => $UID, is_admin_flag => 1));
    is($r->[1]{success}, 1, 'admin mark_admin succeeds');
    ok($r->[1]{count} >= 1, 'admin count includes the temp debate');
    ok($DB->sqlSelect('dateread', 'lastreaddebate', "user_id=$UID AND debateroot_id=$GODSDEB"),
        'admin debate marked read in lastreaddebate');
}

# Teardown: temp debates + every lastreaddebate row for the fake caller.
$DB->sqlDelete('debatecomment', "debatecomment_id IN ($CEDEB, $GODSDEB)");
$DB->sqlDelete('lastreaddebate', "user_id=$UID");

done_testing;
