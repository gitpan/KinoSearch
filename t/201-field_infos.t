#!/usr/bin/perl
use strict;
use warnings;
use bytes;

use lib 't';

use Test::More tests => 9;
use File::Spec::Functions qw( catfile );

BEGIN {
    use_ok('KinoSearch::Index::CompoundFileReader');
    use_ok('KinoSearch::Index::FieldInfos');
    use_ok('KinoSearch::Document::Field');
}
use KinoSearchTestInvIndex qw( create_invindex );

my $finfos = KinoSearch::Index::FieldInfos->new;

for my $name (qw( x b a content )) {
    $finfos->add_field(
        KinoSearch::Document::Field->new(
            name     => $name,
            store_tv => 1,
        )
    );
}

my @nums = map { $finfos->get_field_num($_) } qw( a b content x );
is_deeply( \@nums, [ 0, 1, 2, 3 ],
    "field nums should reflect lexical order" );

is( $finfos->get_fnum_map,
    "\x00\x00\x00\x01\x00\x02\x00\x03",
    "default fnum_map should produce ascending numbers"
);

my $invindex = create_invindex( 'a', 'a b' );
my $cfs_reader = KinoSearch::Index::CompoundFileReader->new(
    invindex => $invindex,
    seg_name => '_1',
);

my $outstream = $invindex->open_outstream('finfos_test');
$finfos->write_infos($outstream);
$outstream->close;

# hack field numbers to simulate Java lucene's non-ordered behavior
for ( ${ $invindex->{ramfiles}{finfos_test} } ) {
    tr/b/z/ == 1 or die "hack failed";
    tr/x/b/ == 1 or die "hack failed";
    tr/z/x/ == 1 or die "hack failed";
}

$finfos = KinoSearch::Index::FieldInfos->new;
my $instream = $invindex->open_instream('finfos_test');
$finfos->read_infos($instream);
$instream->close;
is( $finfos->get_fnum_map,
    "\x00\x00\x00\x03\x00\x02\x00\x01",
    "fnum_map created by read_infos should deal with lucene data correctly"
);

my $finfos2 = KinoSearch::Index::FieldInfos->new;
$instream = $cfs_reader->open_instream("_1.fnm");
$finfos2->read_infos($instream);

my %correct = (
    name                 => 'content',
    field_num            => 0,
    indexed              => 1,
    store_tv             => 0,
    store_offset_with_tv => 0,
    store_pos_with_tv    => 0,
    fnm_bits             => "\x1",
);
my ($finfo) = grep { $_->{name} eq 'content' } $finfos2->get_infos;
my %test;
$test{$_} = $finfo->{$_} for keys %correct;
is_deeply( \%test, \%correct, "Reading and writing, plus get_infos" );

my $master_finfos = KinoSearch::Index::FieldInfos->new;
$master_finfos->consolidate( $finfos, $finfos2 );

is( $finfos2->get_fnum_map, "\x00\x02",
    "consolidate should reassign field nums in source finfos object" );

my $new_content_finfo = $master_finfos->info_by_name('content');
is( $new_content_finfo->{store_tv},
    1, "consolidate and breed_with merge field characteristics properly" );
