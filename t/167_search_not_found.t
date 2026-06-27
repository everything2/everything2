#!/usr/bin/perl
# Regression for #4382 (Tem42): "Can't search for nodes that don't exist".
#
# not_found_node pointed at a tombed node (668164, the "Nothing Found" superdoc, removed in
# #1801) for ~3 years. A search with no exact and no fuzzy match did
# getNodeById(668164) -> undef -> displayPage(undef) -> die "NO NODE!" -> HTTP 500. The bot
# storm (constant random-string searches) made it a recurring 500 that was invisible to
# e2-app-errors (PSGI-wrapper-caught, not $SIG-logged). Fix: not_found_node now resolves to
# search_results (the Findings page), which renders the no-results case ("We couldn't find
# anything for ..."). This test guards the live HTTP path; it SKIPs if the app is unreachable.
use strict;
use warnings;
use Test::More;

SKIP: {
    eval { require LWP::UserAgent; 1 } or skip 'LWP::UserAgent unavailable', 1;
    my $ua = LWP::UserAgent->new( timeout => 20 );

    # A title with no exact match and no fuzzy match -> the not-found path that used to die.
    my $resp = eval { $ua->get('http://localhost/title/xqzwvk123zznope4382') };
    skip 'app unreachable', 1 unless $resp;

    isnt( $resp->code, 500, 'no-match search does NOT 500 (#4382)' );
    is(   $resp->code, 200, 'no-match search returns 200' );
    unlike( $resp->content, qr/NO NODE/,      'no "NO NODE!" die in the response' );
    unlike( $resp->content, qr/caught a die/, 'no PSGI-wrapper die message' );
    like(   $resp->content, qr/"type":\s*"findings"/,
            'routed to the Findings page (contentData type=findings), not a phantom node' );

    # A non-existent node_id must ALSO render the not-found page, not 500: gotoNode's
    # fallback seeds Findings: with the id + an empty result set instead of passing undef
    # to displayPage, and displayPage now falls back defensively rather than dying.
    my $resp2 = eval { $ua->get('http://localhost/?node_id=999999999') };
    if ($resp2) {
        isnt( $resp2->code, 500, 'non-existent node_id does NOT 500 (#4382)' );
        is(   $resp2->code, 200, 'non-existent node_id returns 200' );
        unlike( $resp2->content, qr/NO NODE/, 'no "NO NODE!" die for a bad node_id' );
        like(   $resp2->content, qr/"type":\s*"findings"/,
                'bad node_id routes to the Findings not-found page' );
    }
}

done_testing;
