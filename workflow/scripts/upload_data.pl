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

my $analysis_xml = <<END;
<ANALYSIS_SET xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.ncbi.nlm.nih.gov/viewvc/v1/trunk/sra/doc/SRA_1-5/SRA.analysis.xsd?view=co">
  <ANALYSIS alias="TCGA-A6-2671-01A-01D-1408-10_2011-09-05" center_name="CGHUB" broker_name="NCBI" analysis_center="CGHUB" analysis_date="2011-09-05T00:00:00">
    <TITLE>Christy Test:  Derived from Baylors first upload</TITLE>
    <STUDY_REF accession="SRP000677" refcenter="NHGRI" refname="icgc_pancancer" />
    <DESCRIPTION>High Throughput Directed Sequencing Sequence Alignment/Map of TCGA Colon SAMPLE:TCGA-A6-2671-01A-01D-1408-10</DESCRIPTION>
    <ANALYSIS_TYPE>
      <REFERENCE_ALIGNMENT>
        <ASSEMBLY>
          <STANDARD short_name="HG19" />
        </ASSEMBLY>
        <RUN_LABELS>
          <RUN data_block_name="110823_SN881_0126_AD08JDACXX_6_ID01" read_group_label="0" refname="110823_SN881_0126_AD08JDACXX_6_ID01" refcenter="CGHUB" />
        </RUN_LABELS>
        <SEQ_LABELS>
          <SEQUENCE data_block_name="TCGA-A6-2671-01A-01D-1408-10_2011-09-05" accession="NC_000001.9" seq_label="chr1" />
          <SEQUENCE data_block_name="TCGA-A6-2671-01A-01D-1408-10_2011-09-05" accession="NC_000002.10" seq_label="chr2" />
          <SEQUENCE data_block_name="TCGA-A6-2671-01A-01D-1408-10_2011-09-05" accession="GPC_000000393.1" seq_label="chr3" />
          <SEQUENCE data_block_name="TCGA-A6-2671-01A-01D-1408-10_2011-09-05" accession="NC_000004.10" seq_label="chr4" />
          <SEQUENCE data_block_name="TCGA-A6-2671-01A-01D-1408-10_2011-09-05" accession="NC_000005.8" seq_label="chr5" />
          <SEQUENCE data_block_name="TCGA-A6-2671-01A-01D-1408-10_2011-09-05" accession="NC_000006.10" seq_label="chr6" />
          <SEQUENCE data_block_name="TCGA-A6-2671-01A-01D-1408-10_2011-09-05" accession="NC_000007.12" seq_label="chr7" />
          <SEQUENCE data_block_name="TCGA-A6-2671-01A-01D-1408-10_2011-09-05" accession="NC_000008.9" seq_label="chr8" />
          <SEQUENCE data_block_name="TCGA-A6-2671-01A-01D-1408-10_2011-09-05" accession="NC_000009.10" seq_label="chr9" />
          <SEQUENCE data_block_name="TCGA-A6-2671-01A-01D-1408-10_2011-09-05" accession="NC_000010.9" seq_label="chr10" />
          <SEQUENCE data_block_name="TCGA-A6-2671-01A-01D-1408-10_2011-09-05" accession="NC_000011.8" seq_label="chr11" />
          <SEQUENCE data_block_name="TCGA-A6-2671-01A-01D-1408-10_2011-09-05" accession="NC_000012.10" seq_label="chr12" />
          <SEQUENCE data_block_name="TCGA-A6-2671-01A-01D-1408-10_2011-09-05" accession="NC_000013.9" seq_label="chr13" />
          <SEQUENCE data_block_name="TCGA-A6-2671-01A-01D-1408-10_2011-09-05" accession="NC_000014.7" seq_label="chr14" />
          <SEQUENCE data_block_name="TCGA-A6-2671-01A-01D-1408-10_2011-09-05" accession="NC_000015.8" seq_label="chr15" />
          <SEQUENCE data_block_name="TCGA-A6-2671-01A-01D-1408-10_2011-09-05" accession="NC_000016.8" seq_label="chr16" />
          <SEQUENCE data_block_name="TCGA-A6-2671-01A-01D-1408-10_2011-09-05" accession="NC_000017.9" seq_label="chr17" />
          <SEQUENCE data_block_name="TCGA-A6-2671-01A-01D-1408-10_2011-09-05" accession="NC_000018.8" seq_label="chr18" />
          <SEQUENCE data_block_name="TCGA-A6-2671-01A-01D-1408-10_2011-09-05" accession="NC_000019.8" seq_label="chr19" />
          <SEQUENCE data_block_name="TCGA-A6-2671-01A-01D-1408-10_2011-09-05" accession="NC_000020.9" seq_label="chr20" />
          <SEQUENCE data_block_name="TCGA-A6-2671-01A-01D-1408-10_2011-09-05" accession="NC_000021.7" seq_label="chr21" />
          <SEQUENCE data_block_name="TCGA-A6-2671-01A-01D-1408-10_2011-09-05" accession="NC_000022.9" seq_label="chr22" />
          <SEQUENCE data_block_name="TCGA-A6-2671-01A-01D-1408-10_2011-09-05" accession="NC_000023.9" seq_label="chrX" />
          <SEQUENCE data_block_name="TCGA-A6-2671-01A-01D-1408-10_2011-09-05" accession="NC_000024.8" seq_label="chrY" />
          <SEQUENCE data_block_name="TCGA-A6-2671-01A-01D-1408-10_2011-09-05" accession="NC_001807.4" seq_label="chrM" />
        </SEQ_LABELS>
        <PROCESSING>
          <PIPELINE>
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
            <alignment_includes_failed_reads>false</alignment_includes_failed_reads>
          </DIRECTIVES>
        </PROCESSING>
      </REFERENCE_ALIGNMENT>
    </ANALYSIS_TYPE>
    <TARGETS>
      <TARGET sra_object_type="SAMPLE" accession="SRS156722" refcenter="TCGA" refname="98a2eb02-7bcf-4134-ab7e-943391710e98" />
    </TARGETS>
    <DATA_BLOCK name="TCGA-A6-2671-01A-01D-1408-10_2011-09-05">
      <FILES>
        <FILE filename="4-mb-real-testfile.bam" filetype="bam" checksum_method="MD5" checksum="0e4f1bd5c5cc83b37d6c511dda98866c" />
      </FILES>
    </DATA_BLOCK>
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


