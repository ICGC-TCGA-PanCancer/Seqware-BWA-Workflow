use strict;
use XML::DOM;
use Data::Dumper;

my $down = 1;

 my $parser = new XML::DOM::Parser;
 #my $doc = $parser->parsefile ("https://cghub.ucsc.edu/cghub/metadata/analysisDetail?participant_id=3f70c3e3-0131-466f-92aa-0a63ab3d4258");
 # FIXME: why is this file truncated?
 #system("lwp-download 'https://cghub.ucsc.edu/cghub/metadata/analysisDetail?study=TCGA_MUT_BENCHMARK_4&state=live' data.xml");
 #my $doc = $parser->parsefile ('https://cghub.ucsc.edu/cghub/metadata/analysisDetail?study=TCGA_MUT_BENCHMARK_4&state=live');
 if ($down) { my $cmd = "mkdir -p xml; cgquery -s https://gtrepo-ebi.annailabs.com -o xml/data.xml 'study=*&state=live'"; print "$cmd\n"; system($cmd); }
 my $doc = $parser->parsefile("xml/data.xml");

 # print all HREF attributes of all CODEBASE elements
 my $nodes = $doc->getElementsByTagName ("Result");
 my $n = $nodes->getLength;

 print "\n";

 for (my $i = 0; $i < $n; $i++)
 {
     my $node = $nodes->item ($i);
     #$node->getElementsByTagName('analysis_full_uri')->item(0)->getAttributeNode('errors')->getFirstChild->getNodeValue;
     #print $node->getElementsByTagName('analysis_full_uri')->item(0)->getFirstChild->getNodeValue;
     my $aurl = getVal($node, "analysis_full_uri"); # ->getElementsByTagName('analysis_full_uri')->item(0)->getFirstChild->getNodeValue;
     # have to ensure the UUID is lower case, known GNOS issue
     #print "Analysis Full URL: $aurl\n";
     if($aurl =~ /^(.*)\/([^\/]+)$/) {
     $aurl = $1."/".lc($2);
     } else { 
       print "SKIPPING!\n";
       next;
     }
     print "Analysis Full URL: $aurl\n";
     if ($down) { system("wget -q -O xml/data_$i.xml $aurl"); }
     my $adoc = $parser->parsefile ("xml/data_$i.xml");
     my $analysisId = getVal($adoc, 'analysis_id'); #->getElementsByTagName('analysis_id')->item(0)->getFirstChild->getNodeValue;
     my $analysisDataURI = getVal($adoc, 'analysis_data_uri'); #->getElementsByTagName('analysis_data_uri')->item(0)->getFirstChild->getNodeValue;
     print "ANALYSIS:  $analysisDataURI \n";
     print "AnalysisID: $analysisId\n";
     my $libName = getVal($adoc, 'LIBRARY_NAME'); #->getElementsByTagName('LIBRARY_NAME')->item(0)->getFirstChild->getNodeValue;
     my $libStrategy = getVal($adoc, 'LIBRARY_STRATEGY'); #->getElementsByTagName('LIBRARY_STRATEGY')->item(0)->getFirstChild->getNodeValue;
     my $libSource = getVal($adoc, 'LIBRARY_SOURCE'); #->getElementsByTagName('LIBRARY_SOURCE')->item(0)->getFirstChild->getNodeValue;
     print "LibName: $libName LibStrategy: $libStrategy LibSource: $libSource\n";
     # now if these are defined then move onto the next step
     if (defined($libName) && defined($libStrategy) && defined($libSource) && defined($analysisId) && defined($analysisDataURI)) { 
       print "gtdownload -c gnostest.pem -vv -d $analysisDataURI\n";
       #system "gtdownload -c gnostest.pem -vv -d $analysisId\n";
       print "\n";
     } else {
       print "ERROR: one or more critical fields not defined, will skip $analysisId\n\n";
       next;
     }
 }

 # Print doc file
 #$doc->printToFile ("out.xml");

 # Print to string
 #print $doc->toString;

 # Avoid memory leaks - cleanup circular references for garbage collection
 $doc->dispose;

sub getVal {
  my ($node, $key) = @_;
  #print "NODE: $node KEY: $key\n";
  if ($node != undef) {
    if (defined($node->getElementsByTagName($key))) {
      if (defined($node->getElementsByTagName($key)->item(0))) {
        if (defined($node->getElementsByTagName($key)->item(0)->getFirstChild)) {
          if (defined($node->getElementsByTagName($key)->item(0)->getFirstChild->getNodeValue)) {
           return($node->getElementsByTagName($key)->item(0)->getFirstChild->getNodeValue);
          }
        }
      }
    }
  }
  return(undef);
}

