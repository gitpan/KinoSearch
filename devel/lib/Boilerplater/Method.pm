use strict;
use warnings;

package Boilerplater::Method;
use Carp;
use base qw( Function );
use Boilerplater qw( $prefix $Prefix $PREFIX );

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);

    # count the number of arguments and produce a symbolic list
    my @args = split /,/, $self->{arg_list};
    my @names;
    for my $arg (@args) {
        $arg =~ /
            (\w+)
            \s*
            (?: \)\s*\(.*\) )?    # arg list for function pointer
            \s* 
            ,?\s*$
        /xsm
            or die( "Missing argument name for $_ in "
                . " $self->{micro_name}' from $self->{class_name}" );
        push @names, $1;
    }
    $self->{arg_names} = join ', ', @names;

    if ( !defined $self->{macro_name} ) {
        # transform method_name to Method_Name
        $self->{macro_name} = $self->{micro_name};
        $self->{macro_name} =~ s/((?:^|_).)/\U$1/g;
    }

    if ( !defined $self->{typedef} ) {
        $self->{typedef}     = $self->_gen_typedef;
        $self->{typedef_dec} = $self->_gen_typedef_dec;
    }

    return $self;
}

=begin comment

Turn a Boilerplater::Method object into a Boilerplater::Method::Overridden
object. 

All methods start out as plain old Method objects, because we don't know about
inheritance until we build the Hierarchy after all files have been parsed.
override() is a way of going back and relabeling a method as overridden when
new information has become available: in this case, that a parent class has
defined a method with the same name.

=end comment
=cut 

sub override {
    my ( $self, $orig ) = @_;

    confess(  "Attempt to override final method '$orig->{micro_name}' from "
            . "$orig->{class_nick} by $self->{class_nick}" )
        if $orig->isa("Boilerplater::Method::Final");

    # rebless the object
    bless $self, 'Boilerplater::Method::Overridden';

    # remember the method we're overriding
    $self->set_orig($orig);
}

=begin comment

As with override, above, this is for going back and changing the nature of a
Method object after new information has become available -- typically, when we
discover that the method has been inherited by a "final" class.

However, we don't rebless the object as with override().  Inherited Method
objects are shared between parent and child classes; if a shared Method object
were to become final, it would interfere with its own inheritance.  So, we make
a copy, slightly modified to make it "final".

=end comment
=cut

sub finalize {
    my $self = shift;
    return bless {
        %$self,
        # these are needed in case this method is overriding another
        typedef_dec => $self->typedef_dec,
        typedef     => $self->typedef,
        },
        'Boilerplater::Method::Final';
}

# create the name of the function pointer typedef for the method's
# implementing function.
sub typedef { shift->{typedef} }

sub _gen_typedef {
    my $self = shift;
    return "$self->{class_nick}_$self->{micro_name}_t";
}

# Create a function pointer typedef.
sub typedef_dec { shift->{typedef_dec} }

sub _gen_typedef_dec {
    my $self = shift;
    return <<END_STUFF;
typedef $self->{return_type}
(*$prefix$self->{class_nick}_$self->{micro_name}_t)($self->{arg_list});
END_STUFF
}

# Declare a method macro.  May use the class nick from an inheritor.
sub macro_def {
    my ( $self, $invoker ) = @_;
    my ( $micro_name, $struct_name, $arg_names )
        = @{$self}{qw( micro_name struct_name arg_names )};
    my $full_macro_name = "$Prefix$invoker" . "_$self->{macro_name}";

    return <<END_STUFF;
#define $full_macro_name($arg_names) \\
    (self)->_->$micro_name(($prefix$struct_name*)$arg_names)
END_STUFF
}

# The typedef's short name.
sub short_typedef {
    my $self       = shift;
    my $short_name = "$self->{class_nick}_$self->{micro_name}_t";
    return "  #define $short_name $prefix$short_name\n";
}

# The method macro's short name.
sub short_method_macro {
    my ( $self, $invoker ) = @_;
    my $short_name = $invoker . "_$self->{macro_name}";
    return "  #define $short_name $Prefix$short_name\n";
}

1;
