#!/usr/bin/perl
use strict;
use warnings;

use lib 't';

use Test::More tests => 5;
use File::Spec::Functions qw( catfile );

BEGIN {
    use_ok('KinoSearch::Index::CompoundFileReader');
    use_ok( 'KinoSearch::Index::IndexFileNames', qw( @COMPOUND_EXTENSIONS ) );
}
use KinoSearchTestInvIndex qw( create_invindex );

my $invindex   = create_invindex('a');
my $cfs_reader = KinoSearch::Index::CompoundFileReader->new(
    invindex => $invindex,
    seg_name => '_1',
);

my $instream = $cfs_reader->open_instream('_1.tis');
isa_ok( $instream, 'KinoSearch::Store::InStream' );

my $tis_bytecount = $instream->length;
is( $cfs_reader->slurp_file('_1.tis'),
    $instream->lu_read("a$tis_bytecount"),
    "slurp_file gets the right bytes"
);

my @files = sort map {"_1.$_"} ( @COMPOUND_EXTENSIONS, 'f0' );

my @cfs_entries = sort keys %{ $cfs_reader->{entries} };

is_deeply( \@cfs_entries, \@files, "get all the right files" );

