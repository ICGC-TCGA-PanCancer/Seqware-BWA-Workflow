use strict;
use Data::Dumper;
use Getopt::Long;
use XML::DOM;
use JSON;
use Data::UUID;
use XML::LibXML;

#############################################################################################
# DESCRIPTION                                                                               #
#############################################################################################
# This tool takes metadata URLs and BAM path. It then downloads a sample worth of metadata, #
# parses it, generates headers, the submission files and then performs the uploads.         #
#############################################################################################


#############
# VARIABLES #
#############

my $metadata_urls;
my $bam;
my $parser = new XML::DOM::Parser;
my $output_dir = "test_output_dir";
my $key = "gnostest.pem";
my $md5_file = "";
my $upload_url = "";
my $test = 0;

# FIXME: add workflow version param, url param
if (scalar(@ARGV) != 12 && scalar(@ARGV) != 13) { die "USAGE: 'perl gnos_upload_data.pl --metadata-urls <URLs_comma_separated> --bam <sample-level_bam_file_path> --bam-md5sum-file <file_with_bam_md5sum> --outdir <output_dir> --key <gnos.pem> --upload-url <gnos_server_url> [--test]\n"; }
GetOptions("metadata-urls=s" => \$metadata_urls, "bam=s" => \$bam, "outdir=s" => \$output_dir, "key=s" => \$key, "bam-md5sum-file=s" => \$md5_file, "upload-url=s" => \$upload_url, "test" => \$test);

# setup output dir
my $ug = Data::UUID->new;
my $uuid = lc($ug->create_str());
system("mkdir -p $output_dir/$uuid");
$output_dir = $output_dir."/$uuid/";
system("ln -s $bam $output_dir/");

# md5sum
my $bam_check = `cat $md5_file`;
chomp $bam_check;

##############
# MAIN STEPS #
##############

print "DOWNLOADING METADATA FILES\n";
my $metad = download_metadata($metadata_urls);

print "GENERATING SUBMISSION\n";
my $sub_path = generate_submission($metad);

print "VALIDATING SUBMISSION\n";
if (validate_submission($sub_path)) { die "The submission did not pass validation! Files are located at: $sub_path\n"; }

print "UPLOADING SUBMISSION\n";
if (upload_submission($sub_path)) { die "The upload of files did not work!  Files are located at: $sub_path\n"; }


###############
# SUBROUTINES #
###############

sub validate_submission {
  my ($sub_path) = @_;
  my $cmd = "cgsubmit --validate-only -s $upload_url -o validation.log -u $sub_path -vv";
  print "VALIDATING: $cmd\n";
  return(system($cmd));
}

sub upload_submission {
  my ($sub_path) = @_;
  my $cmd = "cgsubmit -s $upload_url -o metadata_upload.log -u $sub_path -vv -c $key";
  if ($test) { $cmd = "echo ".$cmd; }
  print "UPLOADING METADATA: $cmd\n";
  if (system($cmd)) { return(1); }

  $cmd = "gtupload -c $key -s $upload_url -u $sub_path/manifest.xml";
  if ($test) { $cmd = "echo ".$cmd; }
  print "UPLOADING DATA: $cmd\n";
  return(system($cmd));

}

