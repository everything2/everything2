package Everything::Page::sign_up;

use Moose;
use utf8;
extends 'Everything::Page';

with 'Everything::Form::field_hashing';
use Digest::SHA;
use LWP::UserAgent;
use Data::Dumper;
use JSON;

has 'seclog_user' => (is => 'ro', isa => 'Everything::Node::user', default => sub { my ($self) = shift; return $self->APP->node_by_name('Virgil','user')});

has 'user_addrs' => (is => 'ro', default => sub { my ($self) = shift; return [$self->APP->getIp] }, lazy => 1);

has 'this_page' => (is => 'ro', default => sub { my ($self) = shift; return $self->APP->node_by_name('Sign Up','superdoc')}, lazy => 1);

has 'valid_for_days' => (is => 'ro', default => 10);

# Cache the result from display() so buildReactData doesn't reprocess the form
has '_display_result' => (is => 'rw', isa => 'HashRef', predicate => '_has_display_result');

sub security_log
{
  my ($self, $message) = @_;
  return $self->APP->securityLog($self->this_page->NODEDATA, $self->seclog_user->NODEDATA, "$message; IP: ".join('-', @{$self->user_addrs}));
}


sub is_infected
{
  my ($self, $REQUEST) = @_;

  unless($REQUEST->user->is_guest)
  {
    return 1 if $REQUEST->VARS->{infected};
  }

  # if logged on, no old cookie
  return 0 unless $REQUEST->user->is_guest;

  my $loginCookie = $REQUEST->cgi->cookie($self->CONF->cookiepass);

  return 0 unless $loginCookie;

  my ($user_name) = split(/\|/, $loginCookie);
  my $check_user = $self->APP->node_by_name($user_name, 'user');

  return 1 if $check_user && $check_user->locked;

  return 0;
}

sub verify_recaptcha_token
{
  my ($self, $token) = @_;

  my $ua = LWP::UserAgent->new;
  my $verify_url = 'https://www.google.com/recaptcha/api/siteverify';
  my ($remote_ip) = $self->APP->getIp();
  
  $self->devLog("Doing recaptcha v3 check: url => $verify_url, token => $token, remote_ip => $remote_ip");
  my $resp = $ua->post($verify_url, [secret => $self->CONF->recaptcha_v3_secret_key, response => $token, remote_ip => $remote_ip]);

  $self->devLog("Received HTTP response: ".Data::Dumper->Dump([$resp]));
  if($resp->is_success)
  {
    my $json = JSON::decode_json($resp->decoded_content);
    if($json->{success})
    {
      return $json;
    }else{
      return 0;
    }
  }else{
    return 0;
  }
}

