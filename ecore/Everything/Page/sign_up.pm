package Everything::Page::sign_up;

use Moose;
extends 'Everything::Page';

use HTTP::Request::Common;
use LWP::UserAgent;
use Data::Dumper;
use JSON;

has 'seclog_user' => (is => 'ro', isa => 'Everything::Node::user', default => sub { my ($self) = shift; return $self->APP->node_by_name('Virgil','user')});

has 'user_addrs' => (is => 'ro', default => sub { my ($self) = shift; return [$self->APP->getIp] }, lazy => 1);

has 'this_page' => (is => 'ro', default => sub { my ($self) = shift; return $self->APP->node_by_name('Sign Up','superdoc')}, lazy => 1);

has 'valid_for_days' => (is => 'ro', default => 10);

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

  return 1 if $check_user && $self->locked;

  return 0;
}

sub verify_recaptcha_token
{
  my ($self, $token) = @_;

  my $ua = LWP::UserAgent->new;
  my $verify_url = 'https://www.google.com/recaptcha/api/siteverify';
  my ($remote_ip) = $self->APP->getIp();
  

  $self->devLog("Doing recaptcha v3 check: url => $verify_url, token => $token, remote_ip => $remote_ip");
  my $resp = $ua->request(POST $verify_url, [secret => $self->CONF->recaptcha_v3_secret_key, response => $token, remote_ip => $remote_ip]);

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

  my $query = $REQUEST->cgi;

  my $use_recaptcha = 0;
  if($self->CONF->environment eq "production" or $ENV{HTTP_HOST} =~ /^development\.everything2\.com:?\d?/)
  {
    $use_recaptcha = 1;
  }


  # for how long will a signup form still work after being served?
  my $formLife = 86400;

  my $invalidName = '^\W+$|[\[\]\<\>\&\{\}\|\/\\\]| .*_|_.* |\s\s|^\s|\s$';
  my $validNameDescription = 'Valid user names contain at least one letter or number, and none of
		&#91; &#93; &lt; &gt; &amp; { } | / or \\. They may contain either spaces or underscores
		but not both, may not contain multiple spaces in a row and may not start or end with a space.';

  my $prompt = '';
  my %names = ();

  # use automation-resistant field names
  my $seed = time + $formLife;
  
  if(join(',', $REQUEST->param) =~ /,q5q(\d+)/)
  {
    $seed = "$1";
    $self->devLog("Detected seed: $seed");
  }

  my $hashName = sub{
    my $x = crypt("$_ majtki", "\$5\$$seed}");
    $x =~ s/[^0-9A-z]/q/g;
    return $x;
  };

  foreach ('username', 'email', 'pass')
  {
    $names{$_} = &$hashName;
    $self->devLog("Looking for field for $_: $names{$_} (has ".$REQUEST->param($names{$_}).")");
  };

  my $username = $REQUEST->param($names{'username'});
  $username = '' if not defined($username);

  my $email = $REQUEST->param($names{'email'});
  $email = '' if not defined($email);

  my $pass = $REQUEST->param($names{'pass'});
  $pass = '' if not defined($pass);


  my $recaptcha_token = $REQUEST->param('recaptcha_token');
  my $recaptcha_response = undef;
  my $enforce_recaptcha = 1;

  $self->devLog("Username: $username, Email: $email, Pass: $pass");

  my @addrs = $self->APP->getIp();

  #######

  # filter out undesirables

  my $known_good = $self->APP->node_by_name("known good domains","setting")->VARS;
  my $known_spam = $self->APP->node_by_name("known spam domains", "setting")->VARS;

  if ($username && $email && $pass){
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

      $query->delete(values %names);
      $prompt = int(rand(4)) + 1;
    }
  }

  #######

  # ask them nicely...
  if (time > $seed || !$pass || !$username || !$email || $prompt eq "1")
  {
    $prompt = 'Please fill in all fields';

# then check they've jumped through the hoops:
  }elsif($pass ne $query->param('toad') || $prompt eq "2"){
    $prompt = "Passwords don't match";

  }elsif($email ne $query->param('celery') || $prompt eq "3"){
    $prompt = "Email addresses don't match";

  # RFC 5231 & 5232 are not regexp friendly. Only validate host part:
  }elsif($email !~ /.+@[\w\d.-]+\.[\w]+$/){
    $prompt = "Please enter a valid email address";

  }elsif($username =~ /$invalidName/){
    $prompt = "$validNameDescription<br>Please enter a valid user name";

  }elsif(my $old = $self->APP->is_username_taken($username) || $prompt eq "4"){
    $self->security_log("Rejected username $username: matches ".$self->APP->linkNode($old)) unless $prompt;
    $prompt = 'Sorry, that username is already taken. Please try a different one';

  }elsif($use_recaptcha and not defined($recaptcha_token)){
    $prompt = "Internal form error, did not receive reCAPTCHAv3 token";
  }elsif($use_recaptcha and not ($recaptcha_response = $self->verify_recaptcha_token($recaptcha_token))){
    $prompt = "Could not verify reCAPTCHAv3 token - Please try again";
    $self->security_log("Recaptcha token verification failed");
  }elsif($use_recaptcha and $enforce_recaptcha and $recaptcha_response->{score} < .5)
  {
    $prompt = "Sign up rejected due to spam score of $recaptcha_response->{score}";
    $self->security_log("Spam signup rejected due to recaptcha: $recaptcha_response->{score}, username: $username");
  }

  $query->delete('toad');

  if($prompt)
  {
    $self->devLog("Calling template with: prompt => $prompt, username => $username, email => $email");
    return {"prompt" => $prompt, "username" => $username, "email" => $email, "seed" => time + $formLife, "use_recaptcha" => $use_recaptcha, "recaptcha_v3_public_key" => $self->CONF->recaptcha_v3_public_key};
  }

  #######
  # all tests passed: create account

  my $new_user = $self->APP->create_user($username, $pass, $email);

  unless ($new_user){
	$self->security_log('Failed to create new user: username '.$self->APP->encodeHTML($username, 1));
	return $query -> p('Sorry, something just went horribly wrong. Your account has
		not been created. Please try again.');
  }

  $self->security_log('Created user '.$self->APP->linkNode($new_user));

  # send activation email
  my $mail = $self->APP->node_by_name('Welcome to Everything2', 'mail')->NODEDATA;

  my $params = $self->APP->getTokenLinkParameters($new_user, $pass, 'activate', time() + $self->valid_for_days * 86400);
  my $link = $self->APP->urlGen($params, 'no quotes', $self->APP->node_by_name('Confirm password', 'superdoc')->NODEDATA);

  $mail->{doctext} =~ s/«name»/$username/;
  $mail->{doctext} =~ s/«link»/$link/g;
  $mail->{doctext} =~ s/«servername»/$ENV{SERVER_NAME}/g;

  $self->APP->node2mail($email, $mail, 1);

  $self->APP->set_spam_threshold($new_user, $recaptcha_response->{score});
  return {"success" => 1, "username" => $username, "linkvalid" => $self->valid_for_days};
}

__PACKAGE__->meta->make_immutable;

1;
