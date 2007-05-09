use strict;
use warnings;

package KinoSearch::Schema::FieldSpec;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );
use KinoSearch::Posting::ScorePosting;
use KinoSearch::Search::Similarity;

use constant TRUE  => 1;
use constant FALSE => 0;

sub analyzer     { }
sub similarity   { }
sub boost        {1.0}
sub indexed      {TRUE}
sub stored       {TRUE}
sub analyzed     {TRUE}
sub vectorized   {TRUE}
sub binary       {FALSE}
sub compressed   {FALSE}
sub posting_type {'KinoSearch::Posting::ScorePosting'}
sub sortsub      { }

sub new {
    my $class = shift;
    $class = ref($class) || $class;
    my $self = $class->_new();

    # transfer values to C struct
    $self->_set_boost( $class->boost );
    $self->_set_indexed( $class->indexed );
    $self->_set_stored( $class->stored );
    $self->_set_analyzed( $class->analyzed );
    $self->_set_vectorized( $class->vectorized );
    $self->_set_binary( $class->binary );
    $self->_set_compressed( $class->compressed );
    my $posting_class = $class->posting_type;
    my $sim = $class->similarity || KinoSearch::Search::Similarity->new;
    $self->_set_posting( $posting_class->new( similarity => $sim ) );

    return $self;
}

sub get_singleton {
    my $class = shift;
    my $singleton_ref;
    {
        no strict 'refs';
        $singleton_ref = \${ $class . '::kino_singleton' };
    }
    $$singleton_ref ||= $class->new;
    return $$singleton_ref;
}

1;

__END__

__XS__

MODULE = KinoSearch   PACKAGE = KinoSearch::Schema::FieldSpec

kino_FieldSpec*
_new(class_name)
    const classname_char *class_name;
CODE:
    RETVAL = kino_FSpec_new(class_name);
OUTPUT: RETVAL

void
_set_or_get(self, ...)
    kino_FieldSpec *self;
ALIAS:
    _set_boost             = 1
    _set_indexed           = 3
    _set_stored            = 5
    _set_analyzed          = 7
    _set_vectorized        = 9
    _set_binary            = 11
    _get_binary            = 12
    _set_compressed        = 13
    _set_posting           = 15
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 1:  self->boost = SvNV( ST(1) );
             break;

    case 3:  self->indexed = SvTRUE( ST(1) );
             break;

    case 5:  self->stored = SvTRUE( ST(1) );
             break;

    case 7:  self->analyzed = SvTRUE( ST(1) );
             break;

    case 9:  self->vectorized = SvTRUE( ST(1) );
             break;

    case 11: self->binary = SvTRUE( ST(1) );
             break;

    case 12: retval = newSViv(self->binary);
             break;

    case 13: self->compressed = SvTRUE( ST(1) );
             break;
    
    case 15: if (self->posting != NULL)
                REFCOUNT_DEC(self->posting);
             EXTRACT_STRUCT( ST(1), self->posting, kino_Posting*, 
                "KinoSearch::Posting");
             REFCOUNT_INC(self->posting);
             break;

    END_SET_OR_GET_SWITCH
}
    

__POD__

=head1 NAME 

KinoSearch::Schema::FieldSpec - Define a field's behavior.

=head1 SYNOPSIS

Define your custom subclass:

    package MySchema::UnAnalyzed;
    use base qw( KinoSearch::Schema::FieldSpec )
    sub analyzed { 0 }

Then, arrange for your subclass of KinoSearch::Schema to load it.

    package MySchema;
    use base qw( KinoSearch::Schema );

    our %fields = (
        name  => 'KinoSearch::Schema::FieldSpec',
        price => 'MySchema::UnAnalyzed',
    );

=head1 DESCRIPTION

A FieldSpec defines a set of traits and behaviors which may be associated with
one or more field names.  If the default behaviors are not appropriate for a
given field, FieldSpec may be subclassed.

=head1 CLASS METHODS

=head2 indexed

Returns a boolean indicating whether the field should be indexed, so that it
can be searched later.  Default true.

=head2 analyzed 

Returns a boolean indicating whether to analyze the field using the relevant
L<Analyzer|KinoSearch::Analysis::Analyzer>.  Default true.

Fields such as "category" or "product_number" might be indexed but not analyzed.

=head2 stored

Returns a boolean indicating whether to store the raw field value, so that it
can be retrieved when the document turns up in a search. Default true.

=head2 compressed

Returns a boolean indicating whether to compress the stored field, using the
zlib compression algorithm.  Default false.

=head2 vectorized

Returns a boolean indication whether to store the field's "term vectors",
which are required by L<KinoSearch::Highlight::Highlighter> for excerpt
selection and search term highlighting.  Default true.

Term vectors require a fair amount of space, so you should turn this off if
you don't need it.

=head2 boost

Returns a  multiplier which determines how much a field contributes to a
document's score.  Default 1.0.

=head2 analyzer

By default, analyzer() has no return value, which indicates that the Schema's
default analyzer should be used for this field.  If you want a given field to
use a different analyzer, override this method and have it return an object
which isa L<KinoSearch::Analysis::Analyzer>.

=head2 similarity

I<Expert API.>  Returns nothing by default.  Override it if you want this
field to use a custom subclass of L<KinoSearch::Search::Similarity>, rather
than the Schema's default.

=head2 posting_type 

EXPERIMENTAL - the capacity to specify different posting types is not going
away, but the interface is likely to change.

I<Expert API.>  Indicates what subclass of L<Posting|KinoSearch::Posting> the
field should use.  The default is the general-purpose
L<KinoSearch::Posting::ScorePosting>.  Boolean (true/false only) fields might
use L<KinoSearch::Posting::MatchPosting>.  To override, supply a class name
which isa KinoSearch::Posting.

=head1 COPYRIGHT

Copyright 2005-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut
