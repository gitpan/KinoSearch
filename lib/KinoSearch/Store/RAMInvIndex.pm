package KinoSearch::Store::RAMInvIndex;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Store::InvIndex );

use Digest::MD5 qw( md5_hex );
use KinoSearch::Store::FSInvIndex;
use KinoSearch::Store::InStream;
use KinoSearch::Store::OutStream;
use KinoSearch::Store::RAMLock;

our %instance_vars = __PACKAGE__->init_instance_vars(
    # members
    ramfiles => {},
);

sub init_instance {
    my $self = shift;

    # read in an FSInvIndex if specified
    $self->_read_invindex if defined $self->{path};
}

sub _read_invindex {
    my $self = shift;

    # open an FSInvIndex for reading
    my $source_invindex
        = KinoSearch::Store::FSInvIndex->new( path => $self->{path}, );

    # copy every file in the FSInvIndex into RAM.
    for my $filename ( $source_invindex->list ) {
        my $source_stream = $source_invindex->open_instream($filename);
        my $outstream     = $self->open_outstream($filename);
        local $/ = 4096;
        print $outstream $_ while (<$source_stream>);
        $source_stream->close;
        $outstream->close;
    }

    $source_invindex->close;
}

sub open_outstream {
    my ( $self, $filename ) = @_;

    # use perl scalars as virtual files;
    my $data = '';
    $self->{ramfiles}{$filename} ||= \$data;
    open( my $fh, '>', $self->{ramfiles}{$filename} ) or die $!;
    binmode($fh);
    return KinoSearch::Store::OutStream->new($fh);
}

sub open_instream {
    my ( $self, $filename, $offset, $len ) = @_;
    croak("File '$filename' not loaded into RAM")
        unless exists $self->{ramfiles}{$filename};
    open( my $fh, '<', $self->{ramfiles}{$filename} ) or die $!;
    binmode($fh);
    return KinoSearch::Store::InStream->new( $self, $filename, $fh, $offset,
        $len );
}

sub list {
    keys %{ $_[0]->{ramfiles} };
}

sub file_exists {
    my ( $self, $filename ) = @_;
    return ( exists $self->{ramfiles}{$filename} );
}

sub rename_file {
    my ( $self, $from, $to ) = @_;
    croak("File '$from' not currently in RAM")
        unless exists $self->{ramfiles}{$from};
    $self->{ramfiles}{$to} = delete $self->{ramfiles}{$from};
}

sub delete_file {
    my ( $self, $filename ) = @_;
    my $file = delete $self->{ramfiles}{$filename};
    croak("File '$filename' not currently in RAM")
        unless $file;
}

sub slurp_file {
    my ( $self, $filename ) = @_;
    my $virtual_file_ref = $self->{ramfiles}{$filename};
    croak("File '$filename' not currently in RAM")
        unless defined $virtual_file_ref;

    # return a copy of the virtual file's content
    return $$virtual_file_ref;
}

sub make_lock {
    my $self = shift;
    return KinoSearch::Store::RAMLock->new( @_, invindex => $self );
}
sub close { }

1;

__END__

=head1 NAME

KinoSearch::Store::RAMInvIndex - in-memory InvIndex 

=head1 SYNOPSIS
    

    my $invindex = KinoSearch::Store::RAMInvIndex->new(
        path   => '/path/to/invindex',
    );

    # or...
    my $invindex = KinoSearch::Store::RAMInvIndex->new;


=head1 DESCRIPTION

RAMInvIndex is an entirely in-memory implementation of
KinoSearch::Store::InvIndex.  It serves two main purposes.

First, it's possible to load an existing FSInvIndex into memory, which can
improve search-speed -- if you have that kind of RAM to spare.  Needless to
say, any FSInvIndex you try to load this way should be appropriately modest in
size.

Second, RAMInvIndex is handy for testing and development.

=head1 CONSTRUCTOR

=head2 new

Create a RAMInvIndex object.  C<new> takes one optional parameter, C<path>. If
C<path> is supplied, KinoSearch will try to read an FSInvIndex at that
location into memory.

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05_04.

=cut
