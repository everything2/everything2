#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching RequireDotMatchAnything)
## no critic (ValuesAndExpressions ProhibitInterpolationOfLiterals ProhibitMagicNumbers)

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "$FindBin::Bin/lib";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;
use Everything::Application;
use Everything::API::preferences;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

#############################################################################
# Preferences API - the single source of truth for user-VARS preference
# get/set. Consolidates the former t/029 and t/057 (which overlapped heavily)
# onto the shared MockRequest/MockUser lib.
#
# Covers:
#   - GET defaults (guest + authenticated)
#   - SET validation: whitelisted keys + per-key value validation
#   - Authorization: guests blocked from SET
#   - Default/empty handling deletes the VARS key
#   - Multiple preferences in one request
#   - Bad-request shapes (empty / non-hash / array)
#   - nodeletusergroup (the Usergroup Writeups nodelet group selector that
#     replaced the changeusergroup opcode, #4312)
#############################################################################

my $test_user = $DB->getNode("e2e_user", "user");
ok($test_user, "Got test user (e2e_user)");

my $api = Everything::API::preferences->new();
ok($api, "Created preferences API instance");

# Convenience constructors over the shared MockRequest lib.
sub auth_request {
    my (%args) = @_;
    return MockRequest->new(
        node_id       => $test_user->{node_id},
        title         => $test_user->{title},
        nodedata      => $test_user,
        is_guest_flag => 0,
        vars          => $args{vars} // {},
        postdata      => $args{postdata} // {},
    );
}

sub guest_request {
    my (%args) = @_;
    return MockRequest->new(
        node_id       => 0,
        title         => 'Guest User',
        is_guest_flag => 1,
        postdata      => $args{postdata} // {},
    );
}

#############################################################################
# Guest: GET returns defaults
#############################################################################

subtest 'Guest GET returns all preferences with defaults' => sub {
    plan tests => 6;

    my $result = $api->get_preferences(guest_request());
    is($result->[0], $api->HTTP_OK, "GET returns 200");
    is(ref($result->[1]), 'HASH', "GET returns a hash");
    is($result->[1]{vit_hidenodeinfo}, 0, "List pref defaults to 0");
    is($result->[1]{num_newwus}, 15, "num_newwus defaults to 15");
    is($result->[1]{collapsedNodelets}, '', "String pref defaults to ''");
    is($result->[1]{nodeletusergroup}, '', "nodeletusergroup defaults to ''");
};

#############################################################################
# Guest: SET blocked
#############################################################################

subtest 'Guest cannot SET preferences' => sub {
    plan tests => 2;

    my $r1 = $api->set_preferences(guest_request(postdata => { vit_hidenodeinfo => 1 }));
    is($r1->[0], $api->HTTP_UNAUTHORIZED, "Guest set List pref rejected (401 via around modifier)");

    my $r2 = $api->set_preferences(guest_request(postdata => { collapsedNodelets => "epicenter!" }));
    is($r2->[0], $api->HTTP_UNAUTHORIZED, "Guest set String pref rejected (401 via around modifier)");
};

#############################################################################
# Authenticated: SET valid + persistence
#############################################################################

subtest 'Authenticated SET updates and persists VARS' => sub {
    plan tests => 5;

    my $req = auth_request(postdata => { vit_hidenodeinfo => 1, num_newwus => 30, collapsedNodelets => "test!" });
    my $result = $api->set_preferences($req);
    is($result->[0], $api->HTTP_OK, "SET returns 200");
    is($result->[1]{vit_hidenodeinfo}, 1, "List value returned");
    is($result->[1]{num_newwus}, 30, "Enumerated value returned");
    is($result->[1]{collapsedNodelets}, "test!", "String value returned");

    my $get = $api->get_preferences($req);
    is($get->[1]{num_newwus}, 30, "Value persisted across GET");
};

#############################################################################
# Validation
#############################################################################

subtest 'SET rejects invalid keys and values' => sub {
    plan tests => 4;

    my $bad_key = auth_request(postdata => { not_a_real_preference => 1 });
    is($api->set_preferences($bad_key)->[1]{success}, 0, "Unknown key rejected (200+success:0)");
    ok(!exists($bad_key->user->VARS->{not_a_real_preference}), "Unknown key not written to VARS");

    is($api->set_preferences(auth_request(postdata => { num_newwus => 999 }))->[1]{success}, 0, "Out-of-range enumerated value rejected (200+success:0)");

    is($api->set_preferences(auth_request(postdata => { vit_hidenodeinfo => "badvalue", vit_hidemisc => 0 }))->[1]{success}, 0, "Mixed valid/invalid rejected (200+success:0)");
};

