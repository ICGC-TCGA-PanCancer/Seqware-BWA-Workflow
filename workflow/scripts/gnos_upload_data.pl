#!/usr/bin/env perl

use warnings;
use strict;

use feature qw(say);
use autodie;

use Getopt::Long;

use XML::LibXML;
use XML::DOM;
use XML::XPath;
use XML::XPath::XMLParser;

use JSON;

use GNOS::Upload;

use Data::UUID;

use Time::Piece;

use Data::Dumper;

# seconds to wait for a retry
my $cooldown = 60;
# 30 retries at 60 seconds each is 30 hours
my $retries = 30;
# retries for md5sum, 4 hours
my $md5_sleep = 240;
#example command



#############################################################################################
# DESCRIPTION                                                                               #
#############################################################################################
# This tool takes metadata URLs and BAM path. It then downloads a sample worth of metadata, #
# parses it, generates headers, the submission files and then performs the uploads.         #
#############################################################################################

#############################################################################################
# TODO                                                                                      #
#############################################################################################
# * generally, this script needs to be re-written so it fully parses the input XML into a   #
#   data model and then creates the output XML.  There is far too much hacking on XML text. #
# * add workflow version param, url param                                                   #
# * need GNOS to support the reference we're using                                          #
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
my $skip_validate = 0;
# hardcoded
my $seqware_version = "";
my $workflow_version = "";
my $workflow_bundle_dir = "";
my $workflow_name = "Workflow_Bundle_BWA";
my $workflow_src_url = "https://github.com/SeqWare/public-workflows/tree/$workflow_version/workflow-bwa-pancancer";
my $workflow_url = "https://s3.amazonaws.com/oicr.workflow.bundles/released-bundles/Workflow_Bundle_BWA_".$workflow_version."_SeqWare_$seqware_version.zip";
my $changelog_url = "https://github.com/SeqWare/public-workflows/blob/$workflow_version/workflow-bwa-pancancer/CHANGELOG.md";
my $bwa_version = "0.7.8-r455";
my $biobambam_version = "0.0.148";
my $pcap_version = "1.1.1";
my $samtools_version = "0.1.19";
my $force_copy = 0;
my $unmapped_reads_upload = 0;
my $study_ref_name = "icgc_pancancer";
my $analysis_center = "OICR";

if (scalar(@ARGV) < 18 || scalar(@ARGV) > 30) {
  die "USAGE: 'perl gnos_upload_data.pl
       --metadata-urls <URLs_comma_separated>
       --bam <sample-level_bam_file_path>
       --bam-md5sum-file <file_with_bam_md5sum>
       --outdir <output_dir>
       --key <gnos.pem>
       --upload-url <gnos_server_url>
       --workflow-bundle-dir <workflow_bundle_dir>
       --workflow-version <workflow_version>
       --seqware-version <seqware-version>
       [--force-copy]
       [--study-refname-override <study_refname_override>]
       [--analysis-center-override <analysis_center_override>]
       [--unmapped-reads-upload]
       [--skip-validate]
       [--test]\n"; }

GetOptions(
     "metadata-urls=s" => \$metadata_urls,
     "bam=s" => \$bam,
     "outdir=s" => \$output_dir,
     "key=s" => \$key,
     "bam-md5sum-file=s" => \$md5_file,
     "upload-url=s" => \$upload_url,
     "test" => \$test,
     "force-copy" => \$force_copy,
     "skip-validate" => \$skip_validate,
     "unmapped-reads-upload" => \$unmapped_reads_upload,
     "study-refname-override=s" => \$study_ref_name,     
     "analysis-center-override=s" => \$analysis_center,
     "workflow-bundle-dir=s" => \$workflow_bundle_dir,
     "workflow-version=s" => \$workflow_version,
     "seqware-version=s" => \$seqware_version,
     );

# setup output dir
my @bam_path = split '/', $bam;
my $file_name = $bam_path[-1];
my @file = split /\./, $file_name;
my $file_prefix = $file[0];
$output_dir .= "$file_prefix";
$output_dir .= '-unmapped' if ($unmapped_reads_upload);
my $uuid = '';
my $ug = Data::UUID->new;

if(-d "$output_dir") {
    opendir( my $dh, $output_dir);
    my @dirs = grep {-d "$output_dir/$_" && ! /^\.{1,2}$/} readdir($dh);
    if (scalar @dirs == 1) {
        $uuid = $dirs[0];
    } 
    else {   
        $uuid = lc($ug->create_str());
    }
}
else {
    $uuid = lc($ug->create_str());
}
run("mkdir -p $output_dir/$uuid");
$output_dir = "$output_dir/$uuid";

my $final_touch_file = "$output_dir/upload_complete.txt";

# md5sum
my $bam_check = `cat $md5_file`;
chomp $bam_check;

my $bai_check = `cat $bam.bai.md5`;
chomp $bai_check;


# link / sync for bam and md5sum filea
my $pwd = `pwd`;
chomp $pwd;

my %files = ($bam => "$bam_check.bam",
             $md5_file => "$bam_check.bam.md5",
             "$bam.bai" => "$bam_check.bam.bai",
             "$bam.bai.md5" => "$bam_check.bam.bai.md5"
            );

my $link_method = ($force_copy)? 'rsync -rauv': 'ln -s';
    
foreach my $from (keys %files) {
    my $to = $files{$from};
    my $command = "$link_method $pwd/$from $output_dir/$to";
    run($command) if (not (-e "$pwd/$output_dir/$to"));
}

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

    my $cmd = "cgsubmit --validate-only -s $upload_url -o validation.$bam_check.log -u $sub_path -vv";
    say "VALIDATING: $cmd";

    return 0 if ($skip_validate);

    return run($cmd);
}

