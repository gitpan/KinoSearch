use strict;
use warnings;

package KinoSearch::Search::TopDocs;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # constructor args / members
        total_hits => undef,
        score_docs => undef,
        max_score  => undef,
    );
    __PACKAGE__->ready_get_set(qw( total_hits max_score score_docs ));
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

See L<KinoSearch> version 0.20_01.

=end devdocs
=cut


