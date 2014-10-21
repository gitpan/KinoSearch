use strict;
use warnings;

package Boilerplater::Dumpable;
use Carp;
use Boilerplater::Class;
use Boilerplater::Type;
use Boilerplater::Method;
use Boilerplater::Variable;

sub new {
    my $either = shift;
    return bless {}, ref($either) || $either;
}

sub add_dumpables {
    my ( $self, $class ) = @_;
    confess( $class->get_class_name . " isn't dumpable" )
        unless $class->is('dumpable');

    # Inherit Dump/Load from parent if no novel member vars.
    my $parent = $class->get_parent;
    if ( $parent and $parent->is('dumpable') ) {
        return unless scalar $class->novel_member_vars;
    }

    if ( !$class->novel_method('Dump') ) {
        $self->_add_dump_method($class);
    }
    if ( !$class->novel_method('Load') ) {
        $self->_add_load_method($class);
    }
}

# Create a Boilerplater::Method object for either Dump() or Load().
sub _make_method_obj {
    my ( $self, $class, $dump_or_load ) = @_;
    my $return_type = Boilerplater::Type->new(
        incremented => 1,
        specifier   => 'Obj',
        indirection => 1,
        parcel      => $class->get_parcel,
    );
    my $self_type = Boilerplater::Type->new(
        specifier   => $class->get_struct_name,
        indirection => 1,
        parcel      => $class->get_parcel,
    );
    my $self_var = Boilerplater::Variable->new(
        type      => $self_type,
        parcel    => $class->get_parcel,
        micro_sym => 'self',
    );

    my $param_list;
    if ( $dump_or_load eq 'Dump' ) {
        $param_list
            = Boilerplater::ParamList->new( variables => [$self_var], );
    }
    else {
        my $dump_type = Boilerplater::Type->new(
            specifier   => 'Obj',
            indirection => 1,
            parcel      => $class->get_parcel,
        );
        my $dump_var = Boilerplater::Variable->new(
            type      => $dump_type,
            parcel    => $class->get_parcel,
            micro_sym => 'dump',
        );
        $param_list = Boilerplater::ParamList->new(
            variables => [ $self_var, $dump_var ], );
    }

    return Boilerplater::Method->new(
        parcel      => $class->get_parcel,
        return_type => $return_type,
        class_name  => $class->get_class_name,
        class_cnick => $class->get_cnick,
        param_list  => $param_list,
        macro_name  => $dump_or_load,
        exposure    => 'public',
    );
}

