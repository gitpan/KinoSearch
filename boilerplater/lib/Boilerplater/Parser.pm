use strict;
use warnings;

package Boilerplater::Parser;
use base qw( Parse::RecDescent );

use Boilerplater;
use Boilerplater::Type;
use Boilerplater::Type::Primitive;
use Boilerplater::Type::Object;
use Boilerplater::Type::Void;
use Boilerplater::File;
use Boilerplater::Class;
use Boilerplater::Class::Final;
use Boilerplater::Variable;
use Boilerplater::ParamList;
use Boilerplater::Function;
use Boilerplater::Method;
use Boilerplater::DocuComment;
use Carp;

our $grammar = <<'END_GRAMMAR';

file:
    { Boilerplater::Parser->set_parcel_name(undef); 0; }
    major_block[%arg](s) eofile
    { Boilerplater::Parser->new_file( \%item, \%arg ) }

major_block:
      class_declaration[%arg]
    | embed_c
    | parcel_definition

parcel_definition:
    'parcel' class_name cnick(?) ';'
    { 
        Boilerplater::Parser->set_parcel_name( $item{class_name} );
        Boilerplater::Parser->new_parcel( \%item ); 
    }

class_declaration:
    docucomment(?)
    exposure_specifier(?) class_modifier(s?) 'class' class_name 
        cnick(?)
        class_extension(?)
        class_attribute(s?)
    '{'
        declaration[
            class  => $item{class_name}, 
            cnick  => $item{'cnick(?)'}[0],
            parent => $item{'class_extension(?)'}[0],
        ](s?)
    '}'
    { Boilerplater::Parser->new_class( \%item, \%arg ) }

class_modifier:
      'static'
    | 'abstract'
    | 'final'
    { $item[1] }

class_attribute:
    ':' /[a-z]+(?!\w)/
    { $item[2] }

class_name:
    /[A-Z][A-Za-z0-9]+(::[A-Z][A-Za-z0-9]+)*(?!\w)/

cnick:
    'cnick'
    /([A-Za-z0-9]+)/
    { $1 }

class_extension:
    'extends' class_name
    { $item[2] }

declaration:
      var_declaration
    | subroutine_declaration[%arg]
    | <error>

var_declaration:
    exposure_specifier(?) variable_modifier(s?) type declarator ';'
    {
        $return = {
            exposure  => $item[1][0] || 'parcel',
            modifiers => $item[2],
            declared  => Boilerplater::Parser->new_var( \%item ),
        };
    }

variable:
    type declarator
    { Boilerplater::Parser->new_var(\%item); }

assignment: 
    '=' scalar_constant
    { $item[2] }

subroutine_declaration:
    docucomment(?)
    exposure_specifier(?) subroutine_modifier(s?) type declarator param_list ';'
    {
        $return = {
            exposure  => $item[2],
            modifiers => $item[3],
            declared  => Boilerplater::Parser->new_sub( \%item, \%arg ),
        };
    }

param_list:
    '(' 
    param_list_elem(s? /,/)
    (/,\s*.../)(?)
    ')'
    {
        Boilerplater::Parser->new_param_list( $item[2], $item[3][0] ? 1 : 0 );
    }

param_list_elem:
    variable assignment(?)
    { [ $item[1], $item[2][0] ] }

type:
      object_type
    | composite_type
    | primitive_type
    | void_type
    | va_list_type
    | generic_type
    { $item[1] }

object_type:
    type_qualifier(s?) object_type_specifier /\*(?!\*)/
    { Boilerplater::Parser->new_object_type(\%item); }

composite_type:
    type_qualifier(s?) type_specifier type_postfix(s)
    { Boilerplater::Parser->new_composite_type(\%item); }

primitive_type:
    type_qualifier(s?) primitive_type_specifier
    { Boilerplater::Parser->new_primitive_type(\%item); }
    
void_type:
    void_type_specifier
    { Boilerplater::Type::Void->new( specifier => 'void' ) }

va_list_type:
    va_list_type_specifier
    { Boilerplater::Type->new( specifier => 'va_list' ) }

generic_type:
    generic_type_specifier
    { Boilerplater::Parser->new_generic_type(\%item); }

exposure_specifier:
      'public'
    | 'private'
    | 'parcel'

type_qualifier:
      'const' 
    | 'incremented'
    | 'decremented'

subroutine_modifier:
      'static'
    | 'abstract'
    | 'final'
    { $item[1] }

variable_modifier:
      'static'
    { $item[1] }

type_specifier:
    (    object_type_specifier 
       | primitive_type_specifier
       | void_type_specifier
       | va_list_type_specifier
       | generic_type_specifier
    ) 
    { $item[1] }

primitive_type_specifier:
      chy_integer_specifier
    | c_integer_specifier 
    | c_float_specifier 
    { $item[1] }

chy_integer_specifier:
    /(?:chy_)?([iu](8|16|32|64)|bool)_t(?!\w)/

c_integer_specifier:
    /(?:char|int|short|long)(?!\w)/

c_float_specifier:
    /(?:float|double)(?!\w)/

void_type_specifier:
    'void'

va_list_type_specifier:
    'va_list'

generic_type_specifier:
    /\w+_t(?!\w)/

declarator:
    identifier 
    { $item[1] }

type_postfix:
      '*'
      { '*' }
    | '[' ']'
      { '[]' }
    | '[' constant_expression ']'
      { "[$item[2]]" }

object_type_specifier:
    /[A-Z][A-Za-z0-9]*[a-z]+[A-Za-z0-9]*(?!\w)/

constant_expression:
      /\d+/
    | /[A-Z_]+/

identifier:
    ...!reserved_word /[a-zA-Z_]\w*/x
    { $item[2] }

docucomment:
    /\/\*\*.*?\*\//s
    { Boilerplater::Parser->new_docucomment($item[1]) }

embed_c:
    '__C__'
    /.*?(?=__END_C__)/s  
    '__END_C__'
    { $item[2] }

scalar_constant:
      hex_constant
    | float_constant
    | integer_constant
    | string_literal
    | 'NULL'
    | 'true'
    | 'false'

integer_constant:
    /(?:-\s*)?\d+/
    { $item[1] }

hex_constant:
    /0x[a-fA-F0-9]+/
    { $item[1] }

float_constant:
    /(?:-\s*)?\d+\.\d+/
    { $item[1] }

string_literal: 
    /"(?:[^"\\]|\\.)*"/
    { $item[1] }

reserved_word:
    /(char|const|double|enum|extern|float|int|long|register|signed|sizeof
       |short|static|struct|typedef|union|unsigned|void)(?!\w)/x
    | chy_integer_specifier

eofile:
    /^\Z/

END_GRAMMAR

sub new { return shift->SUPER::new($grammar) }

our $parcel_name = undef;
sub set_parcel_name { $parcel_name = $_[1] }

# Replace plain comments with spaces (but not docu-comments).
sub strip_plain_comments {
    my ( $self, $text ) = @_;
    while ( $text =~ m#(/\*[^*].*?\*/)#ms ) {
        my $blanked = $1;
        $blanked =~ s/\S/ /g;
        $text    =~ s#/\*[^*].*?\*/#$blanked#ms;
    }
    return $text;
}

sub new_primitive_type {
    my ( undef, $item ) = @_;
    my %args = ( specifier => $item->{primitive_type_specifier} );
    $args{$_} = 1 for @{ $item->{'type_qualifier(s?)'} };
    return Boilerplater::Type::Primitive->new(%args);
}

sub new_object_type {
    my ( undef, $item ) = @_;
    my %args = (
        specifier   => $item->{object_type_specifier},
        parcel      => $parcel_name,
        indirection => 1
    );
    $args{$_} = 1 for @{ $item->{'type_qualifier(s?)'} };
    return Boilerplater::Type::Object->new(%args);
}

