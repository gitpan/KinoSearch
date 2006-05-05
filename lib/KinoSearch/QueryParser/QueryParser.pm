package KinoSearch::QueryParser::QueryParser;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor args / members
        analyzer       => undef,
        default_boolop => 'OR',
        default_field  => undef,
        # members
        bool_groups   => {},
        phrases       => {},
        bool_group_re => undef,
        phrase_re     => undef,
        label_inc     => 0,
    );
}

use KinoSearch::Analysis::TokenBatch;
use KinoSearch::Analysis::Tokenizer;
use KinoSearch::Search::BooleanQuery;
use KinoSearch::Search::PhraseQuery;
use KinoSearch::Search::TermQuery;
use KinoSearch::Index::Term;

sub init_instance {
    my $self = shift;

    croak("default_boolop must be either 'AND' or 'OR'")
        unless $self->{default_boolop} =~ /^(?:AND|OR)$/;

    # create a random string that presumably won't appear in a search string
    my @chars      = ( 'A' .. 'Z' );
    my $randstring = '';
    $randstring .= $chars[ rand @chars ] for ( 1 .. 16 );
    $self->{randstring} = $randstring;

    # create labels which won't appear in search strings
    $self->{phrase_re}     = qr/^(_phrase$randstring\d+)/;
    $self->{bool_group_re} = qr/^(_boolgroup$randstring\d+)/;
}

