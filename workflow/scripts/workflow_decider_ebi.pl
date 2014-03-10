use strict;
use XML::DOM;
use Data::Dumper;
use JSON;
use Getopt::Long;
use XML::LibXML;

# DESCRIPTION
# A tool for identifying samples ready for alignment, scheduling on clusters,
# and monitoring for completion.
# TODO:
# * need to use perl package for downloads, not calls out to system
# * need to define cluster json so this script knows how to launch a workflow

#############
# VARIABLES #
#############

my $down = 1;
my $gnos_url = "https://gtrepo-ebi.annailabs.com";
my $cluster_json = "cluster.json";
my $working_dir = "decider_tmp";
my $sample;
my $test = 0;
my $ignore_lane_cnt = 0;
my $force_run = 0;

if (scalar(@ARGV) < 6 || scalar(@ARGV) > 11) { die "USAGE: 'perl workflow_decider_ebi.pl --gnos-url <URL> --cluster-json <cluster_json> --working-dir <working_dir> [--sample <sample_id>] [--test] [--ignore-lane-count] [--force-run]\n"; }

GetOptions("gnos-url=s" => \$gnos_url, "cluster-json=s" => \$cluster_json, "working-dir=s" => \$working_dir, "sample=s" => \$sample, "test" => \$test, "ignore-lane-count" => \$ignore_lane_cnt, "force-run" => \$force_run);


##############
# MAIN STEPS #
##############

# READ CLUSTER INFO AND RUNNING SAMPLES
my ($cluster_info, $running_samples) = read_cluster_info($cluster_json);
print Dumper($cluster_info);
print Dumper($running_samples);

# READ INFO FROM GNOS
my $sample_info = read_sample_info();
print Dumper($sample_info);

# FIND SAMPLES
# now look at each sample, see if it's already schedule, launch if not and a cluster is available, and then exit


###############
# SUBROUTINES #
###############

sub read_sample_info {
  
  my $d = {};

  # PARSE XML
  my $parser = new XML::DOM::Parser;
  #my $doc = $parser->parsefile ("https://cghub.ucsc.edu/cghub/metadata/analysisDetail?participant_id=3f70c3e3-0131-466f-92aa-0a63ab3d4258");
  #system("lwp-download 'https://cghub.ucsc.edu/cghub/metadata/analysisDetail?study=TCGA_MUT_BENCHMARK_4&state=live' data.xml");
  #my $doc = $parser->parsefile ('https://cghub.ucsc.edu/cghub/metadata/analysisDetail?study=TCGA_MUT_BENCHMARK_4&state=live');
  if ($down) { my $cmd = "mkdir -p xml; cgquery -s $gnos_url -o xml/data.xml 'study=*&state=live'"; print "$cmd\n"; system($cmd); }
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
      my $adoc2 = XML::LibXML->new->parse_file("xml/data_$i.xml");
      my $analysisId = getVal($adoc, 'analysis_id'); #->getElementsByTagName('analysis_id')->item(0)->getFirstChild->getNodeValue;
      my $analysisDataURI = getVal($adoc, 'analysis_data_uri'); #->getElementsByTagName('analysis_data_uri')->item(0)->getFirstChild->getNodeValue;
      my $submitterAliquotId = getCustomVal($adoc2, 'submitter_aliquot_id');
      my $aliquotId = getVal($adoc, 'aliquot_id');
      my $submitterParticipantId = getCustomVal($adoc2, 'submitter_participant_id');
      my $participantId = getVal($adoc, 'participant_id');
      my $submitterSampleId = getCustomVal($adoc2, 'submitter_sample_id');
      my $sampleId = getVal($adoc, 'sample_id');
      print "ANALYSIS:  $analysisDataURI \n";
      print "ANALYSISID: $analysisId\n";
      print "PARTICIPANT ID: $participantId\n";
      print "SAMPLE ID: $sampleId\n";
      print "ALIQUOTID: $aliquotId\n";
      print "SUBMITTER PARTICIPANT ID: $submitterParticipantId\n";
      print "SUBMITTER SAMPLE ID: $submitterSampleId\n";
      print "SUBMITTER ALIQUOTID: $submitterAliquotId\n";
      my $libName = getVal($adoc, 'LIBRARY_NAME'); #->getElementsByTagName('LIBRARY_NAME')->item(0)->getFirstChild->getNodeValue;
      my $libStrategy = getVal($adoc, 'LIBRARY_STRATEGY'); #->getElementsByTagName('LIBRARY_STRATEGY')->item(0)->getFirstChild->getNodeValue;
      my $libSource = getVal($adoc, 'LIBRARY_SOURCE'); #->getElementsByTagName('LIBRARY_SOURCE')->item(0)->getFirstChild->getNodeValue;
      print "LibName: $libName LibStrategy: $libStrategy LibSource: $libSource\n";
      # get files
      # now if these are defined then move onto the next step
      if (defined($libName) && defined($libStrategy) && defined($libSource) && defined($analysisId) && defined($analysisDataURI)) { 
        print "  gtdownload -c gnostest.pem -v -d $analysisDataURI\n";
        #system "gtdownload -c gnostest.pem -vv -d $analysisId\n";
        print "\n";
        $d->{$submitterParticipantId}{$submitterSampleId}{$submitterAliquotId}{analysis_id}{$analysisId} = 1; 
        $d->{$submitterParticipantId}{$submitterSampleId}{$submitterAliquotId}{analysis_url}{$analysisDataURI} = 1; 
        $d->{$submitterParticipantId}{$submitterSampleId}{$submitterAliquotId}{library_name}{$libName} = 1; 
        $d->{$submitterParticipantId}{$submitterSampleId}{$submitterAliquotId}{library_strategy}{$libStrategy} = 1; 
        $d->{$submitterParticipantId}{$submitterSampleId}{$submitterAliquotId}{library_source}{$libSource} = 1; 
      } else {
        print "ERROR: one or more critical fields not defined, will skip $analysisId\n\n";
        next;
      }
      my $files = readFiles($adoc);
      print "FILE:\n";
      foreach my $file(keys %{$files}) {
        print "  FILE: $file SIZE: ".$files->{$file}{size}." CHECKSUM: ".$files->{$file}{checksum}."\n";
        print "  LOCAL FILE PATH: $analysisId/$file\n";
        $d->{$submitterParticipantId}{$submitterSampleId}{$submitterAliquotId}{files}{$file}{size} = $files->{$file}{size}; 
        $d->{$submitterParticipantId}{$submitterSampleId}{$submitterAliquotId}{files}{$file}{checksum} = $files->{$file}{checksum}; 
        # URLs?
      }

  }
  
  # Print doc file
  #$doc->printToFile ("out.xml");
  
  # Print to string
  #print $doc->toString;
  
  # Avoid memory leaks - cleanup circular references for garbage collection
  $doc->dispose;

  return($d);
}

