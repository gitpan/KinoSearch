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

/** Write an index; KinoSearch will try to write an identical one.
 *
 * One of the tests in the KinoSearch test suite depends on an index created
 * using this module.
 */

public class CompatTestIndexer extends LuceneIndexer {
    public static Pattern beforeBodyTextPattern = Pattern.compile(
        ".*<div id=\"bodytext\">", Pattern.DOTALL);
    public static Pattern afterBodyTextPattern = Pattern.compile(
        "</div><!--bodytext-->.*", Pattern.DOTALL);
    
    public CompatTestIndexer() { }

    public static void main (String[] args) throws Exception {
        CompatTestIndexer indexer = new CompatTestIndexer();
        indexer.buildIndex(args);
    }

    public Document nextDoc(File f) throws Exception {
        // only deal with .txt or .html files
        String fileName = f.getName();
        if (   !fileName.endsWith(".txt") 
            && !fileName.endsWith(".html")) {
            return null;
        }
        if (fileName.equals("index.html"))
            return null;

        // read content into string
        BufferedReader br = new BufferedReader(new FileReader(f));
        StringBuffer buf = new StringBuffer();
        String str;
        while ( (str = br.readLine()) != null )
                    buf.append( str );
        br.close();
        str = buf.toString();

        // remove everything except the text in the bodytext section
        Matcher beforeBodyTextMatcher = beforeBodyTextPattern.matcher(str);
        str = beforeBodyTextMatcher.replaceAll("");
        Matcher afterBodyTextMatcher = beforeBodyTextPattern.matcher(str);
        str = afterBodyTextMatcher.replaceAll("");
        Matcher tagMatcher = tagPattern.matcher(str);
        str = tagMatcher.replaceAll("");
        Matcher wsMatcher = wsPattern.matcher(str);
        str = wsMatcher.replaceAll(" ");

        // add content to Document
        Document doc = new Document();
        Field contentField = new Field("bodytext", str,
            Field.Store.YES, Field.Index.TOKENIZED, 
            Field.TermVector.NO);
        doc.add(contentField);

        return doc;
    }
}
