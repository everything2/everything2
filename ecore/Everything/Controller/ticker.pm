package Everything::Controller::ticker;

use Moose;
extends 'Everything::Controller';

sub fully_supports
{
  my ($self, $title) = @_;

  # Convert ticker title to page class name
  my $page_name = $title;
  $page_name =~ s/[\s-]/_/g;
  $page_name =~ s/[^A-Za-z0-9]/_/g;
  $page_name = lc($page_name);

  if($page_name =~ /^\d+$/)
  {
    $page_name = "ticker_$page_name";
  }

  # Check if a Page class exists for this ticker
  my $page_class = "Everything::Page::$page_name";

  # Try to load the class
  my $loaded = eval {
    require_module($page_class);
    1;
  };
  if (!$loaded)
  {
    # Page class doesn't exist, fall back to delegation
    return 0;
  }

  # Page class exists, we can handle it
  return 1;
}

sub require_module
{
  my ($module) = @_;
  (my $file = $module) =~ s|::|/|g;
  require "$file.pm";
  return 1;
}

sub display
{
  my ($self, $REQUEST, $node) = @_;

  # Convert ticker title to page class name
  my $page_name = $node->title;
  $page_name =~ s/[\s-]/_/g;
  $page_name =~ s/[^A-Za-z0-9]/_/g;
  $page_name = lc($page_name);

  if($page_name =~ /^\d+$/)
  {
    $page_name = "ticker_$page_name";
  }

  # Load and instantiate the Page class
  my $page_class = "Everything::Page::$page_name";
  my $loaded = eval {
    require_module($page_class);
    1;
  };
  if (!$loaded)
  {
    # Should never happen since fully_supports checked this
    return [$self->HTTP_NOT_FOUND, "Ticker page class not found"];
  }

  my $page = $page_class->new();
  return $page->display($REQUEST, $node);
}

__PACKAGE__->meta->make_immutable;
1;
