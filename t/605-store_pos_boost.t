use strict;
use warnings;
use lib 'buildlib';

package MyTokenizer;
use base qw( KinoSearch::Analysis::Analyzer );

sub analyze {
    my ( $self, $batch ) = @_;
    my $new_batch = KinoSearch::Analysis::TokenBatch->new;

    while ( my $token = $batch->next ) {
        for ( $token->get_text ) {
            my $this_time = /z/ ? 1 : 0;
            # accumulate token start_offsets and end_offsets
            my ( @starts, @ends, @boosts );
            while (/(\w)/g) {
                push @starts, $-[0];
                push @ends,   $+[0];

                # special boost just for one doc
                if ( $1 eq 'a' and $this_time ) {
                    push @boosts, 100;
                }
                else {
                    push @boosts, 1;
                }
            }

            $new_batch->add_many_tokens( $_, \@starts, \@ends, \@boosts );
        }
    }

    return $new_batch;
}

package MySchema::plain;
use base qw( KinoSearch::Schema::FieldSpec );

package MySchema::boosted;
use base qw( KinoSearch::Schema::FieldSpec );

sub store_pos_boost   {1}
sub store_field_boost {0}

sub analyzer { MyTokenizer->new }

package MySchema;
use base qw( KinoSearch::Schema );
use KinoSearch::Analysis::Tokenizer;

__PACKAGE__->init_fields(qw( plain boosted ));
sub analyzer { KinoSearch::Analysis::Tokenizer->new }

package main;

use KinoTestUtils qw( create_invindex );
use Test::More tests => 2;

use KinoSearch::Searcher;
use KinoSearch::Store::RAMFolder;
use KinoSearch::InvIndexer;
use KinoSearch::Index::Term;
use KinoSearch::Search::TermQuery;

my $good    = "x x x a a x x x x x x x x";
my $better  = "x x x a a a x x x x x x x";
my $best    = "x x x a a a a a a a a a a";
my $boosted = "z x x a x x x x x x x x x";

my $schema   = MySchema->new;
my $folder   = KinoSearch::Store::RAMFolder->new;
my $invindex = KinoSearch::InvIndex->create(
    schema => $schema,
    folder => $folder,
);

my $invindexer = KinoSearch::InvIndexer->new( invindex => $invindex, );

for ( $good, $better, $best, $boosted ) {
    $invindexer->add_doc( { plain => $_, boosted => $_ } );
}
$invindexer->finish;

my $searcher = KinoSearch::Searcher->new( invindex => $invindex );

my $q_for_plain = KinoSearch::Search::TermQuery->new(
    term => KinoSearch::Index::Term->new( plain => 'a' ), );
my $hits = $searcher->search( query => $q_for_plain );
is( $hits->fetch_hit_hashref->{plain},
    $best, "verify that search on unboosted field returns best match" );

my $q_for_boosted = KinoSearch::Search::TermQuery->new(
    term => KinoSearch::Index::Term->new( boosted => 'a' ), );
$hits = $searcher->search( query => $q_for_boosted );
is( $hits->fetch_hit_hashref->{boosted},
    $boosted, "artificially boosted token overrides better match" );

__END__

TODO: {
    local $TODO = "positions not passed to boolscorer correctly yet";
    is_deeply(
        \@contents,
        [ $best, $better, $good ],
        "proximity helps boost scores"
    );
}

