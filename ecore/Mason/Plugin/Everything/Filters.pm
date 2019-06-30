package Mason::Plugin::Everything::Filters;
use Mason::PluginRole;

method ParseLinks ($lastnode) {
  require Everything;
  return sub {
    return $Everything::APP->parseLinks($_[0], $lastnode);
  }
}

1;
