<%class>
  has 'NODE' => (isa => 'HashRef', required => 1); #TODO: Do we need this?
  has 'USER' => (isa => 'HashRef', required => 1); #TODO: Do we need this?
  has 'pagetitle' => (isa => 'Str', required => 1);
  has 'stylesheets' => (isa => 'ArrayRef[HashRef]', required => 1);
  has 'customstyle' => (isa => 'Maybe[Str]');
  has 'bodyclass' => (isa => 'Str', required => 1);
  has 'metadescription' => (isa => 'Str', default => 'Everything2 is a community for fiction, nonfiction, poetry, reviews, and more. Get writing help or enjoy nearly a half million pieces of original writing.');
  has 'footergibberish' => (isa => 'Maybe[Str]', default => sub {  
      if ( rand() < 0.1 ) {
        my @gibberish = (
          "We are the bat people.", "Let sleeping demons lie.",
          "Monkey! Bat! Robot Hat!", "We're sneaking up on you.",
        );
        return $gibberish[int(rand(@gibberish))];
      };
      return undef;
      });
  has 'zenadheader' => (isa => 'Str', required => 1);
  has 'static_javascript' => (isa => 'Str', required => 1);

  # Temporary
  has 'nodelets' => (isa => 'Maybe[Str]');
</%class>
<%augment wrap>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html lang="en">
<head>
<!-- Inside of Mason -->
<meta http-equiv="X-UA-Compatible" content="IE=Edge" />
<title><% $.pagetitle %> - Everything2.com</title>
<& helpers/stylesheets.mi, stylesheets => $.stylesheets &>
<& helpers/customstyle.mi, customstyle => $.customstyle &>
<meta name="description" content="<% $.metadescription %>" />
<link rel="icon" href="/favicon.ico" type="image/vnd.microsoft.icon">
<!--[if lt IE 8]><link rel="shortcut icon" href="/favicon.ico" type="image/x-icon"><![endif]-->
</head>
<body class="<% $.bodyclass %>" itemscope itemtype="http://schema.org/WebPage">
<% $.zenadheader %>
<div id='header'><!-- begin header -->
<div id='e2logo'><a href="/">Everything<span id="e2logo2">2</span></a></div>
</div><!-- end header -->
<div id='wrapper'>
<!-- nodelets -->
<% $.nodelets %>
<!-- end nodelets -->
<% inner() %>
</div><!-- end wrapper -->
<div id='footer'>
Everything2 &trade; is brought to you by Everything2 Media, LLC. All content copyright &#169; original author unless stated otherwise.
% if(defined($.footergibberish)) {
<br /><i><% $.footergibberish %></i>
% }
</div><!-- end footer --->
<% $.static_javascript %>
<& helpers/googleanalytics.mi &>
</body>
</html>
</%augment>
