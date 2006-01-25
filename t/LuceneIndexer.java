import org.apache.lucene.index.IndexWriter;
import org.apache.lucene.analysis.WhitespaceAnalyzer;
import org.apache.lucene.document.Document;
import org.apache.lucene.document.Field;

import java.io.File;
import java.io.BufferedReader;
import java.io.FileReader;
import java.util.Date;
import java.util.regex.Pattern;
import java.util.regex.Matcher;
import java.util.Vector;
import java.util.Collections;

/** Generate a Lucene index from a directory containing either html or txt
 * files.
 *
 * Useful for both testing and benchmarking.  
 *
 * When benchmarking, processHTML should be disabled.
 */

public class LuceneIndexer {
    public boolean processHTML = false;
    public File indexDir;
    public File sourceDataDir;

    // quick-n-dirty tag stripper and whitespace collapser 
    public static Pattern tagPattern 
        = Pattern.compile("<.*?>", Pattern.DOTALL);
    public static Pattern wsPattern
        = Pattern.compile("\\s+");

    public LuceneIndexer() { }

    public static void main (String[] args) throws Exception {
        LuceneIndexer indexer = new LuceneIndexer();
        indexer.buildIndex(args);
    }

    public void buildIndex (String[] args) throws Exception {
        // start benchmarking timer
        long start = new Date().getTime();

        // process command line arguments
        if (args.length < 2) {
            throw new Exception("Usage: java LuceneIndexer " 
                + "<indexDir> + <sourceDataDir> + <mergeFactor> + "
                + "<numToIndex> + <processHTML>");
        }
        indexDir      = new File(args[0]);
        sourceDataDir = new File(args[1]);
        int mergeVar      = args.length > 2 ? Integer.parseInt(args[2]) : 0;
        int numToIndex    = args.length > 3 ? Integer.parseInt(args[3]) : 0;
        if (args.length > 4) {
            int noParseBooleanInJava14 = Integer.parseInt(args[4]);
            if (noParseBooleanInJava14 == 1)
                processHTML = true;
        }

        // prepare sorted list of files to index
        File[] files = sourceDataDir.listFiles();
        Vector sortedFiles = new Vector();
        for (int i = 0; i < files.length; i++) {
            sortedFiles.add(files[i]);
        }
        Collections.sort(sortedFiles);
        files = (File[])sortedFiles.toArray(files);
        
        
        // build spec'd IndexWriter
        IndexWriter writer = new IndexWriter(indexDir, 
            new WhitespaceAnalyzer(), true);
        if (mergeVar > 0) {
            writer.setMergeFactor(mergeVar);
            writer.setMaxBufferedDocs(mergeVar);
        }
        
        int docsSoFar = 0;
        for (int i = 0; i < files.length; i++) {

            // only index text or html files
            File f = files[i];

            Document doc = this.nextDoc(f);
            if (doc == null) 
                continue;

            // bail if we've reached spec'd number of docs
            if (numToIndex > 0 && docsSoFar++ == numToIndex)
                break;
            
            // add content to index
            writer.addDocument(doc);
        }
        // finish index
        int numIndexed = writer.docCount();
        writer.optimize();
        writer.close();
        
        // stop benchmarking timer and print report
        long end = new Date().getTime();
        System.out.println("Java Lucene, minMergeDocs and mergeFactor set to " 
            + mergeVar + ", indexing " + numIndexed + " documents took " 
            + (end - start) + " millisecs");
    }

    public Document nextDoc(File f) throws Exception {
        // only deal with .txt or .html files
        if (   !f.getName().endsWith(".txt") 
            && !f.getName().endsWith(".html")) {
            return null;
        }

        // read content into string
        BufferedReader br = new BufferedReader(new FileReader(f));
        StringBuffer buf = new StringBuffer();
        String str;
        while ( (str = br.readLine()) != null )
                    buf.append( str );
        br.close();
        str = buf.toString();

        // strip tags (unreliably, unless content is known) 
        // and collapse whitespace
        if (processHTML) {
            Matcher tagMatcher = tagPattern.matcher(str);
            str = tagMatcher.replaceAll("");
            Matcher wsMatcher = wsPattern.matcher(str);
            str = wsMatcher.replaceAll(" ");
        }

        // add content to index
        Document doc = new Document();
        Field contentField = new Field("content", str,
            Field.Store.YES, Field.Index.TOKENIZED, 
            Field.TermVector.NO);

        return doc;
    }
}
