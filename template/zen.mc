<%class>
  has 'NODE' => (isa => 'HashRef', required => 1); #TODO: Do we need this?
  has 'USER' => (isa => 'HashRef', required => 1); #TODO: Do we need this?

  has 'CONF' => (isa => 'HashRef', required => 1);
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

  # Legacy items here until we unwind htmlcodes
  has 'zenadheader' => (isa => 'Str', required => 1);
  has 'static_javascript' => (isa => 'Str', required => 1);
  has 'zensearchform' => (isa => 'Str', required => 1);
  # Renamed slightly, still legacy
  has 'alternate_epicenter' => (isa => 'Maybe[Str]');


  has 'basehref' => (isa => 'Str', required => 1);

  has 'isguest' => (isa => 'Bool', required => 1);
  has 'noindex' => (isa => 'Bool', required => 1, default => 0);

  has 'atomlink' => (isa => 'Str', required => 1, default => "/node/ticker/New+Writeups+Atom+Feed");
  has 'atomtitle' => (isa => 'Str', required => 1, default => "Everything2 New Writeups");

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
<& helpers/basehref.mi, basehref => $.basehref, isguest => $.isguest &>
<& helpers/metarobots.mi, noindex => $.noindex &>
<& helpers/atomlink.mi, atomlink => $.atomlink, atomtitle => $.atomtitle &>
 
<meta name="description" content="<% $.metadescription %>" />
<!--[if lt IE 8]><link rel="shortcut icon" href="/favicon.ico" type="image/x-icon"><![endif]-->
</head>
<body class="<% $.bodyclass %>" itemscope itemtype="http://schema.org/WebPage">
<% $.zenadheader %>
<div id='header'><!-- begin header -->
<% $.alternate_epicenter %>
<% $.zensearchform %>
<div id='e2logo'><a href="/">Everything<span id="e2logo2">2</span></a></div>
</div><!-- end header -->
<div id='wrapper'>
  <div id='mainbody' itemprop="mainContentOfPage">
    <% inner() %>
  </div> <!-- end mainbody -->

  <div id='sidebar'>
    <!-- nodelets -->
    <% $.nodelets %>
    <!-- end nodelets -->
  </div><!-- end sidebar -->

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
