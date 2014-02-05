use strict;
use XML::DOM;
use Data::Dumper;
use JSON;

# TODO:
# * need to use perl package for downloads, not calls out to system
# * need to define cluster json so this script knows how to launch a workflow

 my $down = 1;

 my $parser = new XML::DOM::Parser;
 #my $doc = $parser->parsefile ("https://cghub.ucsc.edu/cghub/metadata/analysisDetail?participant_id=3f70c3e3-0131-466f-92aa-0a63ab3d4258");
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
     print "ANALYSIS FULL URL: $aurl\n";
     #if ($down) { system("wget -q -O xml/data_$i.xml $aurl"); }
     if ($down) { download($aurl, "xml/data_$i.xml"); }
     my $adoc = $parser->parsefile ("xml/data_$i.xml");
     my $analysisId = getVal($adoc, 'analysis_id'); #->getElementsByTagName('analysis_id')->item(0)->getFirstChild->getNodeValue;
     my $analysisDataURI = getVal($adoc, 'analysis_data_uri'); #->getElementsByTagName('analysis_data_uri')->item(0)->getFirstChild->getNodeValue;
     my $aliquotId = getVal($adoc, 'aliquot_id');
     print "ANALYSIS:  $analysisDataURI \n";
     print "ANALYSISID: $analysisId\n";
     print "ALIQUOTID: $aliquotId\n";
     my $libName = getVal($adoc, 'LIBRARY_NAME'); #->getElementsByTagName('LIBRARY_NAME')->item(0)->getFirstChild->getNodeValue;
     my $libStrategy = getVal($adoc, 'LIBRARY_STRATEGY'); #->getElementsByTagName('LIBRARY_STRATEGY')->item(0)->getFirstChild->getNodeValue;
     my $libSource = getVal($adoc, 'LIBRARY_SOURCE'); #->getElementsByTagName('LIBRARY_SOURCE')->item(0)->getFirstChild->getNodeValue;
     print "LibName: $libName LibStrategy: $libStrategy LibSource: $libSource\n";
     # get files
     my $files = readFiles($adoc);
     print "FILE:\n";
     foreach my $file(keys %{$files}) {
       print "  FILE: $file SIZE: ".$files->{$file}{size}." CHECKSUM: ".$files->{$file}{checksum}."\n";
       print "  LOCAL FILE PATH: $analysisId/$file\n";
     }
     # now if these are defined then move onto the next step
     if (defined($libName) && defined($libStrategy) && defined($libSource) && defined($analysisId) && defined($analysisDataURI)) { 
       print "  gtdownload -c gnostest.pem -v -d $analysisDataURI\n";
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

sub readFiles {
  my ($d) = @_;
  my $ret = {};
  my $nodes = $d->getElementsByTagName ("file");
  my $n = $nodes->getLength;
  for (my $i = 0; $i < $n; $i++)
  {
    my $node = $nodes->item ($i);
	    my $currFile = getVal($node, 'filename');
	    my $size = getVal($node, 'filesize');
	    my $check = getVal($node, 'checksum');
            $ret->{$currFile}{size} = $size;
            $ret->{$currFile}{checksum} = $check;
  }
  return($ret);
}

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

sub download {
  my ($url, $out) = @_;

  my $r = system("wget -q -O $out $url");
  if ($r) {
	  $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME}=0;
    $r = system("lwp-download $url $out");
    if ($r) {
	    print "ERROR DOWNLOADING: $url\n";
	    exit(1);
    }
  }
}
