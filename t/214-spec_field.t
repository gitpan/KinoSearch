use strict;
use warnings;

package MySchema::analyzed;
use base qw( KinoSearch::Schema::FieldSpec );

package MySchema::polyanalyzed;
use base qw( KinoSearch::Schema::FieldSpec );
use KinoSearch::Analysis::PolyAnalyzer;
sub analyzer { KinoSearch::Analysis::PolyAnalyzer->new( language => 'en' ) }

package MySchema::unanalyzed;
use base qw( KinoSearch::Schema::FieldSpec );
sub analyzed {0}
sub analyzer { die "shouldn't get an analyzer for unanalyzed field" }

package MySchema::unindexedbutanalyzed;
use base qw( KinoSearch::Schema::FieldSpec );
sub indexed {0}

package MySchema::unanalyzedunindexed;
use base qw( KinoSearch::Schema::FieldSpec );
sub indexed  {0}
sub analyzed {0}

package MySchema;
use base qw( KinoSearch::Schema );

use KinoSearch::Analysis::Tokenizer;

__PACKAGE__->init_fields(
    qw(
        analyzed
        polyanalyzed
        unanalyzed
        unindexedbutanalyzed
        unanalyzedunindexed
        )
);

sub analyzer { KinoSearch::Analysis::Tokenizer->new }

package main;
use Test::More tests => 10;
use KinoSearch::Store::RAMFolder;
use KinoSearch::InvIndexer;
use KinoSearch::Searcher;
use KinoSearch::Search::TermQuery;
use KinoSearch::Index::Term;

my $folder = KinoSearch::Store::RAMFolder->new;
my $schema = MySchema->new;

my $invindex = KinoSearch::InvIndex->create(
    folder => $folder,
    schema => $schema,
);

my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex );

$invindexer->add_doc( { $_ => 'United States' } ) for qw(
    analyzed
    polyanalyzed
    unanalyzed
    unindexedbutanalyzed
    unanalyzedunindexed
);

$invindexer->finish;

sub check {
    my ( $field_name, $query_text, $expected_num_hits ) = @_;

    my $query = KinoSearch::Search::TermQuery->new(
        term => KinoSearch::Index::Term->new( $field_name, $query_text ), );

    my $searcher = KinoSearch::Searcher->new( invindex => $invindex, );

    my $hits = $searcher->search( query => $query );

    is( $hits->total_hits, $expected_num_hits,
        "$field_name correct num hits " );

    # don't check the contents of the hit if there aren't any
    return unless $expected_num_hits;

    my $hit = $hits->fetch_hit_hashref;
    is( $hit->{$field_name},
        'United States',
        "$field_name correct doc returned"
    );
}

check( 'analyzed',             'States',        1 );
check( 'polyanalyzed',         'state',         1 );
check( 'unanalyzed',           'United States', 1 );
check( 'unindexedbutanalyzed', 'state',         0 );
check( 'unindexedbutanalyzed', 'United States', 0 );
check( 'unanalyzedunindexed',  'state',         0 );
check( 'unanalyzedunindexed',  'United States', 0 );
