use strict;
use warnings;

package KinoSearch::QueryParser;
use KinoSearch::Util::ToolSet;
use KinoSearch::Util::StringHelper qw( utf8ify );
use base qw( KinoSearch::Util::Class );

our %instance_vars = (
    # constructor params / members
    schema         => undef,
    default_boolop => 'OR',
    fields         => undef,
    analyzer       => undef,

    # members
    heed_colons   => 0,
    bool_groups   => undef,
    phrases       => undef,
    bool_group_re => undef,
    phrase_re     => undef,
    label_inc     => 0,
);

BEGIN { __PACKAGE__->ready_set(qw( heed_colons )) }

use KinoSearch::Analysis::TokenBatch;
use KinoSearch::Analysis::Tokenizer;
use KinoSearch::Search::BooleanQuery;
use KinoSearch::Search::PhraseQuery;
use KinoSearch::Search::TermQuery;
use KinoSearch::Index::Term;

sub init_instance {
    my $self = shift;
    $self->{bool_groups} = {};
    $self->{phrases}     = {};

    confess("default_boolop must be either 'AND' or 'OR'")
        unless $self->{default_boolop} =~ /^(?:AND|OR)$/;

    # create a random string that presumably won't appear in a search string
    my @chars      = ( 'A' .. 'Z' );
    my $randstring = '';
    $randstring .= $chars[ rand @chars ] for ( 1 .. 16 );
    $self->{randstring} = $randstring;

    # create labels which won't appear in search strings
    $self->{phrase_re}     = qr/^(_phrase$randstring\d+)/;
    $self->{bool_group_re} = qr/^(_boolgroup$randstring\d+)/;

    # verify schema
    confess("Missing required parameter 'schema'")
        unless a_isa_b( $self->{schema}, "KinoSearch::Schema" );

    # verify or create fields param
    if ( !defined $self->{fields} ) {
        my $schema = $self->{schema};
        my @fields = grep { $schema->fetch_fspec($_)->indexed }
            $self->{schema}->all_fields;
        $self->{fields} = \@fields;
    }
    confess("Required parameter 'fields' not supplied as arrayref")
        unless reftype( $self->{fields} ) eq 'ARRAY';
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
    my ( $self, $qstring_orig, $default_fields ) = @_;

    $qstring_orig = '' unless defined $qstring_orig;
    utf8ify($qstring_orig);
    $default_fields ||= $self->{fields};
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
        my $fields = $default_fields;
        if ( $self->{heed_colons} and s/^$field_re// ) {
            $fields = [$1];
        }

        # if a phrase label is detected...
        if (s/$self->{phrase_re}//) {
            # retreive the text and analyze it
            my $orig_phrase_text = delete $self->{phrases}{$1};
            my $query = $self->_get_field_query( $fields, $orig_phrase_text );
            push @clauses, { query => $query, occur => $occur }
                if defined $query;
        }
        # if a label indicating a bool group is detected...
        elsif (s/$self->{bool_group_re}//) {
            # parse boolean subqueries recursively
            my $inner_text = delete $self->{bool_groups}{$1};
            my $query = $self->parse( $inner_text, $fields );
            push @clauses, { query => $query, occur => $occur };
        }
        # what's left is probably a term
        elsif (s/([^"(\s]+)//) {
            my $query = $self->_get_field_query( $fields, $1 );
            push @clauses, { occur => $occur, query => $query }
                if defined $query;
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

# Wrap a TermQuery/PhraseQuery to deal with multiple fields.
sub _get_field_query {
    my ( $self, $fields, $text ) = @_;
    my $supplied_analyzer = $self->{analyzer};
    my $schema            = $self->{schema};

    my @queries;
    for my $field (@$fields) {
        # custom analyze for each field unless override
        my $analyzer
            = defined $supplied_analyzer
            ? $supplied_analyzer
            : $schema->fetch_analyzer($field);

        # extract token texts
        my @token_texts;
        my $analyzed = 1;
        if ( defined $schema ) {
            my $fspec = $schema->fetch_fspec($field);
            if ( defined $fspec and !$fspec->analyzed ) {
                $analyzed = 0;
            }
        }
        if ($analyzed) {
            @token_texts = grep {length} $analyzer->analyze_raw($text);
        }
        else {
            @token_texts = ($text);
        }

        my $query = $self->_gen_single_field_query( $field, \@token_texts );
        push @queries, $query if defined $query;
    }

    if ( @queries == 0 ) {
        return;
    }
    elsif ( @queries == 1 ) {
        return $queries[0];
    }
    else {
        my $wrapper_query = KinoSearch::Search::BooleanQuery->new;
        for my $query (@queries) {
            $wrapper_query->add_clause(
                query => $query,
                occur => 'SHOULD',
            );
        }
        return $wrapper_query;
    }
}

# Create a TermQuery, a PhraseQuery, or nothing.
sub _gen_single_field_query {
    my ( $self, $field, $token_texts ) = @_;

    if ( @$token_texts == 1 ) {
        my $term = KinoSearch::Index::Term->new( $field, $token_texts->[0] );
        return KinoSearch::Search::TermQuery->new( term => $term );
    }
    elsif ( @$token_texts > 1 ) {
        my $phrase_query = KinoSearch::Search::PhraseQuery->new;
        for my $token_text (@$token_texts) {
            $phrase_query->add_term(
                KinoSearch::Index::Term->new( $field, $token_text ),
            );
        }
        return $phrase_query;
    }

    return;
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

KinoSearch::QueryParser - Transform a string into a Query object.

=head1 SYNOPSIS

    my $query_parser = KinoSearch::QueryParser->new(
        schema => MySchema->new,
        fields => [ 'body' ],
    );
    my $query = $query_parser->parse( $query_string );
    my $hits  = $searcher->search( query => $query );

=head1 DESCRIPTION

The QueryParser accepts UTF-8 search strings as input and produces Query
objects, suitable for feeding into L<KinoSearch::Searcher>.

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

=back

Additionally, the following syntax can be enabled via set_heed_colons():

=over

=item *

Field-specific terms, in the form of C<fieldname:termtext>.  (The field
specified by fieldname will be used instead of the QueryParser's default
fields).

A field can also be given to a logical group, in which case it is the same as
if the field had been prepended onto every term in the group.  For example:
C<foo:(bar baz)> is the same as C<foo:bar foo:baz>.

=back

=head1 METHODS

=head2 new

    my $query_parser = KinoSearch::QueryParser->new(
        schema         => MySchema->new,   # required
        analyzer       => $analyzer,       # overrides schema
        fields         => [ 'bodytext' ],  # default: indexed fields
        default_boolop => 'AND',           # default: 'OR'
    );

Constructor.  Takes hash-style parameters.  Either C<searchable> or C<analyzer>
must be supplied.

=over

=item *

B<schema> - An object which subclasses L<KinoSearch::Schema>.

=item *

B<analyzer> - An object which subclasses L<KinoSearch::Analysis::Analyzer>.
Ordinarily, the analyzers specified by each field's definition will be used,
but if C<analyzer> is supplied, it will override and be used for all fields.
This can lead to mismatches between what is in the index and what is being
searched for, so use caution.

=item *

B<fields> - the names of the fields which will be searched against.  By
default, those fields which are defined as indexed in the supplied Schema.

=item *

B<default_boolop> - two possible values: 'AND' and 'OR'.  The default is 'OR',
which means: return documents which match any of the query terms.  If you
want only documents which match all of the query terms, set this to 'AND'.

=back

=head2 parse

    my $query = $query_parser->parse( $query_string );

Turn a UTF-8 query string into a Query object.  Depending on the contents of
the query string, the returned object could be any one of several subclasses
of L<KinoSearch::Search::Query>.

=head2 set_heed_colons

    $query_parser->set_heed_colons(1); # enable

Enable/disable special parsing of C<foo:bar> constructs.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut
