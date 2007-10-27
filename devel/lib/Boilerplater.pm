use strict;
use warnings;

package Boilerplater;
use base qw( Exporter );

our ( $prefix, $Prefix, $PREFIX );
our @EXPORT_OK;
BEGIN { @EXPORT_OK = qw( $prefix $Prefix $PREFIX ) }

=begin comment

    Boilerplater->init_prefixes(qw( prefix Prefix PREFIX ));

Set the prefixes expected/used by Boilerplater when parsing/generating. Can
only be called once.

=end comment
=cut 

my $prefixes_initialized;

sub init_prefixes {
    my ( undef, $pref, $Pref, $PREF ) = @_;
    confess("usage: Boilerplater->init_prefixes(qw( prefix Prefix PREFIX ))")
        unless @_ == 4;
    confess("can't call init_prefixes() more than once")
        if $prefixes_initialized;
    $prefix = $pref;
    $Prefix = $Pref;
    $PREFIX = $PREF;
}

1;

=head1 NAME

Boilerplater - Generate boilerplate OO code

=head1 PRIVATE API

Boilerplater is an implementation detail.  This documentation is partial --
enough for the curious hacker, but not a full API.

=head1 DESCRIPTION

Boilerplater looks for special keywords in C header files and generates
boilerplate OO code when it finds them.  The keywords must all begin with a
user-settable prefix, and they must be the first item on a line to be
recognized as valid.

As far as the C compiler is concerned, the keywords are simply macros defined
to do nothing -- so they only have meaning vis-a-vis boilerplater.

=head2 Object Model

=over

=item *

Single inheritance.

=item *

Memory management via reference counting.

=item

Method dispatch using virtual tables.

=item *

All classes descend from Obj.

=back

=head2 Prefixes and Short names

All boilerplater symbols are prepended with one of three prefixes to avoid
namespace collisions.  For the rest of this document, we'll use "Boiler" as
our project name and "boil_", "Boil_", and "BOIL_" as prefixes.

"Short names" -- names minus the prefix -- will be auto-generated for all
class symbols, including the names of all functions declared between
C<BOIL_CLASS> and C<BOIL_END_CLASS>.  When there is no danger of namespace
collision, typically because no third-party non-system libraries are being
C<#include>d, the short names can be used after a USE_SHORT_NAMES directive:

    #define BOIL_USE_SHORT_NAMES

=head2 Inclusion

The boilerplate code is written to a file with whose name is the same as the
header file, but with an extension of ".r" (for "representation") rather than
".h".  Files should include "Boiler/Util/Foo.r" rather than
"Boiler/Util/Foo.h".

=head1 Header file requirements

Class declarations begin with a C<BOIL_CLASS> directive and end with
C<BOIL_END_CLASS>.  They must be prepared by including Obj.r and pre-declaring
the object and vtable typedefs.

    #ifndef H_BOIL_FOO
    #define H_BOIL_FOO 1

    #include "Boiler/Util/Obj.r"

    typedef struct boil_Foo boil_Foo;
    typedef struct BOIL_FOO_VTABLE BOIL_FOO_VTABLE;

    BOIL_CLASS("Boiler::Util::Foo", "Foo", "Boiler::Util::Obj")

    struct boil_Foo {
        const BOIL_FOO_VTABLE *_;
        boil_u32_t refcount;
        boil_u32_t num_widgets;
    };

    boil_Foo*
    boil_Foo_new();
    
    int
    boil_Foo_do_stuff(Foo *self);
    BOIL_METHOD("Boil_Foo_Do_Stuff");

    void
    boil_Foo_destroy(Foo *self);
    BOIL_METHOD("Boil_Foo_Destroy");

    BOIL_END_CLASS

    #endif /* H_BOIL_FOO */

In between C<BOIL_CLASS> and C<BOIL_END_CLASS>, all code must adhere strictly
to all guidelines.  Comments are allowed, but auxiliary macros, functions and
such should be defined outside the class declaration, since boilerplater's
parser will throw an error if it finds something it doesn't understand.

=head2 Pre-declaring object and vtable structs

The name of the object struct must be in UpperCamelCase and be prepended with
C<boil_>:

    typedef boil_ClassName boil_ClassName;

The vtable struct's name must be an upper-cased version of the struct name
with "_VTABLE" appended.  (The vtable struct definition will be
auto-generated.)

    typedef struct BOIL_CLASSNAME_VTABLE BOIL_CLASSNAME_VTABLE;

=head2 Object struct definition

The class's object struct definition must adhere to the following criteria:

=over

=item *

The first member must be a vtable pointer named C<_>.

=item *

All classes save Obj must inherit all members from their parent class other
than the vtable.  To facilitate this, a macro named
C<BOIL_CLASSNAME_MEMBER_VARS> is auto-generated for each class which contains
all members save C<_> (the vtable). This macro should follow C<_> in the child
class's object struct definition:

    struct boil_FooJr {
        BOIL_FOOJR_VTABLE *_;
        BOIL_FOO_MEMBER_VARS;
        boil_i32_t another_variable;
    };

=back

=head2 Function declaration conventions

All functions declared between C<BOIL_CLASS> and C<BOIL_END_CLASS> must
follow this naming pattern:
    
    boil_ . $class_nick . '_' . $micro_name;

C<$class_nick> must be the one specified via BOIL_CLASS.  C<$micro_name> must
consist of only characters matching C<[a-z0-9_]>.

=head1 Keywords

=head2 BOIL_CLASS( [class_name], [class_nick], [parent_class] );

Begin a class declaration.  Three double-quoted string arguments are required,
and the struct definition for the object must follow on immediately
afterwards.

=over

=item *

B<class_name> - The name of this class.  The last word should match the
struct's short name.

=item *

B<class_nick> - A recognizable abbreviation of the class name, used as a
prefix for every function and method.

=item *

B<parent_class> - The full name of the parent class.

=back

=head2 BOIL_END_CLASS

Terminate a class declaration.

=head2 BOIL_METHOD("Boil_ClassNick_Method_Name");

This directive assigns method semantics to the supplied double-quoted string
argument, creating a macro which invokes a corresponding function via vtable
double-dereference (unless the class is final).  A function with a matching
class name and a lower-cased version of C<Method_Name> must be available.

Example: this combination of a function definition and BOIL_METHOD
directive...

    void
    boil_Foo_do_stuff(boil_Foo *self);
    BOIL_METHOD("Boil_Foo_Do_Stuff");

... adds C<boil_Foo_do_stuff> to Foo's vtable and generates this method macro:

    #define Boil_Foo_Do_Stuff(self) \
        (self)->_->do_stuff((boil_Foo*)(self))

=head2 BOIL_FINAL_METHOD( "Boil_ClassNick_Method_Name", function_decl );

As BOIL_METHOD above, but method macro becomes a direct alias to the
function name, rather than a vtable invocation.

=head2 BOIL_FINAL_CLASS( [class_name], [class_nick], [parent_class] );

As BOIL_CLASS above, but causes all methods to become final.

=head1 Class definition file requirements

There is only one requirement for the C file where the class is fully defined.
Before the pound-include directive for the ".r" file, the vtable must be
claimed:

    #define BOIL_WANT_FOO_VTABLE
    #include "Boiler/Util/Foo.r"

=head1 COPYRIGHT AND LICENSE

Copyright 2006-2007 Marvin Humphrey

This program is free software; you can redistribute it and/or modify under the
same terms as Perl itself.

=cut

