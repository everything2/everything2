#!/usr/bin/perl -w

use strict;
use utf8;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching RequireDotMatchAnything)
## no critic (ValuesAndExpressions ProhibitInterpolationOfLiterals ProhibitMagicNumbers)

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;
use Everything::Application;

binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

# Suppress expected warnings
$SIG{__WARN__} = sub {
    my $warning = shift;
    warn $warning unless $warning =~ /Could not open log/
                      || $warning =~ /Use of uninitialized value/;
};

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

subtest 'Short text (no truncation needed)' => sub {
    plan tests => 3;

    # Create a mock node with short text
    my $node = {
        type => { title => 'writeup' },
        doctext => 'This is a short writeup with some text.'
    };

    my $result = $APP->metaDescription($node);
    ok($result, 'Generated meta description');
    like($result, qr/This is a short writeup with some text\./, 'Short text preserved without truncation');
    unlike($result, qr/\.\.\.$/, 'Short text does not have ellipsis');
};

subtest 'Long text (truncates at word boundary)' => sub {
    plan tests => 4;

    # Create a mock node with long text
    my $long_text = 'The Everything Development Company was founded in 1998 by a group of developers who wanted to create a collaborative writing platform. The site has grown to include nearly half a million pieces of original writing across multiple genres including fiction, nonfiction, poetry, and reviews.';

    my $node = {
        type => { title => 'writeup' },
        doctext => $long_text
    };

    my $result = $APP->metaDescription($node);
    ok($result, 'Generated meta description');

    # Extract content from meta tag
    my ($content) = $result =~ /content="([^"]+)"/;
    ok($content, 'Extracted content attribute');
    like($content, qr/\.\.\.$/, 'Long text ends with ellipsis');
    # Content should end with a complete word followed by ellipsis (no space between)
    # Pattern: word boundary, then word characters, then ellipsis
    like($content, qr/\b\w+\.\.\.$/, 'Ends with complete word followed by ellipsis');
};

subtest 'HTML tags stripped' => sub {
    plan tests => 2;

    my $node = {
        type => { title => 'writeup' },
        doctext => '<p>This is a <strong>writeup</strong> with <em>HTML tags</em> that should be stripped.</p>'
    };

    my $result = $APP->metaDescription($node);
    ok($result, 'Generated meta description');
    like($result, qr/This is a writeup with HTML tags that should be stripped/, 'HTML tags removed');
};

subtest 'E2 link syntax processed correctly' => sub {
    plan tests => 3;

    my $node = {
        type => { title => 'writeup' },
        doctext => 'I like to visit [Boston|my city], because of the [North End]. Also see [Cambridge|the other city].'
    };

    my $result = $APP->metaDescription($node);
    ok($result, 'Generated meta description');

    # Extract content from meta tag
    my ($content) = $result =~ /content="([^"]+)"/;
    like($content, qr/I like to visit my city, because of the North End/,
        'Soft links use display text (after pipe)');
    like($content, qr/Also see the other city/,
        'All soft link display text preserved');
};

subtest 'Fallback for no content' => sub {
    plan tests => 2;

    my $node = {
        type => { title => 'e2node' },
        group => []  # No writeups
    };

    my $result = $APP->metaDescription($node);
    ok($result, 'Generated meta description');
    like($result, qr/Everything2 is a community/, 'Fallback text used for empty node');
};

done_testing();