#############################################################################
# Default / empty deletes the VARS key
#############################################################################

subtest 'Setting a List pref to its default deletes it from VARS' => sub {
    plan tests => 3;

    my $req = auth_request(vars => { num_newwus => 25 }, postdata => { num_newwus => 15 });
    ok(exists($req->user->VARS->{num_newwus}), "Pref present before SET");
    is($api->set_preferences($req)->[0], $api->HTTP_OK, "SET returns 200");
    ok(!exists($req->user->VARS->{num_newwus}), "Pref deleted when set to default");
};

subtest 'Setting a String pref to empty deletes it from VARS' => sub {
    plan tests => 3;

    my $req = auth_request(vars => { collapsedNodelets => "epicenter!" }, postdata => { collapsedNodelets => "" });
    ok(exists($req->user->VARS->{collapsedNodelets}), "Pref present before SET");
    is($api->set_preferences($req)->[0], $api->HTTP_OK, "SET returns 200");
    ok(!exists($req->user->VARS->{collapsedNodelets}), "Pref deleted when set to empty");
};

#############################################################################
# Multiple preferences in one request
#############################################################################

subtest 'SET handles multiple preferences in one request' => sub {
    plan tests => 4;

    my $req = auth_request(postdata => { vit_hidenodeinfo => 1, vit_hidemaintenance => 1, num_newwus => 20 });
    my $result = $api->set_preferences($req);
    is($result->[0], $api->HTTP_OK, "SET returns 200");
    is($result->[1]{vit_hidenodeinfo}, 1, "First pref set");
    is($result->[1]{vit_hidemaintenance}, 1, "Second pref set");
    is($req->user->VARS->{num_newwus}, 20, "VARS updated for enumerated pref");
};

#############################################################################
# Bad-request shapes
#############################################################################

subtest 'SET rejects bad request shapes' => sub {
    plan tests => 3;

    is($api->set_preferences(auth_request(postdata => {}))->[1]{success}, 0, "Empty hash rejected (200+success:0)");
    is($api->set_preferences(auth_request(postdata => "not a hash"))->[1]{success}, 0, "Non-hash rejected (200+success:0)");
    is($api->set_preferences(auth_request(postdata => []))->[1]{success}, 0, "Array rejected (200+success:0)");
};

#############################################################################
# nodeletusergroup (Usergroup Writeups nodelet selector; replaced
# the changeusergroup opcode, #4312)
#############################################################################

subtest 'nodeletusergroup is a whitelisted, bounded String preference' => sub {
    plan tests => 7;

    # Valid title set + persisted
    my $set = auth_request(postdata => { nodeletusergroup => "E2science" });
    my $set_result = $api->set_preferences($set);
    is($set_result->[0], $api->HTTP_OK, "Valid title accepted (200)");
    is($set_result->[1]{nodeletusergroup}, "E2science", "Returned value matches");
    is($set->user->VARS->{nodeletusergroup}, "E2science", "Title written to VARS");

    # Empty string clears it (revert to default group)
    my $clear = auth_request(vars => { nodeletusergroup => "E2science" },
                             postdata => { nodeletusergroup => "" });
    is($api->set_preferences($clear)->[0], $api->HTTP_OK, "Empty value accepted (200)");
    ok(!exists($clear->user->VARS->{nodeletusergroup}), "Empty value clears the pref");

    # Over-length (>80) rejected
    my $toolong = auth_request(postdata => { nodeletusergroup => ("x" x 81) });
    is($api->set_preferences($toolong)->[1]{success}, 0, "Over-length title rejected (200+success:0)");

    # Embedded newline rejected (titles are single-line)
    my $newline = auth_request(postdata => { nodeletusergroup => "E2science\ninjected" });
    is($api->set_preferences($newline)->[1]{success}, 0, "Newline-bearing title rejected (200+success:0)");
};

#############################################################################
# EDD_Sort (everything_document_directory sort pref; replaced the render-time
# $VARS->{EDD_Sort}= side-effect in the page controller, #4416)
#############################################################################

