use strict;
use warnings;
use lib 'buildlib';

package MyStepper;
use base qw( KinoSearch::Util::Stepper );

our %number;

sub new {
    my $self = shift->SUPER::new(@_);
    $number{$$self} = 0;
    return $self;
}

sub DESTROY {
    my $self = shift;
    delete $number{$$self};
    $self->SUPER::DESTROY;
}

sub get_number { $number{ ${ +shift } } }

sub read_record {
    my ( $self, $instream ) = @_;
    $number{$$self} += $instream->read_c32;
}

sub to_string {
    my $self = shift;
    return $number{$$self};
}

package main;
use Test::More tests => 2;

my $folder = KinoSearch::Store::RAMFolder->new;
my $outstream = $folder->open_out("foo") or die "Can't open outstream";
$outstream->write_c32(10) for 1 .. 5;
$outstream->close;
my $instream = $folder->open_in("foo");
my $stepper  = MyStepper->new;

my @got;
while ( $instream->tell < $instream->length ) {
    $stepper->read_record($instream);
    push @got, $stepper->get_number;
}
is_deeply( \@got, [ 10, 20, 30, 40, 50 ], 'Read_Record' );

$stepper = MyStepper->new;
$instream->seek(0);
my $dump_stream = $folder->open_out('dump')
    or die "Can't open outstream";

$stepper->dump_to_file( instream => $instream, outstream => $dump_stream );
$dump_stream->close;
my $dumped = $folder->slurp_file('dump');
like( $dumped, qr/10.*20.*30.*40.*50/s, "dump_to_file" );
