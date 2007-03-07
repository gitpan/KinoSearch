use strict;
use warnings;

package KinoSearch::Schema;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

use KinoSearch::InvIndex;
use KinoSearch::Search::Similarity;
use KinoSearch::Util::Hash;
use KinoSearch::Schema::FieldSpec;

#-----------------------------------------------------------------------
# CLASS METHODS
#-----------------------------------------------------------------------

sub analyzer   { shift->abstract_death }
sub similarity { KinoSearch::Search::Similarity->new }

sub new {
    my ( $class, $folder ) = @_;

    # get a primary Similarity and primary analyzer
    my $main_sim         = $class->similarity;
    my $default_analyzer = $class->analyzer;

    # create object
    my $self = $class->_new( $default_analyzer, {}, $main_sim );

    # register all the fields in %FIELDS
    my $fields = _retrieve_FIELDS_hashref( $class . '::FIELDS' );
    confess("Can't find \%$class\::FIELDS hash") unless defined $fields;
    while ( my ( $field_name, $fspec_class ) = each %$fields ) {
        $self->add_field( $field_name, $fspec_class );
    }

    return $self;
}

sub create {
    my ( $class, $path ) = @_;
    return KinoSearch::InvIndex->create(
        schema => $class->new,
        folder => $path,
    );
}

sub clobber {
    my ( $class, $path ) = @_;
    return KinoSearch::InvIndex->clobber(
        schema => $class->new,
        folder => $path,
    );
}

sub open {
    my ( $class, $path ) = @_;
    return KinoSearch::InvIndex->open(
        schema => $class->new,
        folder => $path,
    );
}

#-----------------------------------------------------------------------
# INSTANCE METHODS
#-----------------------------------------------------------------------

my %reserved_names = (
    doc_boost => 1,
    boost     => 1,
    score     => 1,
    excerpt   => 1,
    excerpts  => 1,
);

sub add_field {
    my ( $self, $field_name, $fspec_class ) = @_;

    # validate
    confess('Usage: $schema->add_field( $field_name, $field_class')
        unless @_ == 3;
    confess("'$field_name' is reserved for internal use")
        if $reserved_names{$field_name};
    confess("Field names beginning with 'kino' are reserved")
        if $field_name =~ /^kino/i;

    if ( !$fspec_class->isa('KinoSearch::Schema::FieldSpec') ) {
        confess(  "'$fspec_class' either isn't loaded or isn't a "
                . "KinoSearch::Schema::FieldSpec" );
    }

    # if the field already has an association, verify pairing and return
    my $current = $self->fetch_fspec($field_name);
    if ($current) {
        return if $fspec_class eq ref($current);
        confess(  "'$field_name' assigned to '$fspec_class', "
                . "which conflicts with '$current'" );
    }

    # add the association to the object
    $self->_add_field( $field_name, $fspec_class->get_singleton );

    # associate an analyzer if the FieldSpec subclass provides one
    if ( $fspec_class->analyzed ) {
        my $analyzer = $fspec_class->analyzer;
        if ( defined $analyzer ) {
            my $analyzers = $self->_get_analyzers;
            $analyzers->{$field_name} = $analyzer;
        }
    }

    # associate a Similarity if the FieldSpec subclass provides one
    my $sim = $fspec_class->similarity;
    if ( defined $sim ) {
        my $sims = $self->_get_sims;
        $sims->store( $field_name, $sim );
    }
}

sub num_fields {
    my $self = shift;
    return $self->get_fspecs->get_size;
}

1;

__END__

__XS__

MODULE = KinoSearch     PACKAGE = KinoSearch::Schema

kino_Schema*
_new(class, analyzer, analyzers, sim)
    const classname_char *class;
    SV *analyzer;
    SV *analyzers;
    kino_Similarity *sim;
CODE:
    RETVAL = kino_Schema_new(class, analyzer, analyzers, sim);
OUTPUT: RETVAL

SV*
_retrieve_FIELDS_hashref(name)
	const char *name;
CODE:
{
	HV* fields_hash = get_hv(name, 0);
	RETVAL = fields_hash == NULL
		? newSV(0)
		: newRV_inc((SV*)fields_hash);
}
OUTPUT: RETVAL

void
_set_or_get(self, ...)
    kino_Schema *self;
ALIAS:
    get_fspecs         = 2
    _get_analyzers     = 4
    _get_sims          = 6
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 2:  retval = kobj_to_pobj(self->fspecs);
             break;

    case 4:  retval = newSVsv(self->analyzers);
             break;

    case 6:  retval = kobj_to_pobj(self->sims);
             break;

    END_SET_OR_GET_SWITCH
}

SV*
fetch_analyzer(self, ...)
    kino_Schema *self;
CODE:
{
    RETVAL = NULL;

    /* get a registered analyzer if there is one */
    if (items == 2 && self->analyzers != NULL) {
        HV *analyzers_hash = (HV*)SvRV((SV*)self->analyzers);
        HE *entry = hv_fetch_ent(analyzers_hash, ST(1), 0, 0);
        if (entry != NULL) {
            SV *const analyzer_sv = HeVAL(entry);
            if SvOK(analyzer_sv) {
                RETVAL = newSVsv( HeVAL(entry) );
            }
        }
    }

    /* get main analyzer if we didn't haven't got one yet */
    if (RETVAL == NULL) { 
        RETVAL = self->analyzer == NULL
            ? newSV(0)
            : newSVsv(self->analyzer);
    }
}
OUTPUT: RETVAL
    
void
_add_field(self, field_name, fspec)
    kino_Schema *self;
    kino_ByteBuf field_name;
    kino_FieldSpec *fspec;
PPCODE:
    Kino_Schema_Add_Field(self, &field_name, fspec);

SV*
fetch_sim(self, field_name)
    kino_Schema *self;
    kino_ByteBuf field_name;
CODE:
{
    kino_Similarity *sim = Kino_Schema_Fetch_Sim(self, &field_name);
    RETVAL = sim == NULL
        ? newSV(0)
        : kobj_to_pobj(sim); 
}
OUTPUT: RETVAL

SV*
fetch_fspec(self, field_name)
    kino_Schema *self;
    kino_ByteBuf field_name;
CODE:
{
    kino_FieldSpec *field_spec = Kino_Schema_Fetch_FSpec(self, &field_name);
    RETVAL = field_spec == NULL
        ? newSV(0)
        : kobj_to_pobj(field_spec); 
}
OUTPUT: RETVAL

void
all_fields(self)
    kino_Schema *self;
PPCODE:
{
    kino_ByteBuf   *name;
    kino_FieldSpec *field_spec;
    const kino_u32_t num_fields = self->fspecs->size;

    EXTEND(SP, num_fields);

    Kino_Hash_Iter_Init(self->fspecs);
    while (Kino_Hash_Iter_Next(self->fspecs, &name, (kino_Obj**)&field_spec)
    ) {
        SV *const field_name_sv = bb_to_sv(name);
        PUSHs( sv_2mortal(field_name_sv) );
    }
    XSRETURN(num_fields);
}

__POD__

=head1 NAME

KinoSearch::Schema -- User-created specification for an inverted index.

=head1 SYNOPSIS

First, create a subclass of KinoSearch::Schema which describes the structure
of your inverted index.

    package MySchema;
    use base qw( KinoSearch::Schema );
    use KinoSearch::Analysis::PolyAnalyzer;

    our %FIELDS = (
        title   => 'KinoSearch::Schema::FieldSpec',
        content => 'KinoSearch::Schema::FieldSpec',
    );

    sub analyzer { 
        return KinoSearch::Analysis::PolyAnalyzer->new( language => 'en' );
    }

Use the subclass in an indexing script...

    use MySchema;
    my $invindexer = KinoSearch::InvIndexer->new( 
        invindex => MySchema->clobber('/path/to/invindex'),
    );

Use it again at search-time...

    use MySchema;
    my $searcher = KinoSearch::Searcher->new( 
        invindex => MySchema->open('/path/to/invindex')
    );

