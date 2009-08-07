use strict;
use warnings;

use Test::More tests => 128;

BEGIN { use_ok('Boilerplater::Parser') }

my $parser = Boilerplater::Parser->new;
isa_ok( $parser, "Boilerplater::Parser" );

# Set and leave parcel.
$parser->parcel_definition('parcel Boil;')
    or die "failed to process parcel_definition";

is( $parser->strip_plain_comments("/*x*/"),
    "     ", "comments replaced by spaces" );
is( $parser->strip_plain_comments("/**x*/"),
    "/**x*/", "docu-comment untouched" );
is( $parser->strip_plain_comments("/*\n*/"), "  \n  ", "newline preserved" );

isa_ok( $parser->docucomment('/** foo. */'), "Boilerplater::DocuComment" );

is( $parser->embed_c(qq| __C__\n#define FOO 1\n__END_C__  |),
    "#define FOO 1\n", "embed_c" );

for (qw( foo _foo foo_yoo FOO Foo fOO f00 )) {
    is( $parser->identifier($_), $_, "identifier: $_" );
}

for (qw( void unsigned float u32_t i64_t u8_t bool_t )) {
    ok( !$parser->identifier($_), "reserved word not an identifier: $_" );
}

is( $parser->chy_integer_specifier($_), $_, "Charmony integer specifier $_" )
    for qw( u8_t u16_t u32_t u64_t i8_t i16_t i32_t i64_t bool_t );

is( $parser->object_type_specifier($_), $_, "object_type_specifier $_" )
    for qw( ByteBuf Obj ANDScorer );

is( $parser->type_specifier($_), $_, "type_specifier $_" )
    for qw( u32_t char int short long float double void ANDScorer );

is( $parser->type_qualifier($_), $_, "type_qualifier $_" ) for qw( const );

is( $parser->exposure_specifier($_), $_, "exposure_specifier $_" )
    for qw( public private parcel );

is( $parser->type_postfix($_), $_, "postfix: $_" )
    for ( '[]', '[A_CONSTANT]', '*' );
is( $parser->type_postfix('[ FOO ]'), '[FOO]', "type_postfix: [ FOO ]" );

isa_ok( $parser->type($_), "Boilerplater::Type", "type $_" )
    for ( 'const char *', 'Obj*', 'i32_t', 'char[]', 'long[1]',
    'i64_t[FOO]' );

is( $parser->declarator($_), $_, "declarator: $_" )
    for ( 'foo', 'bar_bar_bar' );

isa_ok( $parser->variable($_), "Boilerplater::Variable", "variable: $_" )
    for ( 'u32_t baz;', 'CharBuf *stuff;', 'float **ptr;', );

isa_ok( $parser->var_declaration($_)->{declared},
    "Boilerplater::Variable", "var_declaration: $_" )
    for (
    'parcel int foo;',
    'private Obj *obj;',
    'public static i32_t **foo;',
    'Dog *fido;'
    );

is( $parser->hex_constant($_), $_, "hex_constant: $_" )
    for (qw( 0x1 0x0a 0xFFFFFFFF ));

is( $parser->integer_constant($_), $_, "integer_constant: $_" )
    for (qw( 1 -9999  0 10000 ));

is( $parser->float_constant($_), $_, "float_constant: $_" )
    for (qw( 1.0 -9999.999  0.1 0.0 ));

is( $parser->string_literal($_), $_, "string_literal: $_" )
    for ( q|"blah"|, q|"blah blah"|, q|"\\"blah\\" \\"blah\\""| );

is( $parser->scalar_constant($_), $_, "scalar_constant: $_" )
    for ( q|"blah"|, 1, 1.2, "0xFC" );

my %param_lists = (
    '(int foo)'                 => 1,
    '(Obj *foo, Foo **foo_ptr)' => 2,
    '()'                        => 0,
);
while ( my ( $param_list, $num_params ) = each %param_lists ) {
    my $parsed = $parser->param_list($param_list);
    isa_ok( $parsed, "Boilerplater::ParamList", "param_list: $param_list" );
}
ok( $parser->param_list("(int foo, ...)")->variadic, "variadic param list" );
my $param_list = $parser->param_list(q|(int foo = 0xFF, char *bar ="blah")|);
is_deeply(
    $param_list->get_initial_values,
    [ '0xFF', '"blah"' ],
    "initial values"
);

my %sub_args = ( class => 'Boil::Obj', cnick => 'Obj' );

isa_ok( $parser->subroutine_declaration( $_, 0, %sub_args )->{declared},
    "Boilerplater::Method", "method declaration: $_" )
    for (
    'public int Do_Foo(Obj *self);',
    'parcel Obj* Gimme_An_Obj(Obj *self);',
    'void Do_Whatever(Obj *self, u32_t a_num, float real);',
    'private Foo* Fetch_Foo(Obj *self, int num);',
    );

isa_ok(
    $parser->subroutine_declaration( $_, 0, %sub_args, static => 1 )
        ->{declared},
    "Boilerplater::Function",
    "function declaration: $_"
    )
    for (
    'static int running_count(int biscuit);',
    'public static Hash* init_fave_hash(i32_t num_buckets, bool_t o_rly);',
    );

ok( $parser->subroutine_declaration( $_, 0, %sub_args )->{declared}->final,
    "final method: $_" )
    for ( 'public final void The_End(Obj *self);', );

ok( $parser->declaration( $_, 0, %sub_args, static => 1 ), "declaration: $_" )
    for (
    'public Foo* Spew_Foo(Obj *self, u32_t *how_many);',
    'private Hash *hash;',
    );

ok( $parser->class_name($_), "class_name: $_" )
    for (qw( Foo Foo::FooJr Foo::FooJr::FooIII Foo::FooJr::FooIII::Foo4th ));

ok( !$parser->class_name($_), "illegal class_name: $_" )
    for (qw( foo fooBar Foo_Bar ));

ok( $parser->cnick(qq|cnick $_|), "cnick: $_" ) for (qw( Foo ));

ok( $parser->class_modifier($_), "class_modifier: $_" )
    for (qw( abstract static ));

ok( $parser->class_extension($_), "class_extension: $_" )
    for ( 'extends Foo', 'extends Foo::FooJr::FooIII' );

my $class_content
    = 'public class Foo::FooJr cnick FooJr extends Foo { private int num; }';
my $class = $parser->class_declaration($class_content);
isa_ok( $class, "Boilerplater::Class", "class_declaration FooJr" );
ok( ( scalar grep { $_->micro_sym eq 'num' } $class->get_member_vars ),
    "parsed private member var" );

$class_content = q|
    /** 
     * Bow wow.
     *
     * Wow wow wow.
     */
    public class Animal::Dog extends Animal : lovable : drooly {
        public static Dog* init(Dog *self, CharBuf *name, CharBuf *fave_food);
        static u32_t count();
        static u64_t num_dogs;

        private CharBuf *name;
        private bool_t   likes_to_go_fetch;
        private void     Chase_Tail(Dog *self);

        ChewToy *squishy;
        void       Destroy(Dog *self);

        public CharBuf*    Bark(Dog *self);
        public void        Eat(Dog *self);
        public void        Bite(Dog *self, Enemy *enemy);
        public Thing      *Fetch(Dog *self, Thing *thing);
        public final void  Bury(Dog *self, Bone *bone);
        public Owner      *mom;

        i32_t[1]  flexible_array_at_end_of_struct;
    }
|;

$class = $parser->class_declaration($class_content);
isa_ok( $class, "Boilerplater::Class", "class_declaration Dog" );
ok( ( scalar grep { $_->micro_sym eq 'num_dogs' } $class->get_static_vars ),
    "parsed static var" );
ok( ( scalar grep { $_->micro_sym eq 'mom' } $class->get_member_vars ),
    "parsed public member var" );
ok( ( scalar grep { $_->micro_sym eq 'squishy' } $class->get_member_vars ),
    "parsed parcel member var" );
ok( ( scalar grep { $_->micro_sym eq 'init' } $class->get_functions ),
    "parsed function" );
ok( ( scalar grep { $_->micro_sym eq 'chase_tail' } $class->get_methods ),
    "parsed private method" );
ok( ( scalar grep { $_->micro_sym eq 'destroy' } $class->get_methods ),
    "parsed parcel method" );
ok( ( scalar grep { $_->micro_sym eq 'bury' } $class->get_methods ),
    "parsed public method" );
is( ( scalar grep { $_->public } $class->get_methods ),
    5, "pass acl to Method constructor" );
ok( $class->is('lovable'), "parsed class attribute" );
ok( $class->is('drooly'),  "parsed second class attribute" );

$class_content = qq|
    parcel static class Rigor::Mortis cnick Mort { 
        parcel static void lie_still(); 
    }|;
$class = $parser->class_declaration($class_content);
isa_ok( $class, "Boilerplater::Class", "static class_declaration" );
ok( $class->static, "static modifier parsed and passed to constructor" );

$class_content = qq|
    final class Ultimo { 
        /** Throws an error. 
         */
        void Say_Never(Ultimo *self); 
    }|;
$class = $parser->class_declaration($class_content);
isa_ok( $class, "Boilerplater::Class::Final", "final class_declaration" );

my $parcel_declaration = "parcel Stuff;";
$class_content = qq|
    class Stuff::Foo {
        Foo *a_foo;
        Bar *a_bar;
    }
|;
my $file = $parser->file("$parcel_declaration\n$class_content");
($class) = $file->get_classes;
my ( $a_foo, $a_bar ) = $class->get_member_vars;
is( $a_foo->get_type->get_specifier,
    'stuff_Foo', 'file production picked up parcel def' );
is( $a_bar->get_type->get_specifier, 'stuff_Bar', 'parcel def is sticky' );

$file = $parser->file($class_content);
($class) = $file->get_classes;
( $a_foo, $a_bar ) = $class->get_member_vars;
is( $a_foo->get_type->get_specifier, 'Foo', 'file production resets parcel' );
