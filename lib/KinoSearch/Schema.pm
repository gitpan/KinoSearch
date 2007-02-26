use strict;
use warnings;

package KinoSearch::Schema;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Obj );

use KinoSearch::InvIndex;
use KinoSearch::Index::IndexFileNames
    qw( WRITE_LOCK_NAME WRITE_LOCK_TIMEOUT unused_files );
use KinoSearch::Search::Similarity;
use KinoSearch::Util::Hash;

# class data -- keyed by class name
our %field_registry;

#-----------------------------------------------------------------------
# CLASS METHODS
#-----------------------------------------------------------------------

my %reserved_names = (
    doc_boost => 1,
    boost     => 1,
    score     => 1,
    excerpt   => 1,
    excerpts  => 1,
);

sub init_fields {
    my ( $class, @field_names ) = @_;

    $field_registry{$class} ||= {};
    my $slot = $field_registry{$class};

    for my $field_name (@field_names) {
        my $field_class = $class . "::$field_name";
        confess("Illegal field name: $field_name")
            unless $field_class =~ /^\w+(::\w+)*$/;
        confess("'$field_name' is reserved for internal use")
            if $reserved_names{$field_name};
        confess("Field names beginning with 'kino' are reserved")
            if $field_name =~ /^kino/i;
        if ( !$field_class->isa('KinoSearch::Schema::FieldSpec') ) {
            confess(  "'$field_class' either isn't loaded or isn't a "
                    . "KinoSearch::Schema::FieldSpec" );
        }

        # add FieldSpec subclass to this Schema subclass's list
        $slot->{$field_name} = $field_class;
    }
}

sub analyzer   { shift->abstract_death }
sub similarity { KinoSearch::Search::Similarity->new }

sub new {
    my ( $class, $folder ) = @_;

    # get a primary Similarity
    my $main_sim = $class->similarity;

    # accumulate a collection of FieldSpec objects and similarity mappings
    my $fspecs = KinoSearch::Util::Hash->new;
    my $sims   = KinoSearch::Util::Hash->new;
    my $slot   = $field_registry{$class};
    confess("No Fields defined for $class") unless defined $slot;
    while ( my ( $field_name, $field_class ) = each %$slot ) {
        my $field_spec = $field_class->new;
        $fspecs->store( $field_name, $field_spec );
        my $sim = $field_class->similarity;
        next unless $sim;
        $sims->store( $field_name, $sim );
    }

    # create object
    my $self = $class->_new( $fspecs, $sims, $main_sim );

    # cache analyzer instances
    my %analyzers;
    my $default_analyzer = $class->analyzer;
    while ( my ( $field_name, $field_class ) = each %$slot ) {
        next unless $field_class->analyzed;
        $analyzers{$field_name} = $field_class->analyzer
            || $default_analyzer;
    }
    $self->_set_main_analyzer($default_analyzer);
    $self->_set_analyzers( \%analyzers );

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

sub num_fields {
    my $self = shift;
    return $self->get_fspecs->get_size;
}

1;

__END__

__XS__

MODULE = KinoSearch     PACKAGE = KinoSearch::Schema

kino_Schema*
_new(class, fspecs, sims, sim)
    const classname_char *class;
    kino_Hash *fspecs;
    kino_Hash *sims;
    kino_Similarity *sim;
CODE:
    RETVAL = kino_Schema_new(class, fspecs, sims, sim);
OUTPUT: RETVAL

void
_set_or_get(self, ...)
    kino_Schema *self;
ALIAS:
    get_fspecs         = 2
    _set_main_analyzer = 3
    _set_analyzers     = 5
PPCODE:
{
    START_SET_OR_GET_SWITCH

    case 2:  retval = kobj_to_pobj(self->fspecs);
             break;

    case 3: SvREFCNT_dec((SV*)self->analyzer);
            self->analyzer = (void*)newSVsv( ST(1) );
            break;

    case 5: SvREFCNT_dec((SV*)self->analyzers);
            self->analyzers = (void*)SvRV( ST(1) );
            SvREFCNT_inc((SV*)self->analyzers);
            break;

    END_SET_OR_GET_SWITCH
}

SV*
fetch_analyzer(self, ...)
    kino_Schema *self;
CODE:
{
    if (items == 1 && self->analyzer != NULL) {
        RETVAL = newSVsv(self->analyzer);
    }
    else if (items == 2 && self->analyzers != NULL) {
        HE *entry = hv_fetch_ent(self->analyzers, ST(1), 0, 0);
        if (entry == NULL) {
            RETVAL = newSV(0);
        }
        else {
            RETVAL = newSVsv( HeVAL(entry) );
        }
    }
    else {
        RETVAL = newSV(0);
    }
}
OUTPUT: RETVAL
    

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
all_fspecs(self)
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
        SV *const fspec_sv = kobj_to_pobj(field_spec);
        PUSHs( sv_2mortal(fspec_sv) );
    }
    XSRETURN(num_fields);
}

__POD__

=head1 NAME

KinoSearch::Schema -- User-created specification for an inverted index.

=head1 SYNOPSIS

First, create a subclass of KinoSearch::Schema which describes the structure
of your inverted index.

    # define fields by subclassing KinoSearch::Schema::FieldSpec

    package MySchema::title;
    use base qw( KinoSearch::Schema::FieldSpec );

    package MySchema::content;
    use base qw( KinoSearch::Schema::FieldSpec );

    # subclass KinoSearch::Schema to finish your specification

    package MySchema;
    use base qw( KinoSearch::Schema );
    use KinoSearch::Analysis::PolyAnalyzer;

    __PACKAGE__->init_fields(qw( title content ));

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

Every Schema subclass must meet two requirements.  It must call
init_fields(), and it must provide an implementation of analyzer().

=head2 Always use the same Schema 

The same Schema must always be used with any given invindex.  If you tell an
L<InvIndexer|KinoSearch::InvIndexer> to build an invindex using a given
Schema, then lie about what the InvIndexer did by supplying your
L<Searcher|KinoSearch::Searcher> with either a modified version or a completely
different Schema, you'll either get incorrect results or a crash.

Once an actual index has been created using a particular Schema, existing
fields may not be removed and their definitions may not be changed.  However,
it is possible to add new fields during subsequent indexing sessions.

=head1 CLASS METHODS

=head2 init_fields

    package MySchema;
    __PACKAGE__->init_fields(qw( title content ));

Takes a list of field names as arguments.  For each field name, KinoSearch
verifies that a corresponding subclass of L<KinoSearch::Schema::FieldSpec> has
been loaded and registers it with the Schema subclass.

The FieldSpec subclass names are derived by combining the Schema's class name
with the field name -- for instance, in the above example they would be named
"MySchema::title" and "MySchema::content".

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

Open an existing invindex for either reading or updating.

=head1 COPYRIGHT

Copyright 2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20_01.

=cut

