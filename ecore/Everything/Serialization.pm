#!/usr/bin/perl -w

use strict;
use warnings;

package Everything::Serialization;

#############################################################################
#
# Everything::Serialization
#
# Reading back legacy data stored as Data::Dumper output (the tomb copies
# nukeNode writes, and the heaven table).
#
#############################################################################

use Safe;
use Exporter 'import';

our @EXPORT_OK = qw(safe_deserialize_dumper);

# Data::Dumper output only builds data: constants, anonymous hashes and arrays, references,
# element reads/assignments (for $VAR1->{...} back-references), lexical variables, and bless.
# The compartment permits exactly those operations and nothing else, so anything beyond plain
# data fails to compile instead of running.
my @PERMITTED = (':base_core', ':base_mem', qw(padany srefgen refgen bless));

# :base_core also carries calling subs and methods and regex matching; plain data needs neither.
my @DENIED = qw(
    entersub leavesub leavesublv rv2cv anoncode anonconst prototype coreargs
    method method_named method_super method_redir method_redir_super
    match qr split
);

#############################################################################
# safe_deserialize_dumper
#
# Arguments:
#   $data - Data::Dumper output ("$VAR1 = { ... };" or "my $VAR1 = { ... };")
#
# Returns:
#   The rebuilt data structure, or undef if it is empty or not plain Dumper data
#############################################################################

sub safe_deserialize_dumper
{
    my ($data) = @_;

    return unless defined $data;
    return unless length($data) > 0;

    my $compartment = Safe->new();
    $compartment->permit_only(@PERMITTED);
    $compartment->deny(@DENIED);

    my $code = $data;

    # Data::Dumper writes any code reference as this placeholder: there was never code to rebuild
    # (old htmlcode copies carry a cached compiledCode), so it reads back as undef.
    $code =~ s/(=>\s*)sub \{ "DUMMY" \}(?=\s*[,}\]])/${1}undef/g;

    # A copy stored in Dumper's terse form is a bare { ... } / [ ... ] with no "$VAR1 =".
    # Callers prefix "my ", so drop that and assign it.
    if ($code =~ s/^\s*(?:my\s+)?(?=[\{\[])/my \$VAR1 = /) {
        $code =~ s/;?\s*\z/;/;
    }

    # Evaluate in lexical scope
    unless ($code =~ /^\s*my\s+/) {
        $code = "my $code";
    }

    # Return the assigned variable ($VAR1)
    if ($code =~ /\$(\w+)\s*=/) {
        my $varname = $1;
        $code .= "\n\$$varname;";
    }

    my $result = $compartment->reval($code);

    if ($@) {
        warn "Safe deserialization failed: $@\n";
        return;
    }

    return $result;
}

1;
