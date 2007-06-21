use strict;
use warnings;

package KinoSearch::Simple;
use base qw( KinoSearch::Util::Class );
use KinoSearch::Util::ToolSet;

# create one Schema subclass for each language
my $schema_code = '';
for my $lang_iso (qw( da nl en fi fr de it no pt es sv ru )) {
    $schema_code .= <<LANG_SCHEMA;
    package KinoSearch::Simple::Schema::$lang_iso;
    use base qw( KinoSearch::Schema );
    our\%fields = ();
    sub analyzer { 
        KinoSearch::Analysis::PolyAnalyzer->new( language => '$lang_iso' );
    }
LANG_SCHEMA
}
eval $schema_code;

use KinoSearch::Schema::FieldSpec;
use KinoSearch::Analysis::PolyAnalyzer;
use KinoSearch::InvIndex;
use KinoSearch::InvIndexer;
use KinoSearch::Searcher;
use KinoSearch::Store::FSFolder;

our %instance_vars = (
    # params / members
    path     => undef,
    language => undef,

    # members
    schema     => undef,
    invindex   => undef,
    invindexer => undef,
    searcher   => undef,
    hits       => undef,
);

sub init_instance {
    my $self = shift;

    # verify language
    my $language = lc( $self->{language} );
    croak("Invalid value for language: '$self->{language}'")
        unless $language =~ /^(?:da|de|en|es|fi|fr|it|nl|no|pt|ru|sv)$/;
    $self->{language} = $language;

    # get schema and invindex
    my $schema_package = "KinoSearch::Simple::Schema::$language";
    my $schema = $self->{schema} = $schema_package->new;
    confess("Missing required parameter 'path'") unless defined $self->{path};
    $self->{invindex} = $schema->open( $self->{path} );

    return $self;
}

sub _lazily_create_invindexer {
    my $self = shift;
    if ( !defined $self->{invindexer} ) {
        $self->{invindexer}
            = KinoSearch::InvIndexer->new( invindex => $self->{invindex}, );
    }
}

sub add_doc {
    my ( $self, $hashref ) = @_;
    my $schema = $self->{schema};
    croak("add_doc requires exactly one argument: a hashref")
        unless ( @_ == 2 and reftype($hashref) eq 'HASH' );
    $self->_lazily_create_invindexer;
    $schema->add_field( $_ => 'KinoSearch::Schema::FieldSpec' )
        for keys %$hashref;
    $self->{invindexer}->add_doc($hashref);
}

sub _finish_indexing {
    my $self = shift;

    # don't bother to throw an error if index not modified
    if ( defined $self->{invindexer} ) {
        $self->{invindexer}->finish;

        # trigger searcher and invindexer refresh
        undef $self->{invindexer};
        undef $self->{searcher};
    }
}

sub search {
    my ( $self, %args ) = @_;

    # flush recent adds; lazily create searcher
    $self->_finish_indexing;
    if ( !defined $self->{searcher} ) {
        $self->{searcher}
            = KinoSearch::Searcher->new( invindex => $self->{invindex}, );
    }

    $self->{hits} = $self->{searcher}->search(%args);

    return $self->{hits}->total_hits;
}

sub fetch_hit_hashref {
    my $self = shift;
    return unless defined $self->{hits};

    # get the hashref, bail if hits are exhausted
    my $hashref = $self->{hits}->fetch_hit_hashref;
    if ( !defined $hashref ) {
        undef $self->{hits};
        return;
    }

    return $hashref;
}

sub DESTROY { shift->_finish_indexing }

1;

__END__

__POD__

=head1 NAME

KinoSearch::Simple - Basic search engine.

=head1 SYNOPSIS

First, build an index of your documents.

    my $index = KinoSearch::Simple->new(
        path     => '/path/to/index/'
        language => 'en',
    );

    while ( my ( $title, $content ) = each %source_docs ) {
        $index->add_doc({
            title    => $title,
            content  => $content,
        });
    }

Later, search the index.

    my $total_hits = $index->search( 
        query      => $query_string,
        offset     => 0,
        num_wanted => 10,
    );

    print "Total hits: $total_hits\n";
    while ( my $hit = $index->fetch_hit_hashref ) {
        print "$hit->{title}\n",
    }

=head1 DESCRIPTION

KinoSearch::Simple is a stripped-down interface for the L<KinoSearch> search
engine library.  

=head1 METHODS 

=head2 new

    my $index = KinoSearch::Simple->new(
        path     => '/path/to/index/',
        language => 'en',
    );

Create a KinoSearch::Simple object, which can be used for both indexing and
searching.  Two hash-style parameters are required.

=over 

=item *

B<path> - Where the index directory should be located.  If no index is found
at the specified location, one will be created.

=item *

B<language> - The language of the documents in your collection, indicated 
by a two-letter ISO code.  12 languages are supported:

    |-----------------------|
    | Language   | ISO code |
    |-----------------------|
    | Danish     | da       |
    | Dutch      | nl       |
    | English    | en       |
    | Finnish    | fi       |
    | French     | fr       |
    | German     | de       |
    | Italian    | it       |
    | Norwegian  | no       |
    | Portuguese | pt       |
    | Spanish    | es       |
    | Swedish    | sv       |
    | Russian    | ru       |
    |-----------------------|

=back

=head2 add_doc 

    $index->add_doc({
        location => $url,
        title    => $title,
        content  => $content,
    });

Add a document to the index.  The document must be supplied as a hashref, with
field names as keys and content as values.

=head2 search

    my $total_hits = $index->search( 
        query      => $query_string,    # required
        offset     => 40,               # default 0
        num_wanted => 20,               # default 10
    );

Search the index.  Returns the total number of documents which match the
query.  (This number is unlikely to match C<num_wanted>.)

=over

=item *

B<query> - A search query string.

=item *

B<offset> - The number of most-relevant hits to discard, typically used when
"paging" through hits N at a time.  Setting offset to 20 and num_wanted to 10
retrieves hits 21-30, assuming that 30 hits can be found.

=item *

B<num_wanted> - The number of hits you would like to see after C<offset> is
taken into account.  

=back

=head1 BUGS

Not thread-safe.

=head1 COPYRIGHT

Copyright 2007 Marvin Humphrey

=head1 LICENSE, DISCLAIMER, BUGS, etc.

See L<KinoSearch> version 0.20.

=cut
