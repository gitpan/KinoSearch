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

sub analyzer       { shift->abstract_death }
sub similarity     { KinoSearch::Search::Similarity->new }
sub index_interval {128}
sub skip_interval  {16}
sub pre_sort       { }

sub new {
    my $class = shift;

    # retrieve characteristics from perl-space
    my $main_sim         = $class->similarity;
    my $default_analyzer = $class->analyzer;
    my $index_interval   = $class->index_interval;
    my $skip_interval    = $class->skip_interval;

    # create object
    my $self
        = $class->_new( $default_analyzer, {}, $main_sim, $index_interval,
        $skip_interval );

    # register all the fields in %fields
    my $fields = _retrieve_fields_hashref( $class . '::fields' );
    confess("Can't find \%$class\::fields hash") unless defined $fields;
    while ( my ( $field_name, $fspec_class ) = each %$fields ) {
        $self->add_field( $field_name, $fspec_class );
    }

    return $self;
}

sub create {
    my ( $either, $path ) = @_;
    my $self = blessed $either ? $either : $either->new;
    return KinoSearch::InvIndex->create(
        schema => $self,
        folder => $path,
    );
}

sub clobber {
    my ( $either, $path ) = @_;
    my $self = blessed $either ? $either : $either->new;
    return KinoSearch::InvIndex->clobber(
        schema => $self,
        folder => $path,
    );
}

sub open {
    my ( $either, $path ) = @_;
    my $self = blessed $either ? $either : $either->new;
    return KinoSearch::InvIndex->open(
        schema => $self,
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
_new(class, analyzer, analyzers, sim, index_interval, skip_interval)
    const classname_char *class;
    SV *analyzer;
    SV *analyzers;
    kino_Similarity *sim;
    chy_i32_t index_interval;
    chy_i32_t skip_interval;
CODE:
    RETVAL = kino_Schema_new(class, analyzer, analyzers, sim, index_interval,
        skip_interval);
OUTPUT: RETVAL

SV*
_retrieve_fields_hashref(name)
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
fetch_sim(self, ...)
    kino_Schema *self;
CODE:
{
    kino_Similarity *sim = NULL;
    
    if (items > 1) {
        if (SvOK( ST(1) )) {
            kino_ByteBuf field_name;
            SV_TO_TEMP_BB( ST(1), field_name );
            sim = Kino_Schema_Fetch_Sim(self, &field_name); 
        }
    }

    if (sim == NULL)
        sim = self->sim;
    RETVAL = kobj_to_pobj(sim); 
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
    kino_VArray    *field_list = Schema_All_Fields(self);
    const chy_u32_t num_fields = field_list->size;
    chy_u32_t       i;

    EXTEND(SP, num_fields);

    /* copy field list to Perl scalars on stack, return as list */
    for (i = 0; i < num_fields; i++) {
        kino_ByteBuf *name = (kino_ByteBuf*)Kino_VA_Fetch(field_list, i);
        SV *const field_name_sv = bb_to_sv(name);
        PUSHs( sv_2mortal(field_name_sv) );
    }
    REFCOUNT_DEC(field_list);

    XSRETURN(num_fields);
}

__POD__

=head1 NAME

KinoSearch::Schema - User-created specification for an inverted index.

=head1 SYNOPSIS

First, create a subclass of KinoSearch::Schema which describes the structure
of your inverted index.

    package MySchema;
    use base qw( KinoSearch::Schema );
    use KinoSearch::Analysis::PolyAnalyzer;

    our %fields = (
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
data in an inverted index and interact with it.  It's akin to an SQL table
definition, but implemented using only Perl code.

=head2 Subclassing

KinoSearch::Schema is an abstract class.  To use it, you must provide your own
subclass.

Every Schema subclass must meet two requirements: it must declare a %fields
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

=head2 %fields

Every Schema subclass must declare a C<%fields> hash using C<our> (I<not>
C<my>).  Each key in the hash is a field name, and each value must be a class
name identifying a class which isa L<KinoSearch::Schema::FieldSpec>.

    package UnAnalyzedField;
    use base qw( KinoSearch::Schema::FieldSpec );
    sub analyzed { 0 }

    package MySchema;
    use base qw( KinoSearch::Schema );

    our %fields = (
        title   => 'KinoSearch::Schema::FieldSpec',
        content => 'KinoSearch::Schema::FieldSpec',
        url     => 'UnAnalyzedField',
    );

new() uses the contents of C<%fields> as a base set when initializing each new
Schema object.  Additional fields may be be added subsequently to individual
objects using add_field().

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

    sub similarity { KSx::Search::LongFieldSim->new }

Expert API.  By default, returns a L<KinoSearch::Search::Similarity> object.
If you wish to change scoring behavior by supplying your own subclass of
Similarity, override this method.

=head2 pre_sort

    sub pre_sort { 
        my %spec  = ( field => 'price', reverse => 1 );
        return \%spec;
    }

Expert, experimental API.  Used only in conjunction with
Searcher->set_prune_factor.  Causes documents to be prioritized for scoring
according to their value for the specified C<field>.  Ordinarily all documents
are scored so the sort order is immaterial, but if you stop sooner -- that is,
when search results are "pruned" -- the sort order matters.

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
your file system at the filepath you specify.  If they are invoked as instance
methods by Schema object, they use that object; when invoked as class methods,
a new Schema instance is created.

=head2 create 

    my $invindex = MySchema->create('/path/to/invindex');
    my $invindex = $schema->create('/path/to/invindex');

Create a directory and initialize a new invindex at the specified location.
Fails if the directory already exists and contains files.  

=head2 clobber

    my $invindex = MySchema->clobber('/path/to/invindex');
    my $invindex = $schema->clobber('/path/to/invindex');

Similar to create, but if the specified directory already exists, first
attempts to delete any files within it that look like index files.  

=head2 open

    my $invindex = MySchema->open('/path/to/invindex');
    my $invindex = $schema->open('/path/to/invindex');

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