sub new_composite_type {
    my ( undef, $item ) = @_;
    my %args = ( parcel => $parcel_name );
    $args{$_} = 1 for @{ $item->{'type_qualifier(s?)'} };
    $args{specifier} = $item->{type_specifier};
    my $num_stars = 0;
    for my $postfix ( @{ $item->{'type_postfix(s)'} } ) {
        $args{array} = $postfix if $postfix =~ /\[/;
        $num_stars++ if $postfix eq '*';
    }
    $args{indirection} = $num_stars;

    return Boilerplater::Type->new(%args);
}

sub new_generic_type {
    my ( undef, $item ) = @_;
    return Boilerplater::Type->new(
        specifier => $item->{generic_type_specifier},
        parcel    => $parcel_name,
    );
}

sub new_var {
    my ( undef, $item ) = @_;
    my $exposure = $item->{'exposure_specifier(?)'}[0];
    my %args = $exposure ? ( exposure => $exposure ) : ();
    return Boilerplater::Variable->new(
        parcel    => $parcel_name,
        type      => $item->{type},
        micro_sym => $item->{declarator},
        %args,
    );
}

sub new_param_list {
    my ( undef, $param_list_elems, $variadic ) = @_;
    my @vars = map { $_->[0] } @$param_list_elems;
    my @vals = map { $_->[1] } @$param_list_elems;
    return Boilerplater::ParamList->new(
        variables      => \@vars,
        initial_values => \@vals,
        variadic       => $variadic,
    );
}

sub new_sub {
    my ( undef, $item, $args ) = @_;
    my ( $class, $micro_sym, $macro_name );
    my $modifiers  = $item->{'subroutine_modifier(s?)'};
    my $docu_com   = $item->{'docucomment(?)'}[0];
    my $exposure   = $item->{'exposure_specifier(?)'}[0];
    my $static     = ( scalar grep { $_ eq 'static' } @$modifiers ) ? 1 : 0;
    my $abstract   = ( scalar grep { $_ eq 'abstract' } @$modifiers ) ? 1 : 0;
    my %extra_args = $exposure ? ( exposure => $exposure ) : ();

    if ($static) {
        $class     = 'Boilerplater::Function';
        $micro_sym = $item->{declarator};
    }
    else {
        my $final = ( scalar grep { $_ eq 'final' } @$modifiers ) ? 1 : 0;
        $class      = 'Boilerplater::Method';
        $macro_name = $item->{declarator};
        %extra_args = (
            %extra_args,
            macro_name => $macro_name,
            abstract   => $abstract,
            final      => $final,
        );
        $micro_sym = lc($macro_name);
    }

    return $class->new(
        parcel       => $parcel_name,
        docu_comment => $docu_com,
        class_name   => $args->{class},
        class_cnick  => $args->{cnick},
        return_type  => $item->{type},
        micro_sym    => $micro_sym,
        param_list   => $item->{param_list},
        %extra_args,
    );
}

sub new_class {
    my ( undef, $item, $args ) = @_;
    my ( @member_vars, @static_vars, @functions, @methods );
    my $source_class = $args->{source_class} || $item->{class_name};
    my %class_modifiers
        = map { ( $_ => 1 ) } @{ $item->{'class_modifier(s?)'} };
    my %class_attributes
        = map { ( $_ => 1 ) } @{ $item->{'class_attribute(s?)'} };

    for my $declaration ( @{ $item->{'declaration(s?)'} } ) {
        my $declared  = $declaration->{declared};
        my $exposure  = $declaration->{exposure};
        my $modifiers = $declaration->{modifiers};
        my $static    = ( scalar grep {/static/} @$modifiers ) ? 1 : 0;
        my $subs      = $static ? \@functions : \@methods;
        my $vars      = $static ? \@static_vars : \@member_vars;

        if ( $declared->isa('Boilerplater::Variable') ) {
            push @$vars, $declared;
        }
        else {
            push @$subs, $declared;
        }
    }

    my $class_class
        = $class_modifiers{final}
        ? 'Boilerplater::Class::Final'
        : 'Boilerplater::Class';
    return $class_class->create(
        parcel            => $parcel_name,
        class_name        => $item->{class_name},
        cnick             => $item->{'cnick(?)'}[0],
        parent_class_name => $item->{'class_extension(?)'}[0],
        member_vars       => \@member_vars,
        functions         => \@functions,
        methods           => \@methods,
        static_vars       => \@static_vars,
        docu_comment      => $item->{'docucomment(?)'}[0],
        source_class      => $source_class,
        static            => $class_modifiers{static},
        attributes        => \%class_attributes,
    );
}

sub new_docucomment {
    my ( undef, $text ) = @_;
    return Boilerplater::DocuComment->new($text);
}

sub new_file {
    my ( undef, $item, $args ) = @_;

    return Boilerplater::File->new(
        parcel       => $parcel_name,
        blocks       => $item->{'major_block(s)'},
        source_class => $args->{source_class},
    );
}

sub new_parcel {
    my ( undef, $item ) = @_;
    Boilerplater::Parcel->singleton(
        name  => $item->{class_name},
        cnick => $item->{'cnick(?)'}[0],
    );
}

1;

__END__

__POD__

=head1 NAME

Boilerplater::Parser - Parse Boilerplater header files.

=head1 SYNOPSIS

     my $class_def = $parser->class($class_text);

=head1 DESCRIPTION

This parser class extracts Boilerplater::Class objects from .bp code.  It is
not at all strict, as it relies heavily on the C parser to pick up errors such
as misspelled type names.

=head1 COPYRIGHT

Copyright 2008-2009 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.30.

=cut
