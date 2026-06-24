#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions ProhibitMagicNumbers ProhibitInterpolationOfLiterals)

#############################################################################
# 160_warn_handler_and_getvars.t
#
# Two uninitialized-value cleanups:
#
#  1. Application::_warning_is_suppressed -- the global warn handler now drops
#     purely-third-party library noise (Starman's chunked-input reader checking
#     an uninitialized {inputbuf}, Server.pm "inputbuf ne ''") off the
#     uninitialized EventBridge bus, while still surfacing our own warnings.
#
#  2. Application::getVars -- its "vars field does not exist" diagnostic used to
#     concatenate an undef getId() (warning in its own right when called on an
#     incomplete node). It now guards the id, so getVars on a vars-less node
#     returns {} without itself emitting an uninitialized-value warning.
#############################################################################

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;
use Everything::Application;

initEverything('development-docker');
my $APP = $Everything::APP;
ok($APP, 'Application object created');

#############################################################################
# 1. _warning_is_suppressed
#############################################################################
ok(
    $APP->_warning_is_suppressed(
        'Use of uninitialized value in string ne at /var/libraries/lib/perl5/Starman/Server.pm line 408.'
    ),
    'Starman inputbuf library noise is suppressed'
);

ok(
    !$APP->_warning_is_suppressed(
        'Use of uninitialized value in concatenation (.) at /var/everything/ecore/Everything/Application.pm line 4204.'
    ),
    'our own (app-code) uninitialized warning is NOT suppressed'
);

ok(
    !$APP->_warning_is_suppressed(
        'Use of uninitialized value at /var/libraries/lib/perl5/Some/Other.pm line 1.'
    ),
    'an uninitialized warning from a different library is NOT suppressed (only the known Starman one)'
);

ok( !$APP->_warning_is_suppressed('Some unrelated warning'), 'unrelated warnings are not suppressed' );
ok( !$APP->_warning_is_suppressed(undef),                    'undef warning is handled safely' );

#############################################################################
# 2. getVars on an incomplete node: returns {} and emits no uninitialized warning
#############################################################################
{
    my @warns;
    local $SIG{__WARN__} = sub { push @warns, $_[0] };

    # A bare hashref with neither node_id nor vars -- exercises the guarded
    # diagnostic path. Should not die and should not warn "uninitialized".
    my $vars = $APP->getVars({});
    is_deeply( $vars, {}, 'getVars on a vars-less node returns an empty hashref' );

    my @uninit = grep { /uninitialized value/ } @warns;
    is( scalar(@uninit), 0, 'getVars on an incomplete node emits no uninitialized-value warning' )
        or diag("unexpected: @uninit");
}

done_testing();