sub generate_submission {

  my ($m) = @_;
  
  # const
  # TODO: generate this 
  my $datetime = "2011-09-05T00:00:00";
  # TODO: all of these need to be parameterized/read from header/read from XML
  # populate refcenter from original BAM submission 
  # @RG CN:(.*)
  my $refcenter = "OICR";
  # @CO sample_id 
  my $sample_id = "6895c0b9-de4c-4a80-8fba-6ade7ce1e1dc";
  # capture list
  my $sample_uuids = {};
  # current sample_uuid (which seems to actually be aliquot ID, this is sample ID from the BAM header)
  my $sample_uuid = "6895c0b9-de4c-4a80-8fba-6ade7ce1e1dc";
  # @RG SM or @CO aliquoit_id
  my $aliquot_id = "f7ada105-3771-45ad-a5bb-b00664d6c8e8";
  # hardcoded
  my $workflow_version = "2.0";
  # hardcoded
  my $workflow_url = "http://seqware.io/workflows/Workflow_Bundle_PanCancer_BWA_Mem/2.0/Workflow_Bundle_PanCancer_BWA_Mem_SeqWare_1.0.11.zip"; 
  # @RG LB:(.*)
  my $library = "WGS:OICR:3a690774-f056-470b-b0b9-01ee2222c87d";
  # @RG ID:(.*)
  my $read_group_id = "OICR:963b780d-09dd-494b-bd54-36d7316643c9";
  # @RG PU:(.*)
  my $platform_unit = "OICR:182919";
  # TODO: I think the data_block_name should be the aliquot_id, at least that's what I saw in the example for TCGA
  # hardcoded
  my $analysis_center = "OICR";
  # @CO participant_id
  my $participant_id = "40df3135381b41bdae5e4650c6b28fc3";
  # hardcoded
  my $bam_file = "foo.bam";
  # hardcoded
  my $bam_file_checksum = "0e4f1bd5c5cc83b37d6c511dda98866c";
  
  # these data are collected from all files
  # aliquot_id|library_id|platform_unit|read_group_id|input_url
  my $read_group_info = {};
  my $global_attr = {};
  
  #print Dumper($m);
  
  # this isn't going to work if there are multiple files/readgroups!
  foreach my $file (keys %{$m}) {
    # TODO: generate this 
    $datetime = "2011-09-05T00:00:00";
    # TODO: all of these need to be parameterized/read from header/read from XML
    # populate refcenter from original BAM submission 
    # @RG CN:(.*)
    # FIXME: GNOS currently only allows: ^UCSC$|^NHGRI$|^CGHUB$|^The Cancer Genome Atlas Research Network$|^OICR$
    ############$refcenter = $m->{$file}{'target'}[0]{'refcenter'};
    $sample_uuid = $m->{$file}{'target'}[0]{'refname'};
    $sample_uuids->{$m->{$file}{'target'}[0]{'refname'}} = 1;
    # @CO sample_id 
    my @sample_ids = keys %{$m->{$file}{'analysis_attr'}{'sample_id'}};
    $sample_id = $sample_ids[0];
    # @RG SM or @CO aliquoit_id
    my @aliquot_ids = keys %{$m->{$file}{'analysis_attr'}{'aliquot_id'}};
    $aliquot_id = $aliquot_ids[0];
    # @RG LB:(.*)
    $library = $m->{$file}{'run'}[0]{'data_block_name'};
    # @RG ID:(.*)
    $read_group_id = $m->{$file}{'run'}[0]{'read_group_label'};
    # @RG PU:(.*)
    $platform_unit = $m->{$file}{'run'}[0]{'refname'};
    # TODO: I think the data_block_name should be the aliquot_id, at least that's what I saw in the example for TCGA
    # hardcoded
    ########$analysis_center = $refcenter;
    # @CO participant_id
    my @participant_ids = keys %{$m->{$file}{'analysis_attr'}{'participant_id'}};
    $participant_id = $participant_ids[0];
    # hardcoded
    #$bam_file = "foo.bam";
    # hardcoded
    #$bam_file_checksum = "0e4f1bd5c5cc83b37d6c511dda98866c";
    my $index = 0;
    foreach my $bam_info (@{$m->{$file}{'run'}}) {
      if ($bam_info->{data_block_name} ne '') {
        #print Dumper($bam_info);
        #print Dumper($m->{$file}{'file'}[$index]);
        my $str = "$participant_id|$sample_id|$sample_uuid|$aliquot_id|$library|$platform_unit|$read_group_id|".$m->{$file}{'file'}[$index]{filename}."|".$m->{$file}{'analysis_id'};
        $global_attr->{"participant_id|sample_id|sample_refname|aliquot_id|library|platform_unit|read_group_id|bam_file|analysis_id"}{$str} = 1;
        $read_group_info->{$str} = 1;
      }
      $index++;
    }
  
    # now combine the analysis attr
    foreach my $attName (keys %{$m->{$file}{analysis_attr}}) {
      foreach my $attVal (keys %{$m->{$file}{analysis_attr}{$attName}}) {
        $global_attr->{$attName}{$attVal} = 1;
      }
    }
  }
  
  #print Dumper($read_group_info);
  #print Dumper($global_attr);

  #<!-- CUSTOM doesn't work -->
  #<!--CUSTOM DESCRIPTION="hs37d" REFERENCE_SOURCE="ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/phase2_reference_assembly_sequence/README_human_reference_20110707"/-->

  my $analysis_xml = <<END;
  <!-- TODO: ultimately everything comes back to \@RG. SampleID is correctly linked in here but I'm worried that  
  aliquot ID is never used and linked to the RG either.  -->
  <ANALYSIS_SET xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.ncbi.nlm.nih.gov/viewvc/v1/trunk/sra/doc/SRA_1-5/SRA.analysis.xsd?view=co">
    <ANALYSIS center_name="$analysis_center" analysis_date="$datetime">
      <TITLE>PanCancer Sample-Level Alignment for Sample ID: $sample_id</TITLE>
      <STUDY_REF refcenter="$refcenter" refname="icgc_pancancer" />
      <DESCRIPTION>Sample-level BAM from the reference alignment of $sample_id from participant $participant_id. This uses the SeqWare BWA-Mem PanCancer Workflow version $workflow_version available at $workflow_url.  Please note the reference was actually hs37d, see ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/phase2_reference_assembly_sequence/README_human_reference_20110707 for more information. Briefly this is the integrated reference sequence from the GRCh37 primary assembly (chromosomal plus unlocalized and unplaced contigs), the rCRS mitochondrial sequence (AC:NC_012920), Human herpesvirus 4 type 1 (AC:NC_007605) and the concatenated decoy sequences (hs37d5cs.fa.gz)</DESCRIPTION>
      <ANALYSIS_TYPE>
        <REFERENCE_ALIGNMENT>
          <ASSEMBLY>
  	  <STANDARD short_name="GRCh37"/>
          </ASSEMBLY>
          <RUN_LABELS>
END
            foreach my $url (keys %{$m}) {
              foreach my $run (@{$m->{$url}{'run'}}) {
              #print Dumper($run);
                if (defined($run->{'read_group_label'})) {
                   #print "READ GROUP LABREL: ".$run->{'read_group_label'}."\n";
                   my $dbn = $run->{'data_block_name'};
                   my $rgl = $run->{'read_group_label'};
                   my $rn = $run->{'refname'};
                 $analysis_xml .= "              <RUN data_block_name=\"$dbn\" read_group_label=\"$rgl\" refname=\"$rn\" refcenter=\"$refcenter\" />\n";
                }              
              }
  
  	  }
  
  $analysis_xml .= <<END;
          </RUN_LABELS>
          <SEQ_LABELS>
END
  
            foreach my $dbn (keys %{$sample_uuids}) {
  $analysis_xml .= <<END;
            <SEQUENCE data_block_name="$dbn" accession="NC_000001.10" seq_label="1" />
            <SEQUENCE data_block_name="$dbn" accession="NC_000002.11" seq_label="2" />
            <SEQUENCE data_block_name="$dbn" accession="NC_000003.11" seq_label="3" />
            <SEQUENCE data_block_name="$dbn" accession="NC_000004.11" seq_label="4" />
            <SEQUENCE data_block_name="$dbn" accession="NC_000005.9" seq_label="5" />
            <SEQUENCE data_block_name="$dbn" accession="NC_000006.11" seq_label="6" />
            <SEQUENCE data_block_name="$dbn" accession="NC_000007.13" seq_label="7" />
            <SEQUENCE data_block_name="$dbn" accession="NC_000008.10" seq_label="8" />
            <SEQUENCE data_block_name="$dbn" accession="NC_000009.11" seq_label="9" />
            <SEQUENCE data_block_name="$dbn" accession="NC_000010.10" seq_label="10" />
            <SEQUENCE data_block_name="$dbn" accession="NC_000011.9" seq_label="11" />
            <SEQUENCE data_block_name="$dbn" accession="NC_000012.11" seq_label="12" />
            <SEQUENCE data_block_name="$dbn" accession="NC_000013.10" seq_label="13" />
            <SEQUENCE data_block_name="$dbn" accession="NC_000014.8" seq_label="14" />
            <SEQUENCE data_block_name="$dbn" accession="NC_000015.9" seq_label="15" />
            <SEQUENCE data_block_name="$dbn" accession="NC_000016.9" seq_label="16" />
            <SEQUENCE data_block_name="$dbn" accession="NC_000017.10" seq_label="17" />
            <SEQUENCE data_block_name="$dbn" accession="NC_000018.9" seq_label="18" />
            <SEQUENCE data_block_name="$dbn" accession="NC_000019.9" seq_label="19" />
            <SEQUENCE data_block_name="$dbn" accession="NC_000020.10" seq_label="20" />
            <SEQUENCE data_block_name="$dbn" accession="NC_000021.8" seq_label="21" />
            <SEQUENCE data_block_name="$dbn" accession="NC_000022.10" seq_label="22" />
            <SEQUENCE data_block_name="$dbn" accession="NC_000023.10" seq_label="X" />
            <SEQUENCE data_block_name="$dbn" accession="NC_000024.9" seq_label="Y" />
            <SEQUENCE data_block_name="$dbn" accession="NC_012920" seq_label="MT" />
            <SEQUENCE data_block_name="$dbn" accession="GL000207.1" seq_label="GL000207.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000226.1" seq_label="GL000226.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000229.1" seq_label="GL000229.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000231.1" seq_label="GL000231.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000210.1" seq_label="GL000210.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000239.1" seq_label="GL000239.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000235.1" seq_label="GL000235.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000201.1" seq_label="GL000201.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000247.1" seq_label="GL000247.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000245.1" seq_label="GL000245.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000197.1" seq_label="GL000197.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000203.1" seq_label="GL000203.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000246.1" seq_label="GL000246.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000249.1" seq_label="GL000249.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000196.1" seq_label="GL000196.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000248.1" seq_label="GL000248.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000244.1" seq_label="GL000244.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000238.1" seq_label="GL000238.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000202.1" seq_label="GL000202.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000234.1" seq_label="GL000234.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000232.1" seq_label="GL000232.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000206.1" seq_label="GL000206.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000240.1" seq_label="GL000240.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000236.1" seq_label="GL000236.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000241.1" seq_label="GL000241.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000243.1" seq_label="GL000243.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000242.1" seq_label="GL000242.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000230.1" seq_label="GL000230.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000237.1" seq_label="GL000237.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000233.1" seq_label="GL000233.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000204.1" seq_label="GL000204.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000198.1" seq_label="GL000198.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000208.1" seq_label="GL000208.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000191.1" seq_label="GL000191.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000227.1" seq_label="GL000227.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000228.1" seq_label="GL000228.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000214.1" seq_label="GL000214.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000221.1" seq_label="GL000221.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000209.1" seq_label="GL000209.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000218.1" seq_label="GL000218.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000220.1" seq_label="GL000220.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000213.1" seq_label="GL000213.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000211.1" seq_label="GL000211.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000199.1" seq_label="GL000199.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000217.1" seq_label="GL000217.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000216.1" seq_label="GL000216.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000215.1" seq_label="GL000215.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000205.1" seq_label="GL000205.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000219.1" seq_label="GL000219.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000224.1" seq_label="GL000224.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000223.1" seq_label="GL000223.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000195.1" seq_label="GL000195.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000212.1" seq_label="GL000212.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000222.1" seq_label="GL000222.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000200.1" seq_label="GL000200.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000193.1" seq_label="GL000193.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000194.1" seq_label="GL000194.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000225.1" seq_label="GL000225.1" />
            <SEQUENCE data_block_name="$dbn" accession="GL000192.1" seq_label="GL000192.1" />
            <SEQUENCE data_block_name="$dbn" accession="NC_007605" seq_label="NC_007605" />
            <SEQUENCE data_block_name="$dbn" accession="hs37d5" seq_label="hs37d5" />
END
            }
  
  $analysis_xml .= <<END;
          </SEQ_LABELS>
          <PROCESSING>
            <PIPELINE>
END
            foreach my $url (keys %{$m}) {
              foreach my $run (@{$m->{$url}{'run'}}) {
              #print Dumper($run);
                if (defined($run->{'read_group_label'})) {
                   #print "READ GROUP LABREL: ".$run->{'read_group_label'}."\n";
                   my $dbn = $run->{'data_block_name'};
                   my $rgl = $run->{'read_group_label'};
                   my $rn = $run->{'refname'};
  $analysis_xml .= <<END;
              <!-- TODO -->
              <PIPE_SECTION section_name="Mapping">
                <STEP_INDEX>$rgl</STEP_INDEX>
                <PREV_STEP_INDEX>NIL</PREV_STEP_INDEX>
                <PROGRAM>bwa</PROGRAM>
                <VERSION>0.7.7-r441</VERSION>
                <NOTES>bwa mem -t 8 -p -T 0 genome.fa.gz reference.fasta</NOTES>
              </PIPE_SECTION>
END
                 }
               }
            }
  $analysis_xml .= <<END;
            </PIPELINE>
            <DIRECTIVES>
              <alignment_includes_unaligned_reads>true</alignment_includes_unaligned_reads>
              <alignment_marks_duplicate_reads>true</alignment_marks_duplicate_reads>
              <alignment_includes_failed_reads>false</alignment_includes_failed_reads>
            </DIRECTIVES>
          </PROCESSING>
        </REFERENCE_ALIGNMENT>
      </ANALYSIS_TYPE>
      <TARGETS>
END
  foreach my $curr_sample_uuid (keys %{$sample_uuids}) {
    $analysis_xml .= <<END;
        <TARGET sra_object_type="SAMPLE" refcenter="$refcenter" refname="$curr_sample_uuid" />
END
  }
  $analysis_xml .= <<END;
      </TARGETS>
      <DATA_BLOCK>
        <FILES>
END
  
       $analysis_xml .= "<FILE filename=\"$bam\" filetype=\"bam\" checksum_method=\"MD5\" checksum=\"$bam_check\" />\n";
  
       # incorrect, there's only one bam!
       my $i=0;
       foreach my $url (keys %{$m}) {
       foreach my $run (@{$m->{$url}{'run'}}) {   
       if (defined($run->{'read_group_label'})) {
          my $fname = $m->{$url}{'file'}[$i]{'filename'};
          my $ftype= $m->{$url}{'file'}[$i]{'filetype'};
          my $check = $m->{$url}{'file'}[$i]{'checksum'};
          #$analysis_xml .= "<FILE filename=\"$fname\" filetype=\"$ftype\" checksum_method=\"MD5\" checksum=\"$check\" />\n";
       }
       $i++;
       }
       }
  
  $analysis_xml .= <<END;
        </FILES>
      </DATA_BLOCK>
      <ANALYSIS_ATTRIBUTES>
END
  
    foreach my $key (keys %{$global_attr}) {
      foreach my $val (keys %{$global_attr->{$key}}) {
        $analysis_xml .= "
        <ANALYSIS_ATTRIBUTE>
          <TAG>$key</TAG>
          <VALUE>$val</VALUE>
        </ANALYSIS_ATTRIBUTE>
        ";
      }
    }
  
  $analysis_xml .= <<END;
      </ANALYSIS_ATTRIBUTES>
    </ANALYSIS>
  </ANALYSIS_SET>
END
  
  open OUT, ">$output_dir/analysis.xml" or die;
  print OUT $analysis_xml;
  close OUT;

  # make a uniq list of blocks
  my $uniq_exp_xml = {};
  foreach my $url (keys %{$m}) {
    $uniq_exp_xml->{$m->{$url}{'experiment'}} = 1;
  }
  
  my $exp_xml = <<END;
  <EXPERIMENT_SET xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.ncbi.nlm.nih.gov/viewvc/v1/trunk/sra/doc/SRA_1-5/SRA.experiment.xsd?view=co">
END
  
  foreach my $curr_xml_block (keys %{$uniq_exp_xml}) {
    $exp_xml .= $curr_xml_block;
  }
  
  $exp_xml .= <<END;
  </EXPERIMENT_SET>
END
  
  open OUT, ">$output_dir/experiment.xml" or die;
  print OUT "$exp_xml\n";
  close OUT;

  # make a uniq list of blocks
  my $uniq_run_xml = {};
  foreach my $url (keys %{$m}) {
    $uniq_run_xml->{$m->{$url}{'run_block'}} = 1;
  }
  
  my $run_xml = <<END;
  <RUN_SET xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.ncbi.nlm.nih.gov/viewvc/v1/trunk/sra/doc/SRA_1-5/SRA.run.xsd?view=co">
END
  
  foreach my $run_block (keys %{$uniq_run_xml}) {
    # replace the file 
    $run_block =~ s/filename="\S+"/filename="$bam"/g;
    $run_block =~ s/checksum="\S+"/checksum="$bam_check"/g;
    $run_block =~ s/center_name="[^"]+"/center_name="$refcenter"/g;
    $run_xml .= $run_block;
  }
  
  $run_xml .= <<END;
  </RUN_SET>
