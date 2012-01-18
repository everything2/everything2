use Everything;
use DBI;
use Plucene::Simple;
use Everything::HTML;

initEverything "everything";

my $plucy = Plucene::Simple->open("my_index");

$plucy->optimize();

print "done";
