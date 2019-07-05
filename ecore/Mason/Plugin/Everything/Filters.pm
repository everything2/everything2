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

method ParseLinks {
  return sub {
    $Everything::APP->parseLinks(@_);
  }
}

1;