END
  
  open OUT, ">$output_dir/run.xml" or die;
  print OUT $run_xml;
  close OUT;
  
  return($output_dir);
  
}

sub read_header {
  my ($header) = @_;
  my $hd = {};
  open HEADER, "<$header" or die "Can't open header file $header\n";
  while(<HEADER>) {
    chomp;
    my @a = split /\t+/;
    my $type = $a[0];
    if ($type =~ /^@/) { 
      $type =~ s/@//;
      for(my $i=1; $i<scalar(@a); $i++) {
        $a[$i] =~ /^([^:]+):(.+)$/;
        $hd->{$type}{$1} = $2;
      }
    }
  }
  close HEADER;
  return($hd);
}

sub download_metadata {
  my ($urls_str) = @_;
  my $metad = {};
  system("mkdir -p xml2");
  my @urls = split /,/, $urls_str;
  my $i = 0;
  foreach my $url (@urls) {
    $i++;
    my $xml_path = download_url($url, "xml2/data_$i.xml");
    $metad->{$url} = parse_metadata($xml_path);
  }
  return($metad);
}

sub parse_metadata {
  my ($xml_path) = @_;
  my $doc = $parser->parsefile($xml_path);  
  my $m = {};
  $m->{'analysis_id'} = getVal($doc, 'analysis_id');  
  $m->{'center_name'} = getVal($doc, 'center_name');  
  push @{$m->{'study_ref'}}, getValsMulti($doc, 'STUDY_REF', "refcenter,refname");  
  push @{$m->{'run'}}, getValsMulti($doc, 'RUN', "data_block_name,read_group_label,refname");  
  push @{$m->{'target'}}, getValsMulti($doc, 'TARGET', "refcenter,refname");  
  push @{$m->{'file'}}, getValsMulti($doc, 'FILE', "checksum,filename,filetype");  
  $m->{'analysis_attr'} = getAttrs($doc);  
  $m->{'experiment'} = getBlock($xml_path, "EXPERIMENT ", "EXPERIMENT");
  $m->{'run_block'} = getBlock($xml_path, "RUN center_name", "RUN");
  return($m);
}

