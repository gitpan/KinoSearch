package KinoSearch::Search::HitDoc;
use strict;
use warnings;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

BEGIN {
    __PACKAGE__->init_instance_vars(
        doc_num => undef,
        score   => undef,
        doc     => undef,
    );
    __PACKAGE__->ready_get_set(qw( doc_num score doc ));
}

1;

__END__

=begin devdocs

=head1 NAME

KinoSearch::Search::HitDoc - successful match for a Query

=head1 DESCRIPTION 

Storage vessel which holds a Doc, a score, and a doc number.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.10.

=end devdocs

=cut