sub _add_dump_method {
    my ( $self, $class ) = @_;
    my $method = $self->_make_method_obj( $class, 'Dump' );
    $class->add_method($method);
    my $full_func_sym    = $method->full_func_sym;
    my $full_struct_name = 'kino_' . $class->get_struct_name;
    my $autocode;
    my @members;
    my $parent = $class->get_parent;

    if ( $parent and $parent->is('dumpable') ) {
        my $super_dump = 'kino_' . $parent->get_cnick . '_dump';
        my $super_type = 'kino_' . $parent->get_struct_name;
        $autocode = <<END_STUFF;
kino_Obj*
$full_func_sym($full_struct_name *self)
{
    kino_Hash *dump = (kino_Hash*)$super_dump(($super_type*)self);
END_STUFF
        @members = $class->novel_member_vars;
    }
    else {
        $autocode = <<END_STUFF;
kino_Obj*
$full_func_sym($full_struct_name *self)
{
    kino_Hash *dump = kino_Hash_new(0);
    Kino_Hash_Store_Str(dump, "_class", 6,
        (kino_Obj*)Kino_CB_Clone(Kino_Obj_Get_Class_Name(self)));
END_STUFF
        @members = $class->get_member_vars;
        shift @members;    # skip self->vtable
        shift @members;    # skip refcount self->ref
    }

    for my $member_var (@members) {
        $autocode .= $self->_process_dump_member( $class, $member_var );
    }
    $autocode .= "    return (kino_Obj*)dump;\n}\n\n";
    $class->append_autocode($autocode);
}

sub _process_dump_member {
    my ( $self, $class, $member ) = @_;
    my $type = $member->get_type;
    my $name = $member->micro_sym;
    my $len  = length($name);
    if ( $type->is_integer ) {
        return qq|    Kino_Hash_Store_Str(dump, "$name", $len, |
            . qq|(kino_Obj*)kino_CB_newf("%i64", (chy_i64_t)self->$name));\n|;
    }
    elsif ( $type->is_floating ) {
        return qq|    Kino_Hash_Store_Str(dump, "$name", $len, |
            . qq|(kino_Obj*)kino_CB_newf("%f64", (double)self->$name));\n|;
    }
    elsif ( $type->is_object ) {
        return <<END_STUFF;
    if (self->$name) {
         Kino_Hash_Store_Str(dump, "$name", $len, Kino_Obj_Dump(self->$name));
    }
END_STUFF
    }
    else {
        confess( "Don't know how to dump a " . $type->get_specifier );
    }
}

sub _add_load_method {
    my ( $self, $class ) = @_;
    my $method = $self->_make_method_obj( $class, 'Load' );
    $class->add_method($method);
    my $full_func_sym    = $method->full_func_sym;
    my $full_struct_name = 'kino_' . $class->get_struct_name;
    my $autocode;
    my @members;
    my $parent = $class->get_parent;

    if ( $parent and $parent->is('dumpable') ) {
        my $super_load = 'kino_' . $parent->get_cnick . '_load';
        my $super_type = 'kino_' . $parent->get_struct_name;
        $autocode = <<END_STUFF;
kino_Obj*
$full_func_sym($full_struct_name *self, kino_Obj *dump)
{
    kino_Hash *source = (kino_Hash*)KINO_ASSERT_IS_A(dump, KINO_HASH);
    $full_struct_name *loaded 
        = ($full_struct_name*)$super_load(($super_type*)self, dump);
    CHY_UNUSED_VAR(self);
END_STUFF
        @members = $class->novel_member_vars;
    }
    else {
        $autocode = <<END_STUFF;
kino_Obj*
$full_func_sym($full_struct_name *self, kino_Obj *dump)
{
    kino_Hash *source = (kino_Hash*)KINO_ASSERT_IS_A(dump, KINO_HASH);
    kino_CharBuf *class_name = (kino_CharBuf*)KINO_ASSERT_IS_A(
        Kino_Hash_Fetch_Str(source, "_class", 6), KINO_CHARBUF);
    kino_VTable *vtable = kino_VTable_singleton(class_name, NULL);
    $full_struct_name *loaded = ($full_struct_name*)Kino_VTable_Make_Obj(vtable);
    CHY_UNUSED_VAR(self);
END_STUFF
        @members = $class->get_member_vars;
        shift @members;    # skip self->vtable
        shift @members;    # skip refcount self->ref
    }

    for my $member_var (@members) {
        $autocode .= $self->_process_load_member( $class, $member_var );
    }
    $autocode .= "    return (kino_Obj*)loaded;\n}\n\n";
    $class->append_autocode($autocode);
}

sub _process_load_member {
    my ( $self, $class, $member ) = @_;
    my $type        = $member->get_type;
    my $type_str    = $type->to_c;
    my $name        = $member->micro_sym;
    my $len         = length($name);
    my $struct_name = $type->get_specifier;
    my $vtable_var  = uc($struct_name);
    my $extraction
        = $type->is_integer  ? qq|($type_str)Kino_Obj_To_I64(var)|
        : $type->is_floating ? qq|($type_str)Kino_Obj_To_F64(var)|
        : $type->is_object
        ? qq|($struct_name*)KINO_ASSERT_IS_A(Kino_Obj_Load(var, var), $vtable_var)|
        : confess( "Don't know how to load " . $type->get_specifier );
    return <<END_STUFF;
    {
        kino_Obj *var = Kino_Hash_Fetch_Str(source, "$name", $len);
        if (var) { loaded->$name = $extraction; }
    }
END_STUFF
}

1;

__END__

__POD__

=head1 NAME

Boilerplater::Dumpable - Auto-generate code for "dumpable" classes.

=head1 COPYRIGHT

Copyright 2006-2009 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.30.

=cut
