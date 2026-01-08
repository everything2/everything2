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
use Everything::API::podcasts;
use Everything::API::recordings;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

#############################################################################
# Test Podcast and Recording APIs
#
# This test verifies the podcast and recording API endpoints:
# - podcasts/:id - Update podcast metadata (title, description, link, pubdate)
# - recordings - Create a new recording
#############################################################################

# Get test users
my $admin_user = $DB->getNode("root", "user");
my $normal_user = $DB->getNode("e2e_user", "user") || $DB->getNode("normaluser1", "user");
my $guest_user_id = $Everything::CONF->guest_user;

ok($admin_user, "Got admin user");
ok($normal_user, "Got normal user");

# Create API instances
my $podcasts_api = Everything::API::podcasts->new();
my $recordings_api = Everything::API::recordings->new();
ok($podcasts_api, "Created podcasts API instance");
ok($recordings_api, "Created recordings API instance");

# Get nodetypes
my $podcast_type = $DB->getNode('podcast', 'nodetype');
my $recording_type = $DB->getNode('recording', 'nodetype');
ok($podcast_type, "Got podcast nodetype");
ok($recording_type, "Got recording nodetype");

#############################################################################
# Helper Functions
#############################################################################

my @created_podcasts = ();
my @created_recordings = ();

sub create_test_podcast {
    my ($title, $author_id) = @_;
    $author_id //= $admin_user->{node_id};

    # Insert node
    $DB->sqlInsert('node', {
        title => $title,
        type_nodetype => $podcast_type->{node_id},
        author_user => $author_id,
        createtime => 'now()'
    });

    my $node_id = $DB->{dbh}->last_insert_id(undef, undef, 'node', 'node_id');

    # Insert podcast-specific data
    $DB->sqlInsert('podcast', {
        podcast_id => $node_id,
        description => 'Test podcast description',
        link => 'https://example.com/test.mp3',
        pubdate => '2026-01-01 00:00:00',
        announcement => 0,
        createdby_user => $author_id
    });

    push @created_podcasts, $node_id;
    return $node_id;
}

sub cleanup_test_data {
    foreach my $rec_id (@created_recordings) {
        $DB->sqlDelete('recording', "recording_id=$rec_id");
        $DB->sqlDelete('node', "node_id=$rec_id");
    }

    foreach my $pod_id (@created_podcasts) {
        # First delete any recordings that belong to this podcast
        $DB->sqlDelete('recording', "appears_in=$pod_id");
        $DB->sqlDelete('podcast', "podcast_id=$pod_id");
        $DB->sqlDelete('node', "node_id=$pod_id");
    }

    @created_recordings = ();
    @created_podcasts = ();
}

END {
    cleanup_test_data();
}

#############################################################################
# Test podcasts update endpoint
#############################################################################

subtest 'podcasts update - guest denied' => sub {
    my $podcast_id = create_test_podcast("Test Podcast Guest " . time());

    my $req = MockRequest->new(
        node_id => $guest_user_id,
        is_guest_flag => 1,
        request_method => 'POST',
        postdata => { title => 'New Title' }
    );
    my $result = $podcasts_api->update($req, $podcast_id);

    ok($result, "Got response");
    is($result->[0], 401, "HTTP 401 Unauthorized for guest");
};

subtest 'podcasts update - podcast not found' => sub {
    my $req = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_admin_flag => 1,
        request_method => 'POST',
        postdata => { title => 'New Title' }
    );
    my $result = $podcasts_api->update($req, 999999999);

    is($result->[1]->{success}, 0, "Request denied for non-existent podcast");
    like($result->[1]->{error}, qr/not found/i, "Error mentions not found");
};

subtest 'podcasts update - permission denied for non-owner' => sub {
    my $podcast_id = create_test_podcast("Test Podcast Perms " . time(), $admin_user->{node_id});

    my $req = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_admin_flag => 0,
        request_method => 'POST',
        postdata => { title => 'New Title' }
    );
    my $result = $podcasts_api->update($req, $podcast_id);

    is($result->[1]->{success}, 0, "Request denied for non-owner");
    like($result->[1]->{error}, qr/permission/i, "Error mentions permission");
};

