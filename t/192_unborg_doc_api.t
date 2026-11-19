#!/usr/bin/perl -w
# Everything::API::nate_s_secret_unborg_doc -- POST /api/nate_s_secret_unborg_doc/unborg
# (#4468, Refs #4298). The admin "secret escape hatch" instant-unborg used to run on page
# load (a GET-mutation). It now lives here and shares the clear with the auto-expiry via
# Everything::Application::unborg_user. Tests the admin gate and a real unborg (borged var
# + lastborg), restoring root's vars afterward.
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::API::nate_s_secret_unborg_doc;
use MockRequest;
use TestSeed;

initEverything('development-docker');
ok($DB, 'Database connection established');

my $api = Everything::API::nate_s_secret_unborg_doc->new();
ok($api, 'Created unborg-doc API instance');
is_deeply($api->routes, {unborg => 'unborg_self'}, 'routes: unborg -> unborg_self');

#############################################################################
# Gate: non-admin gets the brush-off
#############################################################################
my $r = $api->unborg_self(MockRequest->new(is_admin_flag => 0, is_guest_flag => 0));
is($r->[0], $api->HTTP_OK, 'returns 200');
is($r->[1]{success}, 0, 'non-admin refused');
like($r->[1]{message}, qr/stay in there/i, 'easter-egg brush-off message');

#############################################################################
# Admin: force-unborg clears the active borg
#############################################################################
{
    my $admin = TestSeed::make_user($DB, $APP, label => 'unborg');
    my $vars  = $APP->getVars($admin);

    # Borg the user (borged = a timestamp).
    my $when = time();
    $vars->{borged} = $when;
    Everything::setVars($admin, $vars);
    $DB->updateNode($admin, -1);

    $r = $api->unborg_self(MockRequest->new(
        is_admin_flag => 1, is_guest_flag => 0, node_id => $admin->{node_id}, nodedata => $admin));
    is($r->[1]{success}, 1, 'admin unborg succeeds');
    like($r->[1]{message}, qr/unborged/i, 'unborged message');

    my $after = $APP->getVars($DB->getNodeById($admin->{node_id}, 'force'));
    ok(!$after->{borged}, 'borged var cleared');
    is($after->{lastborg}, $when, 'lastborg records the cleared borging');
}

END { TestSeed::cleanup($DB) }

done_testing;
