#!/usr/bin/perl -w

use strict;
use warnings;

# Simple utility to extract a field from a nodepack XML file
# Usage: extract-nodepack-field.pl <xml_file> <field_name>

if (@ARGV != 2) {
    print STDERR "Usage: $0 <xml_file> <field_name>\n";
    print STDERR "Example: $0 nodepack/superdoc/foo.xml doctext\n";
    exit 1;
}

my ($xml_file, $field_name) = @ARGV;

unless (-f $xml_file) {
    print STDERR "Error: File '$xml_file' not found\n";
    exit 1;
}

# Read the entire file
open my $fh, '<', $xml_file or die "Cannot open $xml_file: $!\n";
my $content = do { local $/; <$fh> };
close $fh;

# Decode XML entities
sub decode_entities {
    my $text = shift;

    # Decode common XML entities
    $text =~ s/&lt;/</g;
    $text =~ s/&gt;/>/g;
    $text =~ s/&quot;/"/g;
    $text =~ s/&apos;/'/g;
    $text =~ s/&#(\d+);/chr($1)/ge;        # Numeric entities (decimal)
    $text =~ s/&#x([0-9a-fA-F]+);/chr(hex($1))/ge;  # Numeric entities (hex)
    $text =~ s/&amp;/&/g;  # Must be last to avoid double-decoding

    return $text;
}

# Extract the field using a simple regex
# Nodepack XML structure is: <field_name>content</field_name>
# We need to handle both single-line and multi-line content
if ($content =~ m{<$field_name>(.*?)</$field_name>}s) {
    my $field_content = $1;
    print decode_entities($field_content);
} else {
    # Field not found or empty - exit silently (common case for empty fields)
    exit 0;
}
