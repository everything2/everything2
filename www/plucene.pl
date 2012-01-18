#!/usr/bin/perl -w


use Plucene::Document::Field;
use Plucene::Analysis::SimpleAnalyzer;
use Plucene::Index::Writer;
use Plucene::QueryParser;
use Plucene::Search::IndexSearcher;
use Plucene::Search::HitCollector;

my $str;

my $doc = Plucene::Document->new;
        $doc->add(Plucene::Document::Field->Text(content => "testing testing"));
        $doc->add(Plucene::Document::Field->Text(author => "kthejoker"));

my $analyzer = Plucene::Analysis::SimpleAnalyzer->new();
        my $writer = Plucene::Index::Writer->new("my_index", $analyzer, 1);

        $writer->add_document($doc);
        undef $writer; # close

 my $parser = Plucene::QueryParser->new({
                analyzer => Plucene::Analysis::SimpleAnalyzer->new(),
                default  => "text" # Default field for non-specified queries
        });
        my $query = $parser->parse('author:"kthejoker"');

my $searcher = Plucene::Search::IndexSearcher->new("my_index");

        my @docs;
        my $hc = Plucene::Search::HitCollector->new(collect => sub {
                my ($self, $doc, $score) = @_;
                push @docs, $searcher->doc($doc);
        });

        $searcher->search_hc($query => $hc);

foreach (@docs) {
$str.= $_;
}

print $str;
