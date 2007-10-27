#!/usr/bin/perl -T
use strict;
use warnings;

# Load configuration file.  (Note: change conf.pl location as needed.)
my $conf;
BEGIN { $conf = do "./conf.pl" or die "Can't locate conf.pl"; }

use lib @{ $conf->{lib} };
use CGI;
use Data::Pageset;
use HTML::Entities qw( encode_entities );
use USConSchema;
use KinoSearch::Searcher;
use KinoSearch::Highlight::Highlighter;

my $cgi           = CGI->new;
my $q             = $cgi->param('q') || '';
my $offset        = $cgi->param('offset') || 0;
my $hits_per_page = 10;

# Create a Searcher object and feed it a query.
my $searcher = KinoSearch::Searcher->new(
    invindex => USConSchema->open( $conf->{path_to_invindex} ) );
my $hits = $searcher->search(
    query      => $q,
    offset     => $offset,
    num_wanted => $hits_per_page,
);
my $hit_count = $hits->total_hits;

# Arrange for highlighted excerpts to be created.
my $highlighter = KinoSearch::Highlight::Highlighter->new;
$highlighter->add_spec( field => 'content' );
$hits->create_excerpts( highlighter => $highlighter );

# Create result list.
my $report = '';
while ( my $hit = $hits->fetch_hit_hashref ) {
    my $score = sprintf( "%0.3f", $hit->{score} );
    my $title = encode_entities( $hit->{title} );
    $report .= qq|
        <p>
          <a href="$hit->{url}"><strong>$title</strong></a>
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

# Generate paging links and hit count, print and exit.
my $paging_links = generate_paging_info( $q, $hit_count );
blast_out_content( $q, $report, $paging_links );

# Create html fragment with links for paging through results n-at-a-time.
sub generate_paging_info {
    my ( $query_string, $total_hits ) = @_;
    $query_string = encode_entities($query_string);
    my $paging_info;
    if ( !length $query_string ) {
        # No query?  No display.
        $paging_info = '';
    }
    elsif ( $total_hits == 0 ) {
        # Alert the user that their search failed.
        $paging_info
            = qq|<p>No matches for <strong>$query_string</strong></p>|;
    }
    else {
        my $current_page = ( $offset / $hits_per_page ) + 1;
        my $pager        = Data::Pageset->new(
            {   total_entries    => $total_hits,
                entries_per_page => $hits_per_page,
                current_page     => $current_page,
                pages_per_set    => 10,
                mode             => 'slide',
            }
        );
        my $last_result  = $pager->last;
        my $first_result = $pager->first;

        # Display the result nums, start paging info.
        $paging_info = qq|
            <p>
                Results <strong>$first_result-$last_result</strong> 
                of <strong>$total_hits</strong> 
                for <strong>$query_string</strong>.
            </p>
            <p>
                Results Page:
            |;

        # Create a url for use in paging links.
        my $href = $cgi->url( -relative => 1 ) . "?" . $cgi->query_string;
        $href .= ";offset=0" unless $href =~ /offset=/;

        # Generate the "Prev" link.
        if ( $current_page > 1 ) {
            my $new_offset = ( $current_page - 2 ) * $hits_per_page;
            $href =~ s/(?<=offset=)\d+/$new_offset/;
            $paging_info .= qq|<a href="$href">&lt;= Prev</a>\n|;
        }

        # Generate paging links.
        for my $page_num ( @{ $pager->pages_in_set } ) {
            if ( $page_num == $current_page ) {
                $paging_info .= qq|$page_num \n|;
            }
            else {
                my $new_offset = ( $page_num - 1 ) * $hits_per_page;
                $href =~ s/(?<=offset=)\d+/$new_offset/;
                $paging_info .= qq|<a href="$href">$page_num</a>\n|;
            }
        }

        # Generate the "Next" link.
        if ( $current_page != $pager->last_page ) {
            my $new_offset = $current_page * $hits_per_page;
            $href =~ s/(?<=offset=)\d+/$new_offset/;
            $paging_info .= qq|<a href="$href">Next =&gt;</a>\n|;
        }

        # Close tag.
        $paging_info .= "</p>\n";
    }

    return $paging_info;
}

# Print content to output.
sub blast_out_content {
    my ( $query_string, $hit_list, $paging_info ) = @_;
    $query_string = encode_entities($query_string);
    print "Content-type: text/html\n\n";
    print qq|
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
    "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
  <meta http-equiv="Content-type" 
    content="text/html;charset=ISO-8859-1">
  <link rel="stylesheet" type="text/css" 
    href="/us_constitution/uscon.css">
  <title>KinoSearch: $query_string</title>
</head>

<body>

  <div id="navigation">
    <form id="usconSearch" action="">
      <strong>
        Search the 
        <a href="/us_constitution/index.html">US Constitution</a>:
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
      <em>
        Powered by 
        <a href="http://www.rectangular.com/kinosearch/">KinoSearch</a>
      </em>
    </p>
  </div><!--bodytext-->

</body>

</html>
|;
}

