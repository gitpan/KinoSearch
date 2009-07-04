use strict;
use warnings;

package KinoSearch;

use 5.008003;

our $VERSION = '0.30_03';

use XSLoader;
# This loads a large number of disparate subs.
# See the docs for KinoSearch::Util::ToolSet.
BEGIN { XSLoader::load( 'KinoSearch', '0.30_03' ) }

BEGIN {
    push our @ISA, 'Exporter';
    our @EXPORT_OK = qw( kdump );
}

use KinoSearch::Autobinding;

sub kdump {
    require Data::Dumper;
    my $kdumper = Data::Dumper->new( [@_] );
    $kdumper->Sortkeys( sub { return [ sort keys %{ $_[0] } ] } );
    $kdumper->Indent(1);
    warn $kdumper->Dump;
}

{
    package KinoSearch::Util::IndexFileNames;
    BEGIN {
        push our @ISA, 'Exporter';
        our @EXPORT_OK = qw(
            extract_gen
            latest_snapshot
        );
    }
}

{
    package KinoSearch::Util::StringHelper;
    BEGIN {
        push our @ISA, 'Exporter';
        our @EXPORT_OK = qw(
            utf8_flag_on
            utf8_flag_off
            to_base36
            from_base36
            utf8ify
            utf8_valid
            cat_bytes
        );
    }
}

{
    package KinoSearch::Util::ToolSet;
    use Carp qw( carp croak cluck confess );
    use Scalar::Util qw( blessed );
    use Storable qw( nfreeze thaw );

    BEGIN {
        push our @ISA, 'Exporter';
        our @EXPORT_OK = qw(
            carp
            croak
            cluck
            confess
            blessed
            nfreeze
            thaw
            to_kino
            to_perl
        );
    }
}

{
    package KinoSearch::Analysis::Inversion;

    our %new_PARAMS = (
        # params
        text => undef
    );
}

{
    package KinoSearch::Analysis::Stemmer;
    sub lazy_load_snowball {
        require Lingua::Stem::Snowball;
        KinoSearch::Analysis::Stemmer::_copy_snowball_symbols();
    }
}

{
    package KinoSearch::Analysis::Stopalizer;
    use KinoSearch::Util::ToolSet qw( to_kino );

    sub gen_stoplist {
        my ( undef, $language ) = @_;
        require Lingua::StopWords;
        $language = lc($language);
        if ( $language =~ /^(?:da|de|en|es|fi|fr|hu|it|nl|no|pt|ru|sv)$/ ) {
            my $stoplist
                = Lingua::StopWords::getStopWords( $language, 'UTF-8' );
            return to_kino($stoplist);
        }
        return undef;
    }
}

{
    package KinoSearch::Analysis::Token;

    our %new_PARAMS = (
        text         => undef,
        start_offset => undef,
        end_offset   => undef,
        pos_inc      => 1,
        boost        => 1.0,
    );
}

{
    package KinoSearch::Analysis::Tokenizer;

    sub compile_token_re { return qr/$_[1]/ }

    sub new {
        my ( $either, %args ) = @_;
        my $token_re = delete $args{token_re};
        $args{pattern} = "$token_re" if $token_re;
        return $either->_new(%args);
    }
}

{
    package KinoSearch::Doc;
    use KinoSearch::Util::ToolSet qw( nfreeze thaw );
    use bytes;
    no bytes;

    use overload
        fallback => 1,
        '%{}'    => \&get_fields;

    sub serialize_fields {
        my ( $self, $outstream ) = @_;
        my $buf = nfreeze( $self->get_fields );
        $outstream->write_c32( bytes::length($buf) );
        $outstream->write_bytes($buf);
    }

    sub deserialize_fields {
        my ( $self, $instream ) = @_;
        my $len = $instream->read_c32;
        my $buf;
        $instream->read_bytes( $buf, $len );
        $self->set_fields( thaw($buf) );
    }
}

{
    package KinoSearch::Obj;
    use KinoSearch::Util::ToolSet qw( to_kino to_perl );
    sub load { return $_[0]->_load( to_kino( $_[1] ) ) }
}

{
    package KinoSearch::Obj::VTable;

    sub find_parent_class {
        my ( undef, $package ) = @_;
        no strict 'refs';
        for my $parent ( @{"$package\::ISA"} ) {
            return $parent if $parent->isa('KinoSearch::Obj');
        }
        return;
    }

    sub novel_host_methods {
        my ( undef, $package ) = @_;
        no strict 'refs';
        my $stash   = \%{"$package\::"};
        my $methods = KinoSearch::Util::VArray->new(
            capacity => scalar keys %$stash );
        while ( my ( $symbol, $glob ) = each %$stash ) {
            next if ref $glob;
            next unless *$glob{CODE};
            $methods->push( KinoSearch::Util::CharBuf->new($symbol) );
        }
        return $methods;
    }

    sub _register {
        my ( undef, %args ) = @_;
        my $singleton_class = $args{singleton}->get_name;
        my $parent_class    = $args{parent}->get_name;
        if ( !$singleton_class->isa($parent_class) ) {
            no strict 'refs';
            push @{"$singleton_class\::ISA"}, $parent_class;
        }
    }
}

