use strict;
use warnings;

package PrefixQuery;
use base qw( KinoSearch::Search::Query );
use Carp;
use Scalar::Util qw( blessed );

# Inside-out member vars and hand-rolled accessors.
my %query_string;
my %field;
sub get_query_string { my $self = shift; return $query_string{$$self} }
sub get_field        { my $self = shift; return $field{$$self} }

sub new {
    my ( $class, %args ) = @_;
    my $query_string = delete $args{query_string};
    my $field        = delete $args{field};
    my $self         = $class->SUPER::new(%args);
    confess("'query_string' param is required")
        unless defined $query_string;
    confess("Invalid query_string: '$query_string'")
        unless $query_string =~ /\*\s*$/;
    confess("'field' param is required")
        unless defined $field;
    $query_string{$$self} = $query_string;
    $field{$$self}        = $field;
    return $self;
}

sub DESTROY {
    my $self = shift;
    delete $query_string{$$self};
    delete $field{$$self};
    $self->SUPER::DESTROY;
}

sub equals {
    my ( $self, $other ) = @_;
    return 0 unless blessed($other);
    return 0 unless $other->isa("PrefixQuery");
    return 0 unless $field{$$self} eq $field{$$other};
    return 0 unless $query_string{$$self} eq $query_string{$$other};
    return 1;
}

sub to_string {
    my $self = shift;
    return "$field{$$self}:$query_string{$$self}";
}

sub make_compiler {
    my $self = shift;
    return PrefixCompiler->new( @_, parent => $self );
}

package PrefixCompiler;
use base qw( KinoSearch::Search::Compiler );

sub make_matcher {
    my ( $self, %args ) = @_;
    my $seg_reader = $args{reader};

    # Retrieve low-level components LexiconReader and PostingsReader.
    my $lex_reader
        = $seg_reader->obtain("KinoSearch::Index::LexiconReader");
    my $post_reader
        = $seg_reader->obtain("KinoSearch::Index::PostingsReader");
    
    # Acquire a Lexicon and seek it to our query string.
    my $substring = $self->get_parent->get_query_string;
    $substring =~ s/\*.\s*$//;
    my $field = $self->get_parent->get_field;
    my $lexicon = $lex_reader->lexicon( field => $field );
    return unless $lexicon;
    $lexicon->seek($substring);
    
    # Accumulate PostingLists for each matching term.
    my @posting_lists;
    while ( defined( my $term = $lexicon->get_term ) ) {
        last unless $term =~ /^\Q$substring/;
        my $posting_list = $post_reader->posting_list(
            field => $field,
            term  => $term,
        );
        if ($posting_list) {
            push @posting_lists, $posting_list;
        }
        last unless $lexicon->next;
    }
    return unless @posting_lists;
    
    return PrefixScorer->new( posting_lists => \@posting_lists );
}

package PrefixScorer;
use base qw( KinoSearch::Search::Matcher );

# Inside-out member vars.
my %doc_ids;
my %tally;
my %tick;

sub new {
    my ( $class, %args ) = @_;
    my $posting_lists = delete $args{posting_lists};
    my $self          = $class->SUPER::new(%args);

    # Cheesy but simple way of interleaving PostingList doc sets.
    my %all_doc_ids;
    for my $posting_list (@$posting_lists) {
        while ( my $doc_id = $posting_list->next ) {
            $all_doc_ids{$doc_id} = undef;
        }
    }
    my @doc_ids = sort { $a <=> $b } keys %all_doc_ids;
    $doc_ids{$$self} = \@doc_ids;

    $tick{$$self}  = -1;
    $tally{$$self} = KinoSearch::Search::Tally->new;
    $tally{$$self}->set_score(1.0);    # fixed score of 1.0

    return $self;
}

sub DESTROY {
    my $self = shift;
    delete $doc_ids{$$self};
    delete $tick{$$self};
    delete $tally{$$self};
    $self->SUPER::DESTROY;
}

sub next {
    my $self    = shift;
    my $doc_ids = $doc_ids{$$self};
    my $tick    = ++$tick{$$self};
    return 0 if $tick >= scalar @$doc_ids;
    return $doc_ids->[$tick];
}

sub get_doc_id {
    my $self    = shift;
    my $tick    = $tick{$$self};
    my $doc_ids = $doc_ids{$$self};
    return $tick < scalar @$doc_ids ? $doc_ids->[$tick] : 0;
}

sub tally {
    my $self = shift;
    return $tally{$$self};
}

1;

__END__

__POD__

=head1 SAMPLE CLASS

PrefixQuery - Sample subclass of KinoSearch::Query, supporting trailing
wildcards.

=head1 SYNOPSIS

    my $prefix_query = PrefixQuery->new(
        field        => 'content',
        query_string => 'foo*',
    );
    my $hits = $searcher->hits( query => $prefix_query );

=head1 DESCRIPTION

Seek L<KinoSearch::Docs::Cookbook::CustomQuery>.

=head1 COPYRIGHT

Copyright 2008-2009 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.30.

=cut