subtest 'EDD_Sort is a whitelisted, enum-validated String preference' => sub {
    plan tests => 6;

    my $set = auth_request(postdata => { EDD_Sort => 'nameA' });
    my $r = $api->set_preferences($set);
    is($r->[0], $api->HTTP_OK, "Valid sort accepted (200)");
    is($r->[1]{EDD_Sort}, 'nameA', "Returned value matches");
    is($set->user->VARS->{EDD_Sort}, 'nameA', "Written to VARS");

    # Out-of-enum value rejected
    is($api->set_preferences(auth_request(postdata => { EDD_Sort => 'bogus' }))->[1]{success}, 0, "Out-of-enum sort rejected (200+success:0)");

    # Trailing-newline injection rejected (\z anchor, not $)
    is($api->set_preferences(auth_request(postdata => { EDD_Sort => "nameA\ninjected" }))->[1]{success}, 0, "Newline-injected sort rejected (200+success:0)");

    # Guest blocked
    is($api->set_preferences(guest_request(postdata => { EDD_Sort => 'nameA' }))->[0], $api->HTTP_UNAUTHORIZED, "Guest cannot set EDD_Sort (401 via around modifier)");
};

#############################################################################
# ListNodesOfType_Type (list_nodes_of_type selected-type pref; replaced the
# render-time ?setvars_ListNodesOfType_Type side-effect AND the React's dead
# POST to /api/preferences/update, #4416)
#############################################################################

subtest 'ListNodesOfType_Type is a whitelisted node_id String preference' => sub {
    plan tests => 5;

    my $set = auth_request(postdata => { ListNodesOfType_Type => '14' });
    my $r = $api->set_preferences($set);
    is($r->[0], $api->HTTP_OK, "Valid type node_id accepted (200)");
    is($set->user->VARS->{ListNodesOfType_Type}, '14', "Written to VARS");

    # A type NAME (the old achievement/notification deep-links) is non-numeric -> rejected
    is($api->set_preferences(auth_request(postdata => { ListNodesOfType_Type => 'achievement' }))->[1]{success}, 0, "Non-numeric type value rejected (200+success:0)");

    # Trailing-newline injection rejected (\z anchor)
    is($api->set_preferences(auth_request(postdata => { ListNodesOfType_Type => "14\ninjected" }))->[1]{success}, 0, "Newline-injected value rejected (200+success:0)");

    # Guest blocked
    is($api->set_preferences(guest_request(postdata => { ListNodesOfType_Type => '14' }))->[0], $api->HTTP_UNAUTHORIZED, "Guest cannot set ListNodesOfType_Type (401 via around modifier)");
};

#############################################################################
# customstyle (style_defacer custom CSS; replaced the render-time ?vandalism
# side-effect, #4416). Length-capped at 50000 (real storage fix is #4417).
#############################################################################

subtest 'customstyle is a whitelisted, length-capped (50000) String preference' => sub {
    plan tests => 6;

    my $css = 'a { color: #ff6600; }';
    my $set = auth_request(postdata => { customstyle => $css });
    my $r = $api->set_preferences($set);
    is($r->[0], $api->HTTP_OK, "Valid CSS accepted (200)");
    is($set->user->VARS->{customstyle}, $css, "Written to VARS");

    # Multi-line CSS accepted (the /s flag lets `.` span newlines)
    my $multi = "a { color: red; }\nbody { background: #111; }";
    is($api->set_preferences(auth_request(postdata => { customstyle => $multi }))->[0],
        $api->HTTP_OK, "Multi-line CSS accepted (200)");

    # Over the 50000-char cap -> rejected
    is($api->set_preferences(auth_request(postdata => { customstyle => ('x' x 50001) }))->[1]{success}, 0, "Over-cap CSS rejected (200+success:0)");

    # Empty clears it (matches the old "clear the field to remove styles")
    my $clear = auth_request(vars => { customstyle => $css }, postdata => { customstyle => '' });
    $api->set_preferences($clear);
    ok(!exists($clear->user->VARS->{customstyle}), "Empty value clears the pref");

    # Guest blocked
    is($api->set_preferences(guest_request(postdata => { customstyle => $css }))->[0], $api->HTTP_UNAUTHORIZED, "Guest cannot set customstyle (401 via around modifier)");
};

done_testing();