sub getBlock {
  my ($xml_file, $key, $end) = @_;
  my $block = "";
  open IN, "<$xml_file" or die "Can't open file $xml_file\n";
  my $reading = 0;
  while (<IN>) {
    chomp;
    if (/<$key/) { $reading = 1; }
    if ($reading) {
      $block .= "$_\n";
    }
    if (/<\/$end>/) { $reading = 0; }
  }
  close IN;
  return $block;
}

sub download_url {
  my ($url, $path) = @_;
  my $r = system("wget -q -O $path $url");
  if ($r) {
          $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME}=0;
    $r = system("lwp-download $url $path");
    if ($r) {
            print "ERROR DOWNLOADING: $url\n";
            exit(1);
    }
  }
  return($path);
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


sub getAttrs {
  my ($node) = @_;
  my $r = {};
  my $nodes = $node->getElementsByTagName('ANALYSIS_ATTRIBUTE');
  for(my $i=0; $i<$nodes->getLength; $i++) {
	  my $anode = $nodes->item($i);
	  my $tag = getVal($anode, 'TAG');
	  my $val = getVal($anode, 'VALUE');
	  $r->{$tag}{$val}=1;
  }
  return($r);
}

sub getValsWorking {
  my ($node, $key, $tag) = @_;
  my @result;
  my $nodes = $node->getElementsByTagName($key);
  for(my $i=0; $i<$nodes->getLength; $i++) {
	  my $anode = $nodes->item($i);
	  my $tag = $anode->getAttribute($tag);
          push @result, $tag;
  }
  return(@result);
}

