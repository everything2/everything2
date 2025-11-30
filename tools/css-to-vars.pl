#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename;

# Script to help convert CSS files to CSS variable versions
# Usage: ./tools/css-to-vars.pl www/css/NODEID.css

my $input_file = $ARGV[0] or die "Usage: $0 <css-file>\n";

open(my $fh, '<', $input_file) or die "Cannot open $input_file: $!\n";
my @lines = <$fh>;
close($fh);

# Extract all unique hex colors
my %colors;
foreach my $line (@lines) {
    while ($line =~ /#([0-9a-fA-F]{3,6})\b/g) {
        my $color = "#" . lc($1);
        # Normalize 3-digit hex to 6-digit
        if (length($1) == 3) {
            $color = "#" . join('', map { $_ x 2 } split(//, $1));
        }
        $colors{$color}++;
    }
}

# Sort by frequency (most common first)
my @sorted_colors = sort { $colors{$b} <=> $colors{$a} } keys %colors;

print "Found " . scalar(@sorted_colors) . " unique colors:\n\n";
print "Color       | Count | Suggested Variable\n";
print "------------|-------|------------------\n";

my $var_index = 1;
foreach my $color (@sorted_colors) {
    my $count = $colors{$color};
    my $var_name = suggest_variable_name($color, $var_index++);
    printf "%-11s | %5d | %s\n", $color, $count, $var_name;
}

print "\n";
print "Suggested :root block:\n\n";
print ":root {\n";
foreach my $color (@sorted_colors) {
    my $var_name = suggest_variable_name($color, 0);
    printf "  %-40s /* %s */\n", "$var_name: $color;", describe_color($color);
}
print "}\n";

sub suggest_variable_name {
    my ($color, $index) = @_;

    # Common E2 color mappings
    my %known_colors = (
        '#ffffff' => '--e2-color-white',
        '#fff'    => '--e2-color-white',
        '#000000' => '--e2-color-black',
        '#000'    => '--e2-color-black',
        '#4060b0' => '--e2-color-link',
        '#507898' => '--e2-color-link-visited',
        '#3bb5c3' => '--e2-color-link-active',
        '#38495e' => '--e2-color-primary',
        '#f8f9f9' => '--e2-bg-nodelet',
        '#c5cdd7' => '--e2-bg-medium',
        '#d3d3d3' => '--e2-border-light',
        '#333333' => '--e2-border-dark',
        '#eee'    => '--e2-bg-light',
        '#eeeeee' => '--e2-bg-light',
    );

    return $known_colors{$color} if exists $known_colors{$color};
    return "--e2-color-$index";
}

sub describe_color {
    my ($color) = @_;

    my %descriptions = (
        '#ffffff' => 'White',
        '#000000' => 'Black',
        '#4060b0' => 'Link blue',
        '#507898' => 'Visited link',
        '#3bb5c3' => 'Active/hover link',
        '#38495e' => 'Primary dark blue',
        '#f8f9f9' => 'Light background',
        '#c5cdd7' => 'Medium gray',
        '#d3d3d3' => 'Light border',
        '#333333' => 'Dark border',
    );

    return $descriptions{$color} if exists $descriptions{$color};

    # Parse RGB components
    my $r = hex(substr($color, 1, 2));
    my $g = hex(substr($color, 3, 2));
    my $b = hex(substr($color, 5, 2));

    # Determine if it's grayscale
    if (abs($r - $g) < 10 && abs($g - $b) < 10) {
        if ($r < 64) { return "Very dark gray"; }
        elsif ($r < 128) { return "Dark gray"; }
        elsif ($r < 192) { return "Medium gray"; }
        else { return "Light gray"; }
    }

    # Determine dominant color
    my $max = ($r > $g) ? (($r > $b) ? 'R' : 'B') : (($g > $b) ? 'G' : 'B');
    my $brightness = ($r + $g + $b) / 3;

    my $shade = $brightness < 128 ? "Dark" : "Light";
    my %colors = ('R' => 'red', 'G' => 'green', 'B' => 'blue');

    return "$shade " . $colors{$max};
}
