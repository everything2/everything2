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
  my ($remote_ip) = $self->APP->getIp();

  # Check for Enterprise API configuration first, fall back to legacy siteverify
  my $api_key = $self->CONF->recaptcha_enterprise_api_key;
  my $project_id = $self->CONF->recaptcha_enterprise_project_id;
  my $legacy_secret = $self->CONF->recaptcha_v3_secret_key;
  my $site_key = $self->CONF->recaptcha_v3_public_key;

  # Debug: log configuration
  my $token_len = length($token // '');
  my $token_preview = $token ? substr($token, 0, 20) . '...' : '(empty)';

  $self->devLog("verify_recaptcha_token: token length=$token_len, preview=$token_preview");
  $self->devLog("verify_recaptcha_token: remote_ip=$remote_ip");

  # Use Enterprise Assessment API if configured, otherwise use legacy siteverify
  if ($api_key && $project_id) {
    return $self->_verify_recaptcha_enterprise($ua, $token, $api_key, $project_id, $site_key, $remote_ip);
  } elsif ($legacy_secret) {
    return $self->_verify_recaptcha_legacy($ua, $token, $legacy_secret, $remote_ip);
  } else {
    $self->devLog("reCAPTCHA not configured: no Enterprise API key/project or legacy secret");
    $self->security_log("reCAPTCHA not configured");
    return 0;
  }
}

# Legacy siteverify endpoint (works with Enterprise legacy secret keys)
sub _verify_recaptcha_legacy
{
  my ($self, $ua, $token, $secret_key, $remote_ip) = @_;

  my $secret_preview = $secret_key ? substr($secret_key, 0, 10) . '...' : '(empty)';
  $self->devLog("verify_recaptcha_token (legacy siteverify): secret=$secret_preview");

  my $verify_url = 'https://www.google.com/recaptcha/api/siteverify';
  my $resp = $ua->post($verify_url, [
    secret => $secret_key,
    response => $token,
    remoteip => $remote_ip
  ]);

  $self->devLog("Received HTTP response: status=" . $resp->status_line);

  if ($resp->is_success) {
    my $json = JSON::decode_json($resp->decoded_content);
    $self->devLog("reCAPTCHA legacy response: " . $resp->decoded_content);

    if ($json->{success}) {
      return $json;  # Already has {success, score, action, hostname}
    } else {
      my $error_codes = $json->{'error-codes'} || [];
      $self->security_log("reCAPTCHA verification failed: " . join(', ', @$error_codes));
      $self->devLog("reCAPTCHA error-codes: " . join(', ', @$error_codes));
      return 0;
    }
  } else {
    $self->security_log("reCAPTCHA HTTP request failed: " . $resp->status_line);
    $self->devLog("reCAPTCHA HTTP error: " . $resp->status_line);
    return 0;
  }
}

# Enterprise Assessment API (requires GCP API key and project ID)
sub _verify_recaptcha_enterprise
{
  my ($self, $ua, $token, $api_key, $project_id, $site_key, $remote_ip) = @_;

  my $api_key_preview = $api_key ? substr($api_key, 0, 10) . '...' : '(empty)';
  $self->devLog("verify_recaptcha_token (Enterprise API): api_key=$api_key_preview, project=$project_id");

  my $verify_url = "https://recaptchaenterprise.googleapis.com/v1/projects/$project_id/assessments?key=$api_key";

  my $request_body = JSON::encode_json({
    event => {
      token => $token,
      siteKey => $site_key,
      userIpAddress => $remote_ip,
      expectedAction => 'signup'
    }
  });

  $self->devLog("verify_recaptcha_token: POST to $verify_url");

  my $resp = $ua->post(
    $verify_url,
    'Content-Type' => 'application/json; charset=utf-8',
    Content => $request_body
  );

  $self->devLog("Received HTTP response: status=" . $resp->status_line);

  if ($resp->is_success) {
    my $json = JSON::decode_json($resp->decoded_content);
    $self->devLog("reCAPTCHA Enterprise response: " . $resp->decoded_content);

    my $token_valid = $json->{tokenProperties}{valid};
    my $score = $json->{riskAnalysis}{score};
    my $reasons = $json->{riskAnalysis}{reasons} || [];

    if ($token_valid) {
      return {
        success => 1,
        score => $score,
        action => $json->{tokenProperties}{action},
        hostname => $json->{tokenProperties}{hostname},
        reasons => $reasons
      };
    } else {
      my $invalid_reason = $json->{tokenProperties}{invalidReason} || 'unknown';
      $self->security_log("reCAPTCHA token invalid: $invalid_reason");
      $self->devLog("reCAPTCHA token invalid: $invalid_reason");
      return 0;
    }
  } else {
    $self->security_log("reCAPTCHA Enterprise HTTP request failed: " . $resp->status_line);
    $self->devLog("reCAPTCHA Enterprise HTTP error: " . $resp->status_line);
    $self->devLog("Response body: " . ($resp->decoded_content // 'empty'));
    return 0;
  }
}

sub display
{
  my ($self, $REQUEST, $node) = @_;

  # Return cached result if already processed (prevents double form processing)
  return $self->_display_result if $self->_has_display_result;

  # Debug logging for reCAPTCHA Enterprise configuration
  my $api_key = $self->CONF->recaptcha_enterprise_api_key;
  my $project_id = $self->CONF->recaptcha_enterprise_project_id;
  my $public_key = $self->CONF->recaptcha_v3_public_key;
  my $api_key_masked = $api_key ? substr($api_key, 0, 10) . '...' : '(empty)';
  my $api_key_len = length($api_key // '');
  $self->devLog("sign_up Page: recaptcha_enterprise_api_key loaded = $api_key_masked ($api_key_len chars)");
  $self->devLog("sign_up Page: recaptcha_enterprise_project_id = " . ($project_id // '(empty)'));
  $self->devLog("sign_up Page: recaptcha_v3_public_key (site key) = $public_key");
  $self->devLog("sign_up Page: is_production = " . ($self->CONF->is_production ? 'true' : 'false'));
  $self->devLog("sign_up Page: HTTP_HOST = " . ($ENV{HTTP_HOST} // 'undef'));

  my $recaptcha_token = $REQUEST->param('recaptcha_token');
  my $recaptcha_response = undef;
  my $enforce_recaptcha = 1;
  my $use_recaptcha = 0;

  if($self->CONF->is_production or $ENV{HTTP_HOST} =~ /^development\.everything2\.com:?\d?/)
  {
    $use_recaptcha = 1;
    $self->devLog("sign_up Page: recaptcha ENABLED (production or development.everything2.com)");
  }else{
    $self->devLog("sign_up Page: recaptcha DISABLED (not production, HTTP_HOST doesn't match development.everything2.com)");
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
