#!/usr/bin/perl -w
#
# Smoke test: Accept-Encoding -> correct compression type -> correct S3 asset link.
#
# S3 can't content-negotiate, so the app must bake the pre-compressed variant
# (/zstd/, /br/, /deflate/, /gzip/, or none) into the CSS/JS *shell links* based
# on the request's Accept-Encoding. This is the half of the compression story
# that survived the PSGI offload: the app no longer compresses the response
# *body* (Apache does that at the edge), but it still must KNOW the encoding to
# emit the right asset URL. Regressing this serves, e.g., a br-encoded stylesheet
# to a client that only accepts gzip -> broken CSS. This pins the mapping.
#
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "$FindBin::Bin/lib";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;

initEverything('development-docker');

# [ Accept-Encoding header, expected compression type ]. best_compression_type
# prefers zstd > br > deflate > gzip and takes the first token PRESENT in the
# header (no q-value weighting -- that's the existing contract, pinned here).
my @cases = (
    [ 'gzip, deflate, br, zstd', 'zstd' ],
    [ 'gzip, deflate, br',       'br' ],
    [ 'gzip, deflate',           'deflate' ],
    [ 'gzip',                    'gzip' ],
    [ 'br',                      'br' ],
    [ 'zstd',                    'zstd' ],
    [ 'identity',                undef ],
    [ '',                        undef ],
);

# --- 1. best_compression_type: the AE -> type decision (config-independent) ---
for my $c (@cases) {
    my ( $ae, $want ) = @$c;
    local $ENV{HTTP_ACCEPT_ENCODING} = $ae;
    is( $APP->best_compression_type, $want,
        "best_compression_type('$ae') => " . ( $want // 'undef' ) );
}

# --- 2. asset_uri in S3 mode: the type must land as the path segment ---
# Force use_local_assets off so we exercise the prod path regardless of the dev
# config (dev runs local assets). Override the accessor for the duration.
my $loc = $Everything::CONF->assets_location;
{
    no warnings 'redefine';
    local *Everything::Configuration::use_local_assets = sub { 0 };

    for my $c (@cases) {
        my ( $ae, $type ) = @$c;
        local $ENV{HTTP_ACCEPT_ENCODING} = $ae;
        my $uri  = $APP->asset_uri('css/foo.css');
        my $want = defined $type ? "$loc/$type/css/foo.css" : "$loc/css/foo.css";
        is( $uri, $want,
            "asset_uri(css) for '$ae' => " . ( defined $type ? "/$type/ variant" : 'uncompressed' ) );
    }

    # A .js asset rides the same path; sanity-check one to catch ext-specific drift.
    local $ENV{HTTP_ACCEPT_ENCODING} = 'gzip, br';
    is( $APP->asset_uri('react/bundle.js'), "$loc/br/bundle.js",
        'asset_uri(js) strips react/ and applies the br S3 prefix' );
}

# --- 3. asset_uri in local-assets mode (dev): never an S3 / compression link ---
{
    no warnings 'redefine';
    local *Everything::Configuration::use_local_assets = sub { 1 };
    local $ENV{HTTP_ACCEPT_ENCODING} = 'br';
    is( $APP->asset_uri('css/foo.css'), '/css/css/foo.css',
        'asset_uri local mode => local path, no compression prefix' );
}

done_testing();
