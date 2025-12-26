<%flags>
extends => undef
</%flags>
<%class>
has 'e2' => (is => 'ro', required => 1);
has 'REQUEST' => (is => 'ro', required => 1);
has 'node' => (is => 'ro', required => 1);
</%class>
<%init>
use JSON;
my $json = JSON->new->allow_nonref;  # Don't use ->utf8 to avoid double-encoding
my $e2_json = $json->encode($.e2);

# Get stylesheet URLs from database nodes (like Controller.pm does)
my $APP = $.REQUEST->APP;
my $VARS = $.REQUEST->user->VARS;

my $basesheet_node = $APP->node_by_name("basesheet", "stylesheet");
my $zensheet_node = $.REQUEST->user->style;
my $printsheet_node = $APP->node_by_name("print", "stylesheet");

my $basesheet = $basesheet_node->cdn_link;
my $zensheet = $zensheet_node->cdn_link;
my $printsheet = $printsheet_node->cdn_link;
my $favicon = "/static/favicon.ico";
</%init>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">

<html lang="en">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<meta name="description" content="Everything2 is a community for fiction, nonfiction, poetry, reviews, and more. Encyclopedic articles on all subjects, written by a community of volunteer authors.">
<title>Everything2</title>
<link rel="stylesheet" id="basesheet" type="text/css" href="<% $basesheet %>" media="all">
<link rel="stylesheet" id="zensheet" type="text/css" href="<% $zensheet %>" media="screen,tv,projection">
% if (exists($VARS->{customstyle}) && defined($VARS->{customstyle})) {
    <style type="text/css">
<% $APP->htmlScreen($VARS->{customstyle}) %>
    </style>
% }
    <link rel="stylesheet" id="printsheet" type="text/css" href="<% $printsheet %>" media="print">
    <link rel="icon" href="<% $favicon %>" type="image/vnd.microsoft.icon">
    <!--[if lt IE 8]><link rel="shortcut icon" href="<% $favicon %>" type="image/x-icon"><![endif]-->
    <link rel="alternate" type="application/atom+xml" title="Everything2 New Writeups" href="/node/ticker/New+Writeups+Atom+Feed">
    <script async src="https://www.googletagmanager.com/gtag/js?id=G-2GBBBF9ZDK"></script>
</head>



<body class="fullpage" id="guestfrontpage">
    <div class="headerads">
        <center>
        <script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-0613380022572506"
             crossorigin="anonymous"></script>
        <ins class="adsbygoogle"
             style="display:inline-block;width:728px;height:90px"
             data-ad-client="ca-pub-0613380022572506"
             data-ad-slot="9636638260"></ins>
        <script>
             (adsbygoogle = window.adsbygoogle || []).push({});
        </script>
        </center>
    </div>
    <div id="header">
           <div id="e2logo"><a href="/title/About+Everything2">Everything<span id="e2logo2">2</span></a></div>
<h2 id='tagline'><a href="/title/Everything2+Help">Read with us. Write for us.</a></h2>
    </div>
<div id='wrapper'>
    <div id='mainbody'>

<div id="e2-react-page-root"></div>

</div>
<div id='sidebar' class="pagenodelets">
<div id="e2-react-root"></div>
</div>

</div>
<div id='footer'>
 Everything2 &trade; is brought to you by Everything2 Media, LLC. All content copyright &#169; original author unless stated otherwise.
</div>
  <script>
    window.e2 = <% $e2_json %>;
  </script>
  <script src="/react/main.bundle.js"></script>
</body>
</html>