{
    package KinoSearch::Index::IndexReader;

    sub new {
        confess(
            "IndexReader is an abstract class; use open() instead of new()");
    }
    sub lexicon {
        my $self       = shift;
        my $lex_reader = $self->fetch("KinoSearch::Index::LexiconReader");
        return $lex_reader->lexicon(@_) if $lex_reader;
        return;
    }
    sub posting_list {
        my $self        = shift;
        my $post_reader = $self->fetch("KinoSearch::Index::PostingsReader");
        return $post_reader->posting_list(@_) if $post_reader;
        return;
    }
    sub offsets { shift->_offsets->to_arrayref }
}

{
    package KinoSearch::Index::PolyReader;
    use KinoSearch::Util::ToolSet qw( to_kino );

    sub try_read_snapshot {
        my ( undef, %args ) = @_;
        my ( $snapshot, $folder, $filename )
            = @args{qw( snapshot folder filename )};
        eval {
            $snapshot->read_file( folder => $folder, filename => $filename );
        };
        if   ($@) { return KinoSearch::Util::CharBuf->new($@) }
        else      { return undef }
    }

    sub try_open_segreaders {
        my ( $self, $segments ) = @_;
        my $schema   = $self->get_schema;
        my $folder   = $self->get_folder;
        my $snapshot = $self->get_snapshot;
        my $seg_readers
            = KinoSearch::Util::VArray->new( capacity => scalar @$segments );
        my $segs = to_kino($segments);    # FIXME: Don't convert twice.
        eval {
            # Create a SegReader for each segment in the index.
            my $num_segs = scalar @$segments;
            for ( my $seg_tick = 0; $seg_tick < $num_segs; $seg_tick++ ) {
                my $seg_reader = KinoSearch::Index::SegReader->new(
                    schema   => $schema,
                    folder   => $folder,
                    segments => $segs,
                    seg_tick => $seg_tick,
                    snapshot => $snapshot,
                );
                $seg_readers->push($seg_reader);
            }
        };
        if ($@) {
            return KinoSearch::Util::CharBuf->new($@);
        }
        return $seg_readers;
    }
}

{
    package KinoSearch::Index::Segment;
    use KinoSearch::Util::ToolSet qw( to_kino );
    sub store_metadata {
        my ( $self, %args ) = @_;
        $self->_store_metadata( %args,
            metadata => to_kino( $args{metadata} ) );
    }
}

{
    package KinoSearch::Index::SegReader;

    sub try_init_components {
        my $self = shift;
        my $arch = $self->get_schema->get_architecture;
        eval { $arch->init_seg_reader($self); };
        if ($@) { return KinoSearch::Util::CharBuf->new($@); }
        return;
    }
}

{
    package KinoSearch::Index::SortCache;
    our %value_PARAMS = ( ord => undef, );
}

{
    package KinoSearch::Indexer;

    sub new {
        my ( $either, %args ) = @_;
        my $flags = 0;
        $flags |= CREATE   if delete $args{'create'};
        $flags |= TRUNCATE if delete $args{'truncate'};
        return $either->_new( %args, flags => $flags );
    }

    our %add_doc_PARAMS = ( doc => undef, boost => 1.0 );
}

{
    package KinoSearch::Search::Compiler;
    use KinoSearch::Util::ToolSet qw( confess blessed );

    sub new {
        my ( $either, %args ) = @_;
        if ( !defined $args{boost} ) {
            confess("'parent' is not a Query")
                unless ( blessed( $args{parent} )
                and $args{parent}->isa("KinoSearch::Search::Query") );
            $args{boost} = $args{parent}->get_boost;
        }
        return $either->do_new(%args);
    }
}

{
    package KinoSearch::Search::Query;

    sub make_compiler {
        my ( $self, %args ) = @_;
        $args{boost} = $self->get_boost unless defined $args{boost};
        return $self->_make_compiler(%args);
    }
}

{
    package KinoSearch::Search::SortRule;

    my %types = (
        field  => FIELD(),
        score  => SCORE(),
        doc_id => DOC_ID(),
    );

    sub new {
        my ( $either, %args ) = @_;
        my $type = delete $args{type} || 'field';
        confess("Invalid type: '$type'") unless defined $types{$type};
        return $either->_new( %args, type => $types{$type} );
    }
}

{
    package KinoSearch::Util::BitVector;
    sub to_arrayref { shift->to_array->to_arrayref }
}

