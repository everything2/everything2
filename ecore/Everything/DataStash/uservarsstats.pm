package Everything::DataStash::uservarsstats;

use Moose;
use namespace::autoclean;
extends 'Everything::DataStash';

has '+manual' => (default => 1);

sub generate
{
  my ($this) = @_;
  my $csr = $this->DB->sqlSelectMany("node_id","node","type_nodetype=".$this->DB->getType("user")->{node_id});

  my $vars_stats = {};
  my $users_with_bad_keydata = [];
  while (my $row = $csr->fetchrow_arrayref)
  {
    my $u = $this->DB->getNodeById($row->[0]);
    my $v = Everything::getVars($u);

    foreach my $key (keys %$v)
    {
      if($key =~ /\%/ or $key =~ /^\d+$/ or $key =~ /\n/ or $key =~ /\s/ or $key eq '' or length($key) <= 2)
	  {
        push @$users_with_bad_keydata, $row->[0];
      }else{
        $vars_stats->{$key} ||= 0;
        $vars_stats->{$key}++;
      }
    }
  }

  return $this->SUPER::generate([{"stats" => $vars_stats,"users_with_bad_keydata" => $users_with_bad_keydata}]);
}


__PACKAGE__->meta->make_immutable;
1;
