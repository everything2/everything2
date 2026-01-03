#!/usr/bin/perl
# Generate password reset email link for testing
#
# Usage: docker exec e2devapp perl /var/everything/tools/test-password-reset.pl <username> [new_password]
#
# In development, the password reset form sends emails which may not be delivered.
# This tool generates the reset link that WOULD have been sent, so you can:
# 1. See what the email looks like
# 2. Click the reset link to complete the password reset flow
# 3. Test the 'Confirm password' page
#
# Arguments:
#   username      - The username to reset password for (required)
#   new_password  - The new password to set (default: newpassword123)
#
# Example workflow:
#   1. Run: docker exec e2devapp perl /var/everything/tools/test-password-reset.pl normaluser1 mynewpass
#   2. Click the reset link in the output
#   3. Log in with normaluser1 / mynewpass

use strict;
use warnings;
use lib '/var/libraries/lib/perl5';
use lib '/var/everything/ecore';

use Everything;

initEverything();

my $APP = $Everything::APP;
my $DB = $APP->{db};

my $username = $ARGV[0];
my $new_password = $ARGV[1] || 'newpassword123';
my $valid_for_minutes = 20;

unless ($username) {
    print STDERR "Usage: $0 <username> [new_password]\n";
    print STDERR "\nExample:\n";
    print STDERR "  docker exec e2devapp perl /var/everything/tools/test-password-reset.pl normaluser1 mynewpass\n";
    exit 1;
}

print "=" x 60 . "\n";
print "PASSWORD RESET TEST TOOL\n";
print "=" x 60 . "\n\n";

# Find the user
my $user = $DB->getNode($username, 'user');

unless ($user) {
    die "ERROR: User '$username' not found\n";
}

print "User: $username (node_id: $user->{node_id})\n";
print "Email: $user->{email}\n";
print "New password: $new_password\n\n";

# Ensure user has salt
$APP->updatePassword($user, $user->{passwd}) unless $user->{salt};

# Generate reset link parameters
print "-" x 60 . "\n";
print "PASSWORD RESET LINK\n";
print "-" x 60 . "\n\n";

my $expiry_time = time() + ($valid_for_minutes * 60);
my $params = $APP->getTokenLinkParameters($user, $new_password, 'reset', $expiry_time);

my $confirm_password_node = $DB->getNode('Confirm password', 'superdoc');
unless ($confirm_password_node) {
    die "ERROR: Could not find 'Confirm password' superdoc\n";
}

my $link = $APP->urlGen($params, 'no quotes', $confirm_password_node);

# Use localhost for dev - prepend if relative, or replace if absolute
if ($link !~ m|^https?://|) {
    $link = "http://localhost:9080" . $link;
} else {
    $link =~ s|https://everything2\.com|http://localhost:9080|;
}

print "Reset link (valid for $valid_for_minutes minutes):\n\n";
print "  $link\n\n";

# Get and format the password reset email template
print "-" x 60 . "\n";
print "PASSWORD RESET EMAIL CONTENT\n";
print "-" x 60 . "\n\n";

my $mail_node = $DB->getNode('Everything2 password reset', 'mail');
if ($mail_node) {
    my $mail_content = $mail_node->{doctext};
    my $name = $user->{realname} || $user->{title};

    # Substitute template variables (using both old and new style)
    $mail_content =~ s/<name>/$name/g;
    $mail_content =~ s/«name»/$name/g;
    $mail_content =~ s/<link>/$link/g;
    $mail_content =~ s/«link»/$link/g;
    $mail_content =~ s/<servername>/localhost:9080/g;
    $mail_content =~ s/«servername»/localhost:9080/g;

    print "Subject: $mail_node->{title}\n";
    print "To: $user->{email}\n";
    print "-" x 40 . "\n";
    print "$mail_content\n";
} else {
    print "WARNING: Could not find 'Everything2 password reset' mail template\n";
    print "The reset link above should still work.\n";
}

print "\n" . "-" x 60 . "\n";
print "COPY-PASTE URL\n";
print "-" x 60 . "\n\n";

# Output the reset link with HTML entities decoded for easy copy-paste
my $clean_link = $link;
$clean_link =~ s/&amp;/&/g;
print "$clean_link\n";

print "\n" . "-" x 60 . "\n";
print "NEXT STEPS\n";
print "-" x 60 . "\n\n";

print "1. Copy the URL above\n";
print "2. Open it in your browser (use incognito mode to be safe)\n";
print "3. The 'Confirm password' page should confirm the password reset\n";
print "4. Try logging in with:\n";
print "   Username: $username\n";
print "   Password: $new_password\n";
print "\n";

print "=" x 60 . "\n";