subtest 'podcasts update - successful title update' => sub {
    my $podcast_id = create_test_podcast("Test Podcast Title " . time(), $admin_user->{node_id});
    my $new_title = "Updated Podcast Title " . time();

    my $req = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_admin_flag => 1,
        nodedata => $admin_user,  # Pass actual user hashref for canUpdateNode
        request_method => 'POST',
        postdata => { title => $new_title }
    );
    my $result = $podcasts_api->update($req, $podcast_id);

    is($result->[1]->{success}, 1, "Request succeeded") or diag("Error: " . ($result->[1]->{error} // 'none'));
    ok(grep { $_ eq 'title' } @{$result->[1]->{updated_fields}}, "Title in updated_fields");

    # Verify in database
    my $db_title = $DB->sqlSelect('title', 'node', "node_id=$podcast_id");
    is($db_title, $new_title, "Title updated in database");
};

subtest 'podcasts update - successful description update' => sub {
    my $podcast_id = create_test_podcast("Test Podcast Desc " . time(), $admin_user->{node_id});
    my $new_description = "New description for podcast " . time();

    my $req = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_admin_flag => 1,
        nodedata => $admin_user,
        request_method => 'POST',
        postdata => { description => $new_description }
    );
    my $result = $podcasts_api->update($req, $podcast_id);

    is($result->[1]->{success}, 1, "Request succeeded") or diag("Error: " . ($result->[1]->{error} // 'none'));
    ok(grep { $_ eq 'description' } @{$result->[1]->{updated_fields}}, "Description in updated_fields");

    # Verify in database
    my $db_desc = $DB->sqlSelect('description', 'podcast', "podcast_id=$podcast_id");
    is($db_desc, $new_description, "Description updated in database");
};

subtest 'podcasts update - successful link update' => sub {
    my $podcast_id = create_test_podcast("Test Podcast Link " . time(), $admin_user->{node_id});
    my $new_link = "https://example.com/updated_" . time() . ".mp3";

    my $req = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_admin_flag => 1,
        nodedata => $admin_user,
        request_method => 'POST',
        postdata => { link => $new_link }
    );
    my $result = $podcasts_api->update($req, $podcast_id);

    is($result->[1]->{success}, 1, "Request succeeded") or diag("Error: " . ($result->[1]->{error} // 'none'));
    ok(grep { $_ eq 'link' } @{$result->[1]->{updated_fields}}, "Link in updated_fields");

    # Verify in database
    my $db_link = $DB->sqlSelect('link', 'podcast', "podcast_id=$podcast_id");
    is($db_link, $new_link, "Link updated in database");
};

subtest 'podcasts update - multiple fields at once' => sub {
    my $podcast_id = create_test_podcast("Test Podcast Multi " . time(), $admin_user->{node_id});
    my $new_title = "Multi-field Update " . time();
    my $new_description = "Multi-field description " . time();
    my $new_link = "https://example.com/multi_" . time() . ".mp3";

    my $req = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_admin_flag => 1,
        nodedata => $admin_user,
        request_method => 'POST',
        postdata => {
            title => $new_title,
            description => $new_description,
            link => $new_link
        }
    );
    my $result = $podcasts_api->update($req, $podcast_id);

    is($result->[1]->{success}, 1, "Request succeeded") or diag("Error: " . ($result->[1]->{error} // 'none'));
    is(scalar @{$result->[1]->{updated_fields}}, 3, "Three fields updated");

    # Verify all in database
    my $db_title = $DB->sqlSelect('title', 'node', "node_id=$podcast_id");
    my $db_desc = $DB->sqlSelect('description', 'podcast', "podcast_id=$podcast_id");
    my $db_link = $DB->sqlSelect('link', 'podcast', "podcast_id=$podcast_id");

    is($db_title, $new_title, "Title updated");
    is($db_desc, $new_description, "Description updated");
    is($db_link, $new_link, "Link updated");
};

subtest 'podcasts update - empty title rejected' => sub {
    my $podcast_id = create_test_podcast("Test Podcast Empty " . time(), $admin_user->{node_id});

    my $req = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_admin_flag => 1,
        nodedata => $admin_user,
        request_method => 'POST',
        postdata => { title => '' }
    );
    my $result = $podcasts_api->update($req, $podcast_id);

    is($result->[1]->{success}, 0, "Empty title rejected");
    like($result->[1]->{error}, qr/empty/i, "Error mentions empty");
};

subtest 'podcasts update - title too long rejected' => sub {
    my $podcast_id = create_test_podcast("Test Podcast Long " . time(), $admin_user->{node_id});
    my $long_title = 'x' x 250;  # More than 240 characters

    my $req = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_admin_flag => 1,
        nodedata => $admin_user,
        request_method => 'POST',
        postdata => { title => $long_title }
    );
    my $result = $podcasts_api->update($req, $podcast_id);

    is($result->[1]->{success}, 0, "Long title rejected");
    like($result->[1]->{error}, qr/long/i, "Error mentions too long");
};

subtest 'podcasts update - no fields to update' => sub {
    my $podcast_id = create_test_podcast("Test Podcast NoFields " . time(), $admin_user->{node_id});

    my $req = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_admin_flag => 1,
        nodedata => $admin_user,
        request_method => 'POST',
        postdata => {}
    );
    my $result = $podcasts_api->update($req, $podcast_id);

    is($result->[1]->{success}, 0, "No fields rejected");
    like($result->[1]->{error}, qr/no fields/i, "Error mentions no fields");
};

#############################################################################
# Test recordings create endpoint
#############################################################################

subtest 'recordings create - guest denied' => sub {
    my $podcast_id = create_test_podcast("Test Podcast RecGuest " . time(), $admin_user->{node_id});

    my $req = MockRequest->new(
        node_id => $guest_user_id,
        is_guest_flag => 1,
        request_method => 'POST',
        postdata => { title => 'Test Recording', appears_in => $podcast_id }
    );
    my $result = $recordings_api->create($req);

    ok($result, "Got response");
    is($result->[0], 401, "HTTP 401 Unauthorized for guest");
};

subtest 'recordings create - missing title' => sub {
    my $podcast_id = create_test_podcast("Test Podcast RecNoTitle " . time(), $admin_user->{node_id});

    my $req = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_admin_flag => 1,
        request_method => 'POST',
        postdata => { appears_in => $podcast_id }
    );
    my $result = $recordings_api->create($req);

    is($result->[1]->{success}, 0, "Missing title rejected");
    like($result->[1]->{error}, qr/title.*required/i, "Error mentions title required");
};

