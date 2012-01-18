use KinoSearch::Searcher;
    use KinoSearch::Analysis::PolyAnalyzer;
    
    my $analyzer
        = KinoSearch::Analysis::PolyAnalyzer->new( language => 'en' );
    
    my $searcher = KinoSearch::Searcher->new(
        invindex => 'my_kino',
        analyzer => $analyzer,
    );
    
    my $hits = $searcher->search( 'Brian Eno' );
    while ( my $hit = $hits->fetch_hit_hashref ) {
        print "$hit->{node_id}\n";
    }
