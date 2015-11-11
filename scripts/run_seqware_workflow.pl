#!/usr/bin/perl

use strict;
use Getopt::Long;
use Cwd;

########
# ABOUT
########
# This script wraps calling a SeqWare workflow, in this case, the BWA workflow.
# It reads param line options, which are easier to deal with in CWL, then
# creates an INI file, and, finally, executes the workflow.  This workflow
# is already setup to run in local file mode so I just really need to override
# the inputs and outputs.
# EXAMPLE:
# perl /workflow/scripts/run_seqware_workflow.pl --file '${workflow_bundle_dir}/Workflow_Bundle_BWA/2.6.6/data/testData/sample_bam_sequence_synthetic_chr22_normal/9c414428-9446-11e3-86c1-ab5c73f0e08b/hg19.chr22.5x.normal.bam' --file '${workflow_bundle_dir}/Workflow_Bundle_BWA/2.6.6/data/testData/sample_bam_sequence_synthetic_chr22_normal/4fb18a5a-9504-11e3-8d90-d1f1d69ccc24/hg19.chr22.5x.normal2.bam'
# TODO:
# this is a very hard-coded script and assumes it's running inside the Docker container

my @files;
my $cwd = cwd();

GetOptions ("file=s"   => \@files)
 or die("Error in command line arguments\n");

# PARSE OPTIONS
my $file_str = join ",", @files;
my @metadata;
my @download;
for (my $i=0; $i<scalar(@files); $i++) {
  # we're not using these so just pad them with URLs
  push @metadata, "https://gtrepo-ebi.annailabs.com/cghub/metadata/analysisFull/87bad5b8-bc1f-11e3-a065-b669c091c278";
  push @download, "https://gtrepo-ebi.annailabs.com/cghub/data/analysis/download/87bad5b8-bc1f-11e3-a065-b669c091c278";
}
my $metadata_str = join ",", @metadata;
my $download_str = join ",", @download;

# MAKE CONFIG
# the default config is the workflow_local.ini and has most configs ready to go
my $config = "
# these make sure S3 and GNOS are not used
useGNOS=true
use_gtdownload=false
use_gtupload=false
use_gtvalidation=false

# don't cleanup the BAMS, we need them after the workflow runs!
cleanup=false

# key=input_bam_paths:type=text:display=T:display_name=The relative BAM paths which are typically the UUID/bam_file.bam for bams from a GNOS repo if use_gtdownload is true. If use_gtdownload is false these should be full paths to local BAMs.
input_bam_paths=$file_str

# key=input_file_urls:type=text:display=T:display_name=The URLs (comma-delimited) that are used to download the BAM files. The URLs should be in the same order as the BAMs for input_bam_paths. These are not used if use_gtdownload is false.
input_file_urls=$download_str

# key=gnos_input_metadata_urls:type=text:display=T:display_name=The URLs (comma-delimited) that are used to download the BAM files. The URLs should be in the same order as the BAMs for input_bam_paths. Metadata is read from GNOS regardless of whether or not bams are downloaded from there.
gnos_input_metadata_urls=$metadata_str

# key=output_dir:type=text:display=F:display_name=A local file path if chosen rather than an upload to a GNOS server
output_dir=/

# key=output_prefix:type=text:display=F:display_name=The output_prefix is a convention and used to specify the root of the absolute output path
output_prefix=$cwd/
";

open OUT, ">workflow.ini" or die;
print OUT $config;
close OUT;

# NOW RUN WORKFLOW
my $error = system("seqware bundle launch --dir /home/seqware/Seqware-BWA-Workflow/target/Workflow_Bundle_BWA_2.6.6_SeqWare_1.1.1 --engine whitestar --ini workflow.ini --no-metadata");

# NOW FIND OUTPUT
my $path = `ls -1t /datastore/ | grep 'oozie-' | head -1`;
chomp $path;
my $bam_path = "$path/data/merged_output.bam";
my $bai_path = "$path/data/merged_output.bam.bai";
my $ubam_path = "$path/data/merged_output.unmapped.bam";
my $ubai_path = "$path/data/merged_output.unmapped.bam.bai";

# MOVE THESE TO THE RIGHT PLACE
system("mv $path/data/merged_output.bam* $cwd");
system("mv $path/data/merged_output.unmapped.bam* $cwd");

# RETURN RESULT
exit($error);