sub read_cluster_info {
  my ($cluster_info) = @_;
  my $json_txt = "";
  my $d = {};
  my $run_samples = {};
  open IN, "<$cluster_info" or die "Can't open $cluster_info";
  while(<IN>) {
    $json_txt .= $_;
  }
  close IN; 
  my $json = decode_json($json_txt);

  foreach my $c (keys %{$json}) {
    my $user = $json->{$c}{username};
    my $pass = $json->{$c}{password};
    my $web = $json->{$c}{webservice};
    my $acc = $json->{$c}{workflow_accession};
    #print "wget -O - --http-user=$user --http-password=$pass -q $web\n"; 
    my $info = `wget -O - --http-user='$user' --http-password=$pass -q $web/workflows/$acc`; 
    #print "INFO: $info\n";
    my $dom = XML::LibXML->new->parse_string($info);
    # check the XML returned above
    if ($dom->findnodes('//Workflow/name/text()')) {
      # now figure out if any of these workflows are currently scheduled here
      #print "wget -O - --http-user='$user' --http-password=$pass -q $web/workflows/$acc/runs\n";
      my $wr = `wget -O - --http-user='$user' --http-password=$pass -q $web/workflows/$acc/runs`; 
      #print "WR: $wr\n";
      my $dom2 = XML::LibXML->new->parse_string($wr);
      # find running samples
      for my $node ($dom2->findnodes('//WorkflowRunList2/list/iniFile/text()')) {
        my $ini_contents = $node->toString();
        $ini_contents =~ /gnos_input_metadata_urls=(\S+)/;
        $run_samples->{$1} = 1;
      }
      # find available clusters
      my $running = 0;
      for my $node ($dom2->findnodes('//WorkflowRunList2/list/status/text()')) {
        print "WORKFLOW: ".$acc." STATUS: ".$node->toString()."\n";
        if ($node->toString() eq 'running' || $node->toString() eq 'scheduled' || $node->toString() eq 'submitted') { $running++; }
      } 
      # if there are no running workflows on this cluster it's a candidate
      if ($running == 0) {
        print "NO RUNNING WORKFLOWS, ADDING TO LIST OF AVAILABLE CLUSTERS\n";
        $d->{$c} = $json->{$c}; 
      }
    }
  }
  #print "Final cluster list:\n";
  #print Dumper($d);
  return($d, $run_samples);
  
}

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

sub getCustomVal {
  my ($dom2, $key) = @_;
  #print "HERE $dom2 $key\n";
  for my $node ($dom2->findnodes('//ANALYSIS_ATTRIBUTES/ANALYSIS_ATTRIBUTE')) {
    #print "NODE: ".$node->toString()."\n";
    my $i=0;
    for my $currKey ($node->findnodes('//TAG/text()')) {
      $i++;
      my $keyStr = $currKey->toString();
      if ($keyStr eq $key) {
        my $j=0;
        for my $currVal ($node->findnodes('//VALUE/text()')) {
          $j++;   
          if ($j==$i) { 
            #print "TAG: $keyStr\n";
            return($currVal->toString());
          }
        } 
      }
    }
  }
  return("");
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