sub display
{
  my ($self, $REQUEST, $node) = @_;

  # Return cached result if already processed (prevents double form processing)
  return $self->_display_result if $self->_has_display_result;

  my $recaptcha_token = $REQUEST->param('recaptcha_token');
  my $recaptcha_response = undef;
  my $enforce_recaptcha = 1;
  my $use_recaptcha = 0;

  if($self->CONF->is_production or $ENV{HTTP_HOST} =~ /^development\.everything2\.com:?\d?/)
  {
    $use_recaptcha = 1;
  }

  my $invalidName = '^\W+$|[\[\]\<\>\&\{\}\|\/\\\]| .*_|_.* |\s\s|^\s|\s$';
  my $validNameDescription = 'Valid user names contain at least one letter or number, and none of
		&#91; &#93; &lt; &gt; &amp; { } | / or \\. They may contain either spaces or underscores
		but not both, may not contain multiple spaces in a row and may not start or end with a space.';

  my $prompt = '';
  my %names = ();

  my ($username, $email, $pass) = ('','','');

  if(!$self->is_form_submitted($REQUEST))
  {
    $prompt = "Please fill in all fields";
  }

  if($prompt eq '' and not $self->has_valid_formsignature($REQUEST))
  {
    $prompt = "Form does not have valid signature, please resubmit";
  }

  $username = $REQUEST->param('username');
  $username = '' if not defined($username);

  if($prompt eq '' and $username =~ /$invalidName/)
  {
    $prompt = "$validNameDescription<br>Please enter a valid user name";
  }

  my $olduser = $self->APP->is_username_taken($username);

  if($prompt eq '' and defined($olduser))
  {
    $self->security_log("Rejected username $username: matches ".$self->APP->linkNode($olduser));
    $prompt = 'Sorry, that username is already taken. Please try a different one';
  }

  $email = $REQUEST->param('email');
  $email = '' if not defined($email);

  $pass = $REQUEST->param('pass');
  $pass = '' if not defined($pass);

  my $hashedemail = $self->get_hashed_field($REQUEST,'email');
  $hashedemail = '' if not defined($hashedemail);

  my $hashedpass = $self->get_hashed_field($REQUEST, 'pass');
  $hashedpass = '' if not defined($hashedpass);

  if($prompt eq '' and ($email eq '' or $pass eq '' or $username eq ''))
  {
    $prompt = "Some fields were blank, please try again. ($email, $pass, $username)";
  }

  if($prompt eq '' and $email ne $hashedemail)
  {
    $prompt = "Emails do not match, please try again";
  }

  if($prompt eq '' and $email !~ /.+@[\w\d.-]+\.[\w]+$/)
  {
    $prompt = "Email does not appear to be from a valid domain structure. Please try again";
  }

  if($prompt eq '' and $pass ne $hashedpass)
  {
    $prompt = "Passwords do not match, please try again"
  }

  if($prompt eq '')
  {
    # filter out undesirables
    my @addrs = $self->APP->getIp();

    my $known_good = $self->APP->node_by_name("known good domains","setting")->VARS;
    my $known_spam = $self->APP->node_by_name("known spam domains", "setting")->VARS;

    my @undesirable = ();

    # check for blacklisted IP
    my $blacklisted = undef;
    foreach my $ip (@addrs) {
      last if $blacklisted = $self->APP->is_ip_blacklisted($ip);
    }

    push @undesirable, "request from blacklisted IP: $blacklisted" if $blacklisted;

    # check if email address belongs to a locked account
    my $lockedUser = undef;
    $lockedUser = $self->APP->is_email_in_locked_account($email);

    push @undesirable, 'same email address as locked user: '.$self->APP->linkNode($lockedUser) if $lockedUser;

    my $domain = lc($email);
    $domain =~ s/.*?@//g;

    push @undesirable, "email address $email is from spamland domain $domain" if(exists($known_spam->{$domain}) and not exists($known_good->{$domain}));

    # check for locked user cookie infection
    push @undesirable, 'infected by cookie from locked user' if $self->is_infected($REQUEST);

    # break things and annoy the user if necessary
    if (@undesirable){
      my $log = join('; ', @undesirable);
      $self->security_log("Sign up rejected: $log");

      $prompt = "Sign up rejected. Please contact support";
      $username = '';
      $pass = '';
      $email = '';
    }
  }

  if($prompt eq '' and $use_recaptcha and not defined($recaptcha_token))
  {
    $prompt = "Internal form error, did not receive reCAPTCHAv3 token";
  }
  
  if($prompt eq '' and $use_recaptcha and not ($recaptcha_response = $self->verify_recaptcha_token($recaptcha_token)))
  {
    $prompt = "Could not verify reCAPTCHAv3 token - Please try again";
    $self->security_log("Recaptcha token verification failed");
  }
  
  if($prompt eq '' and $use_recaptcha and $enforce_recaptcha and $recaptcha_response->{score} < .5)
  {
    $prompt = "Sign up rejected due to spam score of $recaptcha_response->{score}";
    $self->security_log("Spam signup rejected due to recaptcha: $recaptcha_response->{score}, username: $username");
  }

  if($prompt ne '')
  {
    my $formtime = time;
    my $result = {
      "prompt" => $prompt,
      "username" => $username,
      "email" => $email,
      "formtime" => $formtime,
      "formsignature" => $self->formsignature($formtime),
      "email_confirm_field" => $self->hash_item('email', $formtime),
      "pass_confirm_field" => $self->hash_item('pass', $formtime),
      "use_recaptcha" => $use_recaptcha,
      "recaptcha_v3_public_key" => $self->CONF->recaptcha_v3_public_key,
      "type" => "sign_up"
    };
    $self->_display_result($result);
    return $result;
  }

  # all tests passed: create account
  my $new_user = $self->APP->create_user($username, $pass, $email);

  unless ($new_user)
  {
    $self->security_log('Failed to create new user: username '.$self->APP->encodeHTML($username, 1));
    $prompt = 'Sorry, something just went horribly wrong. Your account has not been created. Please try again';
    my $result = {"prompt" => $prompt, "type" => "sign_up"};
    $self->_display_result($result);
    return $result;
  }

  $self->security_log('Created user '.$self->APP->linkNode($new_user));

  # send activation email
  if($self->CONF->is_production)
  {
    my $mail = $self->APP->node_by_name('Welcome to Everything2', 'mail')->NODEDATA;

    my $params = $self->APP->getTokenLinkParameters($new_user, $pass, 'activate', time() + $self->valid_for_days * 86400);
    my $link = $self->APP->urlGen($params, 'no quotes', $self->APP->node_by_name('Confirm password', 'superdoc')->NODEDATA);

    $mail->{doctext} =~ s/<name>/$username/;
    $mail->{doctext} =~ s/<link>/$link/g;
    $mail->{doctext} =~ s/<servername>/$ENV{SERVER_NAME}/g;

    $self->APP->node2mail($email, $mail, 1);
  }

  $self->APP->set_spam_threshold($new_user, $recaptcha_response->{score});
  my $result = {"success" => 1, "username" => $username, "linkvalid" => $self->valid_for_days, "type" => "sign_up"};
  $self->_display_result($result);
  return $result;
}

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  # Call existing display() method which returns perfect React data structure
  return $self->display($REQUEST, $REQUEST->node);
}

__PACKAGE__->meta->make_immutable;

1;
