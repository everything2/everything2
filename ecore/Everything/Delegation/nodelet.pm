package Everything::Delegation::nodelet;

use strict;
use warnings;

BEGIN {
  *getVars = *Everything::HTML::getVars;
  *linkNode = *Everything::HTML::linkNode;
  *htmlcode = *Everything::HTML::htmlcode;
  *parseLinks = *Everything::HTML::parseLinks;
  *getRef = *Everything::HTML::getRef;
  *linkNodeTitle = *Everything::HTML::linkNodeTitle;
}

sub epicenter
{
  return '';
}

sub new_writeups
{
  return '';
}

sub other_users
{
  return '';
}

sub sign_in
{
  return '';
}

sub recommended_reading
{
  return '';
}

sub vitals
{
  return '';
}

sub chatterbox
{
  # React-based chatterbox - all rendering handled by React component
  return '';
}

sub personal_links
{
  return '';
}

sub random_nodes
{
  return '';
}

sub everything_developer
{
  return '';
}

sub statistics
{
  return '';
}

sub readthis
{
  return '';
}

sub notelet
{
  return '';
}

sub recent_nodes
{
  return '';
}

sub master_control
{
  return '';
}

sub current_user_poll
{
  return '';
}

sub favorite_noders
{
  return '';
}

sub new_logs
{
  return '';
}

sub usergroup_writeups
{
  return '';
}

sub notifications
{
  # React-based notifications nodelet - all rendering handled by React component
  return '';
}

sub categories
{
  return '';
}

sub most_wanted
{
  return '';
}

sub messages
{
  # React-based messages nodelet - all rendering handled by React component
  return '';
}

sub neglected_drafts
{
  return '';
}

sub for_review
{
  # React-based for_review nodelet - all rendering handled by React component
  return '';
}

sub quick_reference
{
  return '';
}

1;
