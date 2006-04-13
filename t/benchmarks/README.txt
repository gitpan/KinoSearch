Indexing Benchmarks

The purpose of this experiment is to test raw indexing speed, using
Reuters-21578, Distribution 1.0 as a test corpus.  As of this writing,
Reuters-21578 is available at: 
    
    http://www.daviddlewis.com/resources/testcollections/reuters21578

The corpus comes packaged in SGML, which means we need to preprocess it so
that our results are not infected by differences between SGML parsers.  A
simple perl script, "./extract_reuters.plx" is supplied, which expands the
Reuters articles out into the file system, 1 article per file, with the title
as the first line of text.  It takes one command line argument: the location
of the un-tarred Reuters collection.

    ./extract_reuters.plx /path/to/reuters_collection

Filepaths are hard-coded, and the assumption is that the apps will be run from
within the benchmarks/ directory.  Each of the indexing apps takes three
optional command line arguments: the number of documents to index, the number
of times to repeat the indexing process, and the increment, or number of docs
to add during each index writer instance.

    perl indexers/kinosearch_indexer.plx --docs=1000 --reps=6 --increment=10
    java [flags] LuceneIndexer -docs 1000 -reps 6 -increment 10

If no command line args are supplied, the apps will index the entire 19043
article collection once, using a single index writer.

Upon finishing, each app will produce a "truncated mean" report: the slowest
25% and fastest 25% of  reps will be discarded, and the rest will be averaged. 


