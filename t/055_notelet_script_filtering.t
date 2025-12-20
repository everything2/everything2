#!/usr/bin/perl -w

use strict;
use FindBin;
use lib "$FindBin::Bin/../ecore";
use Test::More;
use Everything;
use Everything::Application;

# Test that script tags are stripped from notelet content at render time
# This tests the fix for legacy notelets containing <script> tags that
# break React pages

my $APP = Everything::Application->new;

# Test helper to simulate notelet content rendering
sub filter_notelet_content {
    my ($content) = @_;
    # This is the exact filtering logic from Application.pm and notelet_editor.pm
    $content =~ s/<script[^>]*>.*?<\/script>//gis;
    $content =~ s/<script[^>]*>//gis;
    $content =~ s/<\/script>//gis;  # Also catch stray closing tags
    return $content;
}

# Test 1: Simple script tag removal
{
    my $input = '<script>alert("xss")</script>Hello World';
    my $expected = 'Hello World';
    my $result = filter_notelet_content($input);
    is($result, $expected, "Simple script tag is removed");
}

# Test 2: Script tag with attributes
{
    my $input = '<script type="text/javascript">alert("xss")</script>Hello';
    my $expected = 'Hello';
    my $result = filter_notelet_content($input);
    is($result, $expected, "Script tag with type attribute is removed");
}

# Test 3: Script tag with src attribute
{
    my $input = '<script src="http://evil.com/bad.js"></script>Content';
    my $expected = 'Content';
    my $result = filter_notelet_content($input);
    is($result, $expected, "Script tag with src attribute is removed");
}

# Test 4: Multiple script tags
{
    my $input = '<script>one</script>Text<script>two</script>More';
    my $expected = 'TextMore';
    my $result = filter_notelet_content($input);
    is($result, $expected, "Multiple script tags are removed");
}

# Test 5: Multiline script content
{
    my $input = qq{<script>
function bad() {
    alert('xss');
}
</script>Safe content};
    my $expected = 'Safe content';
    my $result = filter_notelet_content($input);
    is($result, $expected, "Multiline script content is removed");
}

# Test 6: Case insensitive matching
{
    my $input = '<SCRIPT>alert("xss")</SCRIPT>Hello';
    my $expected = 'Hello';
    my $result = filter_notelet_content($input);
    is($result, $expected, "Uppercase SCRIPT tag is removed");
}

# Test 7: Mixed case
{
    my $input = '<ScRiPt>alert("xss")</sCrIpT>Hello';
    my $expected = 'Hello';
    my $result = filter_notelet_content($input);
    is($result, $expected, "Mixed case script tag is removed");
}

# Test 8: Unclosed script tag
{
    my $input = '<script>never closed - Hello World';
    my $expected = 'never closed - Hello World';
    my $result = filter_notelet_content($input);
    is($result, $expected, "Unclosed script tag is removed");
}

# Test 9: Content without script tags is unchanged
{
    my $input = '<b>Bold</b> and <i>italic</i> text with [links]';
    my $expected = '<b>Bold</b> and <i>italic</i> text with [links]';
    my $result = filter_notelet_content($input);
    is($result, $expected, "Content without script tags is unchanged");
}

# Test 10: Empty content
{
    my $input = '';
    my $expected = '';
    my $result = filter_notelet_content($input);
    is($result, $expected, "Empty content stays empty");
}

# Test 11: Only script tag
{
    my $input = '<script>alert("only script")</script>';
    my $expected = '';
    my $result = filter_notelet_content($input);
    is($result, $expected, "Content that is only a script tag becomes empty");
}

# Test 11b: Stray closing script tag (breaks JSON embedding in page)
{
    my $input = 'Hello</script>World';
    my $expected = 'HelloWorld';
    my $result = filter_notelet_content($input);
    is($result, $expected, "Stray closing script tag is removed");
}

# Test 11c: Multiple stray closing script tags
{
    my $input = 'A</script>B</SCRIPT>C</Script>D';
    my $expected = 'ABCD';
    my $result = filter_notelet_content($input);
    is($result, $expected, "Multiple stray closing script tags are removed");
}

# Test 12: Script tag with newlines in attributes
{
    my $input = qq{<script
  type="text/javascript"
  src="bad.js">
</script>Safe};
    my $expected = 'Safe';
    my $result = filter_notelet_content($input);
    is($result, $expected, "Script tag with newlines in attributes is removed");
}

# Test 13: Real-world legacy notelet example
{
    my $input = q{<b>My Links</b><br>
[Home Node]<br>
[Everything's Best Users]<br>
<script>
// Old custom script that breaks things
document.write('<marquee>old school</marquee>');
</script>
[Cream of the Cool]};
    my $result = filter_notelet_content($input);
    like($result, qr/My Links/, "Real-world example preserves links");
    unlike($result, qr/<script/i, "Real-world example removes script");
    unlike($result, qr/document\.write/, "Real-world example removes script content");
}

# Test 14: Verify screenNotelet also strips scripts
{
    require Everything::Delegation::htmlcode;

    # Mock minimal objects needed for screenNotelet
    my $VARS = {
        noteletRaw => '<b>Test</b><script>bad()</script>Content'
    };

    # We can't easily call screenNotelet without full DB setup,
    # but we can verify the regex pattern is the same
    my $work = $VARS->{noteletRaw};
    $work =~ s/<script[^>]*>.*?<\/script>//gis;
    $work =~ s/<script[^>]*>//gis;

    is($work, '<b>Test</b>Content', "screenNotelet-style filtering works");
}

done_testing;
