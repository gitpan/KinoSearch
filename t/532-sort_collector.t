use strict;
use warnings;

use Test::More tests => 1;
use KinoSearch::Test;
use List::Util qw( shuffle );

my $schema = KinoSearch::Schema->new;
my $type = KinoSearch::FieldType::StringType->new( sortable => 1 );
$schema->spec_field( name => 'letter', type => $type );
$schema->spec_field( name => 'number', type => $type );
$schema->spec_field( name => 'id',     type => $type );

my $folder  = KinoSearch::Store::RAMFolder->new;
my $indexer = KinoSearch::Indexer->new(
    index  => $folder,
    schema => $schema,
);

my @letters = 'a' .. 'z';
my @numbers = 1 .. 5;
my @docs    = (
    { letter => 'c', number => '4', id => 1, },
    { letter => 'b', number => '2', id => 2, },
    { letter => 'a', number => '5', id => 3, },
);
for my $id ( 4 .. 100 ) {
    my $doc = {
        letter => $letters[ rand @letters ],
        number => $numbers[ rand @numbers ],
        id     => $id,
    };
    push @docs, $doc;
}
$indexer->add_doc($_) for @docs;
$indexer->commit;

my $polyreader = KinoSearch::Index::IndexReader->open( index => $folder );
my $seg_reader = $polyreader->get_seg_readers->[0];

my $by_letter = KinoSearch::Search::SortSpec->new(
    rules => [
        KinoSearch::Search::SortRule->new( field => 'letter' ),
        KinoSearch::Search::SortRule->new( type  => 'doc_id' ),
    ]
);

my $collector = KinoSearch::Search::HitCollector::SortCollector->new(
    sort_spec => $by_letter,
    schema    => $schema,
    wanted    => 1,
);

$collector->set_reader($seg_reader);
$collector->collect($_) for 1 .. 100;
my $match_docs = $collector->pop_match_docs;
is( $match_docs->[0]->get_doc_id,
    3, "Early doc numbers preferred by collector" );

