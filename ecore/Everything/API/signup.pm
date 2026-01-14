package Everything::API::signup;

use Moose;
use utf8;
use JSON;
use LWP::UserAgent;
use Encode qw(decode_utf8);
extends 'Everything::API';

=head1 NAME

Everything::API::signup - User registration API

=head1 DESCRIPTION

Handles user registration via JSON API instead of form POST.
This provides better error handling and maintains React state.

=head1 ENDPOINTS

=head2 POST /api/signup

Create a new user account.

Request body (JSON):
{
  "username": "desired_username",
  "password": "user_password",
  "email": "user@example.com",
  "recaptcha_token": "token_from_recaptcha_v3"
}

Response (JSON):
Success:
{
  "success": true,
  "username": "created_username",
  "linkvalid": 10
}

Error:
{
  "success": false,
  "error": "error_code",
  "message": "Human readable message"
}

Error codes:
- invalid_username: Username contains invalid characters
- username_taken: Username already exists
- invalid_email: Email format invalid
- email_spam: Email from blocked domain
- email_locked: Email belongs to locked account
- ip_blacklisted: Request from blacklisted IP
- recaptcha_missing: No reCAPTCHA token provided
- recaptcha_failed: reCAPTCHA verification failed
- recaptcha_score: Score too low (likely bot)
- creation_failed: Account creation failed
- infected: Cookie infection from locked user

=cut

has 'seclog_user' => (
  is => 'ro',
  lazy => 1,
  default => sub {
    my $self = shift;
    return $self->APP->node_by_name('Virgil', 'user');
  }
);

has 'valid_for_days' => (is => 'ro', default => 10);

sub route {
  my ($self, $REQUEST, $extra) = @_;
  my $method = lc($REQUEST->request_method());

  if ($method eq 'post' && (!$extra || $extra eq '')) {
    return $self->create_account($REQUEST);
  }

  return [$self->HTTP_NOT_FOUND, { error => 'Not found' }];
}

sub security_log {
  my ($self, $message) = @_;
  my $signup_page = $self->APP->node_by_name('Sign Up', 'superdoc');
  my @addrs = $self->APP->getIp();
  return $self->APP->securityLog(
    $signup_page->NODEDATA,
    $self->seclog_user->NODEDATA,
    "$message; IP: " . join('-', @addrs)
  );
}

sub create_account {
  my ($self, $REQUEST) = @_;

  my $APP = $self->APP;
  my $CONF = $self->CONF;

  # Parse JSON body - do NOT decode_utf8 before decode_json
  my $postdata = $REQUEST->POSTDATA;

  my $data;
  my $json_ok = eval {
    $data = JSON::decode_json($postdata);
    1;
  };
  if (!$json_ok || !$data) {
    return [$self->HTTP_BAD_REQUEST, {
      success => 0,
      error => 'invalid_json',
      message => 'Invalid JSON in request body'
    }];
  }

  my $username = $data->{username} // '';
  my $password = $data->{password} // '';
  my $email = $data->{email} // '';
  my $recaptcha_token = $data->{recaptcha_token} // '';

  # Determine if we need reCAPTCHA
  my $use_recaptcha = 0;
  if ($CONF->is_production || ($ENV{HTTP_HOST} // '') =~ /^development\.everything2\.com/) {
    $use_recaptcha = 1;
  }

  # Validate username format
  my $invalidName = '^\W+$|[\[\]\<\>\&\{\}\|\/\\\]| .*_|_.* |\s\s|^\s|\s$';
  if ($username =~ /$invalidName/ || $username eq '') {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'invalid_username',
      message => 'Username contains invalid characters or is empty'
    }];
  }

  # Check if username taken
  my $olduser = $APP->is_username_taken($username);
  if ($olduser) {
    $self->security_log("Rejected username $username: matches " . $APP->linkNode($olduser));
    return [$self->HTTP_OK, {
      success => 0,
      error => 'username_taken',
      message => 'That username is already taken'
    }];
  }

  # Validate password
  if ($password eq '') {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'invalid_password',
      message => 'Password is required'
    }];
  }

  # Validate email format
  if ($email !~ /.+@[\w\d.-]+\.[\w]+$/) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'invalid_email',
      message => 'Email does not appear to be valid'
    }];
  }

  # Check for undesirables
  my @addrs = $APP->getIp();

  # Check blacklisted IP
  my $blacklisted;
  for my $ip (@addrs) {
    last if $blacklisted = $APP->is_ip_blacklisted($ip);
  }
  if ($blacklisted) {
    $self->security_log("Sign up rejected: blacklisted IP $blacklisted");
    return [$self->HTTP_OK, {
      success => 0,
      error => 'ip_blacklisted',
      message => 'Sign up rejected. Please contact support.'
    }];
  }

  # Check email in locked account
  my $lockedUser = $APP->is_email_in_locked_account($email);
  if ($lockedUser) {
    $self->security_log("Sign up rejected: email belongs to locked user " . $APP->linkNode($lockedUser));
    return [$self->HTTP_OK, {
      success => 0,
      error => 'email_locked',
      message => 'Sign up rejected. Please contact support.'
    }];
  }

  # Check spam domain
  my $known_good = $APP->node_by_name('known good domains', 'setting')->VARS;
  my $known_spam = $APP->node_by_name('known spam domains', 'setting')->VARS;
  my $domain = lc($email);
  $domain =~ s/.*?@//g;

  if (exists($known_spam->{$domain}) && !exists($known_good->{$domain})) {
    $self->security_log("Sign up rejected: spam domain $domain");
    return [$self->HTTP_OK, {
      success => 0,
      error => 'email_spam',
      message => 'Sign up rejected. Please contact support.'
    }];
  }

  # Check for cookie infection
  if ($self->is_infected($REQUEST)) {
    $self->security_log("Sign up rejected: infected by locked user cookie");
    return [$self->HTTP_OK, {
      success => 0,
      error => 'infected',
      message => 'Sign up rejected. Please contact support.'
    }];
  }

  # reCAPTCHA verification
  my $recaptcha_response;
  if ($use_recaptcha) {
    if (!$recaptcha_token) {
      return [$self->HTTP_OK, {
        success => 0,
        error => 'recaptcha_missing',
        message => 'reCAPTCHA verification required'
      }];
    }

    $recaptcha_response = $self->verify_recaptcha_token($recaptcha_token);
    if (!$recaptcha_response) {
      $self->security_log("reCAPTCHA verification failed for $username");
      return [$self->HTTP_OK, {
        success => 0,
        error => 'recaptcha_failed',
        message => 'Could not verify reCAPTCHA. Please try again.'
      }];
    }

    if ($recaptcha_response->{score} < 0.5) {
      $self->security_log("Spam signup rejected: score=$recaptcha_response->{score}, username=$username");
      return [$self->HTTP_OK, {
        success => 0,
        error => 'recaptcha_score',
        message => 'Sign up rejected due to spam detection'
      }];
    }
  }

  # All checks passed - create the account
  my $new_user = $APP->create_user($username, $password, $email);

  unless ($new_user) {
    $self->security_log("Failed to create user: $username");
    return [$self->HTTP_OK, {
      success => 0,
      error => 'creation_failed',
      message => 'Account creation failed. Please try again.'
    }];
  }

  $self->security_log("Created user " . $APP->linkNode($new_user));

  # Send activation email in production
  if ($CONF->is_production) {
    my $mail = $APP->node_by_name('Welcome to Everything2', 'mail')->NODEDATA;
    my $params = $APP->getTokenLinkParameters(
      $new_user,
      $password,
      'activate',
      time() + $self->valid_for_days * 86400
    );
    my $link = $APP->urlGen(
      $params,
      'no quotes',
      $APP->node_by_name('Confirm password', 'superdoc')->NODEDATA
    );

    $mail->{doctext} =~ s/<name>/$username/;
    $mail->{doctext} =~ s/<link>/$link/g;
    $mail->{doctext} =~ s/<servername>/$ENV{SERVER_NAME}/g;

    $APP->node2mail($email, $mail, 1);
  }

  # Set spam threshold if we have recaptcha score
  if ($recaptcha_response && $recaptcha_response->{score}) {
    $APP->set_spam_threshold($new_user, $recaptcha_response->{score});
  }

  return [$self->HTTP_OK, {
    success => 1,
    username => $username,
    linkvalid => $self->valid_for_days
  }];
}