sub getValsMulti {
  my ($node, $key, $tags_str) = @_;
  my @result;
  my @tags = split /,/, $tags_str;
  my $nodes = $node->getElementsByTagName($key);
  for(my $i=0; $i<$nodes->getLength; $i++) {
       my $data = {};
       foreach my $tag (@tags) {
         	  my $anode = $nodes->item($i);
	          my $value = $anode->getAttribute($tag);
		  if (defined($value) && $value ne '') { $data->{$tag} = $value; }
       }
       push @result, $data;
  }
  return(@result);
}

# doesn't work
sub getVals {
  my ($node, $key, $tag) = @_;
  #print "NODE: $node KEY: $key\n";
  my @r;
  if ($node != undef) {
    if (defined($node->getElementsByTagName($key))) {
      if (defined($node->getElementsByTagName($key)->item(0))) {
        if (defined($node->getElementsByTagName($key)->item(0)->getFirstChild)) {
          if (defined($node->getElementsByTagName($key)->item(0)->getFirstChild->getNodeValue)) {
            #return($node->getElementsByTagName($key)->item(0)->getFirstChild->getNodeValue);
            foreach my $aNode ($node->getElementsByTagName($key)) {
              # left off here
              if (defined($tag)) {   } else { push @r, $aNode->getFirstChild->getNodeValue; }
            }
          }
        }
      }
    }
  }
  return(@r);
}

0;

