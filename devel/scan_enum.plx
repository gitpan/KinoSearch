#!/usr/bin/perl
use strict;
use warnings;
$|++;

use Time::HiRes qw( time );
use KinoSearch::Store::FSInvIndex;
use KinoSearch::Index::FieldInfos;
use KinoSearch::Index::CompoundFileReader;
use KinoSearch::Index::SegTermEnum;

my $invindex = KinoSearch::Store::FSInvIndex->new( path => $ARGV[0], );

my $cfs_reader = KinoSearch::Index::CompoundFileReader->new(
    invindex => $invindex,
    seg_name => '_1',
);
my $finfos = KinoSearch::Index::FieldInfos->new;
$finfos->read_infos( $cfs_reader->open_instream('_1.fnm') );

my $t0 = time;
while (1) {
    print ".";
    #    1 for 1 .. 10000;
    my $instream = $cfs_reader->open_instream('_1.tl');
    my $enum     = KinoSearch::Index::SegTermEnum->new(
        finfos   => $finfos,
        instream => $instream,
    );
    $enum->fill_cache();
    # 1 while defined (my $term = $enum->next);
}
print( ( time - $t0 ) . " secs\n" );
