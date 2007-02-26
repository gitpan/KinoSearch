use strict;
use warnings;

package KinoSearch::Searcher::SearchClient;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Searcher );

use Storable qw( nfreeze thaw );

BEGIN {
    __PACKAGE__->init_instance_vars(
        # params/members
        peer_address => undef,
        password     => undef,
    );
}

use IO::Socket::INET;

sub init_instance {
    my $self = shift;

    # verify schema
    confess("required parameter 'schema'")
        unless a_isa_b( $self->{schema}, "KinoSearch::Schema" );

    # establish a connection
    my $sock = IO::Socket::INET->new(
        PeerAddr => $self->{peer_address},
        Proto    => 'tcp',
    );
    confess("No socket: $!") unless $sock;
    $sock->autoflush(1);
    $self->{sock} = $sock;

    # verify password
    print $sock "$self->{password}\n";
    chomp( my $response = <$sock> );
    confess("Failed to connect: '$response'") unless $response =~ /accept/i;
}

=for comment

Make a remote procedure call.  For every call that does not close/terminate
the socket connection, expect a response back that's been serialized using
Storable.

=cut

sub _rpc {
    my ( $self, $method, $args ) = @_;
    my $sock = $self->{sock};

    my $serialized = nfreeze($args);
    my $packed_len = pack( 'N', bytes::length($serialized) );
    print $sock "$method\n$packed_len$serialized";

    # bail out if we're either closing or shutting down the server remotely
    return if $method eq 'done';
    return if $method eq 'terminate';

    # decode response
    $sock->read( $packed_len, 4 );
    my $arg_len = unpack( 'N', $packed_len );
    my $check_val = read( $sock, $serialized, $arg_len );
    confess("Tried to read $arg_len bytes, got $check_val")
        unless ( defined $arg_len and $check_val == $arg_len );
    return thaw($serialized);
}

my %search_top_docs_args = (
    query      => undef,
    filter     => undef,
    num_wanted => undef,
    sort_spec  => undef,
);

sub search_top_docs {
    my $self = shift;
    confess kerror() unless verify_args( \%search_top_docs_args, @_ );
    my %args = ( %search_top_docs_args, @_ );
    confess("remote filtered search not supported") if defined $args{filter};

    return $self->_rpc( 'search_top_docs', \%args );
}

sub terminate {
    my $self = shift;
    return $self->_rpc( 'terminate', {} );
}

sub fetch_doc {
    my ( $self, $doc_num ) = @_;
    return $self->_rpc( 'fetch_doc', { doc_num => $doc_num } );
}

sub fetch_doc_vec {
    my ( $self, $doc_num ) = @_;
    return $self->_rpc( 'fetch_doc_vec', { doc_num => $doc_num } );
}

sub max_doc {
    my $self = shift;
    return $self->_rpc( 'max_doc', {} );
}

sub doc_freq {
    my ( $self, $term ) = @_;
    return $self->_rpc( 'doc_freq', { term => $term } );
}

sub doc_freqs {
    my ( $self, $terms ) = @_;
    return $self->_rpc( 'doc_freqs', { terms => $terms } );
}

sub close {
    my $self = shift;
    $self->_rpc( 'done', {} );
    my $sock = $self->{sock};
    close $sock or confess("Error when closing socket: $!");
    undef $self->{sock};
}

sub DESTROY {
    my $self = shift;
    $self->close if defined $self->{sock};
}

1;

__END__

=head1 NAME

KinoSearch::Search::SearchClient - Connect to a remote SearchServer.

=head1 SYNOPSIS

    my $client = KinoSearch::Search::SearchClient->new(
        peer_address => 'searchserver1:7890',
        password     => $pass,
    );
    my $hits = $client->search( query => $query );

=head1 DESCRIPTION

SearchClient is a subclass of L<KinoSearch::Searcher> which can be used to
search an index on a remote machine made accessible via
L<SearchServer|KinoSearch::Search::SearchServer>.

=head1 METHODS

=head2 new

Constructor.  Takes hash-style params.

=over

=item *

B<peer_address> - The name/IP and the port number which the client should
attempt to connect to.

=item *

B<password> - Password to be supplied to the SearchServer when initializing
socket connection.

=back

=head1 LIMITATIONS

Limiting search results with a QueryFilter is not supported.

=head1 COPYRIGHT

Copyright 2006-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.14.

=cut

