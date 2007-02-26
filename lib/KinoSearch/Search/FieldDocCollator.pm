use strict;
use warnings;

package KinoSearch::Search::FieldDocCollator;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

BEGIN { __PACKAGE__->init_instance_vars() }
our %instance_vars;

our %add_defaults = (
    sort_cache => undef,
    reverse    => 0,
);

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch::Search::FieldDocCollator

kino_FieldDocCollator*
new(...)
CODE:
    KINO_UNUSED_VAR(items);
    RETVAL = kino_FDocCollator_new();
OUTPUT: RETVAL

void
add(self, ...)
    kino_FieldDocCollator *self;
PPCODE:
{
    HV *const args_hash = build_args_hash( &(ST(0)), 1, items,
        "KinoSearch::Search::FieldDocCollator::add_defaults");
    kino_bool_t reverse = 0 != extract_iv(args_hash, SNL("reverse"));
    kino_IntMap *sort_cache = extract_obj(args_hash, SNL("sort_cache"),
        "KinoSearch::Util::IntMap");
    
    kino_FDocCollator_add(self, sort_cache, reverse);
}

__POD__

=begin devdocs

=head1 PRIVATE CLASS 

KinoSearch::Search::FieldDocCollator - IndexReader-specific SortSpec

=head1 DESCRIPTION

FieldDocCollator is an IndexReader-specific realization of SortSpec.  The
relationship is akin to that between Query and Scorer.

SortSpec is implemented in pure Perl for ease of serialization and sending
between SearchServer and SearchClient; FieldDocCollator contains references to
large IntMap objects, and should not be (cannot be) serialized.

=head1 COPYRIGHT

Copyright 2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20_01.

=end devdocs

=cut

