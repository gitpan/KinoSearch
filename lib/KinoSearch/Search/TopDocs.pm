use strict;
use warnings;

package KinoSearch::Search::TopDocs;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

our %instance_vars = (
    # constructor args / members
    total_hits => undef,
    score_docs => undef,
    max_score  => undef,

    # members 
    remotified => 0,
);

BEGIN {
    __PACKAGE__->ready_get_set(
        qw( total_hits max_score score_docs remotified ));
}

use KinoSearch::Util::VArray;
use KinoSearch::Search::RemoteFieldDoc;

# Kludge.  Change FieldDocs to RemoteFieldDocs, to enable sorting with
# MultiSearcher.
sub remotify {
    my ( $self, $sort_spec, $reader ) = @_;
    return if $self->{remotified};
    my $sort_criteria = $sort_spec->get_criteria;
    my @fields        = map { $_->{field} } @$sort_criteria;
    my @sort_caches   = map { $reader->fetch_sort_cache($_) } @fields;
    my @lexicons      = map { $reader->look_up_field($_) } @fields;
    my $num_fields    = scalar @fields;

    my @remote_docs;
    for my $field_doc ( @{ $self->{score_docs} } ) {
        my $doc_num = $field_doc->get_doc_num;
        my $field_vals
            = KinoSearch::Util::VArray->new( capacity => $num_fields );
        for my $i ( 0 .. $#fields ) {
            my $field    = $fields[$i];
            my $term_num = $sort_caches[$i]->get($doc_num);
            my $lexicon  = $lexicons[$i];
            $lexicon->seek_by_num($term_num);
            $field_vals->push(
                KinoSearch::Util::ByteBuf->new(
                    $lexicon->get_term->get_text
                )
            );
        }
        my $remote_doc = KinoSearch::Search::RemoteFieldDoc->new(
            doc_num    => $doc_num,
            score      => $field_doc->get_score,
            field_vals => $field_vals,
        );
        push @remote_docs, $remote_doc;
    }
    $self->{score_docs} = \@remote_docs;
    $self->{remotified} = 1;
}


1;

__END__

__POD__

=begin devdocs

=head1 PRIVATE CLASS

KinoSearch::Search::TopDocs - The top-scoring documents.

=head1 DESCRIPTION

A TopDocs object encapsulates the highest scoring N documents and their
associated scores.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=end devdocs
=cut