{
    package KinoSearch::Util::ByteBuf;
    BEGIN {
        push our @ISA, 'Exporter';
        our @EXPORT_OK = qw( bb_compare );    # testing only
    }

    {
        # Override autogenerated deserialize binding.
        no warnings 'redefine';
        sub deserialize { shift->_deserialize(@_) }
    }

    package KinoSearch::Util::ViewByteBuf;
    use KinoSearch::Util::ToolSet qw( confess );

    sub new { confess "ViewByteBuf objects can only be created from C." }
}

{
    package KinoSearch::Util::CharBuf;
    BEGIN {
        push our @ISA, 'Exporter';
        our @EXPORT_OK = qw( cb_compare );
    }

    {
        # Defeat obscure bugs in the XS auto-generation by redefining clone()
        # and deserialize().  (Because of how the typemap works for CharBuf*,
        # the auto-generated methods return UTF-8 Perl scalars rather than
        # actual CharBuf objects.)
        no warnings 'redefine';
        sub clone       { shift->_clone(@_) }
        sub deserialize { shift->_deserialize(@_) }
    }

    package KinoSearch::Util::ViewCharBuf;
    use KinoSearch::Util::ToolSet qw( confess );

    sub new { confess "ViewCharBuf has no public constructor." }

    package KinoSearch::Util::ZombieCharBuf;
    use KinoSearch::Util::ToolSet qw( confess );

    sub new { confess "ZombieCharBuf objects can only be created from C." }

    sub DESTROY { }
}

{
    package KinoSearch::Util::Hash;
    no warnings 'redefine';
    sub deserialize { shift->_deserialize(@_) }
}

{
    package KinoSearch::Util::VArray;
    no warnings 'redefine';
    sub clone       { CORE::shift->_clone }
    sub deserialize { CORE::shift->_deserialize(@_) }
}

{
    package KinoSearch::Util::Compat::DirManip;
    use File::Spec::Functions qw( rel2abs );
    sub absolutify { return rel2abs( $_[1] ) }
}

{
    package KinoSearch::Util::Debug;
    BEGIN {
        push our @ISA, 'Exporter';
        our @EXPORT_OK = qw(
            DEBUG
            DEBUG_PRINT
            DEBUG_ENABLED
            ASSERT
            set_env_cache
            num_allocated
            num_freed
            num_globals
        );
    }
}

{
    package KinoSearch::Util::I32Array;
    our %new_PARAMS = ( ints => undef );
}

{
    package KinoSearch::Util::Json;
    use KinoSearch::Util::ToolSet qw( to_kino );

    use JSON::XS qw();

    my $json_encoder = JSON::XS->new->pretty(1)->canonical(1);

    sub slurp_json {
        my ( undef, %args ) = @_;
        my $instream = $args{folder}->open_in( $args{filename} );
        return unless $instream;
        my $len = $instream->length;
        my $json;
        $instream->read_bytes( $json, $len );
        my $result = eval { to_kino( $json_encoder->decode($json) ) };
        return if $@;
        return $result;
    }

    sub spew_json {
        my ( undef, %args ) = @_;
        my $json      = $json_encoder->encode( $args{'dump'} );
        my $outstream = $args{folder}->open_out( $args{filename} );
        return 0 unless $outstream;
        $outstream->print($json);
        $outstream->close;
        return 1;
    }

    sub to_json {
        my ( undef, $dump ) = @_;
        return $json_encoder->encode($dump);
    }

    sub from_json {
        return to_kino( $json_encoder->decode( $_[1] ) );
    }
}

{
    package KinoSearch::Util::Host;
    BEGIN {
        if ( !__PACKAGE__->isa('KinoSearch::Obj') ) {
            push our @ISA, 'KinoSearch::Obj';
        }
    }
}

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch

BOOT:
    kino_Boot_bootstrap();

IV
_dummy_function()
CODE:
    RETVAL = 1;
OUTPUT:
    RETVAL

MODULE = KinoSearch    PACKAGE = KinoSearch::Util::ToolSet

SV*
to_kino(sv)
    SV *sv;
CODE:
{
    kino_Obj *obj = XSBind_perl_to_kino(sv);
    KOBJ_TO_SV_NOINC(obj, RETVAL);
}
OUTPUT: RETVAL

SV*
to_perl(sv)
    SV *sv;
CODE:
{
    if (sv_isobject(sv) && sv_derived_from(sv, KINO_OBJ.name->ptr)) {
        IV tmp = SvIV(SvRV(sv));
        kino_Obj* obj = INT2PTR(kino_Obj*, tmp);
        RETVAL = XSBind_kobj_to_pobj(obj);
    }
    else {
        RETVAL = newSVsv(sv);
    }
}
OUTPUT: RETVAL

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.
