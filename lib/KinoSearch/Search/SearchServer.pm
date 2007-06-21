use strict;
use warnings;

package KinoSearch::Search::SearchServer;
use KinoSearch::Util::ToolSet;
use base qw( KinoSearch::Util::Class );

our %instance_vars = (
    # params / members
    searchable => undef,
    port       => undef,
    password   => undef,

    # members
    sock => undef,

);

use IO::Socket::INET;
use IO::Select;
use Storable qw( nfreeze thaw );

sub init_instance {
    my $self = shift;

    confess("Missing required param 'password'")
        unless defined $self->{password};

    # establish a listening socket
    confess("Invalid port") unless $self->{port} =~ /^\d+$/;
    my $sock = IO::Socket::INET->new(
        LocalPort => $self->{port},
        Proto     => 'tcp',
        Listen    => SOMAXCONN,
        Reuse     => 1,
    );
    confess("No socket: $!") unless $sock;
    $sock->autoflush(1);
    $self->{sock} = $sock;
}

my %dispatch = (
    max_doc       => \&do_max_doc,
    doc_freq      => \&do_doc_freq,
    doc_freqs     => \&do_doc_freqs,
    top_docs      => \&do_top_docs,
    fetch_doc     => \&do_fetch_doc,
    fetch_doc_vec => \&do_fetch_doc_vec,
    terminate     => undef,
);

sub serve {
    my $self      = shift;
    my $main_sock = $self->{sock};
    my $read_set  = IO::Select->new($main_sock);

    while ( my @ready = $read_set->can_read ) {
        for my $readhandle (@ready) {
            # if this is the main handle, we have a new client, so accept
            if ( $readhandle == $main_sock ) {
                my $client_sock = $main_sock->accept;

                # verify password
                chomp( my $pass = <$client_sock> );
                if ( $pass eq $self->{password} ) {
                    $read_set->add($client_sock);
                    print $client_sock "accepted\n";
                }
                else {
                    print $client_sock "password incorrect\n";
                }
            }
            # otherwise it's a client sock, so process the request
            else {
                my $client_sock = $readhandle;
                my ( $check_val, $buf, $len, $method, $args );
                chomp( $method = <$client_sock> );

                # if "done", the client's closing
                if ( $method eq 'done' ) {
                    $read_set->remove($client_sock);
                    $client_sock->close;
                    next;
                }
                # remote signal to close the server
                elsif ( $method eq 'terminate' ) {
                    $read_set->remove($client_sock);
                    $client_sock->close;
                    $main_sock->close;
                    return;
                }
                # sanity check the method name
                elsif ( !$dispatch{$method} ) {
                    print $client_sock "ERROR: Bad method name: $method\n";
                    next;
                }

                # process the method call
                read( $client_sock, $buf, 4 );
                $len = unpack( 'N', $buf );
                read( $client_sock, $buf, $len );
                my $response   = $dispatch{$method}->( $self, thaw($buf) );
                my $frozen     = nfreeze($response);
                my $packed_len = pack( 'N', bytes::length($frozen) );
                print $client_sock $packed_len . $frozen;
            }
        }
    }
}

sub do_doc_freq {
    my ( $self, $args ) = @_;
    my $doc_freq = $self->{searchable}->doc_freq( $args->{term} );
    return { doc_freq => $doc_freq };
}

sub do_doc_freqs {
    my ( $self, $args ) = @_;
    return $self->{searchable}->doc_freqs( $args->{terms} );
}

sub do_top_docs {
    my ( $self, $args ) = @_;
    confess("remote filtered search not supported")
        if defined $args->{filter};
    return $self->{searchable}->top_docs(%$args);
}

sub do_max_doc {
    my ( $self, $args ) = @_;
    my $max_doc = $self->{searchable}->max_doc;
    return { max_doc => $max_doc };
}

sub do_fetch_doc {
    my ( $self, $args ) = @_;
    return $self->{searchable}->fetch_doc( $args->{doc_num} );
}

sub do_fetch_doc_vec {
    my ( $self, $args ) = @_;
    return $self->{searchable}->fetch_doc_vec( $args->{doc_num} );
}

1;

__END__

=head1 NAME

KinoSearch::Search::SearchServer - Make a Searcher remotely accessible.

=head1 SYNOPSIS

    my $searcher = KinoSearch::Searcher->new(
        invindex => MySchema->read('path/to/invindex'),
    );
    my $search_server = KinoSearch::Search::SearchServer->new(
        searchable => $searcher,
        port       => 7890,
        password   => $pass,
    );
    $search_server->serve;

=head1 DESCRIPTION 

The SearchServer class, in conjunction with
L<SearchClient|KinoSearch::Search::SearchClient>, makes it possible to run
a search on one machine and report results on another.  

By aggregating several SearchClients under a
L<MultiSearcher|KinoSearch::Search::MultiSearcher>, the cost of searching
what might have been a prohibitively large monolithic index can be distributed
across multiple nodes, each with its own, smaller index.

=head1 METHODS

=head2 new

    my $search_server = KinoSearch::Search::SearchServer->new(
        searchable => $searcher, # required
        port       => 7890,      # required
        password   => $pass,     # required
    );

Constructor.  Takes hash-style parameters.

=over

=item *

B<searchable> - the L<Searcher|KinoSearch::Searcher> that the SearchServer
will wrap.

=item *

B<port> - the port on localhost that the server should open and listen on.

=item *

B<password> - a password which must be supplied by clients.

=back

=head2 serve

    $search_server->serve;

Open a listening socket on localhost and wait for SearchClients to connect.

=head1 COPYRIGHT

Copyright 2006-2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut

