package Mason::Plugin::Everything::Filters;

# Perl critic bug
## no critic (RequireUseStrict,RequireUseWarnings,RequireEndWithOne)

use Mason::PluginRole;
require Everything;

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

1;
