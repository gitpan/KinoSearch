#!/usr/bin/perl -T
use strict;
use warnings;

### In order for search.cgi to work, $path_to_invindex must be modified so
### that it points to the invindex created by invindexer.plx, and
### $base_url may have to change to reflect where a web-browser should
### look for the us_constitution directory.
my $path_to_invindex = '';
my $base_url         = '/us_constitution';

use CGI;
use List::Util qw( max min );
use POSIX qw( ceil );
use USConSchema;
use KinoSearch::Searcher;
use KinoSearch::Highlight::Highlighter;

my $cgi           = CGI->new;
my $q             = $cgi->param('q');
my $offset        = $cgi->param('offset');
my $hits_per_page = 10;
$q      = '' unless defined $q;
$offset = 0  unless defined $offset;

# create a Searcher object and feed it a query
my $searcher = KinoSearch::Searcher->new(
    invindex => USConSchema->open($path_to_invindex), );
my $hits = $searcher->search(
    query      => $q,
    offset     => $offset,
    num_wanted => $hits_per_page,
);
my $hit_count = $hits->total_hits;

# arrange for highlighted excerpts to be created.
my $highlighter = KinoSearch::Highlight::Highlighter->new;
$highlighter->add_spec( field => 'content' );
$hits->create_excerpts( highlighter => $highlighter );

# create result list
my $report = '';
while ( my $hit = $hits->fetch_hit_hashref ) {
    my $score = sprintf( "%0.3f", $hit->{score} );
    $report .= qq|
        <p>
            <a href="$hit->{url}"><strong>$hit->{title}</strong></a>
            <em>$score</em>
            <br>
            $hit->{excerpts}{content}
            <br>
            <span class="excerptURL">$hit->{url}</span>
        </p>
        |;
}

#--------------------------------------------------------------------------#
# No KinoSearch tutorial material below this point - just html generation. #
#--------------------------------------------------------------------------#

# generate paging links and hit count, print and exit
my $paging_links = generate_paging_info( $q, $hit_count );
blast_out_content( $q, $report, $paging_links );
exit;

# Create html fragment with links for paging through results 10-at-a-time.
sub generate_paging_info {
    my ( $query_string, $total_hits ) = @_;
    $query_string = CGI::escapeHTML($query_string);
    my $paging_info;
    if ( !length $query_string ) {
        # no query, no display
        $paging_info = '';
    }
    elsif ( $total_hits == 0 ) {
        # alert the user that their search failed
        $paging_info
            = qq|<p>No matches for <strong>$query_string</strong></p>|;
    }
    else {
        # calculate the nums for the first and last hit to display
        my $last_result = min( ( $offset + $hits_per_page ), $total_hits );
        my $first_result = min( ( $offset + 1 ), $last_result );

        # display the result nums, start paging info
        $paging_info = qq|
            <p>
                Results <strong>$first_result-$last_result</strong> 
                of <strong>$total_hits</strong> for <strong>$query_string</strong>.
            </p>
            <p>
                Results Page:
            |;

        # calculate first and last hits pages to display / link to
        my $current_page = int( $first_result / $hits_per_page ) + 1;
        my $last_page    = ceil( $total_hits / $hits_per_page );
        my $first_page   = max( 1, ( $current_page - 9 ) );
        $last_page = min( $last_page, ( $current_page + 10 ) );

        # create a url for use in paging links
        my $href = $cgi->url( -relative => 1 ) . "?" . $cgi->query_string;
        $href .= ";offset=0" unless $href =~ /offset=/;

        # generate the "Prev" link;
        if ( $current_page > 1 ) {
            my $new_offset = ( $current_page - 2 ) * $hits_per_page;
            $href =~ s/(?<=offset=)\d+/$new_offset/;
            $paging_info .= qq|<a href="$href">&lt;= Prev</a>\n|;
        }

        # generate paging links
        for my $page_num ( $first_page .. $last_page ) {
            if ( $page_num == $current_page ) {
                $paging_info .= qq|$page_num \n|;
            }
            else {
                my $new_offset = ( $page_num - 1 ) * $hits_per_page;
                $href =~ s/(?<=offset=)\d+/$new_offset/;
                $paging_info .= qq|<a href="$href">$page_num</a>\n|;
            }
        }

        # generate the "Next" link
        if ( $current_page != $last_page ) {
            my $new_offset = $current_page * $hits_per_page;
            $href =~ s/(?<=offset=)\d+/$new_offset/;
            $paging_info .= qq|<a href="$href">Next =&gt;</a>\n|;
        }

        # close tag
        $paging_info .= "</p>\n";
    }

    return $paging_info;
}

# Print content to output.
sub blast_out_content {
    my ( $query_string, $hit_list, $paging_info ) = @_;
    $query_string = CGI::escapeHTML($query_string);
    print "Content-type: text/html\n\n";
    print <<END_HTML;
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
    "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
    <meta http-equiv="Content-type" 
        content="text/html;charset=ISO-8859-1">
    <link rel="stylesheet" type="text/css" href="$base_url/uscon.css">
    <title>KinoSearch: $query_string</title>
</head>

<body>

    <div id="navigation">
        <form id="usconSearch" action="">
            <strong>
            Search the <a href="$base_url/index.html">US Constitution</a>:
            </strong>
            <input type="text" name="q" id="q" value="$query_string">
            <input type="submit" value="=&gt;">
            <input type="hidden" name="offset" value="0">
        </form>
    </div><!--navigation-->

    <div id="bodytext">

    $hit_list

    $paging_info

    <p style="font-size: smaller; color: #666">
        <em>Powered by 
            <a href="http://www.rectangular.com/kinosearch/">
                KinoSearch
            </a>
        </em>
    </p>
    </div><!--bodytext-->

</body>

</html>
END_HTML
}

