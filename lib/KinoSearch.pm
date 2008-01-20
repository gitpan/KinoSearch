use strict;
use warnings;

package KinoSearch;

use 5.008003;

our $VERSION = '0.20_051';

use constant K_DEBUG => 0;

use XSLoader;
# This loads a large number of disparate subs.
# See the docs for KinoSearch::Util::ToolSet.
XSLoader::load( 'KinoSearch', $VERSION );

use base qw( Exporter );
our @EXPORT_OK = qw( K_DEBUG kdump );

sub kdump {
    require Data::Dumper;
    my $kdumper = Data::Dumper->new( [@_] );
    $kdumper->Sortkeys( sub { return [ sort keys %{ $_[0] } ] } );
    $kdumper->Indent(1);
    warn $kdumper->Dump;
}

1;

__END__

__XS__

MODULE = KinoSearch    PACKAGE = KinoSearch

IV
_dummy_function()
CODE:
    RETVAL = 1;
OUTPUT:
    RETVAL

__POD__

=head1 NAME

KinoSearch - Search engine library.

=head1 VERSION

0.20_051

=head1 EXTRA WARNING

This is a developer's release.  The new features and API changes are being
auditioned and may change.  

=head1 WARNING

KinoSearch 0.20 B<BREAKS BACKWARDS COMPATIBILITY> with earlier versions.  Both
the API and the file format have changed.  Old applications must be tweaked,
and old indexes cannot be read and must be recreated -- see the C<Changes> file
for details.

KinoSearch is still officially "alpha" software -- see 
C<Backwards Compatibility Policy>, below.

=head1 SYNOPSIS

First, plan out your index structure and describe it with a "schema".

    # ./MySchema.pm

    package MySchema;
    use base qw( KinoSearch::Schema );
    use KinoSearch::Analysis::PolyAnalyzer;
    
    our %fields = (
        title   => 'text',
        content => 'text',
    );

    sub analyzer { 
        return KinoSearch::Analysis::PolyAnalyzer->new( language => 'en' );
    }

Next, create the index and add documents to it.

    use KinoSearch::InvIndexer;
    use MySchema;
    
    my $invindexer = KinoSearch::InvIndexer->new(
        invindex => MySchema->clobber('/path/to/invindex'),
    );
    
    while ( my ( $title, $content ) = each %source_docs ) {
        $invindexer->add_doc({
            title   => $title,
            content => $content,
        });
    }
    
    $invindexer->finish;

Finally, search the index:

    use KinoSearch::Searcher;
    
    my $searcher = KinoSearch::Searcher->new(
        invindex => MySchema->read('/path/to/invindex'),
    );
    
    my $hits = $searcher->search( query => "foo bar" );
    while ( my $hit = $hits->fetch_hit_hashref ) {
        print "$hit->{title}\n";
    }

=head1 DESCRIPTION

KinoSearch is a loose port of the Java search engine library Apache Lucene,
written in C and Perl. The archetypal application is website search, but it
can be put to many different uses.

=head2 Features

=over

=item *

Extremely fast.  A single machine can handle millions of documents.

=item *

Scalable to multiple machines.

=item *

Incremental indexing (addition/deletion of documents to/from an existing
index).

=item *

UTF-8 support.

=item *

Support for boolean operators AND, OR, and AND NOT; parenthetical groupings;
and prepended +plus and -minus.

=item *

Algorithmic selection of relevant excerpts and highlighting of search terms
within excerpts.

=item *

Highly customizable query and indexing APIs.

=item *

Customizable sorting.

=item *

Phrase matching.

=item *

Stemming.

=item *

Stoplists.

=back

=head2 Getting Started

L<KinoSearch::Simple> provides a stripped down API which may suffice for many
tasks.

L<KinoSearch::Docs::Tutorial> demonstrates how to build a basic CGI search
application.  Most people cut-and-paste the sample code from it and get right
down to business, referring back to the class documentation only as needed.

The tutorial spends most of its time on these five classes:

=over 

=item *

L<KinoSearch::Schema> - Plan out your index.

=item *

L<KinoSearch::FieldSpec> - Define index fields.

=item *

L<KinoSearch::InvIndexer> - Manipulate index content.

=item *

L<KinoSearch::Searcher> - Search an index.

=item *

L<KinoSearch::Analysis::PolyAnalyzer> - A one-size-fits-all parser/tokenizer.

=back

=head2 Supported Languages and Encodings

As of version 0.20, KinoSearch supports Unicode in addition to Latin-1.  All
output strings use Perl's internal Unicode encoding.  For use of KinoSearch
with non-Latin-1 material, see L<Encode>.

