use strict;
use warnings;

use Test::More tests => 7;

BEGIN { use_ok('Boilerplater::DocuComment') }

my $text = <<'END_COMMENT';
/** 
 * Brief description.  Full description including brief. 
 * 
 * More full description.
 * 
 * @param foo A foo.
 * @param bar A bar.
 *
 * @param baz A baz.
 */
END_COMMENT

my $docu_com = Boilerplater::DocuComment->new($text);

is( $docu_com->get_brief, "Brief description.", "brief" );
like( $docu_com->get_full, qr/brief.*full description.\s*\Z/ims, "full" );
is_deeply( $docu_com->get_param_names, [qw( foo bar baz )], "param names" );
is( $docu_com->get_param_docs->[0], "A foo.", '@param terminated by @' );
is( $docu_com->get_param_docs->[1],
    "A bar.", '@param terminated by empty line' );
is( $docu_com->get_param_docs->[2],
    "A baz.", '@param terminated by end of string' );
