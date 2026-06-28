#!/usr/bin/perl -w
# PageState::_build_user role flags (#4390).
#
# Guards the developer-flag quirk: _build_user used to emit `developer => ... ? \1 : \1`,
# i.e. user.developer was ALWAYS true, so every developer-gated React control showed to
# everyone. This test renders _build_user for a NON-developer and asserts user.developer is
# false -- it FAILS against the old `? \1 : \1` and passes after the `: \0` fix.
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use Test::More;
use Everything;
use Everything::PageState;

initEverything('development-docker');
plan skip_all => 'no DB' unless $DB && $APP;

# normaluser1: a plain member -- not a developer, not an admin, not a guest.
my $normal = $DB->getNode('normaluser1', 'user');
plan skip_all => 'normaluser1 not present' unless $normal;
my $VARS = $APP->getVars($normal);

my $user = Everything::PageState->_build_user($APP, $normal, $VARS);
ok($user, '_build_user returned a user hash');

# The flags are JSON-boolean scalar refs (\0 / \1); deref to compare.
is(${ $user->{developer} }, 0, 'non-developer: user.developer is FALSE (#4390 quirk: was always-true)');
is(${ $user->{admin} },     0, 'normal user: user.admin is false');
is(${ $user->{editor} },    0, 'normal user: user.editor is false');
is(${ $user->{guest} },     0, 'logged-in user: user.guest is false');

done_testing;