=head1 DESCRIPTION

A Schema is a blueprint specifying how other entities should interpret the raw
data in an invindex and interact with it.  It's akin to an SQL table
definition, but implemented using only Perl code.

=head2 Subclassing

KinoSearch::Schema is an abstract class.  To use it, you must provide your own
subclass.

Every Schema subclass must meet two requirements: it must declare a %FIELDS
hash, and it must provide an implementation of analyzer().

=head2 Always use the same Schema 

The same Schema must always be used with any given invindex.  If you tell an
L<InvIndexer|KinoSearch::InvIndexer> to build an invindex using a given
Schema, then lie about what the InvIndexer did by supplying your
L<Searcher|KinoSearch::Searcher> with either a modified version or a completely
different Schema, you'll either get incorrect results or a crash.

Once an actual index has been created using a particular Schema, existing
fields may not be associated with new FieldSpec subclasses and their
definitions may not be changed.  However, it is possible to add new fields
during subsequent indexing sessions.

=head1 CLASS VARIABLES

=head2 %FIELDS

Every Schema subclass must declare a C<%FIELDS> hash using C<our> (I<not>
C<my>).  The keys of the hash are field names, and the values must be class
names which identify either L<KinoSearch::Schema::FieldSpec> or a subclass.

    package UnAnalyzedField;
    use base qw( KinoSearch::Schema::FieldSpec );
    sub analyzed { 0 }

    package MySchema;
    use base qw( KinoSearch::Schema );

    our %FIELDS = (
        title   => 'KinoSearch::Schema::FieldSpec',
        content => 'KinoSearch::Schema::FieldSpec',
        url     => 'UnAnalyzedField',
    );

new() uses %FIELDS as a base set when initializing each new object.
Additional fields may be be added subsequently to individual objects using
add_field().

=head1 CLASS METHODS

=head2 analzyer 

    sub analyzer {
        return KinoSearch::Analysis::PolyAnalyzer->new( language => 'en' );
    }

Abstract method.  Implementations must return an object which isa
L<KinoSearch::Analysis::Analyzer>, which will be used to parse and process
field content.  Individual fields can override this default by providing their
own analyzer().

=head2 similarity

    sub similarity { KinoSearch::Contrib::LongFieldSim->new }

By default, returns a L<KinoSearch::Search::Similarity> object.  If you wish
to change scoring behavior by supplying your own subclass of Similarity,
override this method.

=head1 CONSTRUCTOR

=head2 new

    my $schema = MySchema->new;
    my $folder = KinoSearch::RAMFolder->new;
    my $invindex = KinoSearch::InvIndex->create(
        schema => $schema,
        folder => $folder,
    );

new() returns an instance of your schema subclass.

Most of the time, you won't need to call new() explicitly, as it is called
internally by the factory methods described below.

=head1 FACTORY METHODS 

A Schema is just a blueprint, so it's not very useful on its own.  What you
need is an L<InvIndex|KinoSearch::InvIndex> built according to your Schema,
whose content you can manipulate and search.

These three factory methods return an InvIndex object representing an index on
your file system at the filepath you specify.

=head2 create 

    my $invindex = MySchema->create('/path/to/invindex');

Create a directory and initialize a new invindex at the specified location.
Fails if the directory already exists and contains files.  

=head2 clobber

    my $invindex = MySchema->clobber('/path/to/invindex');

Similar to create, but if the specified directory already exists, first
attempts to delete any files within it that look like index files.  

=head2 open

    my $invindex = MySchema->open('/path/to/invindex');

Open an existing invindex for either reading or updating.  All fields which
have ever been defined for this invindex will be loaded/verified via
add_field().

=head1 INSTANCE METHODS

=head2 add_field

    $schema->add_field( foo => 'KinoSearch::Analysis::FieldSpec' );

Add a field to an individual schema object.  

Calling add_field multiple times against the same field name is fine, but the
name of the FieldSpec subclass must always be the same or an exception will be
thrown.

=head1 COPYRIGHT

Copyright 2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut
