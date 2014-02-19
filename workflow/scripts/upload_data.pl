use strict;
use Data::Dumper;

my ($header) = @ARGV;

print "GENERATING SUBMISSION\n";

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

print Dumper $hd;

# constants

# TODO: generate this 
my $datetime = "2011-09-05T00:00:00";
# TODO: all of these need to be parameterized/read from header/read from XML
# populate refcenter from original BAM submission 
# @RG CN:(.*)
my $refcenter = "OICR";
# @CO sample_id 
my $sample_id = "6895c0b9-de4c-4a80-8fba-6ade7ce1e1dc";
# @RG SM or @CO aliquoit_id
my $aliquot_id = "f7ada105-3771-45ad-a5bb-b00664d6c8e8";
# hardcoded
my $workflow_version = "1.0";
# hardcoded
my $workflow_url = "http://oicr.on.ca/fillmein"; 
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

my $analysis_xml = <<END;
<!-- TODO: ultimately everything comes back to \@RG. SampleID is correctly linked in here but I'm worried that  
aliquot ID is never used and linked to the RG either.  -->
<ANALYSIS_SET xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.ncbi.nlm.nih.gov/viewvc/v1/trunk/sra/doc/SRA_1-5/SRA.analysis.xsd?view=co">
  <ANALYSIS center_name="$analysis_center" analysis_date="$datetime">
    <TITLE></TITLE>
    <STUDY_REF refcenter="$refcenter" refname="icgc_pancancer" />
    <DESCRIPTION>Sample-level BAM from the alignment of $sample_id from participant $participant_id. This uses the SeqWare workflow version $workflow_version available at $workflow_url</DESCRIPTION>
    <ANALYSIS_TYPE>
      <REFERENCE_ALIGNMENT>
        <ASSEMBLY>
          <CUSTOM DESCRIPTION="hs37d5" REFERENCE_SOURCE="ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/phase2_reference_assembly_sequence/README_human_reference_20110707"/>
        </ASSEMBLY>
        <RUN_LABELS>
          <!-- TODO: I think this needs to be in a for loop for each of the lane-level BAMs -->
          <!-- foreach bam : input_bams -->
            <!-- TODO: what is a data_block? If I use library and read_group_id here then how do I know what aliquot this is? -->
            <RUN data_block_name="$sample_id" read_group_label="$read_group_id" refname="$platform_unit" refcenter="$refcenter" />
            <RUN data_block_name="$sample_id" read_group_label="$read_group_id" refname="$platform_unit" refcenter="$refcenter" />
          <!-- end -->
        </RUN_LABELS>
        <SEQ_LABELS>
          <!-- TODO: looks like it's needs to be repeated for each data block! -->
          <!-- TODO: should the data_block_name be the library or the aliquot ID?  Keiran uses library and TCGA example uses aliquot_id+timestamp -->
          <!-- TODO: fill these in for the hs37d.fa values -->
          <SEQUENCE data_block_name="$sample_id" accession="NC_000001.9" seq_label="chr1" />
          <SEQUENCE data_block_name="$sample_id" accession="NC_000002.10" seq_label="chr2" />
          <SEQUENCE data_block_name="$sample_id" accession="GPC_000000393.1" seq_label="chr3" />
          <SEQUENCE data_block_name="$sample_id" accession="NC_000004.10" seq_label="chr4" />
          <SEQUENCE data_block_name="$sample_id" accession="NC_000005.8" seq_label="chr5" />
          <SEQUENCE data_block_name="$sample_id" accession="NC_000006.10" seq_label="chr6" />
          <SEQUENCE data_block_name="$sample_id" accession="NC_000007.12" seq_label="chr7" />
          <SEQUENCE data_block_name="$sample_id" accession="NC_000008.9" seq_label="chr8" />
          <SEQUENCE data_block_name="$sample_id" accession="NC_000009.10" seq_label="chr9" />
          <SEQUENCE data_block_name="$sample_id" accession="NC_000010.9" seq_label="chr10" />
          <SEQUENCE data_block_name="$sample_id" accession="NC_000011.8" seq_label="chr11" />
          <SEQUENCE data_block_name="$sample_id" accession="NC_000012.10" seq_label="chr12" />
          <SEQUENCE data_block_name="$sample_id" accession="NC_000013.9" seq_label="chr13" />
          <SEQUENCE data_block_name="$sample_id" accession="NC_000014.7" seq_label="chr14" />
          <SEQUENCE data_block_name="$sample_id" accession="NC_000015.8" seq_label="chr15" />
          <SEQUENCE data_block_name="$sample_id" accession="NC_000016.8" seq_label="chr16" />
          <SEQUENCE data_block_name="$sample_id" accession="NC_000017.9" seq_label="chr17" />
          <SEQUENCE data_block_name="$sample_id" accession="NC_000018.8" seq_label="chr18" />
          <SEQUENCE data_block_name="$sample_id" accession="NC_000019.8" seq_label="chr19" />
          <SEQUENCE data_block_name="$sample_id" accession="NC_000020.9" seq_label="chr20" />
          <SEQUENCE data_block_name="$sample_id" accession="NC_000021.7" seq_label="chr21" />
          <SEQUENCE data_block_name="$sample_id" accession="NC_000022.9" seq_label="chr22" />
          <SEQUENCE data_block_name="$sample_id" accession="NC_000023.9" seq_label="chrX" />
          <SEQUENCE data_block_name="$sample_id" accession="NC_000024.8" seq_label="chrY" />
          <SEQUENCE data_block_name="$sample_id" accession="NC_001807.4" seq_label="chrM" />
          <!-- for -->
        </SEQ_LABELS>
        <PROCESSING>
          <PIPELINE>
            <!-- TODO -->
            <PIPE_SECTION section_name="Mapping">
              <STEP_INDEX>1</STEP_INDEX>
              <PREV_STEP_INDEX>NIL</PREV_STEP_INDEX>
              <PROGRAM>bwa</PROGRAM>
              <VERSION>0.5.9</VERSION>
              <NOTES>bwa aln reference.fasta fast1file > fastq.sai</NOTES>
            </PIPE_SECTION>
          </PIPELINE>
          <DIRECTIVES>
            <alignment_includes_unaligned_reads>true</alignment_includes_unaligned_reads>
            <alignment_marks_duplicate_reads>true</alignment_marks_duplicate_reads>
            <!-- TODO: can I tell? -->
            <alignment_includes_failed_reads>false</alignment_includes_failed_reads>
          </DIRECTIVES>
        </PROCESSING>
      </REFERENCE_ALIGNMENT>
    </ANALYSIS_TYPE>
    <TARGETS>
      <TARGET sra_object_type="SAMPLE" refcenter="$refcenter" refname="$sample_id" />
    </TARGETS>
    <DATA_BLOCK name="$sample_id">
      <FILES>
        <FILE filename="$bam_file" filetype="bam" checksum_method="MD5" checksum="$bam_file_checksum" />
      </FILES>
    </DATA_BLOCK>
    <ANALYSIS_ATTRIBUTES>
      <!-- TODO: these will be the union (with key repeats) of all the individual lane-level attributes -->
      <ANALYSIS_ATTRIBUTE>
        <TAG>analyte_code</TAG>
        <VALUE>D</VALUE>
      </ANALYSIS_ATTRIBUTE>
    </ANALYSIS_ATTRIBUTES>
  </ANALYSIS>