KinoSearch provides "native support" for 12 languages, meaning that a stemmer
and a stoplist are available, and PolyAnalyzer supports them.

=over

=item *

Danish

=item *

Dutch

=item *

English

=item *

Finnish

=item *

French

=item *

German

=item *

Italian

=item *

Norwegian

=item *

Portuguese

=item *

Russian

=item *

Spanish

=item *

Swedish

=back

KinoSearch can also be extended to support other languages if you write your
own subclass of L<KinoSearch::Analysis::Analyzer>.

=head2 Delving Deeper

For creating complex queries, see L<KinoSearch::Search::Query> and its
subclasses L<BooleanQuery|KinoSearch::Search::BooleanQuery>,
L<TermQuery|KinoSearch::Search::TermQuery>, and
L<PhraseQuery|KinoSearch::Search|PhraseQuery>, plus
L<KinoSearch::QueryParser> and
L<KinoSearch::Search::QueryFilter>.

If PolyAnalyzer doesn't meet your needs, see the base class
L<KinoSearch::Analysis::Analyzer> for how to write and integrate your own
Analyzer subclass.

For distributed searching, see L<KinoSearch::Search::SearchServer>,
L<KinoSearch::Search::SearchClient>, and L<KinoSearch::Search::MultiSearcher>.

If you'd like a peek under the hood, see L<KinoSearch::Docs::FileFormat> for
an overview of the invindex file format, and L<KinoSearch::Docs::DevGuide> for
hacking/debugging tips.

=head2 Backwards Compatibility Policy

Until version 1.0 is released, KinoSearch's API and file format are subject to
change without relation to the version number.  Such changes are not
undertaken lightly and hopefully none will be needed after the disruptions of
0.20.  

Starting with 1.0, the following policy will be put in place:

    Search is a rapidly advancing field.  To stay current, KinoSearch
    has adopted a policy of "continuity" rather than backwards
    compatibility in perpetuity:

    Starting with version 1.0, KinoSearch will support obsolete
    features and files for one "extra" major revision.  API features
    which are supported in 1.0 and deprecated in 1.x will be removed
    no sooner than 3.0.  Indexes which are modified at least once
    using 2.x will be readable at least until 4.0.

    Rapid-fire incrementing of major version numbers is not
    anticipated.  With luck, someone might even solve Perl5/CPAN's
    versioning problem before the release of KinoSearch 2.0.

=head1 SEE ALSO 

The KinoSearch homepage, where you'll find links to the mailing list and so
on, is L<http://www.rectangular.com/kinosearch>.

The Lucene homepage is L<http://lucene.apache.org>.

=head2 History 

Search::Kinosearch 0.02x, now dead and removed from CPAN, was this suite's
forerunner.  L<Plucene> is a pure-Perl port of Lucene 1.3. KinoSearch is a
from-scratch project which attempts to draws on the lessons of both. 

KinoSearch is named for Kino, the main character in John Steinbeck's novella,
"The Pearl".

=head1 SUPPORT

Please direct support questions to the kinosearch mailing list: subscription
information at L<http://www.rectangular.com/kinosearch>.

=head1 AUTHORS

Marvin Humphrey, E<lt>marvin at rectangular dot comE<gt>

Apache Lucene by Doug Cutting et al.

=head1 BUGS

Not thread-safe.

Some exceptions leak memory.

Won't work on esoteric architectures where a char is more than one byte,
or where floats don't conform to IEEE 754.

Please report any other bugs or feature requests to
C<bug-kinosearch@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=KinoSearch>.

=head1 COPYRIGHT & LICENSE

Copyright 2005-2007 Marvin Humphrey

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

Terms of usage for Apache Lucene, from which portions of KinoSearch are
derived, are spelled out in the Apache License: see the file
"ApacheLicense2.0.txt".

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY FOR THE
SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN OTHERWISE
STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES PROVIDE THE
SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS FOR A PARTICULAR PURPOSE. THE ENTIRE RISK AS TO THE QUALITY AND
PERFORMANCE OF THE SOFTWARE IS WITH YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE,
YOU ASSUME THE COST OF ALL NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING WILL ANY
COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR REDISTRIBUTE THE
SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE LIABLE TO YOU FOR DAMAGES,
INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING
OUT OF THE USE OR INABILITY TO USE THE SOFTWARE (INCLUDING BUT NOT LIMITED TO
LOSS OF DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR
THIRD PARTIES OR A FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER
SOFTWARE), EVEN IF SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE
POSSIBILITY OF SUCH DAMAGES.

=cut