subtest 'recordings create - missing appears_in' => sub {
    my $req = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_admin_flag => 1,
        request_method => 'POST',
        postdata => { title => 'Test Recording' }
    );
    my $result = $recordings_api->create($req);

    is($result->[1]->{success}, 0, "Missing appears_in rejected");
    like($result->[1]->{error}, qr/appears_in.*required/i, "Error mentions appears_in required");
};

subtest 'recordings create - podcast not found' => sub {
    my $req = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_admin_flag => 1,
        request_method => 'POST',
        postdata => { title => 'Test Recording', appears_in => 999999999 }
    );
    my $result = $recordings_api->create($req);

    is($result->[1]->{success}, 0, "Non-existent podcast rejected");
    like($result->[1]->{error}, qr/podcast.*not found/i, "Error mentions podcast not found");
};

subtest 'recordings create - permission denied for non-owner' => sub {
    my $podcast_id = create_test_podcast("Test Podcast RecPerms " . time(), $admin_user->{node_id});

    my $req = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_admin_flag => 0,
        request_method => 'POST',
        postdata => { title => 'Test Recording', appears_in => $podcast_id }
    );
    my $result = $recordings_api->create($req);

    is($result->[1]->{success}, 0, "Permission denied for non-owner");
    like($result->[1]->{error}, qr/permission/i, "Error mentions permission");
};

subtest 'recordings create - successful creation' => sub {
    my $podcast_id = create_test_podcast("Test Podcast RecCreate " . time(), $admin_user->{node_id});
    my $recording_title = "Test Recording " . time();

    my $req = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_admin_flag => 1,
        nodedata => $admin_user,
        request_method => 'POST',
        postdata => { title => $recording_title, appears_in => $podcast_id }
    );
    my $result = $recordings_api->create($req);

    is($result->[1]->{success}, 1, "Recording created") or diag("Error: " . ($result->[1]->{error} // 'none'));
    ok($result->[1]->{node_id}, "Got node_id");
    is($result->[1]->{title}, $recording_title, "Title matches");
    is($result->[1]->{appears_in}, $podcast_id, "appears_in matches");

    # Track for cleanup
    push @created_recordings, $result->[1]->{node_id} if $result->[1]->{node_id};

    # Verify in database
    my $rec_id = $result->[1]->{node_id};
    if ($rec_id) {
        my $db_title = $DB->sqlSelect('title', 'node', "node_id=$rec_id");
        my $db_appears = $DB->sqlSelect('appears_in', 'recording', "recording_id=$rec_id");

        is($db_title, $recording_title, "Title in database");
        is($db_appears, $podcast_id, "appears_in in database");
    }
};

subtest 'recordings create - title too long rejected' => sub {
    my $podcast_id = create_test_podcast("Test Podcast RecLong " . time(), $admin_user->{node_id});
    my $long_title = 'x' x 70;  # More than 64 characters

    my $req = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_admin_flag => 1,
        nodedata => $admin_user,
        request_method => 'POST',
        postdata => { title => $long_title, appears_in => $podcast_id }
    );
    my $result = $recordings_api->create($req);

    is($result->[1]->{success}, 0, "Long title rejected");
    like($result->[1]->{error}, qr/too long/i, "Error mentions too long");
};

done_testing();