# regex matching a quoted string
my $quoted_re = qr/
                "            # opening quote
                (            # capture
                    [^"]*?   # anything not a quote
                )
                (?:"|$)      # closed by either a quote or end of string
            /xsm;

# regex matching a parenthetical group
my $paren_re = qr/
                \(           # opening paren
                (            # capture
                    [^()]*?  # anything not a paren
                )
                (?:\)|$)     # closed by paren or end of string
            /xsm;

# regex matching a negating boolean operator
my $neg_re = qr/^(?:
                NOT\s+         # NOT followed by space
                |-(?=\S)       # minus followed by something not-spacey
             )/xsm;

# regex matching a requiring boolean operator
my $req_re = qr/^
                \+(?=\S)       # plus followed by something not-spacey
             /xsm;

# regex matching a field indicator
my $field_re = qr/^
                (              # capture
                    [^"(:\s]+  # non-spacey string
                )
                :              # followed by :
             /xsm;

sub parse {
    my ( $self, $qstring_orig ) = @_;
    $qstring_orig = '' unless defined $qstring_orig;
    my $default_field  = $self->{default_field};
    my $default_boolop = $self->{default_boolop};
    my @clauses;

    # substitute contiguous labels for phrases and boolean groups
    my $qstring = $self->_extract_phrases($qstring_orig);
    $qstring = $self->_extract_boolgroups($qstring);

    local $_ = $qstring;
    while ( bytes::length $_ ) {
        # fast-forward past whitespace
        next if s/^\s+//;

        my $occur = $default_boolop eq 'AND' ? 'MUST' : 'SHOULD';

        if (s/^AND\s+//) {
            if (@clauses) {
                # require the previous clause (unless it's negated)
                if ( $clauses[-1]{occur} eq 'SHOULD' ) {
                    $clauses[-1]{occur} = 'MUST';
                }
            }
            # require this clause
            $occur = 'MUST';
        }
        elsif (s/^OR\s+//) {
            if (@clauses) {
                $clauses[-1]{occur} = 'SHOULD';
            }
            $occur = 'SHOULD';
        }

        # detect tokens which cause this clause to be required or negated
        if (s/$neg_re//) {
            $occur = 'MUST_NOT';
        }
        elsif (s/$req_re//) {
            $occur = 'MUST';
        }

        # set the field
        my $field = s/^$field_re// ? $1 : $default_field;

        # if a phrase label is detected...
        if (s/$self->{phrase_re}//) {
            my $query;

            # retreive the text and analyze it
            my $orig_phrase_text = delete $self->{phrases}{$1};
            my $token_texts      = $self->_analyze($orig_phrase_text);

            # create a TermQuery, a PhraseQuery, or nothing
            if ( @$token_texts == 1 ) {
                my $term = KinoSearch::Index::Term->new( $field,
                    $token_texts->[0] );
                $query = KinoSearch::Search::TermQuery->new( term => $term );
            }
            elsif ( @$token_texts > 1 ) {
                $query = KinoSearch::Search::PhraseQuery->new;
                for my $token_text (@$token_texts) {
                    $query->add_term(
                        KinoSearch::Index::Term->new( $field, $token_text ),
                    );
                }
            }

            push @clauses, { query => $query, occur => $occur }
                if defined $query;
        }
        # if a label indicating a bool group is detected...
        elsif (s/$self->{bool_group_re}//) {
            # parse boolean subqueries recursively
            my $inner_text = delete $self->{bool_groups}{$1};
            my $query      = $self->parse($inner_text);
            push @clauses, { query => $query, occur => $occur };
        }
        # what's left is probably a term
        elsif (s/([^"(\s]+)//) {
            my $token_texts = $self->_analyze($1);
            my @terms = map { KinoSearch::Index::Term->new( $field, $_ ) }
                @$token_texts;
            for my $term (@terms) {
                my $query
                    = KinoSearch::Search::TermQuery->new( term => $term );
                push @clauses, { occur => $occur, query => $query };
            }
        }
    }

    if ( @clauses == 1 and $clauses[0]{occur} ne 'MUST_NOT' ) {
        # if it's just a simple query, return it unwrapped
        return $clauses[0]{query};
    }
    else {
        # otherwise, build a boolean query
        my $bool_query = KinoSearch::Search::BooleanQuery->new;
        for my $clause (@clauses) {
            $bool_query->add_clause(
                query => $clause->{query},
                occur => $clause->{occur},
            );
        }
        return $bool_query;
    }
}

# break a string into tokens
sub _analyze {
    my ( $self, $string ) = @_;

    my $token_batch = KinoSearch::Analysis::TokenBatch->new;
    $token_batch->add_token( $string, 0, bytes::length($string) );
    $token_batch = $self->{analyzer}->analyze($token_batch);
    my @token_texts;
    while ( $token_batch->next ) {
        push @token_texts, $token_batch->get_text;
    }
    return \@token_texts;
}

# replace all phrases with labels
sub _extract_phrases {
    my ( $self, $qstring ) = @_;

    while ( $qstring =~ $quoted_re ) {
        my $label
            = sprintf( "_phrase$self->{randstring}%d", $self->{label_inc}++ );
        $qstring =~ s/$quoted_re/$label /;    # extra space for safety

        # store the phrase text for later retrieval
        $self->{phrases}{$label} = $1;
    }

    return $qstring;
}

# recursively replace boolean groupings with labels, innermost first
sub _extract_boolgroups {
    my ( $self, $qstring ) = @_;

    while ( $qstring =~ $paren_re ) {
        my $label = sprintf( "_boolgroup$self->{randstring}%d",
            $self->{label_inc}++ );
        $qstring =~ s/$paren_re/$label /;    # extra space for safety

        # store the text for later retrieval
        $self->{bool_groups}{$label} = $1;
    }

    return $qstring;
}

1;

__END__

=head1 NAME

KinoSearch::QueryParser::QueryParser - transform a string into a Query object

=head1 SYNOPSIS

    my $query_parser = KinoSearch::QueryParser::QueryParser->new(
        analyzer      => $analyzer,
        default_field => 'bodytext',
    );
    my $query = $query_parser->parse( $query_string );
    my $hits  = $searcher->search( query => $query );

=head1 DESCRIPTION

The QueryParser accepts search strings as input and produces Query objects,
suitable for feeding into L<KinoSearch::Searcher|KinoSearch::Searcher>.

=head2 Syntax

The following constructs are recognized by QueryParser.

=over

=item *

Boolean operators 'AND', 'OR', and 'AND NOT'.

=item *

Prepented +plus and -minus, indicating that the labeled entity should be
either required or forbidden -- be it a single word, a phrase, or a
parenthetical group.

=item *

Logical groups, delimited by parentheses.

=item *

Phrases, delimited by double quotes.

=item *

Field-specific terms, in the form of C<fieldname:termtext>.  (The field
specified by fieldname will be used instead of the QueryParser's default
field).

=back

=head1 METHODS

=head2 new

    my $query_parser = KinoSearch::QueryParser::QueryParser->new(
        analyzer       => $analyzer,      # required
        default_field  => 'bodytext',     # required
        default_boolop => 'AND',          # default: 'OR'
    );

Constructor.  Takes hash-style parameters:

=over

=item *

B<analyzer> - An object which subclasses
L<KinoSearch::Analysis::Analyzer|KinoSearch::Analysis::Analyzer>.  This
B<must> be identical to the Analyzer used at index-time, or the results won't
match up.

=item *

B<default_field> - the name of the (only) field which will be searched
against.  If you need to search multiple fields, you need multiple QueryParser
objects.

=item *

B<default_boolop> - two possible values: 'AND' and 'OR'.  The default is 'OR',
which means: return documents which match any of the query terms.  If you
want only documents which match all of the query terms, set this to 'AND'.

=back

=head2 parse

    my $query = $query_parser->parse( $query_string );

Turn a query string into a Query object.  Depending on the contents of the
query string, the returned object could be any one of several subclasses of
L<KinoSearch::Search::Query|KinoSearch::Search::Query>.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.10.

=cut

