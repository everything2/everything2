#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "$FindBin::Bin/lib";
use lib "/var/libraries/lib/perl5";

use Test::More;
use JSON;
use Everything;
use Everything::Application;
use Everything::API::e2clients;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

#############################################################################
# Test E2clients API
#
# This test verifies the e2client API endpoints:
# - e2clients/:id - Update e2client metadata (title, version, homeurl, dlurl, clientstr, doctext)
#############################################################################

# Get test users
my $admin_user = $DB->getNode("root", "user");
my $normal_user = $DB->getNode("e2e_user", "user") || $DB->getNode("normaluser1", "user");
my $guest_user_id = $Everything::CONF->guest_user;

ok($admin_user, "Got admin user");
ok($normal_user, "Got normal user");

# Create API instance
my $e2clients_api = Everything::API::e2clients->new();
ok($e2clients_api, "Created e2clients API instance");

# Get nodetypes
my $e2client_type = $DB->getNode('e2client', 'nodetype');
ok($e2client_type, "Got e2client nodetype");

#############################################################################
# Helper Functions
#############################################################################

my @created_e2clients = ();

sub create_test_e2client {
    my ($title, $author_id) = @_;
    $author_id //= $admin_user->{node_id};

    # Insert node
    $DB->sqlInsert('node', {
        title => $title,
        type_nodetype => $e2client_type->{node_id},
        author_user => $author_id,
        createtime => 'now()'
    });

    my $node_id = $DB->{dbh}->last_insert_id(undef, undef, 'node', 'node_id');

    # Insert e2client-specific data
    $DB->sqlInsert('e2client', {
        e2client_id => $node_id,
        version => '1.0.0',
        homeurl => 'https://example.com',
        dlurl => 'https://example.com/download',
        clientstr => 'TestClient/1.0'
    });

    # Insert document for doctext
    $DB->sqlInsert('document', {
        document_id => $node_id,
        doctext => 'Test client description'
    });

    push @created_e2clients, $node_id;
    return $node_id;
}

sub cleanup_test_data {
    foreach my $client_id (@created_e2clients) {
        $DB->sqlDelete('e2client', "e2client_id=$client_id");
        $DB->sqlDelete('document', "document_id=$client_id");
        $DB->sqlDelete('node', "node_id=$client_id");
    }
    @created_e2clients = ();
}

END {
    cleanup_test_data();
}

#############################################################################
# Test e2clients update endpoint
#############################################################################

subtest 'e2clients update - guest denied' => sub {
    my $client_id = create_test_e2client("Test E2client Guest " . time());

    my $req = MockRequest->new(
        node_id => $guest_user_id,
        is_guest_flag => 1,
        request_method => 'POST',
        postdata => { title => 'New Title' }
    );
    my $result = $e2clients_api->update($req, $client_id);

    ok($result, "Got response");
    is($result->[0], 401, "HTTP 401 Unauthorized for guest");
};

subtest 'e2clients update - client not found' => sub {
    my $req = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_admin_flag => 1,
        request_method => 'POST',
        postdata => { title => 'New Title' }
    );
    my $result = $e2clients_api->update($req, 999999999);

    is($result->[1]->{success}, 0, "Request denied for non-existent e2client");
    like($result->[1]->{error}, qr/not found/i, "Error mentions not found");
};

subtest 'e2clients update - permission denied for non-owner' => sub {
    my $client_id = create_test_e2client("Test E2client Perms " . time(), $admin_user->{node_id});

    my $req = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_admin_flag => 0,
        request_method => 'POST',
        postdata => { title => 'New Title' }
    );
    my $result = $e2clients_api->update($req, $client_id);

    is($result->[1]->{success}, 0, "Request denied for non-owner");
    like($result->[1]->{error}, qr/permission/i, "Error mentions permission");
};