</ANALYSIS_SET>
END

my $exp_xml = <<END;
<EXPERIMENT_SET xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.ncbi.nlm.nih.gov/viewvc/v1/trunk/sra/doc/SRA_1-5/SRA.experiment.xsd?view=co">
  <EXPERIMENT alias="IWX_TCOL.A6-2671-01A-T_2pA_1" center_name="CGHUB">
    <TITLE>Christy Test:  Derived from Baylors first upload</TITLE>
    <STUDY_REF accession="SRP000677" refcenter="NHGRI" refname="CGTEST" />
    <DESIGN>
      <DESIGN_DESCRIPTION>Whole Exome Sequencing of TCGA Colon sample TCGA-A6-2671-01A-01D-1408-10 by Hybrid Selection</DESIGN_DESCRIPTION>
      <SAMPLE_DESCRIPTOR accession="SRS156722" refcenter="TCGA" refname="98a2eb02-7bcf-4134-ab7e-943391710e98" />
      <LIBRARY_DESCRIPTOR>
        <LIBRARY_NAME>IWX_TCOL.A6-2671-01A-T_2pA</LIBRARY_NAME>
        <LIBRARY_STRATEGY>WXS</LIBRARY_STRATEGY>
        <LIBRARY_SOURCE>GENOMIC</LIBRARY_SOURCE>
        <LIBRARY_SELECTION>Hybrid Selection</LIBRARY_SELECTION>
        <LIBRARY_LAYOUT>
          <PAIRED NOMINAL_LENGTH="200" NOMINAL_SDEV="20.0" />
        </LIBRARY_LAYOUT>
      </LIBRARY_DESCRIPTOR>
      <SPOT_DESCRIPTOR>
        <SPOT_DECODE_SPEC>
          <READ_SPEC>
            <READ_INDEX>0</READ_INDEX>
            <READ_CLASS>Application Read</READ_CLASS>
            <READ_TYPE>Forward</READ_TYPE>
            <BASE_COORD>1</BASE_COORD>
          </READ_SPEC>
          <READ_SPEC>
            <READ_INDEX>1</READ_INDEX>
            <READ_CLASS>Application Read</READ_CLASS>
            <READ_TYPE>Reverse</READ_TYPE>
            <BASE_COORD>101</BASE_COORD>
          </READ_SPEC>
        </SPOT_DECODE_SPEC>
      </SPOT_DESCRIPTOR>
    </DESIGN>
    <PLATFORM>
      <ILLUMINA>
        <INSTRUMENT_MODEL>Illumina HiSeq 2000</INSTRUMENT_MODEL>
      </ILLUMINA>
    </PLATFORM>
    <PROCESSING>
      <PIPELINE>
        <PIPE_SECTION section_name="Base Caller">
          <STEP_INDEX>1</STEP_INDEX>
          <PREV_STEP_INDEX>NIL</PREV_STEP_INDEX>
          <PROGRAM>Casava</PROGRAM>
          <VERSION>V1.7</VERSION>
          <NOTES />
        </PIPE_SECTION>
        <PIPE_SECTION section_name="Quality Scores">
          <STEP_INDEX>2</STEP_INDEX>
          <PREV_STEP_INDEX>1</PREV_STEP_INDEX>
          <PROGRAM>Casava</PROGRAM>
          <VERSION>V1.7</VERSION>
          <NOTES />
        </PIPE_SECTION>
      </PIPELINE>
    </PROCESSING>
  </EXPERIMENT>
</EXPERIMENT_SET>
END

my $run_xml = <<END;
<RUN_SET xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.ncbi.nlm.nih.gov/viewvc/v1/trunk/sra/doc/SRA_1-5/SRA.run.xsd?view=co">
  <RUN alias="110823_SN881_0126_AD08JDACXX_6_ID01" center_name="CGHUB">
    <EXPERIMENT_REF refname="IWX_TCOL.A6-2671-01A-T_2pA_1" refcenter="CGHUB" />
    <DATA_BLOCK>
      <FILES>
        <FILE filename="4-mb-real-testfile.bam" filetype="bam" checksum_method="MD5" checksum="0e4f1bd5c5cc83b37d6c511dda98866c" />
      </FILES>
    </DATA_BLOCK>
  </RUN>
</RUN_SET>
END


