package Everything::node;

sub new
{
	my ($class, $data) = @_;
	return bless $data,$class;
}

1;
