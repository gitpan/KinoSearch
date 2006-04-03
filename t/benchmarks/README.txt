Indexing Benchmarks

The purpose of this experiment is to test raw indexing speed, using
Reuters-21578, Distribution 1.0 as a test corpus.  Reuters-21578 is available
from David D. Lewis' professional home page, currently:
   
    http://www.research.att.com/~lewis

The corpus comes packaged in SGML, which means we need to preprocess it so
that our results are not infected by differences between SGML parsers.  A
simple perl script, "./extract_reuters.plx" is supplied, which expands the
Reuters articles out into the file system, 1 article per file, with the title
as the first line of text.  It takes one command line argument: the location
of the un-tarred Reuters collection.

    ./extract_reuters.plx /path/to/reuters_collection

Each of the indexing apps takes one optional command line argument: the number
of documents to index.  Filepaths are hard-coded, and the assumption is that
they will be run from within the benchmarks/ directory:

    ./indexers/kinosearch_indexer.plx 1000

If no command line args are supplied, the apps will index the entire 19000+
article collection.  


