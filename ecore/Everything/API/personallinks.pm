package Everything::API::personallinks;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

## no critic (ProhibitBuiltinHomonyms)

sub routes
{
  return {
  "get" => "get_personal_links",
  "update" => "update_personal_links",
  "add" => "add_current_node",
  "delete/:index" => "delete_link(:index)",
  }
}

sub get_personal_links
{
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;
  my $VARS = $user->VARS;

  # Get the personal_nodelet string and parse it
  my $personal_nodelet = $VARS->{personal_nodelet} || '';
  my @links = split('<br>', $personal_nodelet);

  # Clean up empty entries
  @links = grep { $_ && $_ !~ /^\s*$/ } @links;

  # Calculate total character count
  my $total_chars = 0;
  foreach my $link (@links) {
    $total_chars += length($link);
  }

  # Limits: 20 items OR 1000 characters
  my $item_limit = 20;
  my $char_limit = 1000;

  return [$self->HTTP_OK, {
    links => \@links,
    count => scalar(@links),
    total_chars => $total_chars,
    item_limit => $item_limit,
    char_limit => $char_limit,
  }];
}

sub update_personal_links
{
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;
  my $VARS = $user->VARS;

  # Get POST data
  my $data = $REQUEST->JSON_POSTDATA;
  if (!$data || !exists $data->{links}) {
    return [$self->HTTP_BAD_REQUEST, { error => "Missing links array in request body" }];
  }

  my $links = $data->{links};
  if (ref $links ne 'ARRAY') {
    return [$self->HTTP_BAD_REQUEST, { error => "links must be an array" }];
  }

  # Limits: 20 items OR 1000 characters
  my $item_limit = 20;
  my $char_limit = 1000;

  # Get current state for comparison
  my $current_personal_nodelet = $VARS->{personal_nodelet} || '';
  my @current_links = split('<br>', $current_personal_nodelet);
  @current_links = grep { $_ && $_ !~ /^\s*$/ } @current_links;
  my $current_item_count = scalar(@current_links);
  my $current_char_count = 0;
  foreach my $link (@current_links) {
    $current_char_count += length($link);
  }

  # Process and sanitize new links
  my @clean_links = ();
  my $total_chars = 0;

  foreach my $link (@$links) {
    # Skip empty entries
    next if !defined($link) || $link =~ /^\s*$/;

    # Sanitize: escape brackets
    my $clean = $link;
    $clean =~ s/\[/\&\#91;/g;
    $clean =~ s/\]/\&\#93;/g;

    # Apply htmlScreen for additional sanitization
    $clean = $self->APP->htmlScreen($clean);

    push @clean_links, $clean;
    $total_chars += length($clean);
  }

  my $new_item_count = scalar(@clean_links);

  # Enforce limits with reduction allowance:
  # - If under limits: allow (normal case)
  # - If over limits BUT reducing usage: allow (user is working to get back under)
  # - If over limits AND increasing usage: reject (user is making it worse)

  # Check item limit
  if ($new_item_count > $item_limit) {
    # Over limit - only allow if reducing from current state
    if ($new_item_count > $current_item_count) {
      return [$self->HTTP_BAD_REQUEST, {
        error => "Cannot add more links. You are over the $item_limit item limit. Please remove items to get back under the limit.",
        item_limit => $item_limit,
        current_count => $current_item_count,
        new_count => $new_item_count
      }];
    }
  }

  # Check character limit
  if ($total_chars > $char_limit) {
    # Over limit - only allow if reducing from current state
    if ($total_chars > $current_char_count) {
      return [$self->HTTP_BAD_REQUEST, {
        error => "Cannot add more characters. You are over the $char_limit character limit. Please remove items to get back under the limit.",
        char_limit => $char_limit,
        current_chars => $current_char_count,
        new_chars => $total_chars
      }];
    }
  }

  # Update the user's personal_nodelet variable
  $VARS->{personal_nodelet} = join('<br>', @clean_links);
  $user->set_vars($VARS);

  # Return updated list
  return $self->get_personal_links($REQUEST);
}

sub add_current_node
{
  my ($self, $REQUEST) = @_;

  my $user = $REQUEST->user;
  my $VARS = $user->VARS;

  # Get POST data
  my $data = $REQUEST->JSON_POSTDATA;
  if (!$data || !exists $data->{title}) {
    return [$self->HTTP_BAD_REQUEST, { error => "Missing title in request body" }];
  }

  my $title = $data->{title};
  if (!defined($title) || length($title) == 0) {
    return [$self->HTTP_BAD_REQUEST, { error => "Title cannot be empty" }];
  }

  # Get current links
  my $personal_nodelet = $VARS->{personal_nodelet} || '';
  my @links = split('<br>', $personal_nodelet);
  @links = grep { $_ && $_ !~ /^\s*$/ } @links;

  # Limits: 20 items OR 1000 characters
  my $item_limit = 20;
  my $char_limit = 1000;

  # Calculate current total characters
  my $total_chars = 0;
  foreach my $link (@links) {
    $total_chars += length($link);
  }

  # Sanitize title
  my $clean_title = $title;
  $clean_title =~ s/\[/\&\#91;/g;
  $clean_title =~ s/\]/\&\#93;/g;
  $clean_title = $self->APP->htmlScreen($clean_title);

  my $new_title_length = length($clean_title);

  # Check if we can add more (item limit OR character limit)
  if (scalar(@links) >= $item_limit) {
    return [$self->HTTP_BAD_REQUEST, {
      error => "Cannot add more links. Maximum is $item_limit items.",
      item_limit => $item_limit
    }];
  }

  if (($total_chars + $new_title_length) > $char_limit) {
    return [$self->HTTP_BAD_REQUEST, {
      error => "Cannot add link. Would exceed $char_limit character limit.",
      char_limit => $char_limit,
      current_chars => $total_chars,
      new_title_length => $new_title_length
    }];
  }

  # Add to links
  push @links, $clean_title;

  # Update the user's personal_nodelet variable
  $VARS->{personal_nodelet} = join('<br>', @links);
  $user->set_vars($VARS);

  # Return updated list
  return $self->get_personal_links($REQUEST);
}

sub delete_link
{
  my ($self, $REQUEST, $index) = @_;

  # Validate index
  if (!defined($index) || $index !~ /^\d+$/) {
    return [$self->HTTP_BAD_REQUEST, { error => "Invalid index" }];
  }

  my $user = $REQUEST->user;
  my $VARS = $user->VARS;

  # Get current links
  my $personal_nodelet = $VARS->{personal_nodelet} || '';
  my @links = split('<br>', $personal_nodelet);
  @links = grep { $_ && $_ !~ /^\s*$/ } @links;

  # Validate index is in range
  if ($index < 0 || $index >= scalar(@links)) {
    return [$self->HTTP_BAD_REQUEST, {
      error => "Index out of range",
      count => scalar(@links)
    }];
  }

  # Remove the link at the specified index
  splice(@links, $index, 1);

  # Update the user's personal_nodelet variable
  $VARS->{personal_nodelet} = join('<br>', @links);
  $user->set_vars($VARS);

  # Return updated list
  return $self->get_personal_links($REQUEST);
}

# Require logged-in users (no guests)
around ['get_personal_links', 'update_personal_links', 'add_current_node', 'delete_link'] => \&Everything::API::unauthorized_if_guest;

__PACKAGE__->meta->make_immutable;
1;
