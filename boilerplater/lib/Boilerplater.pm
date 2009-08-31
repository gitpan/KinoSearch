use strict;
use warnings;

package Boilerplater;
use base qw( Exporter );

our $VERSION = '0.01';

use Boilerplater::Parcel;

1;

=head1 NAME

Boilerplater - Bolt OO functionality onto C.

=head1 PRIVATE API

Boilerplater is an implementation detail.  This documentation is partial --
enough for the curious hacker, but not a full API.

=head1 DESCRIPTION

=head2 Overview.

Boilerplater is a small language for describing an object oriented interface,
and a compiler which generates some "boilerplate" header code allowing that
interface to be used from C.

=head2 Object Model

=over

=item *

Single inheritance.

=item

Method dispatch using virtual tables.

=back

=head2 Method invocation syntax.

Methods are differentiated from functions via capitalization:
Dog_say_hello is a function, Dog_Say_Hello is a method.

    /* Implementing function, in Dog/Chihuahua.c */
    void
    Chihuahua_say_hello(Chihuahua *self) 
    {
        printf("Yap! Yap! Yap!\n");
        Dog_Wag_Tail(self);
    }

    /* Implementing function, in Dog/SaintBernard.c. */
    void
    StBernard_say_hello(SaintBernard *self)
    {
        printf("Rooorf! Rooorf!\n");
        Dog_Wag_Tail(self);
    }

    /* Invoke Say_Hello method for several Dog objects. */
    void
    DogPack_greet(DogPack *self)
    {
        u32_t i;
        for (i = 0; i < self->pack_size; i++) {
            Dog_Say_Hello(self->pack_members[i]);
        }
    }

=head2 Class declaration syntax

    [final] [inert] class CLASSNAME [cnick CNICK] [extends PARENT] {
        [declarations]
    }

Example:

    class Dog::SaintBernard cnick StBernard extends Dog {
        void Say_Hello(SaintBernard *self);
    }

=over

=item *

B<CLASS_NAME> - The name of this class.  The last string of characters will be
used as the objects C struct name.

=item *

B<CNICK> - A recognizable abbreviation of the class name, used as a prefix for
every function and method.

=item *

B<PARENT> - The full name of the parent class.

=back

=head2 Memory management

At present, memory is managed via a reference counting scheme, but this is not
inherently part of Boilerplater.

=head2 Namespaces, parcels, prefixes, and "short names"

There are two levels of namespacing in Boilerplater: parcels and classes.

Boilerplater classes intended to be published as a single unit may be grouped
together using a "parcel" (akin to a "package" in Java).  Parcel directives
need to go at the top of each class file.

    parcel Crustaceans cnick Crust;

All symbols generated by Boilerplater for classes within a parcel will be
prefixed by varying capitalizations of the parcel's C-nickname or "cnick" in
order to avoid namespace collisions with other projects.

Within a parcel, the last part of each class name must be unique.

    class Crustacean::Lobster::Claw { ... }
    class Crustacean::Crab::Claw    { ... } /* Illegal, "Claw" already used */

"Short names" -- names minus the parcel prefix -- will be auto-generated for
all class symbols.  When there is no danger of namespace collision, typically
because no third-party non-system libraries are being pound-included, the
short names can be used after a USE_SHORT_NAMES directive:

    #define BOIL_USE_SHORT_NAMES

The USE_SHORT_NAMES directives do not affect class prefixes, only package
prefixes.

    /* No short names. */
    crust_Lobster *lobster = crust_Lobster_new();
    
    /* With short names. */
    #define CRUST_USE_SHORT_NAMES
    Lobster *lobster = Lobster_new();

=head2 Inclusion

The boilerplate code is written to a file with whose name is the same as the
.bp file, but with an extension of ".h".  C code should pound-include 
"Boiler/Util/Foo.h" for a class defined in "Boiler/Util/Foo.bp".

=head1 COPYRIGHT AND LICENSE

Copyright 2006-2009 Marvin Humphrey

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