subtest 'e2clients update - successful title update' => sub {
    my $client_id = create_test_e2client("Test E2client Title " . time(), $admin_user->{node_id});
    my $new_title = "Updated Client Title " . time();

    my $req = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_admin_flag => 1,
        nodedata => $admin_user,
        request_method => 'POST',
        postdata => { title => $new_title }
    );
    my $result = $e2clients_api->update($req, $client_id);

    is($result->[1]->{success}, 1, "Request succeeded") or diag("Error: " . ($result->[1]->{error} // 'none'));
    ok(grep { $_ eq 'title' } @{$result->[1]->{updated_fields}}, "Title in updated_fields");

    # Verify in database
    my $db_title = $DB->sqlSelect('title', 'node', "node_id=$client_id");
    is($db_title, $new_title, "Title updated in database");
};

subtest 'e2clients update - successful version update' => sub {
    my $client_id = create_test_e2client("Test E2client Version " . time(), $admin_user->{node_id});
    my $new_version = "2.0.0";

    my $req = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_admin_flag => 1,
        nodedata => $admin_user,
        request_method => 'POST',
        postdata => { version => $new_version }
    );
    my $result = $e2clients_api->update($req, $client_id);

    is($result->[1]->{success}, 1, "Request succeeded") or diag("Error: " . ($result->[1]->{error} // 'none'));
    ok(grep { $_ eq 'version' } @{$result->[1]->{updated_fields}}, "Version in updated_fields");

    # Verify in database
    my $db_version = $DB->sqlSelect('version', 'e2client', "e2client_id=$client_id");
    is($db_version, $new_version, "Version updated in database");
};

subtest 'e2clients update - successful homeurl update' => sub {
    my $client_id = create_test_e2client("Test E2client Homeurl " . time(), $admin_user->{node_id});
    my $new_homeurl = "https://newexample.com/" . time();

    my $req = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_admin_flag => 1,
        nodedata => $admin_user,
        request_method => 'POST',
        postdata => { homeurl => $new_homeurl }
    );
    my $result = $e2clients_api->update($req, $client_id);

    is($result->[1]->{success}, 1, "Request succeeded") or diag("Error: " . ($result->[1]->{error} // 'none'));
    ok(grep { $_ eq 'homeurl' } @{$result->[1]->{updated_fields}}, "Homeurl in updated_fields");

    # Verify in database
    my $db_homeurl = $DB->sqlSelect('homeurl', 'e2client', "e2client_id=$client_id");
    is($db_homeurl, $new_homeurl, "Homeurl updated in database");
};

subtest 'e2clients update - successful dlurl update' => sub {
    my $client_id = create_test_e2client("Test E2client Dlurl " . time(), $admin_user->{node_id});
    my $new_dlurl = "https://download.example.com/" . time();

    my $req = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_admin_flag => 1,
        nodedata => $admin_user,
        request_method => 'POST',
        postdata => { dlurl => $new_dlurl }
    );
    my $result = $e2clients_api->update($req, $client_id);

    is($result->[1]->{success}, 1, "Request succeeded") or diag("Error: " . ($result->[1]->{error} // 'none'));
    ok(grep { $_ eq 'dlurl' } @{$result->[1]->{updated_fields}}, "Dlurl in updated_fields");

    # Verify in database
    my $db_dlurl = $DB->sqlSelect('dlurl', 'e2client', "e2client_id=$client_id");
    is($db_dlurl, $new_dlurl, "Dlurl updated in database");
};

subtest 'e2clients update - successful clientstr update' => sub {
    my $client_id = create_test_e2client("Test E2client Clientstr " . time(), $admin_user->{node_id});
    my $new_clientstr = "NewClient/2.0";

    my $req = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_admin_flag => 1,
        nodedata => $admin_user,
        request_method => 'POST',
        postdata => { clientstr => $new_clientstr }
    );
    my $result = $e2clients_api->update($req, $client_id);

    is($result->[1]->{success}, 1, "Request succeeded") or diag("Error: " . ($result->[1]->{error} // 'none'));
    ok(grep { $_ eq 'clientstr' } @{$result->[1]->{updated_fields}}, "Clientstr in updated_fields");

    # Verify in database
    my $db_clientstr = $DB->sqlSelect('clientstr', 'e2client', "e2client_id=$client_id");
    is($db_clientstr, $new_clientstr, "Clientstr updated in database");
};

subtest 'e2clients update - successful doctext update' => sub {
    my $client_id = create_test_e2client("Test E2client Doctext " . time(), $admin_user->{node_id});
    my $new_doctext = "New description for e2client " . time();

    my $req = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_admin_flag => 1,
        nodedata => $admin_user,
        request_method => 'POST',
        postdata => { doctext => $new_doctext }
    );
    my $result = $e2clients_api->update($req, $client_id);

    is($result->[1]->{success}, 1, "Request succeeded") or diag("Error: " . ($result->[1]->{error} // 'none'));
    ok(grep { $_ eq 'doctext' } @{$result->[1]->{updated_fields}}, "Doctext in updated_fields");

    # Verify in database
    my $db_doctext = $DB->sqlSelect('doctext', 'document', "document_id=$client_id");
    is($db_doctext, $new_doctext, "Doctext updated in database");
};

subtest 'e2clients update - multiple fields at once' => sub {
    my $client_id = create_test_e2client("Test E2client Multi " . time(), $admin_user->{node_id});
    my $new_title = "Multi-field Client " . time();
    my $new_version = "3.0.0";
    my $new_homeurl = "https://multi.example.com/" . time();
    my $new_clientstr = "MultiClient/3.0";

    my $req = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_admin_flag => 1,
        nodedata => $admin_user,
        request_method => 'POST',
        postdata => {
            title => $new_title,
            version => $new_version,
            homeurl => $new_homeurl,
            clientstr => $new_clientstr
        }
    );
    my $result = $e2clients_api->update($req, $client_id);

    is($result->[1]->{success}, 1, "Request succeeded") or diag("Error: " . ($result->[1]->{error} // 'none'));
    is(scalar @{$result->[1]->{updated_fields}}, 4, "Four fields updated");

    # Verify all in database
    my $db_title = $DB->sqlSelect('title', 'node', "node_id=$client_id");
    my $db_version = $DB->sqlSelect('version', 'e2client', "e2client_id=$client_id");
    my $db_homeurl = $DB->sqlSelect('homeurl', 'e2client', "e2client_id=$client_id");
    my $db_clientstr = $DB->sqlSelect('clientstr', 'e2client', "e2client_id=$client_id");

    is($db_title, $new_title, "Title updated");
    is($db_version, $new_version, "Version updated");
    is($db_homeurl, $new_homeurl, "Homeurl updated");
    is($db_clientstr, $new_clientstr, "Clientstr updated");
};

subtest 'e2clients update - empty title rejected' => sub {
    my $client_id = create_test_e2client("Test E2client Empty " . time(), $admin_user->{node_id});

    my $req = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_admin_flag => 1,
        nodedata => $admin_user,
        request_method => 'POST',
        postdata => { title => '' }
    );
    my $result = $e2clients_api->update($req, $client_id);

    is($result->[1]->{success}, 0, "Empty title rejected");
    like($result->[1]->{error}, qr/empty/i, "Error mentions empty");
};

subtest 'e2clients update - title too long rejected' => sub {
    my $client_id = create_test_e2client("Test E2client Long " . time(), $admin_user->{node_id});
    my $long_title = 'x' x 250;  # More than 240 characters

    my $req = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_admin_flag => 1,
        nodedata => $admin_user,
        request_method => 'POST',
        postdata => { title => $long_title }
    );
    my $result = $e2clients_api->update($req, $client_id);

    is($result->[1]->{success}, 0, "Long title rejected");
    like($result->[1]->{error}, qr/long/i, "Error mentions too long");
};

subtest 'e2clients update - version too long rejected' => sub {
    my $client_id = create_test_e2client("Test E2client VersionLong " . time(), $admin_user->{node_id});
    my $long_version = 'x' x 260;  # More than 255 characters

    my $req = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_admin_flag => 1,
        nodedata => $admin_user,
        request_method => 'POST',
        postdata => { version => $long_version }
    );
    my $result = $e2clients_api->update($req, $client_id);

    is($result->[1]->{success}, 0, "Long version rejected");
    like($result->[1]->{error}, qr/long/i, "Error mentions too long");
};

subtest 'e2clients update - homeurl too long rejected' => sub {
    my $client_id = create_test_e2client("Test E2client HomeurlLong " . time(), $admin_user->{node_id});
    my $long_url = 'https://example.com/' . ('x' x 260);  # More than 255 characters

    my $req = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_admin_flag => 1,
        nodedata => $admin_user,
        request_method => 'POST',
        postdata => { homeurl => $long_url }
    );
    my $result = $e2clients_api->update($req, $client_id);

    is($result->[1]->{success}, 0, "Long homeurl rejected");
    like($result->[1]->{error}, qr/long/i, "Error mentions too long");
};

subtest 'e2clients update - no fields to update' => sub {
    my $client_id = create_test_e2client("Test E2client NoFields " . time(), $admin_user->{node_id});

    my $req = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_admin_flag => 1,
        nodedata => $admin_user,
        request_method => 'POST',
        postdata => {}
    );
    my $result = $e2clients_api->update($req, $client_id);

    is($result->[1]->{success}, 0, "No fields rejected");
    like($result->[1]->{error}, qr/no fields/i, "Error mentions no fields");
};

subtest 'e2clients update - clear optional fields with empty string' => sub {
    my $client_id = create_test_e2client("Test E2client ClearFields " . time(), $admin_user->{node_id});

    my $req = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_admin_flag => 1,
        nodedata => $admin_user,
        request_method => 'POST',
        postdata => {
            version => '',
            homeurl => '',
            dlurl => '',
            clientstr => ''
        }
    );
    my $result = $e2clients_api->update($req, $client_id);

    is($result->[1]->{success}, 1, "Request succeeded") or diag("Error: " . ($result->[1]->{error} // 'none'));

    # Verify fields are cleared in database
    my $db_version = $DB->sqlSelect('version', 'e2client', "e2client_id=$client_id");
    my $db_homeurl = $DB->sqlSelect('homeurl', 'e2client', "e2client_id=$client_id");
    my $db_dlurl = $DB->sqlSelect('dlurl', 'e2client', "e2client_id=$client_id");
    my $db_clientstr = $DB->sqlSelect('clientstr', 'e2client', "e2client_id=$client_id");

    is($db_version, '', "Version cleared");
    is($db_homeurl, '', "Homeurl cleared");
    is($db_dlurl, '', "Dlurl cleared");
    is($db_clientstr, '', "Clientstr cleared");
};

done_testing();
