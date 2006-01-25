package KinoSearch::Search::HitDoc;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

our %instance_vars = __PACKAGE__->init_instance_vars(
    doc_num => undef,
    score   => undef,
    doc     => undef,
);

__PACKAGE__->ready_get_set(qw( doc_num score doc ));

1;

__END__

=begin devdocs

=head1 NAME

KinoSearch::Search::HitDoc - document which matched a Query

=head1 DESCRIPTION 

Storage vessel which holds a Doc, a score, and a doc number.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05_03.

=end devdocs
=cut
