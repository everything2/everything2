#!/usr/bin/perl
# Generate activation email for a user created via Sign Up form
#
# Usage: docker exec e2devapp perl /var/everything/tools/test-signup.pl <username> [password]
#
# In development, the Sign Up form creates users but doesn't send activation emails.
# This tool generates the email that WOULD have been sent, so you can:
# 1. See what the email looks like
# 2. Click the activation link to complete the signup flow
# 3. Test the 'Confirm password' page
#
# Arguments:
#   username  - The username you signed up with (required)
#   password  - The password you used (default: testpassword123)
#
# Example workflow:
#   1. Go to http://localhost:9080/title/Sign+Up in incognito
#   2. Fill out form with username "mytest", password "mypass123"
#   3. Run: docker exec e2devapp perl /var/everything/tools/test-signup.pl mytest mypass123
#   4. Click the activation link in the output
#   5. Log in with mytest / mypass123

use strict;
use warnings;
use lib '/var/libraries/lib/perl5';
use lib '/var/everything/ecore';

use Everything;
use Data::Dumper;

initEverything();

my $APP = $Everything::APP;
my $DB = $APP->{db};

# Get or generate username
my $username = $ARGV[0] || 'testuser_' . int(rand(100000));
my $password = $ARGV[1] || 'testpassword123';
my $email = "$username\@test.example.com";
my $valid_for_days = 10;

print "=" x 60 . "\n";
print "SIGN UP TEST TOOL\n";
print "=" x 60 . "\n\n";

# Check if user already exists
my $existing_user = $DB->getNode($username, 'user');
my $user;

if ($existing_user) {
    print "User '$username' already exists (node_id: $existing_user->{node_id})\n";
    print "Using existing user for activation link generation\n\n";
    $user = $existing_user;
} else {
    print "Creating new user: $username\n";
    print "Password: $password\n";
    print "Email: $email\n\n";

    # Create the user
    $user = $APP->create_user($username, $password, $email);

    unless ($user) {
        die "ERROR: Failed to create user '$username'\n";
    }

    print "SUCCESS: User created (node_id: $user->{node_id})\n\n";
}

# Generate activation link parameters
print "-" x 60 . "\n";
print "ACTIVATION LINK\n";
print "-" x 60 . "\n\n";

my $expiry_time = time() + ($valid_for_days * 86400);
my $params = $APP->getTokenLinkParameters($user, $password, 'activate', $expiry_time);

my $confirm_password_node = $DB->getNode('Confirm password', 'superdoc');
unless ($confirm_password_node) {
    die "ERROR: Could not find 'Confirm password' superdoc\n";
}

my $link = $APP->urlGen($params, 'no quotes', $confirm_password_node);

# Use localhost for dev
$link =~ s|https://everything2\.com|http://localhost:9080|;

print "Activation link (valid for $valid_for_days days):\n\n";
print "  $link\n\n";

# Get and format the welcome email template
print "-" x 60 . "\n";
print "WELCOME EMAIL CONTENT\n";
print "-" x 60 . "\n\n";

my $mail_node = $DB->getNode('Welcome to Everything2', 'mail');
if ($mail_node) {
    my $mail_content = $mail_node->{doctext};

    # Substitute template variables
    $mail_content =~ s/<name>/$username/g;
    $mail_content =~ s/<link>/$link/g;
    $mail_content =~ s/<servername>/localhost:9080/g;

    print "Subject: $mail_node->{title}\n";
    print "To: $email\n";
    print "-" x 40 . "\n";
    print "$mail_content\n";
} else {
    print "WARNING: Could not find 'Welcome to Everything2' mail template\n";
    print "The activation link above should still work.\n";
}

print "\n" . "-" x 60 . "\n";
print "COPY-PASTE URL\n";
print "-" x 60 . "\n\n";

# Output the activation link with HTML entities decoded for easy copy-paste
my $clean_link = $link;
$clean_link =~ s/&amp;/&/g;
print "$clean_link\n";

print "\n" . "-" x 60 . "\n";
print "NEXT STEPS\n";
print "-" x 60 . "\n\n";

print "1. Copy the URL above\n";
print "2. Open it in your browser (as a guest - use incognito mode)\n";
print "3. The 'Confirm password' page should activate the account\n";
print "4. Try logging in with:\n";
print "   Username: $username\n";
print "   Password: $password\n";
print "\n";

if (!$existing_user) {
    print "To delete this test user when done:\n";
    print "  docker exec e2devdb mysql -u root -pblah everything \\\n";
    print "    -e \"DELETE FROM node WHERE node_id=$user->{node_id}\"\n";
    print "\n";
}

print "=" x 60 . "\n";
