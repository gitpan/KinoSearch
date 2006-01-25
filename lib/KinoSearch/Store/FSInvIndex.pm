package KinoSearch::Store::FSInvIndex;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Store::InvIndex );

use File::Spec::Functions qw( canonpath catfile catdir tmpdir no_upwards );
use File::Path qw( rmtree );
use Digest::MD5 qw( md5_hex );
use KinoSearch::Store::InStream;
use KinoSearch::Store::OutStream;
use vars qw( $LOCK_DIR );    # used by FSLock
use KinoSearch::Store::FSLock;

BEGIN {
    # confirm or create a directory to put lockfiles in
    $LOCK_DIR = catdir( tmpdir, 'kinosearch_lockdir' );
    if ( !-d $LOCK_DIR ) {
        mkdir $LOCK_DIR or die "couldn't mkdir '$LOCK_DIR': $!";
        chmod 0777, $LOCK_DIR;
    }
}

our %instance_vars = __PACKAGE__->init_instance_vars();

sub init_instance {
    my $self = shift;

    # clean up path.
    my $path = $self->{path} = canonpath( $self->{path} );

    if ( $self->{create} ) {
        # clear out lockfiles related to this path
        my $lock_prefix = $self->get_lock_prefix;
        opendir LOCKDIR, $LOCK_DIR,
            or croak("couldn't opendir '$LOCK_DIR': $!");
        my @lockfiles = grep {/$lock_prefix/} readdir LOCKDIR;
        closedir LOCKDIR;
        for (@lockfiles) {
            $_ = catfile( $LOCK_DIR, $_ );
            unlink $_ or croak("couldn't unlink '$_': $!");
        }

        # blast any existing index files
        rmtree($path);
        croak("'rmtree($path) not completely successful - still exists")
            if ( -e $path );
        mkdir $path or croak("couldn't mkdir '$path': $!");
    }

    # by now, we should have a directory, so throw an error if we don't
    if ( !-d $path ) {
        croak( "invindex location '$path' doesn't exist - are the values for "
                . "'path' and 'create' correct?" )
            unless -e $path;
        croak("invindex location '$path' isn't a directory");
    }
}

sub open_outstream {
    my ( $self, $filename ) = @_;
    my $filepath = catfile( $self->{path}, $filename );
    open( my $fh, "+>", $filepath )    # clobbers
        or croak("Couldn't open file '$filepath': $!");
    binmode($fh);
    return KinoSearch::Store::OutStream->new($fh);
}

sub open_instream {
    my ( $self, $filename, $offset, $len ) = @_;
    my $filepath = catfile( $self->{path}, $filename );
    open( my $fh, "<", $filepath )
        or croak("Couldn't open file '$filepath': $!");
    binmode($fh);
    return KinoSearch::Store::InStream->new( $self, $filename, $fh, $offset,
        $len );
}

sub list {
    my $self = shift;
    opendir( my $dir, $self->{path} )
        or croak("Couldn't opendir '$self->{path}'");
    return no_upwards( readdir $dir );
}

sub file_exists {
    my ( $self, $filename ) = @_;
    return -e catfile( $self->{path}, $filename );
}

sub rename_file {
    my ( $self, $from, $to ) = @_;
    $_ = catfile( $self->{path}, $_ ) for ( $from, $to );
    rename( $from, $to )
        or croak("couldn't rename file '$from' to '$to': $!");
}

sub delete_file {
    my ( $self, $filename ) = @_;
    $filename = catfile( $self->{path}, $filename );
    unlink $filename or croak("couldn't unlink file '$filename': $!");
}

sub slurp_file {
    my ( $self, $filename ) = @_;
    my $filepath = catfile( $self->{path}, $filename );
    open( my $fh, "<", $filepath )
        or croak("Couldn't open file '$filepath': $!");
    binmode($fh);
    local $/;
    return <$fh>;
}

sub make_lock {
    my $self = shift;
    return KinoSearch::Store::FSLock->new( @_, invindex => $self );
}

# Create a hashed string derived from this invindex's path.
sub get_lock_prefix {
    my $self = shift;
    return "kinosearch-" . md5_hex( canonpath( $self->{path} ) );
}

sub close { }

1;

__END__

=head1 NAME

KinoSearch::Store::FSInvIndex - file system InvIndex 

=head1 SYNOPSIS

    my $invindex = KinoSearch::Store::FSInvIndex->new(
        path   => '/path/to/invindex',
        create => 1,
    );

=head1 DESCRIPTION

Implementation of KinoSearch::Store::InvIndex using a single file system 
directory and multiple files.

=head1 CONSTRUCTOR

=head2 new

C<new> takes two parameters:

=over 

=item

B<path> - the location of the invindex.

=item

B<create> - if set to 1, create a fresh invindex, clobbering an
existing one if necessary. Default value is 0, indicating that an existing
invindex should be opened.

=back

=head1 COPYRIGHT

Copyright 2005-2006 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch|KinoSearch> version 0.05_04.

=cut
