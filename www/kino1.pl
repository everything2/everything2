use KinoSearch::InvIndexer;
use KinoSearch::Analysis::PolyAnalyzer;
use Everything;
use DBI;
use strict;
use Everything::HTML;

initEverything "everything";

my $analyzer = KinoSearch::Analysis::PolyAnalyzer->new( language => 'en' );

    my $invindexer = KinoSearch::InvIndexer->new(
        invindex => 'my_kino',
#create => 1,
        analyzer => $analyzer,
    );

    $invindexer->spec_field( 
        name  => 'bodytext',
        boost => 3,
stored => 0
    );
    $invindexer->spec_field( 
        name  => 'node_id' ,
        boost => 1,
	stored => 1,
compressed => 1,
	analyzed => 0,
	indexed => 0
    );

my $jw = getNodeById(1786402);
my $lastIndex = $$jw{doctext};

my $toDo = 10000;

my $wList = $DB->sqlSelectMany("*","document","document_id>$lastIndex and (select count(*) from writeup where writeup_id=document_id limit 1)=1 limit $toDo");


my $newLast;
while (my $wu = $wList->fetchrow_hashref) {

    my $doc = $invindexer->new_doc;

        $doc->set_value( node_id    => $$wu{document_id} );
        $doc->set_value( bodytext => $$wu{doctext} );
        $invindexer->add_doc($doc);
 $newLast = $$wu{document_id};

}

$$jw{doctext} = $newLast;
updateNode($jw,-1);

    $invindexer->finish(optimize => 1);

print $newLast,"done";
