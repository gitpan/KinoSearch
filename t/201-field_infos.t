#!/usr/bin/perl
use strict;
use warnings;

use lib 't';

use Test::More tests => 7;
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
            name       => $name,
            vectorized => 0,
        )
    );
}

my @nums = map { $finfos->get_field_num($_) } qw( a b content x );
is_deeply( \@nums, [ 0, 1, 2, 3 ],
    "field nums should reflect lexical order" );

my $invindex = create_invindex( 'a', 'a b' );
my $cfs_reader = KinoSearch::Index::CompoundFileReader->new(
    invindex => $invindex,
    seg_name => '_1',
);

my $outstream = $invindex->open_outstream('finfos_test');
$finfos->write_infos($outstream);
$outstream->close;

$finfos = KinoSearch::Index::FieldInfos->new;
my $instream = $invindex->open_instream('finfos_test');
$finfos->read_infos($instream);
$instream->close;

my $finfos2 = KinoSearch::Index::FieldInfos->new;
$instream = $cfs_reader->open_instream("_1.fnm");
$finfos2->read_infos($instream);

my %correct = (
    name       => 'content',
    field_num  => 0,
    indexed    => 1,
    vectorized => 1,
    fnm_bits   => "\x3",
);
my ($finfo) = grep { $_->get_name eq 'content' } $finfos2->get_infos;
my %test;
$test{$_} = $finfo->{$_} for keys %correct;
is_deeply( \%test, \%correct, "Reading and writing, plus get_infos" );

my $master_finfos = KinoSearch::Index::FieldInfos->new;
$master_finfos->consolidate( $finfos, $finfos2 );

my $new_content_finfo = $master_finfos->info_by_name('content');
is( $new_content_finfo->get_vectorized,
    1, "consolidate and breed_with merge field characteristics properly" );

$finfos = KinoSearch::Index::FieldInfos->new;
my @correct = ( 'a' .. 'z' );
for my $name ( reverse @correct ) {
    $finfos->add_field( KinoSearch::Document::Field->new( name => $name ) );
}
$outstream = $invindex->open_outstream('finfos_test2');
$finfos->write_infos($outstream);
$outstream->close;
$finfos   = KinoSearch::Index::FieldInfos->new;
$instream = $invindex->open_instream('finfos_test2');
$finfos->read_infos($instream);
my @got = map { $finfos->info_by_num($_)->get_name } 0 .. 25;
is_deeply( \@got, \@correct, "field numbers still correct after write/read" );