sub upload_submission {
    my ($sub_path) = @_;
    
    my $metadata_file = "metadata_upload.$bam_check.log";
    my $cmd = "cgsubmit -s $upload_url -o $metadata_file -u $sub_path -vv -c $key";

    say "UPLOADING METADATA: $cmd";
    if ($test) {
        say "SKIPPING: test mode";
        return 0;
    }
    
    return 1 if (!run($cmd));
    
    # we need to hack the manifest.xml to drop any files that are inputs and I won't upload again
    modify_manifest_file("$sub_path/manifest.xml", $sub_path) if( not $test);
    my $log_file = 'upload.log';
    my $gt_upload_command = "cd $sub_path; gtupload -v -c $key -l ./$log_file -u ./manifest.xml; cd -";
    say "UPLOADING DATA: $cmd";

    return 1 if ( GNOS::Upload->upload($gt_upload_command, "$sub_path/$log_file", $retries, $cooldown, $md5_sleep)  );

    # just touch this file to ensure monitoring tools know upload is complete
    run_("date +\%s > $final_touch_file", $metadata_file);

}

sub modify_manifest_file {
    my ($man, $sub_path) = @_;

    open IN, '<', $man;
    open OUT, '>', "$man.new";

    while(<IN>) {
        chomp;
        if (/filename="([^"]+)"/) {
           say OUT $_ if (-e "$sub_path/$1");    
        } 
        else {
            say OUT $_;
        }
    }

    close IN;
    close OUT;
 
    system("mv $man.new $man");
}

