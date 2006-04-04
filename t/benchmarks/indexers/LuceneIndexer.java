import org.apache.lucene.index.IndexWriter;
import org.apache.lucene.analysis.WhitespaceAnalyzer;
import org.apache.lucene.document.Document;
import org.apache.lucene.document.Field;

import java.io.File;
import java.io.BufferedReader;
import java.io.FileReader;
import java.text.DecimalFormat;
import java.util.Date;
import java.util.Vector;
import java.util.Collections;

public class LuceneIndexer {
  private File corpusDir = new File("extracted_corpus");
  private File indexDir  = new File("lucene_index");

  public LuceneIndexer() { }

  public static void main (String[] args) throws Exception {
    LuceneIndexer indexer = new LuceneIndexer();

    // index all docs unless otherwise spec'd
    int maxToIndex = args.length > 0 ? 
      Integer.parseInt(args[0]) : 0;

    // verify that we're running from the right directory
    String curDir = new File(".").getCanonicalPath();
    if (!curDir.endsWith("benchmarks"))
      throw new Exception("Must be run from benchmarks/ ");

    // assemble the sorted list of article files
    String[] fileList = indexer.buildFileList();

    // start the clock and build the index
    long start = new Date().getTime(); 
    int numIndexed = indexer.buildIndex(fileList, maxToIndex);

    // stop the clock and print a report
    long end = new Date().getTime();
    indexer.printReport(start, end, numIndexed);
  }

  // Return a lexically sorted list of all article files from all subdirs.
  private String[] buildFileList () throws Exception {
    File[] articleDirs = corpusDir.listFiles();
    Vector filePaths = new Vector();
    for (int i = 0; i < articleDirs.length; i++) {
      File[] articles = articleDirs[i].listFiles();
      for (int j = 0; j < articles.length; j++) {
        String path = articles[i].getCanonicalPath();
        if (path.indexOf("article") == -1)
          continue;
        filePaths.add(path);
      }
    }
    Collections.sort(filePaths);
    return (String[])filePaths.toArray(new String[filePaths.size()]);
  }

  // Build an index, stopping at maxToIndex docs if maxToIndex > 0.
  private int buildIndex (String[] fileList, int maxToIndex) 
      throws Exception {
    IndexWriter writer = new IndexWriter(indexDir, 
      new WhitespaceAnalyzer(), true);
      writer.setMaxBufferedDocs(1000);
      writer.setUseCompoundFile(false);
    
    int docsSoFar = 0;
    for (int i = 0; i < fileList.length; i++) {
      // add content to index
      File f = new File(fileList[i]);
      Document doc = new Document();
      BufferedReader br = new BufferedReader(new FileReader(f));
  
      try {
        // the title is the first line
        String title;
        if ( (title = br.readLine()) == null)
          throw new Exception("Failed to read title");
        Field titleField = new Field("title", title, Field.Store.YES, 
    		Field.Index.TOKENIZED, Field.TermVector.NO);
        doc.add(titleField);
    
        // the body is the rest
        StringBuffer buf = new StringBuffer();
        String str;
        while ( (str = br.readLine()) != null )
          buf.append( str );
        String body = buf.toString();
        Field bodyField = new Field("body", body, Field.Store.YES, 
    		Field.Index.TOKENIZED, Field.TermVector.WITH_POSITIONS_OFFSETS);
        doc.add(bodyField);
        /*
        Field bodyField = new Field("body", br);
        doc.add(bodyField);
        */
  
        writer.addDocument(doc);
      } finally {
        br.close();
      }

      // bail if we've reached spec'd number of docs
      if (maxToIndex > 0 && ++docsSoFar == maxToIndex)
        break;
    }

    // finish index
    int numIndexed = writer.docCount();
    writer.optimize();
    writer.close();
    
    return numIndexed;
  }

  // Print out stats for this run.
  private void printReport(long start, long end, int numIndexed) {
    float secs = (float)(end - start) / 1000;
    DecimalFormat format = new DecimalFormat("#,##0.00");
    String secString = format.format(secs);
    Package lucenePackage = org.apache.lucene.LucenePackage.get();
    String version = lucenePackage.getSpecificationVersion();
    System.out.println("Java Lucene " +  version
      + " DOCS: " + numIndexed + " SECS: " + secString);
  }
}
