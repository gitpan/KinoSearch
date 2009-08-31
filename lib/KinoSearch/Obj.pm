use KinoSearch;

1;

__END__

__BINDING__

my $xs_code = <<'END_XS_CODE';
MODULE = KinoSearch     PACKAGE = KinoSearch::Obj

chy_bool_t
is_a(self, class_name)
    kino_Obj *self;
    kino_ZombieCharBuf class_name;
CODE:
{
    kino_VTable *target = kino_VTable_fetch_vtable((kino_CharBuf*)&class_name);
    RETVAL = Kino_Obj_Is_A(self, target);
}
OUTPUT: RETVAL

void
STORABLE_freeze(self, ...)
    kino_Obj *self;
PPCODE:
{
    CHY_UNUSED_VAR(self);
    if (items < 2 || !SvTRUE(ST(1))) {
        SV *retval;
        kino_ByteBuf *serialized_bb;
        kino_RAMFileDes *file_des = kino_RAMFileDes_new(NULL);
        kino_OutStream *target = kino_OutStream_new((kino_FileDes*)file_des);

        Kino_Obj_Serialize(self, target);

        Kino_OutStream_Close(target);
        serialized_bb = Kino_RAMFileDes_Contents(file_des);
        retval = XSBind_bb_to_sv(serialized_bb);
        KINO_DECREF(file_des);

        if (Kino_BB_Get_Size(serialized_bb) == 0) { /* Thwart Storable bug */
            KINO_DECREF(target);
            KINO_DECREF(serialized_bb);
            THROW(KINO_ERR, "Calling serialize produced an empty string");
        }
        else {
            KINO_DECREF(target);
            KINO_DECREF(serialized_bb);
        }
        ST(0) = sv_2mortal(retval);
        XSRETURN(1);
    }
}

=begin comment

Calls deserialize(), and copies the object pointer.  Since deserialize is an
abstract method, it will confess() unless implemented.

=end comment
=cut

void
STORABLE_thaw(blank_obj, cloning, serialized_sv)
    SV *blank_obj;
    SV *cloning;
    SV *serialized_sv;
PPCODE:
{
    STRLEN len;
    char *ptr = SvPV(serialized_sv, len);
    kino_ViewFileDes *file_des = kino_ViewFileDes_new(ptr, len);
    kino_InStream *instream = kino_InStream_new((kino_FileDes*)file_des);
    kino_ZombieCharBuf class_name = XSBind_sv_to_class_name(blank_obj);
    kino_VTable *vtable = (kino_VTable*)kino_VTable_singleton(
        (kino_CharBuf*)&class_name, NULL);
    kino_Obj *self = Kino_VTable_Foster_Obj(vtable, blank_obj);
    kino_Obj *deserialized = Kino_Obj_Deserialize(self, instream);

    CHY_UNUSED_VAR(cloning);
    KINO_DECREF(file_des);
    KINO_DECREF(instream);

    /* Catch bad deserialize() override. */
    if (deserialized != self) 
        THROW(KINO_ERR, "Error when deserializing obj of class %o", &class_name);
}


SV*
to_pobj(self)
    kino_Obj *self;
CODE:
    RETVAL = XSBind_kobj_to_pobj(self);
OUTPUT: RETVAL

void
DESTROY(self)
    kino_Obj *self;
PPCODE:
    /*
    {
        char *perl_class = HvNAME(SvSTASH(SvRV(ST(0))));
        warn("Destroying: 0x%x %s", (unsigned)self, perl_class);
    }
    */
    Kino_Obj_Destroy(self);
END_XS_CODE

my $synopsis = <<'END_SYNOPSIS';
    package MyObj;
    use base qw( KinoSearch::Obj );
    
    # Inside-out member var.
    my %foo;
    
    sub new {
        my ( $class, %args ) = @_;
        my $foo = delete $args{foo};
        my $self = $class->SUPER::new(%args);
        $foo{$$self} = $foo;
        return $self;
    }
    
    sub get_foo {
        my $self = shift;
        return $foo{$$self};
    }
    
    sub DESTROY {
        my $self = shift;
        delete $foo{$$self};
        $self->SUPER::DESTROY;
    }
END_SYNOPSIS

my $description = <<'END_DESCRIPTION';
All objects in the KinoSearch:: hierarchy descend from KinoSearch::Obj.  All
classes are implemented as blessed scalar references, with the scalar storing
a pointer to a C struct.

==head2 Subclassing

The recommended way to subclass KinoSearch::Obj and its descendants is to use
the inside-out design pattern.  (See L<Class::InsideOut> for an introduction
to inside-out techniques.)

Since the blessed scalar stores a C pointer value which is unique per-object,
C<$$self> can be used as an inside-out ID.

    # Accessor for 'foo' member variable.
    sub get_foo {
        my $self = shift;
        return $foo{$$self};
    }


Caveats:

==over

==item *

Inside-out aficionados will have noted that the "cached scalar id" stratagem
recommended above isn't compatible with ithreads -- but KinoSearch doesn't
support ithreads anyway, so it doesn't matter.

==back

==head1 CONSTRUCTOR

==head2 new()

Abstract constructor -- must be invoked via a subclass.  Attempting to
instantiate objects of class "KinoSearch::Obj" directly causes an error.

Takes no arguments; if any are supplied, an error will be reported.

==head1 DESTRUCTOR

==head2 DESTROY

All KinoSearch classes implement a DESTROY method; if you override it in a
subclass, you must call C<< $self->SUPER::DESTROY >> to avoid leaking memory.
END_DESCRIPTION

Boilerplater::Binding::Perl::Class->register(
    parcel       => "KinoSearch",
    class_name   => "KinoSearch::Obj",
    xs_code      => $xs_code,
    bind_methods => [
        qw( Get_RefCount
            Inc_RefCount
            Dec_RefCount
            Get_VTable
            To_String
            To_I64
            To_F64
            Dump
            _load|Load
            Clone
            Mimic
            Equals
            Hash_Code
            Serialize
            Deserialize )
    ],
    bind_constructors => ["new"],
    make_pod          => {
        synopsis    => $synopsis,
        description => $description,
        methods     => [
            qw(
                to_string
                to_i64
                to_f64
                equals
                dump
                load
                )
        ],
    }
);

__COPYRIGHT__

Copyright 2005-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify
under the same terms as Perl itself.

