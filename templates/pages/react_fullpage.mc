<%flags>
extends => undef
</%flags>
<%class>
has 'e2' => (is => 'ro', required => 1);
has 'REQUEST' => (is => 'ro', required => 1);
has 'node' => (is => 'ro', required => 1);
</%class>
<%init>
# Get theme from e2 object (already built by buildNodeInfoStructure)
my $theme = $.e2->{basesheet} || '/css/1882070.css';
</%init>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title><% $.node->title %> - Everything2.com</title>
  <link rel="stylesheet" href="<% $theme %>">
</head>
<body>
  <div id="e2-react-page-root"></div>
  <div id="e2-react-root"></div>
<%perl>
use JSON;
my $json = JSON->new->allow_nonref;  # Don't use ->utf8 to avoid double-encoding
my $e2_json = $json->encode($.e2);
</%perl>
  <script>
    window.e2 = <% $e2_json %>;
  </script>
  <script src="/react/main.bundle.js"></script>
</body>
</html>
