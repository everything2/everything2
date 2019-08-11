<%class>
  has 'seed' => (default => 0);

  has 'prompt' => (default => 'Please fill in all fields');
  has 'password_maxlength' => (default => 240);
  has 'email_maxlength' => (default => 240);

  has 'username' => (default => '');
  has 'email' => (default => '');
  has 'confirm_email' => (default => '');

  has 'use_recaptcha' => (default => 1);
  has 'recaptcha_v3_public_key' => (default => '');

  has 'success' => (default => 0);
  has 'linkvalid' => (default => 0);

  sub hash_field_name {
    my $self = shift;
    my $value = shift;
    my $x = crypt("$value majtki", "\$5\$".$self->seed."}");
    $x =~ s/[^0-9A-z]/q/g;
    return $x;
  }

  has 'form_elements' => (lazy => 1, default => sub {
    my $self = shift;
    return [
      {
        "name" => "Username",
        "maxlength" => 20,
        "fieldname" => "username",
        "autocomplete" => "username",
        "hash" => 1,
        "default" => $self->username,
      },
      {
        "name" => "Password",
        "maxlength" => $self->password_maxlength,
        "fieldname" => "pass",
        "type" => "password",
        "autocomplete" => "new-password",
        "hash" => 1,
        "default" => "",
      },
      {
        "name" => "Confirm password",
        "maxlength" => $self->password_maxlength,
        "fieldname" => "toad",
        "type" => "password",
        "autocomplete" => "new-password",
        "default" => "",
      },
      {
        "name" => "Email address",
        "maxlength" => $self->email_maxlength,
        "fieldname" => "email",
        "autocomplete" => "email",
        "hash" => 1,
        "default" => $self->email,
      },
      {
        "name" => "Confirm email",
        "maxlength" => $self->email_maxlength,
        "fieldname" => "celery",
        "autocomplete" => "email",
        "default" => $self->confirm_email,
      }
  ]});  
</%class>
% if ($.success) {
<h3>Welcome to Everything2, <% $.username %></h3>
<p>Your new user account has been created, and an email has been sent to the address you provided.
You cannot use your account until you have followed the link in the email to activate it.
This link will expire in <% $.linkvalid %> days.</p>
<p>The email contains some useful information, so please read it carefully, print it out on high-quality paper, and hang it on your wall in a tasteful frame.</p>

% } else {
<& '/helpers/openform.mi', node => $.node, id => "signupform" &>
<fieldset style="width: 32em; max-width: 100%; margin: 3em auto 0">
<legend>Sign Up</legend>
<p><% $.prompt %>:</p>
<p style="text-align: right">
%   foreach my $element (@{$.form_elements}) {
  <label>
  <% $element->{name} | Obfuscate %>:<input type="<% $element->{type} || "text" %>" name="<% $element->{hash} ? $.hash_field_name($element->{fieldname}) : $element->{fieldname} %>" size="30" maxlength="<% $element->{maxlength} %>" value="<% $element->{default} %>" autocomplete="<% $element->{autocomplete} %>">
  </label>
  <br />
%   }
<br />
<input type="submit" name="beseech" value="Create new account" />
<input type="hidden" name="recaptcha_token" value="" />
</p>
</fieldset>
</form>

<h4>Email Privacy Policy</h4>

<p>We will only use your email to send you an account activation email and for any other email services that you specifically request. It will not be disclosed to anyone else.</p>

<h4>Spam Policy</h4>

<p>We neither perpetrate nor tolerate spam.</p>

<p>New accounts advertizing any product, service or web site (including "personal" sites and blogs) in their posts or in their profile are subject to immediate deletion. Their details may be submitted to public blacklists for the use of other web sites.</p>

<h4>Underage users</h4>

<p>Everything2 may include member-created content designed for an adult audience. Viewing this content does not require an account. For logged-in account holders, Everything2 may display text conversations conducted by adults and intended for an adult audience. On-site communications are not censored or restricted by default. Users under the age of 18 are advised that they should expect to be interacting primarily with adults and that the site may not be considered appropriate by their parents, guardians, or other powers-that-be. Everything2 is not intended for use by children under the age of 13 and does not include any features or content designed to appeal to children of that age.</p>

%   if ($.use_recaptcha) {
<script src="https://www.google.com/recaptcha/api.js?render=<% $.recaptcha_v3_public_key %>"></script>
<script>grecaptcha.ready(function() {
  grecaptcha.execute('<% $.recaptcha_v3_public_key %>', {action: 'signup'}).then(function(token){
    document.getElementById("signupform").recaptcha_token.value = token;
  });
});
</script>
%   }
% }
