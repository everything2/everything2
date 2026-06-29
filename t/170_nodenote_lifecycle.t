#!/usr/bin/perl -w
# Everything::Application::nodenote_is_lifecycle (#4389) -- classifies
# auto-generated lifecycle breadcrumbs (publish/unpublish/remove/insure/create/
# review) vs genuine editorial feedback, so Recent Node Notes can hide/badge the
# noise. The breadcrumbs are attributed to the acting user, so the plain
# "noter_user != 0" system filter misses them; this classifier catches them.
use strict;
use warnings;

## no critic (RegularExpressions ValuesAndExpressions ProhibitInterpolationOfLiterals)

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;

initEverything('development-docker');
ok($APP, 'Application object created');

# --- Auto-generated lifecycle breadcrumbs -> lifecycle (mirror the
#     addNodeNote/add_nodenote call sites in drafts/admin/maintenance) ---
my @lifecycle = (
    'Published from draft',
    'Republished writeup by SomeAuthor',
    'Returned to drafts',
    'Returned to drafts by author',
    'Removed: spam',
    'Removed by root: duplicate',
    'Insured',
    'Uninsured',
    'Created by [bob[user]]',
    'author requested review',
);
ok($APP->nodenote_is_lifecycle($_), "lifecycle breadcrumb: $_") for @lifecycle;

# --- Genuine editorial feedback -> NOT lifecycle ---
my @editorial = (
    'Needs a stronger lede.',
    'Great writeup -- fixed a typo for you.',
    'Please add sources before this can be published.',
    'I published this myself, looks good',   # mentions publish but is prose
);
ok(!$APP->nodenote_is_lifecycle($_), "editorial feedback: $_") for @editorial;

ok(!$APP->nodenote_is_lifecycle(undef), 'undef notetext is not lifecycle (no warning)');
ok(!$APP->nodenote_is_lifecycle(''),    'empty notetext is not lifecycle');

# --- SQL companion used for paged filtering ---
my $sql = $APP->nodenote_editorial_sql;
like($sql, qr/notetext NOT REGEXP/, 'editorial SQL excludes via NOT REGEXP');
like($sql, qr/Published from draft/, 'editorial SQL references the breadcrumb patterns');

done_testing;
