
use DBI;
use strict;
use Plucene::Simple;
use Everything;
use Everything::HTML;
use Time::HiRes;
use CGI;

my @start = Time::HiRes::gettimeofday;
my $tStr;

initEverything "everything", 0, { servers => ["127.0.0.1:11211"] };

my $index_path = "/usr/local/everything/www/my_index";
my $plucy = Plucene::Simple->open($index_path);

my $jw = getNodeById(1786402);
my $latestID = $$jw{doctext};

my $toDo = 100000;

my $writeups = $DB->sqlSelectMany("*","document","document_id>$latestID and (select count(*) from writeup where writeup_id = document_id limit 1)=1 order by document_id limit $toDo");

my $str;

while (my $wu = $writeups->fetchrow_hashref) {
my $dt = $$wu{doctext};
next unless length($dt) > 0;
$plucy->index_document( $$wu{document_id} => $dt);
$str = $$wu{document_id};
}
$plucy->optimize();

$$jw{doctext} = $str;
updateNode($jw,-1);

$str = "\n".Time::HiRes::tv_interval(\@start, [ Time::HiRes::gettimeofday ])."\n";

print $str;