sub generate_submission {
    my ($m) = @_;
  
    # const
    my $t = gmtime;
    my $datetime = $t->datetime();
    # populate refcenter from original BAM submission
    # @RG CN:(.*)
    my $refcenter = "OICR";
    # @CO sample_id
    my $sample_id = "";
    # capture list
    my $sample_uuids = {};
    # current sample_uuid (which seems to actually be aliquot ID, this is sample ID from the BAM header)
    my $sample_uuid = "";
    # @RG SM or @CO aliquoit_id
    my $aliquot_id = "";
    # @RG LB:(.*)
    my $library = "";
    # @RG ID:(.*)
    my $read_group_id = "";
    # @RG PU:(.*)
    my $platform_unit = "";
    # @CO participant_id
    my $participant_id = "";
    # hardcoded
    my $bam_file = "";
    # hardcoded
    my $bam_file_checksum = "";
    # center name
    my $center_name = "";
  
    # these data are collected from all files
    # aliquot_id|library_id|platform_unit|read_group_id|input_url
    my $global_attr = {};
  
    # input info
    my $pi2 = {};
  
    # this isn't going to work if there are multiple files/readgroups!
    foreach my $file (keys %{$m}) {
        # populate refcenter from original BAM submission
        # @RG CN:(.*)
        # FIXME: GNOS currently only allows: ^UCSC$|^NHGRI$|^CGHUB$|^The Cancer Genome Atlas Research Network$|^OICR$
        $refcenter = $m->{$file}{'target'}[0]{'refcenter'};
        $center_name = $m->{$file}{'center_name'};
        $sample_uuid = $m->{$file}{'target'}[0]{'refname'};
        $sample_uuids->{$m->{$file}{'target'}[0]{'refname'}} = 1;
        # @CO sample_id
        my @sample_ids = keys %{$m->{$file}{'analysis_attr'}{'sample_id'}};
        # workaround for updated XML
        if (scalar(@sample_ids) == 0) { @sample_ids = keys %{$m->{$file}{'analysis_attr'}{'submitter_specimen_id'}}; }
        $sample_id = $sample_ids[0];
        # @RG SM or @CO aliquoit_id
        my @aliquot_ids = keys %{$m->{$file}{'analysis_attr'}{'aliquot_id'}};
        # workaround for updated XML
        if (scalar(@aliquot_ids) == 0) { @aliquot_ids = keys %{$m->{$file}{'analysis_attr'}{'submitter_sample_id'}}; }
        $aliquot_id = $aliquot_ids[0];
        # @RG LB:(.*)
        $library = $m->{$file}{'run'}[0]{'data_block_name'};
        # @RG ID:(.*)
        $read_group_id = $m->{$file}{'run'}[0]{'read_group_label'};
        # @RG PU:(.*)
        $platform_unit = $m->{$file}{'run'}[0]{'refname'};
        # @CO participant_id
        my @participant_ids = keys %{$m->{$file}{'analysis_attr'}{'participant_id'}};
        @participant_ids = keys %{$m->{$file}{'analysis_attr'}{'submitter_donor_id'}} if (scalar(@participant_ids) == 0); 
        $participant_id = $participant_ids[0];
        my $index = 0;
        foreach my $bam_info (@{$m->{$file}{'run'}}) {
            if ((eval {exists $bam_info->{data_block_name}}) and $bam_info->{data_block_name} ne '') {
                #print Dumper($m->{$file}{'file'}[$index]);
                my $pi = {};
                $pi->{'input_info'}{'donor_id'} = $participant_id;
                $pi->{'input_info'}{'specimen_id'} = $sample_id;
                $pi->{'input_info'}{'target_sample_refname'} = $sample_uuid;
                $pi->{'input_info'}{'analyzed_sample'} = $aliquot_id;
                $pi->{'input_info'}{'library'} = $library;
                $pi->{'input_info'}{'platform_unit'} = $platform_unit;
                $pi->{'read_group_id'} = $read_group_id;
                $pi->{'input_info'}{'analysis_id'} = $m->{$file}{'analysis_id'};
                $pi->{'input_info'}{'bam_file'} = $m->{$file}{'file'}[$index]{filename};
                push @{$pi2->{'pipeline_input_info'}}, $pi;
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

    my $str = to_json($pi2);
    $global_attr->{"pipeline_input_info"}{$str} = 1;
  
    # FIXME: either custom needs to work or the reference needs to be listed in GNOS
    #<!--CUSTOM DESCRIPTION="hs37d" REFERENCE_SOURCE="ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/phase2_reference_assembly_sequence/README_human_reference_20110707"/-->
  
    my $description = "Specimen-level BAM from the reference alignment of specimen $sample_id from donor $participant_id. This uses the SeqWare BWA-MEM PanCancer Workflow version $workflow_version available at $workflow_url. This workflow can be created from source, see $workflow_src_url. For a complete change log see $changelog_url. Input BAMs are prepared and submitted to GNOS server according to the submission SOP documented at: https://wiki.oicr.on.ca/display/PANCANCER/PCAP+%28a.k.a.+PAWG%29+Sequence+Submission+SOP+-+v1.0. Please note the reference is hs37d, see ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/phase2_reference_assembly_sequence/README_human_reference_20110707 for more information. Briefly this is the integrated reference sequence from the GRCh37 primary assembly (chromosomal plus unlocalized and unplaced contigs), the rCRS mitochondrial sequence (AC:NC_012920), Human herpesvirus 4 type 1 (AC:NC_007605) and the concatenated decoy sequences (hs37d5cs.fa.gz).";
  
    if ($unmapped_reads_upload) {
      $description = "The BAM file includes unmapped reads extracted from specimen-level BAM with the reference alignment of specimen $sample_id from donor $participant_id. This uses the SeqWare BWA-MEM PanCancer Workflow version $workflow_version available at $workflow_url. This workflow can be created from source, see $workflow_src_url. For a complete change log see $changelog_url. Input BAMs are prepared and submitted to GNOS server according to the submission SOP documented at: https://wiki.oicr.on.ca/display/PANCANCER/PCAP+%28a.k.a.+PAWG%29+Sequence+Submission+SOP+-+v1.0.";
    }
  
    my $analysis_xml = <<END;
  <ANALYSIS_SET xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.ncbi.nlm.nih.gov/viewvc/v1/trunk/sra/doc/SRA_1-5/SRA.analysis.xsd?view=co">
    <ANALYSIS center_name="$center_name" analysis_center="$analysis_center" analysis_date="$datetime">
      <TITLE>TCGA/ICGC PanCancer Specimen-Level Alignment for Specimen $sample_id from Participant $participant_id</TITLE>
      <STUDY_REF refcenter="$refcenter" refname="$study_ref_name" />
      <DESCRIPTION>$description</DESCRIPTION>
      <ANALYSIS_TYPE>
        <REFERENCE_ALIGNMENT>
          <ASSEMBLY>
  	  <STANDARD short_name="GRCh37"/>
          </ASSEMBLY>
          <RUN_LABELS>
END
            foreach my $url (keys %{$m}) {
              foreach my $run (@{$m->{$url}{'run'}}) {
                if (defined($run->{'read_group_label'})) {
                   #print "READ GROUP LABREL: ".$run->{'read_group_label'}."\n";
                   my $dbn = $run->{'data_block_name'};
                   my $rgl = $run->{'read_group_label'};
                   my $rn = $run->{'refname'};
                 $analysis_xml .= "              <RUN data_block_name=\"$dbn\" read_group_label=\"$rgl\" refname=\"$rn\" refcenter=\"$center_name\" />\n";
                }
              }

  	  }

  $analysis_xml .= <<END;
          </RUN_LABELS>
          <SEQ_LABELS>
END

            my $last_dbn ="";
            foreach my $dbn (keys %{$sample_uuids}) {
              $last_dbn = $dbn;
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

  unless ($unmapped_reads_upload) {

    $analysis_xml .= <<END;
                  <PIPE_SECTION section_name="fastq_extract">
                    <STEP_INDEX>1</STEP_INDEX>
                    <PREV_STEP_INDEX>NIL</PREV_STEP_INDEX>
                    <PROGRAM>bamtofastq</PROGRAM>
                    <VERSION>$biobambam_version</VERSION>
                    <NOTES>bamtofastq exclude=QCFAIL,SECONDARY,SUPPLEMENTARY T=out.t S=out.s O=out.o O2=out.o2 collate=1 tryoq=1 filename=input.bam</NOTES>
                  </PIPE_SECTION>
END

    $analysis_xml .= <<END;
                  <PIPE_SECTION section_name="mapping">
                    <STEP_INDEX>2</STEP_INDEX>
                    <PREV_STEP_INDEX>1</PREV_STEP_INDEX>
                    <PROGRAM>bwa</PROGRAM>
                    <VERSION>$bwa_version</VERSION>
                    <NOTES>bwa mem -t 8 -p -T 0 -R header.txt genome.fa.gz</NOTES>
                  </PIPE_SECTION>
END

    $analysis_xml .= <<END;
                  <PIPE_SECTION section_name="bam_sort">
                    <STEP_INDEX>3</STEP_INDEX>
                    <PREV_STEP_INDEX>2</PREV_STEP_INDEX>
                    <PROGRAM>bamsort</PROGRAM>
                    <VERSION>$biobambam_version</VERSION>
                    <NOTES>bamsort inputformat=sam level=1 inputthreads=2 outputthreads=2 inputformat=sam level=1 inputthreads=2 outputthreads=2 genome.fa.gz tmpfile=out.sorttmp O=out.bam</NOTES>
                  </PIPE_SECTION>
END

    $analysis_xml .= <<END;
              <PIPE_SECTION section_name="mark_duplicates">
                <STEP_INDEX>4</STEP_INDEX>
                <PREV_STEP_INDEX>3</PREV_STEP_INDEX>
                <PROGRAM>bammarkduplicates</PROGRAM>
                <VERSION>$biobambam_version</VERSION>
                <NOTES>bammarkduplicates O=out.merged.sorted.markdup.bam M=output.metrics tmpfile=tmp.biormdup rewritebam=1 rewritebamlevel=1 index=1 md5=1 I=out.bam</NOTES>
              </PIPE_SECTION>
END

  }
  else {
    $analysis_xml .= <<END;
              <PIPE_SECTION section_name="unmapped_reads_extraction">
                <STEP_INDEX>1</STEP_INDEX>
                <PREV_STEP_INDEX>NIL</PREV_STEP_INDEX>
                <PROGRAM>samtools</PROGRAM>
                <VERSION>$samtools_version</VERSION>
                <NOTES>This extracts the unmapped reads out from BWA MEM aligned BAM. Note that mapped reads with unmapped mate are also extracted.</NOTES>
              </PIPE_SECTION>
END
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
      <DATA_BLOCK name=\"$last_dbn\">
        <FILES>
END

       $analysis_xml .= "          <FILE filename=\"$bam_check.bam\" filetype=\"bam\" checksum_method=\"MD5\" checksum=\"$bam_check\" />\n";
       $analysis_xml .= "          <FILE filename=\"$bam_check.bam.bai\" filetype=\"bai\" checksum_method=\"MD5\" checksum=\"$bai_check\" />\n";

  $analysis_xml .= <<END;
        </FILES>
      </DATA_BLOCK>
      <ANALYSIS_ATTRIBUTES>
END

    # this is a merge of the key-values from input XML
    foreach my $key (keys %{$global_attr}) {
      foreach my $val (keys %{$global_attr->{$key}}) {
      	if ($unmapped_reads_upload){
      	  next if ($key eq "pipeline_input_info");
      	  next if ($key eq "pipeline_input_info");
      	}
        $analysis_xml .= "        <ANALYSIS_ATTRIBUTE>
          <TAG>$key</TAG>
          <VALUE>$val</VALUE>
        </ANALYSIS_ATTRIBUTE>
";
      }
    }
  # some metadata about this workflow
  # TODO: add runtime info in here too, possibly other info
  # see https://jira.oicr.on.ca/browse/PANCANCER-43
  # see https://jira.oicr.on.ca/browse/PANCANCER-6
  $analysis_xml .= "        <ANALYSIS_ATTRIBUTE>
          <TAG>workflow_name</TAG>
          <VALUE>$workflow_name</VALUE>
        </ANALYSIS_ATTRIBUTE>
        <ANALYSIS_ATTRIBUTE>
          <TAG>workflow_version</TAG>
          <VALUE>$workflow_version</VALUE>
        </ANALYSIS_ATTRIBUTE>
        <ANALYSIS_ATTRIBUTE>
          <TAG>workflow_source_url</TAG>
          <VALUE>$workflow_src_url</VALUE>
        </ANALYSIS_ATTRIBUTE>
        <ANALYSIS_ATTRIBUTE>
          <TAG>workflow_bundle_url</TAG>
          <VALUE>$workflow_url</VALUE>
        </ANALYSIS_ATTRIBUTE>
";

if ($unmapped_reads_upload) {
  $analysis_xml .= "        <ANALYSIS_ATTRIBUTE>
          <TAG>workflow_output_bam_contents</TAG>
          <VALUE>unaligned</VALUE>
        </ANALYSIS_ATTRIBUTE>
";
} 
else {
  $analysis_xml .= "        <ANALYSIS_ATTRIBUTE>
          <TAG>workflow_output_bam_contents</TAG>
          <VALUE>aligned+unaligned</VALUE>
        </ANALYSIS_ATTRIBUTE>
";
}

unless ($unmapped_reads_upload) {
  $analysis_xml .= "        <ANALYSIS_ATTRIBUTE>
          <TAG>bwa_version</TAG>
          <VALUE>$bwa_version</VALUE>
        </ANALYSIS_ATTRIBUTE>
        <ANALYSIS_ATTRIBUTE>
          <TAG>biobambam_version</TAG>
          <VALUE>$biobambam_version</VALUE>
        </ANALYSIS_ATTRIBUTE>
        <ANALYSIS_ATTRIBUTE>
          <TAG>PCAP-core_version</TAG>
          <VALUE>$pcap_version</VALUE>
        </ANALYSIS_ATTRIBUTE>
";
  # QC
  $analysis_xml .= "        <ANALYSIS_ATTRIBUTE>
          <TAG>qc_metrics</TAG>
          <VALUE>" . &getQcResult() . "</VALUE>
        </ANALYSIS_ATTRIBUTE>
";
  # Runtime
  $analysis_xml .= "        <ANALYSIS_ATTRIBUTE>
          <TAG>timing_metrics</TAG>
          <VALUE>" . &getRuntimeInfo() . "</VALUE>
        </ANALYSIS_ATTRIBUTE>
";
  # Markduplicates metrics
  $analysis_xml .= "        <ANALYSIS_ATTRIBUTE>
          <TAG>markduplicates_metrics</TAG>
          <VALUE>" . &getMarkduplicatesMetrics() . "</VALUE>
        </ANALYSIS_ATTRIBUTE>
";
}
  $analysis_xml .= <<END;
      </ANALYSIS_ATTRIBUTES>
    </ANALYSIS>
  </ANALYSIS_SET>
END
  open OUT, '>', "$output_dir/analysis.xml";
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

  open OUT, '>', "$output_dir/experiment.xml";
  say OUT $exp_xml;
  close OUT;

  # make a uniq list of blocks
  my $uniq_run_xml = {};
  foreach my $url (keys %{$m}) {
    my $run_block = $m->{$url}{'run_block'};
    # no longer modifying the run block, this is the original input reads *not* the aligned BAM result!
    #$run_block =~ s/filename="\S+"/filename="$bam_check.bam"/g;
    #$run_block =~ s/checksum="\S+"/checksum="$bam_check"/g;
    #$run_block =~ s/center_name="[^"]+"/center_name="$refcenter"/g;
    $uniq_run_xml->{$run_block} = 1;
  }

  my $run_xml = <<END;
  <RUN_SET xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.ncbi.nlm.nih.gov/viewvc/v1/trunk/sra/doc/SRA_1-5/SRA.run.xsd?view=co">
END

  foreach my $run_block (keys %{$uniq_run_xml}) {
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
    open HEADER, '<', $header;
    while(<HEADER>) {
        chomp;
        my @a = split /\t+/;
        my $type = $a[0];
        if ($type =~ /^@/) {
            $type =~ s/@//;
            for (my $i=1; $i<scalar(@a); $i++) {
                $a[$i] =~ /^([^:]+):(.+)$/;
                $hd->{$type}{$1} = $2;
            }
        }
    }
    close HEADER;

    return $hd;
}

sub download_metadata {
    my ($urls_str) = @_;
  
    my $metad = {};
    run("mkdir -p xml2");
    my @urls = split /,/, $urls_str;
    my $i = 0;
    foreach my $url (@urls) {
      $i++;
      my $xml_path = download_url($url, "xml2/data_$i.xml");
      $metad->{$url} = parse_metadata($xml_path);
    }
    return $metad;
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
    $m->{'experiment'} = getBlock($xml_path, "/ResultSet/Result/experiment_xml/EXPERIMENT_SET/EXPERIMENT");
    $m->{'run_block'} = getBlock($xml_path, "/ResultSet/Result/run_xml/RUN_SET/RUN");
  
    return $m;
}

sub getBlock {
    my ($xml_file, $xpath) = @_;
  
    my $block = "";
    ## use XPath parser instead of using REGEX to extract desired XML fragment, to fix issue: https://jira.oicr.on.ca/browse/PANCANCER-42
    my $xp = XML::XPath->new(filename => $xml_file) or die "Can't open file $xml_file\n";
  
    my $nodeset = $xp->find($xpath);
    foreach my $node ($nodeset->get_nodelist) {
        $block .= XML::XPath::XMLParser::as_string($node) . "\n";
    }
  
    return $block;
}

sub download_url {
    my ($url, $path) = @_;

    my $r = run("wget --no-clobber -q -O $path $url");
    if ($r) {
        $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME}=0;
        $r = run("lwp-download $url $path");
        if ($r) {
            print "ERROR DOWNLOADING: $url\n";
            exit(1);
        }
    }

    return $path;
}

sub getVal {
    my ($node, $key) = @_;
  
    #print "NODE: $node KEY: $key\n";
    if (defined $node ) {
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

    return undef;
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

sub getRuntimeInfo {
    # detect all the timing files by checking file name pattern, read QC data
    # to pull back the read group and associate with timing
  
    opendir DIR, ".";
  
    my @qc_result_files = grep { /^out_\d+\.bam\.stats\.txt/ } readdir(DIR);
  
    closedir(DIR);
  
    my $ret = { "timing_metrics" => [] };
  
    foreach (@qc_result_files) {
    
        # find the index number so we can match with timing info
        $_ =~ /out_(\d+)\.bam\.stats\.txt/;
        my $i = $1;
    
        open (QC, "< $_");
    
        my @header = split /\t/, <QC>;
        my @data = split /\t/, <QC>;
        chomp ((@header, @data));
    
        close (QC);
    
        my $qc_metrics = {};
        $qc_metrics->{$_} = shift @data for (@header);
    
        my $read_group = $qc_metrics->{readgroup};
    
        # now go ahead and read that index file for timing
        my $download_timing = ($test) ? '99': read_timing("download_timing_$i.txt");
        my $bwa_timing = read_timing("bwa_timing_$i.txt");
        my $qc_timing = read_timing("qc_timing_$i.txt");
        my $merge_timing = read_timing("merge_timing.txt");
    
        # fill in the data structure
        push @{ $ret->{timing_metrics} }, { "read_group_id" => $read_group, 
                                            "metrics" => { "download_timing_seconds" => $download_timing, 
                                                           "bwa_timing_seconds" => $bwa_timing, 
                                                           "qc_timing_seconds" => $qc_timing, 
                                                            "merge_timing_seconds" => $merge_timing 
                                                         } 
                                          };
    
    }
  
    return to_json $ret;
}

sub read_timing {
    my ($file) = @_;

    open IN, '<', $file or return "not_collected"; # very quick workaround to deal with no download_timing file generated due to skip gtdownload option. Brian, please handle it as you see it appropriate
    my $start = <IN>;
    my $stop = <IN>;
    chomp $start;
    chomp $stop;
    my $delta = $stop - $start;
    close IN;

    return $delta;
}

sub getQcResult {
    # detect all the QC report files by checking file name pattern

    
    opendir DIR, ".";

    my @qc_result_files = grep { /^out_\d+\.bam\.stats\.txt/ } readdir(DIR);

    closedir(DIR);

    my $ret = { "qc_metrics" => [] };

    foreach (@qc_result_files) {
        open QC, '<', $_;

        my @header = split /\t/, <QC>;
        my @data = split /\t/, <QC>;
        chomp ((@header, @data));

        close (QC);

        my $qc_metrics = {};
        $qc_metrics->{$_} = shift @data for (@header);

        push @{ $ret->{qc_metrics} }, {"read_group_id" => $qc_metrics->{readgroup}, "metrics" => $qc_metrics};
    }

    return to_json $ret;
}

sub getMarkduplicatesMetrics {
    my $dup_metrics = `cat $bam.metrics`;
    my @rows = split /\n/, $dup_metrics;

    my @header = ();
    my @data = ();
    my $data_row = 0;
    foreach (@rows) {
        last if (/^## HISTOGRAM/); # ignore everything with this and after
        next if (/^#/ || /^\s*$/);

        $data_row++;
        do {@header = split /\t/; next} if ($data_row == 1); # header line

        push @data, $_;
    }

    my $ret = {"markduplicates_metrics" => [], "note" => "The metrics are produced by bammarkduplicates tool of the Biobambam package"};
    foreach (@data) {
        my $metrics = {};
        my @fields = split /\t/;

        $metrics->{lc($_)} = shift @fields for (@header);
        delete $metrics->{'estimated_library_size'}; # this is irrelevant

        push @{ $ret->{"markduplicates_metrics"} }, {"library" => $metrics->{'library'}, "metrics" => $metrics};
    }

    return to_json $ret;
}

sub run {
    my ($cmd, $do_die) = @_;

    say "CMD: $cmd";
    my $result = system($cmd);
    if ($do_die && $result) { die "ERROR: CMD '$cmd' returned non-zero status"; }

    return $result;
}

0;
