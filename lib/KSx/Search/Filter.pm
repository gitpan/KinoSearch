use strict;
use warnings;

package KSx::Search::Filter;
BEGIN { our @ISA = qw( KinoSearch::Search::Query ) }
use Carp;
use Storable qw( nfreeze thaw );
use Scalar::Util qw( blessed weaken );
use bytes;
no bytes;

# Inside-out member vars.
our %query;
our %cached_bits;

sub new {
    my ( $either, %args ) = @_;
    my $query = delete $args{query};
    confess("required parameter query is not a KinoSearch::Search::Query")
        unless ( blessed($query)
        && $query->isa('KinoSearch::Search::Query') );
    my $self = $either->SUPER::new(%args);
    $self->_init_cache;
    $query{$$self} = $query;
    $self->set_boost(0);
    return $self;
}

sub DESTROY {
    my $self = shift;
    delete $query{$$self};
    delete $cached_bits{$$self};
    $self->SUPER::DESTROY;
}

sub make_compiler {
    my $self = shift;
    return KSx::Search::FilterCompiler->new( @_, parent => $self );
}

sub serialize {
    my ( $self, $outstream ) = @_;
    $self->SUPER::serialize($outstream);
    my $frozen = nfreeze( $query{$$self} );
    $outstream->write_c32( bytes::length($frozen) );
    $outstream->print($frozen);
}

sub deserialize {
    my ( $self, $instream ) = @_;
    $self->SUPER::deserialize($instream);
    my $len = $instream->read_c32;
    my $frozen;
    $instream->read( $frozen, $len );
    $query{$$self} = thaw($frozen);
    return $self;
}

sub equals {
    my ( $self, $other ) = @_;
    return 0 unless $other->isa(__PACKAGE__);
    return 0 unless $query{$$self}->equals( $query{$$other} );
    return 0 unless $self->get_boost == $other->get_boost;
    return 1;
}

sub to_string {
    my $self = shift;
    return 'Filter(' . $query{$$self}->to_string . ')';
}

sub _bits {
    my ( $self, $seg_reader ) = @_;

    my $cached_bits = $self->_fetch_cached_bits($seg_reader);

    # Fill the cache.
    if ( !defined $cached_bits ) {
        $cached_bits = KinoSearch::Object::BitVector->new(
            capacity => $seg_reader->doc_max + 1 );
        $self->_store_cached_bits( $seg_reader, $cached_bits );

        my $collector = KinoSearch::Search::Collector::BitCollector->new(
            bit_vector => $cached_bits );

        my $polyreader = KinoSearch::Index::PolyReader->new(
            schema      => $seg_reader->get_schema,
            folder      => $seg_reader->get_folder,
            snapshot    => $seg_reader->get_snapshot,
            sub_readers => [$seg_reader],
        );
        my $searcher
            = KinoSearch::Search::IndexSearcher->new( index => $polyreader );

        # Perform the search.
        $searcher->collect(
            query     => $query{$$self},
            collector => $collector,
        );
    }

    return $cached_bits;
}

# Store a cached BitVector associated with a particular SegReader.  Store a
# weak reference to the SegReader as an indicator of cache validity.
sub _store_cached_bits {
    my ( $self, $seg_reader, $bits ) = @_;
    my $pair = { seg_reader => $seg_reader, bits => $bits };
    weaken( $pair->{seg_reader} );
    $cached_bits{$$self}{ $seg_reader->hash_sum } = $pair;
}

# Retrieve a cached BitVector associated with a particular SegReader.  As a
# side effect, clear away any BitVectors which are no longer valid because
# their SegReaders have gone away.
sub _fetch_cached_bits {
    my ( $self, $seg_reader ) = @_;
    my $cached_bits = $cached_bits{$$self};

    # Sweep.
    while ( my ( $hash_sum, $pair ) = each %$cached_bits ) {
        # If weak ref has decomposed into undef, SegReader is gone... so
        # delete.
        next if defined $pair->{seg_reader};
        delete $cached_bits->{$hash_sum};
    }

    # Fetch.
    my $pair = $cached_bits->{ $seg_reader->hash_sum };
    return $pair->{bits} if defined $pair;
    return;
}

# Kill any existing cached filters.
sub _init_cache {
    my $self = shift;
    $cached_bits{$$self} = {};
}

# Testing only.
sub _cached_count {
    my $self = shift;
    return scalar grep { defined $cached_bits{$$self}{$_}{seg_reader} }
        keys %{ $cached_bits{$$self} };
}

package KSx::Search::FilterCompiler;
BEGIN { our @ISA = qw( KinoSearch::Search::Compiler ) }

sub new {
    my ( $class, %args ) = @_;
    $args{similarity} ||= $args{searcher}->get_schema->get_similarity;
    return $class->SUPER::new(%args);
}

sub make_matcher {
    my ( $self, %args ) = @_;
    my $seg_reader = $args{reader};
    my $bits       = $self->get_parent->_bits($seg_reader);
    return KSx::Search::FilterScorer->new(
        bits    => $bits,
        doc_max => $seg_reader->doc_max,
    );
}

package KSx::Search::FilterScorer;
BEGIN { our @ISA = qw( KinoSearch::Search::Matcher ) }

1;

__END__

__BINDING__

Clownfish::Binding::Perl::Class->register(
    parcel            => "KinoSearch",
    class_name        => "KSx::Search::FilterScorer",
    bind_constructors => ["new"],
);

__POD__

=head1 NAME

KSx::Search::Filter - Build a caching filter based on results of a Query.

=head1 SYNOPSIS

    my %category_filters;
    for my $category (qw( sweet sour salty bitter )) {
        my $cat_query = KinoSearch::Search::TermQuery->new(
            field => 'category',
            term  => $category,
        );
        $category_filters{$category} = KSx::Search::Filter->new( 
            query => $cat_query, 
        );
    }
    
    while ( my $cgi = CGI::Fast->new ) {
        my $user_query = $cgi->param('q');
        my $filter     = $category_filters{ $cgi->param('category') };
        my $and_query  = KinoSearch::Search::ANDQuery->new;
        $and_query->add_child($user_query);
        $and_query->add_child($filter);
        my $hits = $searcher->hits( query => $and_query );
        ...

=head1 DESCRIPTION 

A Filter is a L<KinoSearch::Search::Query> subclass that can be used to filter
the results of another Query.  The effect is very similar to simply using the
wrapped inner query, but there are two important differences:

=over

=item

A Filter does not contribute to the score of the documents it matches.  

=item

A Filter caches its results, so it is more efficient if you use it more than
once.

=back

To obtain logically equivalent results to the Filter but avoid the caching,
substitute the wrapped query but use set_boost() to set its C<boost> to 0.

=head1 METHODS

=head2 new

    my $filter = KSx::Search::Filter->new(
        query => $query;
    );

Constructor.  Takes one hash-style parameter, C<query>, which must be an
object belonging to a subclass of L<KinoSearch::Search::Query>.

=head1 BUGS

Filters do not cache when used in a search cluster with KSx::Remote's
SearchServer and SearchClient.

=head1 COPYRIGHT

Copyright 2005-2010 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, etc.

See L<KinoSearch> version 0.30.

=cut
