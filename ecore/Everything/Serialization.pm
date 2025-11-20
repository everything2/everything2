#!/usr/bin/perl -w

use strict;
use warnings;

package Everything::Serialization;

#############################################################################
#
# Everything::Serialization
#
# Safe deserialization utilities for legacy data
#
# This module provides safe alternatives to eval() for deserializing
# legacy Perl data structures stored in Data::Dumper format in the database.
#
#############################################################################

use Safe;
use Opcode qw(opset opdesc full_opset);
use Exporter 'import';

our @EXPORT_OK = qw(safe_deserialize_dumper);

#############################################################################
# safe_deserialize_dumper
#
# Safely deserialize Data::Dumper format data using Safe compartment
#
# Arguments:
#   $data - String containing Perl code in Data::Dumper format
#           (e.g., "$VAR1 = { ... };" or "my $VAR1 = { ... };")
#
# Returns:
#   Hashref containing the deserialized data, or undef on error
#
# This uses Safe.pm to evaluate the data in a restricted compartment
# with only safe operations allowed (no system calls, file I/O, etc.)
#############################################################################

sub safe_deserialize_dumper
{
    my ($data) = @_;

    return unless defined $data;
    return unless length($data) > 0;

    # Create a restricted Safe compartment
    my $compartment = Safe->new();

    # Start with full operation set, then deny dangerous operations
    # This is more maintainable than trying to permit every needed operation
    my $opset = full_opset();

    # Deny dangerous operations: system calls, exec, file I/O, etc.
    $opset = opset(':dangerous', qw(
        syscall
        backtick
        system
        exec
        fork
        wait
        waitpid
        glob
        require
        dofile
        entereval
    ));

    $compartment->deny_only($opset);

    # Prepare the code for evaluation
    # Data::Dumper format is typically: $VAR1 = { ... };
    # We want to return the value, so wrap it appropriately
    my $code = $data;

    # If the data doesn't start with 'my', prepend it for lexical scope
    unless ($code =~ /^\s*my\s+/) {
        $code = "my $code";
    }

    # Ensure we return the value
    # Look for $VAR1 or similar variable and return it
    if ($code =~ /\$(\w+)\s*=/) {
        my $varname = $1;
        $code .= "\n\$$varname;";
    }

    # Evaluate in the safe compartment
    my $result = $compartment->reval($code);

    if ($@) {
        warn "Safe deserialization failed: $@\n";
        return;
    }

    return $result;
}

1;
