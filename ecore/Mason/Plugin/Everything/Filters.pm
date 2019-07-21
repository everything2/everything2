package Mason::Plugin::Everything::Filters;

# Perl critic bug
## no critic (RequireUseStrict,RequireUseWarnings,RequireEndWithOne)

use Mason::PluginRole;
require Everything;
require Date::Format;
require Date::Parse;

method ParseLinks ($lastnode) {
  return sub {
    $Everything::APP->parseLinks($_[0], $lastnode);
  }
}

method Obfuscate {
  return sub {
    my $text = shift;
    $text =~ s/([aeiounp])/'&#'.ord($1).';'/eg;
    return $text;
  }
}

method PrettyDate($template) {
  return sub {
    my $time = shift;

    unless($time =~ /^\d+$/)
    {
      $time = Date::Parse::str2time($time);
    }
    return Date::Format::time2str($template || "%C" ,$time);
  }
}

1;