sub is_infected {
  my ($self, $REQUEST) = @_;

  return 0 unless $REQUEST->user->is_guest;

  my $loginCookie = $REQUEST->cgi->cookie($self->CONF->cookiepass);
  return 0 unless $loginCookie;

  my ($user_name) = split(/\|/, $loginCookie);
  my $check_user = $self->APP->node_by_name($user_name, 'user');

  return 1 if $check_user && $check_user->locked;
  return 0;
}

sub verify_recaptcha_token {
  my ($self, $token) = @_;

  my $CONF = $self->CONF;
  my $ua = LWP::UserAgent->new;
  my ($remote_ip) = $self->APP->getIp();

  my $api_key = $CONF->recaptcha_enterprise_api_key;
  my $project_id = $CONF->recaptcha_enterprise_project_id;
  my $legacy_secret = $CONF->recaptcha_v3_secret_key;
  my $site_key = $CONF->recaptcha_v3_public_key;

  if ($api_key && $project_id) {
    return $self->_verify_recaptcha_enterprise($ua, $token, $api_key, $project_id, $site_key, $remote_ip);
  } elsif ($legacy_secret) {
    return $self->_verify_recaptcha_legacy($ua, $token, $legacy_secret, $remote_ip);
  }

  $self->devLog("reCAPTCHA not configured");
  return 0;
}

sub _verify_recaptcha_legacy {
  my ($self, $ua, $token, $secret_key, $remote_ip) = @_;

  my $verify_url = 'https://www.google.com/recaptcha/api/siteverify';
  my $resp = $ua->post($verify_url, [
    secret => $secret_key,
    response => $token,
    remoteip => $remote_ip
  ]);

  if ($resp->is_success) {
    my $json = JSON::decode_json($resp->decoded_content);
    if ($json->{success}) {
      return $json;
    }
  }

  return 0;
}

sub _verify_recaptcha_enterprise {
  my ($self, $ua, $token, $api_key, $project_id, $site_key, $remote_ip) = @_;

  my $verify_url = "https://recaptchaenterprise.googleapis.com/v1/projects/$project_id/assessments?key=$api_key";

  my $request_body = JSON::encode_json({
    event => {
      token => $token,
      siteKey => $site_key,
      userIpAddress => $remote_ip,
      expectedAction => 'signup'
    }
  });

  my $resp = $ua->post(
    $verify_url,
    'Content-Type' => 'application/json; charset=utf-8',
    Content => $request_body
  );

  if ($resp->is_success) {
    my $json = JSON::decode_json($resp->decoded_content);
    my $token_valid = $json->{tokenProperties}{valid};
    my $score = $json->{riskAnalysis}{score};

    if ($token_valid) {
      return {
        success => 1,
        score => $score,
        action => $json->{tokenProperties}{action},
        hostname => $json->{tokenProperties}{hostname}
      };
    }
  }

  return 0;
}

__PACKAGE__->meta->make_immutable;

1;
