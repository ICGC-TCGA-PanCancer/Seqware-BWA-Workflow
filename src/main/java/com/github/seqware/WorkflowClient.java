package com.github.seqware;

/**
 * Mine
 */
import java.util.ArrayList;
import java.util.Collections;
import java.util.Map;
import java.util.logging.Level;
import java.util.logging.Logger;

import net.sourceforge.seqware.pipeline.workflowV2.AbstractWorkflowDataModel;
import net.sourceforge.seqware.pipeline.workflowV2.model.Job;
import net.sourceforge.seqware.pipeline.workflowV2.model.SqwFile;

public class WorkflowClient extends AbstractWorkflowDataModel {
  // GENERAL
  String gtDownloadWrapperVersion = "2.0.10";
  // comma-seperated for multiple bam inputs
  String inputBamPaths = null;
  ArrayList<String> bamPaths = new ArrayList<>();
  ArrayList<String> inputURLs = new ArrayList<>();
  ArrayList<String> inputMetadataURLs = new ArrayList<>();
  String bwaChoice = "aln"; // can be "aln" or "mem"
  // used to download with gtdownload
  String gnosInputFileURLs = null;
  String gnosInputMetadataURLs = null;
  String gnosUploadFileURL = null;
  String gnosKey = null;
  int gnosMaxChildren = 3;
  int gnosRateLimit = 200; // unit: MB/s
  int gnosTimeout = 40; // unit: minute
  boolean useGtDownload = true;
  boolean useGtUpload = true;
  boolean useGtValidation = true;
  boolean cleanup = true;
  // number of splits for bam files, default 1=no split
  int bamSplits = 1;
  String reference_path = null;
  String dataDir = "data/";
  String outputDir = "results";
  String outputPrefix = "./";
  String resultsDir = outputPrefix + outputDir;
  String outputFileName = "merged_output.bam";
  String outputUnmappedFileName = "merged_output.unmapped.bam";
  // BWA
  String bwaAlignMemG = "8";
  String bwaSampeMemG = "8";
  String bwaSampeSortSamMemG = "8";
  String additionalPicardParams;
  String picardSortMem = "6";
  String picardSortJobMem = "8";
  String uploadScriptJobMem = "2";
  int numOfThreads = 1; // aln
  int maxInsertSize; // sampe
  String readGroup;// sampe
  String bwa_aln_params;
  String bwa_sampe_params;
  String skipUpload = null;
  String pcapPath = "/bin/PCAP-core-1.1.1";
  // GTDownload
  // each retry is 1 minute
  String gtdownloadRetries = "30";
  String gtdownloadMd5Time = "120";
  String timeoutMin = "60";
  String gtdownloadMem = "8";
  String gtdownloadWrapperType = "timer_based";
  String smallJobMemM = "4000";
  String studyRefnameOverride = "icgc_pancancer";
  String unmappedReadsJobMemM = "8000";
    
  // We don't really need a separate variable. We can just rename the old one without the word "gnos"
  // private String uploadURL = "";

  // Should come from INI file. If false, then use S3.
  Boolean useGNOS = true;

  // Should come from INI file. If true, download reference files from S3.
  // e.g. http://s3.amazonaws.com/pan-cancer-data/pan-cancer-reference/genome.fa.gz, etc
  Boolean download_reference_files = false;

  @Override
  public Map<String, SqwFile> setupFiles() {

    /*
     * This workflow isn't using file provisioning since we're using GeneTorrent. 
     * So this method is just being used to setup various variables.
     */
    try {

      inputBamPaths = getProperty("input_bam_paths");
      Collections.addAll(bamPaths, inputBamPaths.split(","));

      gnosInputFileURLs = getProperty("input_file_urls");
      Collections.addAll(inputURLs, gnosInputFileURLs.split(","));

      gnosInputMetadataURLs = getProperty("gnos_input_metadata_urls");
      Collections.addAll(inputMetadataURLs, gnosInputMetadataURLs.split(","));

      outputDir = getProperty("output_dir");
      outputPrefix = getProperty("output_prefix");
      resultsDir = outputPrefix + outputDir;
      gnosUploadFileURL = getProperty("output_file_url");
      gnosKey = getProperty("gnos_key");
      gnosMaxChildren = getProperty("gnos_max_children") == null ? 3 : Integer.parseInt(getProperty("gnos_max_children"));
      gnosRateLimit = getProperty("gnos_rate_limit") == null ? 50 : Integer.parseInt(getProperty("gnos_rate_limit"));
      gnosTimeout = getProperty("gnos_timeout") == null ? 40 : Integer.parseInt(getProperty("gnos_timeout"));
      reference_path = getProperty("input_reference");
      bwaChoice = getProperty("bwa_choice") == null ? "aln" : getProperty("bwa_choice");
      bwaAlignMemG = getProperty("bwaAlignMemG") == null ? "8" : getProperty("bwaAlignMemG");
      bwaSampeMemG = getProperty("bwaSampeMemG") == null ? "8" : getProperty("bwaSampeMemG");
      bwaSampeSortSamMemG = getProperty("bwaSampeSortSamMemG") == null ? "4" : getProperty("bwaSampeSortSamMemG");
      picardSortMem = getProperty("picardSortMem") == null ? "6" : getProperty("picardSortMem");
      picardSortJobMem = getProperty("picardSortJobMem") == null ? "8" : getProperty("picardSortJobMem");
      uploadScriptJobMem = getProperty("uploadScriptJobMem") == null ? "2" : getProperty("uploadScriptJobMem");
      additionalPicardParams = getProperty("additionalPicardParams");
      skipUpload = getProperty("skip_upload") == null ? "true" : getProperty("skip_upload");
      gtdownloadRetries = getProperty("gtdownloadRetries") == null ? "30" : getProperty("gtdownloadRetries");
      timeoutMin = getProperty("gnos_timeout_min") == null ? "60" : getProperty("gnos_timeout_min");
      gtdownloadMd5Time = getProperty("gtdownloadMd5time") == null ? "120" : getProperty("gtdownloadMd5time");
      gtdownloadMem = getProperty("gtdownloadMemG") == null ? "8" : getProperty("gtdownloadMemG");
      gtdownloadWrapperType = getProperty("gtdownloadWrapperType") == null ? "timer_based" : getProperty("gtdownloadWrapperType");
      studyRefnameOverride = getProperty("study-refname-override") == null ? "icgc_pancancer" : getProperty("study-refname-override");
      smallJobMemM = getProperty("smallJobMemM") == null ? "3000" : getProperty("smallJobMemM");
      unmappedReadsJobMemM = getProperty("unmappedReadsJobMemM") == null ? "8000" : getProperty("unmappedReadsJobMemM");

      if (getProperty("download_reference_files") != null) {
        if ("true".equals(getProperty("download_reference_files"))) {
          download_reference_files = true;
        } 
      }
            
      if (getProperty("useGNOS") != null) {
        if ("false".equals(getProperty("useGNOS"))) {
          useGNOS = false;
        } 
      }
            
      if (getProperty("use_gtdownload") != null) {
        if ("false".equals(getProperty("use_gtdownload"))) {
          useGtDownload = false;
        }
      }

      if (getProperty("use_gtupload") != null) {
        if ("false".equals(getProperty("use_gtupload"))) {
          useGtUpload = false;
        }
      }

      if (getProperty("use_gtvalidation") != null) {
        if ("false".equals(getProperty("use_gtvalidation"))) {
          useGtValidation = false;
        }
      }

      if (getProperty("cleanup") != null) {
        if ("false".equals(getProperty("cleanup"))) {
          cleanup = false;
        }
      }

      if (!getProperty("numOfThreads").isEmpty()) {
        numOfThreads = Integer.parseInt(getProperty("numOfThreads"));
      }

    } catch (Exception e) {
      Logger.getLogger(WorkflowClient.class.getName()).log(Level.SEVERE, null, e);
      throw new RuntimeException("Problem parsing variable values: " + e.getMessage());
    }

    return this.getFiles();
  }

  @Override
  public void setupDirectory() {
    // creates the final output
    this.addDirectory(dataDir);
    this.addDirectory(resultsDir);
  }

  @Override
  public void buildWorkflow() {

    int numBamFiles = bamPaths.size();
    ArrayList<Job> bamJobs = new ArrayList<>();
    ArrayList<Job> qcJobs = new ArrayList<>();

    // download reference data if not present
    Job reference_download = null;
    if (download_reference_files) {
       reference_download = this.getWorkflow().createBashJob("reference_download");
       reference_download.getCommand()
         .addArgument("set -e; set -o pipefail;")
         .addArgument("perl " + this.getWorkflowBaseDir() + "/scripts/download_data.pl")
         .addArgument(this.getWorkflowBaseDir() + "/data" );
    }

    // downloading the input BAMs if necessary
    int numInputURLs = this.inputURLs.size();
    for (int i = 0; i < numInputURLs; i++) {

      // the file downloaded will be in this path
      String file = bamPaths.get(i);
      // the URL to download this from
      String fileURL = inputURLs.get(i);

      /*
       * Job job05 = this.getWorkflow().createBashJob("upload"); job05.getCommand().addArgument("" +
       * "synapse -u <uSERNAME > -p <PASSWORD> -parentId add " + fileURL + " > " + file +".synapse" );
       */

      // the download job that either downloads or locates the file on the filesystem
      Job downloadJob = null;
            
      if (useGNOS) {
        if (useGtDownload) {
          downloadJob = this.getWorkflow().createBashJob("gtdownload");
          addDownloadJobArgs(downloadJob, file, fileURL, i, gtdownloadWrapperType);
          downloadJob.setMaxMemory(gtdownloadMem + "000");
          if (download_reference_files) {
            downloadJob.addParent(reference_download);
          }
        }
      } else if (file.startsWith("s3://")) {
        downloadJob = this.getWorkflow().createBashJob("aws_s3_download");
        downloadJob.getCommand().addArgument("export AWS_CONFIG_FILE=/home/ubuntu/.gnos/config && aws s3 cp " + fileURL 
                                             + " " + file.replaceAll("/.*$", "") + " --recursive");
        if (download_reference_files) {
          downloadJob.addParent(reference_download);
        }
      }

      // in the future this should use the read group if provided otherwise use read group from bam file
      Job headerJob = this.getWorkflow().createBashJob("headerJob" + i);

      // Empty PI in @RG causes downstream analysis fail at BI, see https://jira.oicr.on.ca/browse/PANCANCER-32
      // The quick fix is to detect that and drop the empty PI in the header, one liner Perl is used (replacing previous sed)
      headerJob
        .getCommand()
        .addArgument("set -e; set -o pipefail; "
                     + this.getWorkflowBaseDir()
                     + pcapPath
                     + "/bin/samtools view -H "
                     + file
                     + " | perl -nae 'next unless /^\\@RG/; s/\\tPI:\\s*\\t/\\t/; s/\\tPI:\\s*\\z/\\n/; s/\\t/\\\\t/g; print' > bam_header."
                     + i + ".txt");

      if (useGtDownload) {
        headerJob.addParent(downloadJob);
      }

      headerJob.setMaxMemory(smallJobMemM);

      if (download_reference_files) {
        headerJob.addParent(reference_download);
      }     

      // the QC job used by either path below
      Job qcJob = null;

      if ("aln".equals(bwaChoice)) {

        // BWA ALN STEPS
        // bwa aln -t 8 -b1 ./reference/genome.fa.gz ./HG00096.chrom20.ILLUMINA.bwa.GBR.low_coverage.20120522.bam_000000.bam >
        // aligned_1.sai 2> aligned_1.err
        // bwa aln -t 8 -b2 ./reference/genome.fa.gz ./HG00096.chrom20.ILLUMINA.bwa.GBR.low_coverage.20120522.bam_000000.bam >
        // aligned_2.sai 2> aligned_2.err
        Job job01 = this.getWorkflow().createBashJob("bwa_align1_" + i);
        job01.addParent(headerJob);
        job01.getCommand().addArgument("set -e; set -o pipefail; date +%s > bwa_timing_" + i + ".txt ;")
          .addArgument(this.getWorkflowBaseDir() + "/bin/bwa-0.6.2/bwa aln ")
          .addArgument(this.parameters("aln") == null ? " " : this.parameters("aln")).addArgument(reference_path + " -b1 ")
          .addArgument(file).addArgument(" > aligned_" + i + "_1.sai");
        job01.setMaxMemory(bwaAlignMemG + "900");
        /*
         * if (!getProperty("numOfThreads").isEmpty()) { job01.setThreads(Integer.parseInt(getProperty("numOfThreads"))); }
         */

        Job job02 = this.getWorkflow().createBashJob("bwa_align2_" + i);
        job02.addParent(headerJob);
        job02.getCommand().addArgument(this.getWorkflowBaseDir() + "/bin/bwa-0.6.2/bwa aln ")
          .addArgument(this.parameters("aln") == null ? " " : this.parameters("aln")).addArgument(reference_path + " -b2 ")
          .addArgument(file).addArgument(" > aligned_" + i + "_2.sai");
        job02.setMaxMemory(bwaAlignMemG + "900");
        /*
         * if (!getProperty("numOfThreads").isEmpty()) { job02.setThreads(Integer.parseInt(getProperty("numOfThreads"))); }
         */

        // BWA SAMPE + CONVERT TO BAM
        // bwa sampe reference/genome.fa.gz aligned_1.sai aligned_2.sai
        // HG00096.chrom20.ILLUMINA.bwa.GBR.low_coverage.20120522.bam_000000.bam
        // HG00096.chrom20.ILLUMINA.bwa.GBR.low_coverage.20120522.bam_000000.bam > aligned.sam
        Job job03 = this.getWorkflow().createBashJob("bwa_sam_bam_" + i);
        job03.getCommand().addArgument("set -e; set -o pipefail;")
          .addArgument(this.getWorkflowBaseDir() + "/bin/bwa-0.6.2/bwa sampe ")
          .addArgument("-r \"`cat bam_header." + i + ".txt`\"")
          .addArgument(this.parameters("sampe").isEmpty() ? " " : this.parameters("sampe")).addArgument(reference_path)
          .addArgument("aligned_" + i + "_1.sai").addArgument("aligned_" + i + "_2.sai").addArgument(file).addArgument(file)
          .addArgument(" | java -Xmx" + bwaSampeSortSamMemG + "g -jar ")
          .addArgument(this.getWorkflowBaseDir() + "/bin/picard-tools-1.89/SortSam.jar")
          .addArgument("I=/dev/stdin TMP_DIR=./ VALIDATION_STRINGENCY=SILENT")
          .addArgument("SORT_ORDER=coordinate CREATE_INDEX=true").addArgument("O=out_" + i + ".bam ;")
          .addArgument("date +%s >> bwa_timing_" + i + ".txt");

        job03.addParent(job01);
        job03.addParent(job02);
        job03.setMaxMemory(bwaSampeMemG + "900");
        bamJobs.add(job03);

        // QC JOB
        qcJob = this.getWorkflow().createBashJob("bam_stats_qc_" + i);
        addBamStatsQcJobArgument(i, qcJob);
        qcJob.addParent(job03);
        qcJob.setMaxMemory(smallJobMemM);
        qcJobs.add(qcJob);

        // CLEANUP DOWNLOADED INPUT UNALIGNED BAM FILES
        if (useGtDownload && cleanup) {
          Job cleanup1 = this.getWorkflow().createBashJob("cleanup_" + i);
          cleanup1.getCommand().addArgument("rm -f " + file);
          cleanup1.setMaxMemory(smallJobMemM);
          cleanup1.addParent(job03);
        }

      } else if ("mem".equals(bwaChoice)) {

        // BWA MEM
        Job job01 = this.getWorkflow().createBashJob("bwa_mem_" + i);
        job01.addParent(headerJob);
        job01.getCommand()
          .addArgument("set -e; set -o pipefail; date +%s > bwa_timing_" + i + ".txt ;")
          .addArgument("LD_LIBRARY_PATH=" + this.getWorkflowBaseDir() + pcapPath + "/lib")
          .addArgument(this.getWorkflowBaseDir() + pcapPath + "/bin/bamtofastq")
          .addArgument("exclude=QCFAIL,SECONDARY,SUPPLEMENTARY")
          .addArgument("T=out_" + i + ".t")
          .addArgument("S=out_" + i + ".s")
          .addArgument("O=out_" + i + ".o")
          .addArgument("O2=out_" + i + ".o2")
          .addArgument("collate=1")
          .addArgument("tryoq=1")
          .addArgument("filename=" + file)
          .addArgument(" | perl -e 'while(<>){$i++; $_ =~ s|@[01](/[12])$|\\1| if($i % 4 == 1); print $_;} $c = $i/4; warn \"$c\\n\";' 2> input_bam_"
                       + i + ".count.txt")
          .addArgument(" | LD_LIBRARY_PATH=" + this.getWorkflowBaseDir() + pcapPath + "/lib")
          .addArgument(this.getWorkflowBaseDir() + pcapPath + "/bin/bwa mem")
          // this pulls in threads and extra params
          .addArgument(this.parameters("mem") == null ? " " : this.parameters("mem")).addArgument("-p -T 0")
          .addArgument("-R \"`cat bam_header." + i + ".txt`\"").addArgument(reference_path).addArgument("-")
          .addArgument("| LD_LIBRARY_PATH=" + this.getWorkflowBaseDir() + pcapPath + "/lib ")
          .addArgument(this.getWorkflowBaseDir() + pcapPath + "/bin/bamsort")
          .addArgument("inputformat=sam level=1 inputthreads=2 outputthreads=2")
          .addArgument("calmdnm=1 calmdnmrecompindetonly=1 calmdnmreference=" + reference_path)
          .addArgument("tmpfile=out_" + i + ".sorttmp").addArgument("O=out_" + i + ".bam 2> bamsort_info_" + i + ".txt")
          .addArgument("&& date +%s >> bwa_timing_" + i + ".txt;");
 
        // CLEANUP DOWNLOADED INPUT UNALIGNED BAM FILES
        if (useGtDownload && cleanup) {
          job01.getCommand().addArgument("rm -f " + file);
        }

        job01.setMaxMemory(bwaAlignMemG + "900");

        bamJobs.add(job01);

        // QC JOB
        qcJob = this.getWorkflow().createBashJob("bam_stats_qc_" + i);
        addBamStatsQcJobArgument(i, qcJob);
        qcJob.addParent(job01);
        qcJob.setMaxMemory(smallJobMemM);
        qcJobs.add(qcJob);
      } else {
        // not sure if there's a better way to do this
        throw new RuntimeException("Don't understand a bwa choice of " + bwaChoice + " needs to be aln or mem");
      }
    }

    // MERGE
    Job job04 = this.getWorkflow().createBashJob("mergeBAM");

    if ("aln".equals(bwaChoice)) {

      job04.getCommand()
        .addArgument("set -e; set -o pipefail; date +%s > merge_timing.txt ;")
        .addArgument("java -Xmx" + picardSortMem + "g -jar " + this.getWorkflowBaseDir()
                     + "/bin/picard-tools-1.89/MergeSamFiles.jar " + " "
                     + (additionalPicardParams.isEmpty() ? "" : additionalPicardParams));
      for (int i = 0; i < numBamFiles; i++) {
        job04.getCommand().addArgument(" I=out_" + i + ".bam");
      }
      job04.getCommand().addArgument(" O=" + this.dataDir + outputFileName)
        .addArgument("SORT_ORDER=coordinate VALIDATION_STRINGENCY=SILENT CREATE_INDEX=true CREATE_MD5_FILE=true ;")
        .addArgument("date +%s >> merge_timing.txt ;");
      for (Job pJob : bamJobs) {
        job04.addParent(pJob);
      }
      job04.setMaxMemory(picardSortJobMem + "900");

    } else if ("mem".equals(bwaChoice)) {

      job04.getCommand().addArgument("set -e; set -o pipefail; date +%s > merge_timing.txt ;")
        .addArgument("LD_LIBRARY_PATH=" + this.getWorkflowBaseDir() + pcapPath + "/lib")
        .addArgument(this.getWorkflowBaseDir() + pcapPath + "/bin/bammarkduplicates")
        .addArgument("O=" + this.dataDir + outputFileName).addArgument("M=" + this.dataDir + outputFileName + ".metrics")
        .addArgument("tmpfile=" + this.dataDir + outputFileName + ".biormdup").addArgument("markthreads=" + numOfThreads)
        .addArgument("rewritebam=1 rewritebamlevel=1 index=1 md5=1");
      for (int i = 0; i < numBamFiles; i++) {
        job04.getCommand().addArgument(" I=out_" + i + ".bam");
      }
      job04.getCommand().addArgument(" && date +%s >> merge_timing.txt ");
      for (Job pJob : bamJobs) {
        job04.addParent(pJob);
      }
      /*
       * if (!getProperty("numOfThreads").isEmpty()) { job04.setThreads(Integer.parseInt(getProperty("numOfThreads"))); }
       */

      // now compute md5sum for the bai file
      job04.getCommand().addArgument(" && md5sum " + this.dataDir + outputFileName + ".bai | awk '{printf $1}'" + 
                                     " > " + this.dataDir + outputFileName + ".bai.md5");

      job04.setMaxMemory(picardSortJobMem + "900");

    }

    // extract unmapped reads (both ends or either end unmapped)
    Job unmappedReadsJob1;
    Job unmappedReadsJob2;
    Job unmappedReadsJob3;
    unmappedReadsJob1 = this.getWorkflow().createBashJob("unmappedReads1");
    unmappedReadsJob1
      .getCommand()
      .addArgument(this.getWorkflowBaseDir() + pcapPath
                   + "/bin/samtools view -h -f 4 " // reads unmapped
                   + this.dataDir + outputFileName + " | perl " + this.getWorkflowBaseDir()
                   + "/scripts/remove_both_ends_unmapped_reads.pl ")
      // this is necessary because samtools -f 4 outputs both-ends-unmapped reads
      .addArgument("| LD_LIBRARY_PATH=" + this.getWorkflowBaseDir() + pcapPath + "/lib ")
      .addArgument(this.getWorkflowBaseDir() + pcapPath + "/bin/bamsort")
      .addArgument("inputformat=sam level=1 inputthreads=2 outputthreads=2")
      .addArgument("calmdnm=1 calmdnmrecompindetonly=1 calmdnmreference=" + reference_path)
      .addArgument("tmpfile=unmapped1.sorttmp").addArgument("O=unmappedReads1.bam");

    unmappedReadsJob1.setMaxMemory(unmappedReadsJobMemM);
    unmappedReadsJob1.addParent(job04);

    unmappedReadsJob2 = this.getWorkflow().createBashJob("unmappedReads2");
    unmappedReadsJob2
      .getCommand()
      .addArgument(this.getWorkflowBaseDir() + pcapPath
                   + "/bin/samtools view -h -f 8 " // reads' mate unmapped
                   + this.dataDir + outputFileName + " | perl " + this.getWorkflowBaseDir()
                   + "/scripts/remove_both_ends_unmapped_reads.pl ")
      // this is necessary because samtools -f 8 outputs both-ends-unmapped reads
      .addArgument("| LD_LIBRARY_PATH=" + this.getWorkflowBaseDir() + pcapPath + "/lib ")
      .addArgument(this.getWorkflowBaseDir() + pcapPath + "/bin/bamsort")
      .addArgument("inputformat=sam level=1 inputthreads=2 outputthreads=2")
      .addArgument("calmdnm=1 calmdnmrecompindetonly=1 calmdnmreference=" + reference_path)
      .addArgument("tmpfile=unmapped2.sorttmp").addArgument("O=unmappedReads2.bam");

    unmappedReadsJob2.setMaxMemory(unmappedReadsJobMemM);
    unmappedReadsJob2.addParent(job04);

    unmappedReadsJob3 = this.getWorkflow().createBashJob("unmappedReads3");
    // reads with both ends unmapped, no need to sort at all
    unmappedReadsJob3.getCommand().addArgument(this.getWorkflowBaseDir() + pcapPath + "/bin/samtools view -h -b -f 12 " 
                                               + this.dataDir + outputFileName + " > unmappedReads3.bam");
    unmappedReadsJob3.setMaxMemory(unmappedReadsJobMemM);
    unmappedReadsJob3.addParent(job04);

    // MERGE unmapped reads
    Job mergeUnmappedJob = this.getWorkflow().createBashJob("mergeUnmappedBAM");

    mergeUnmappedJob.getCommand().addArgument("LD_LIBRARY_PATH=" + this.getWorkflowBaseDir() + pcapPath + "/lib")
      .addArgument(this.getWorkflowBaseDir() + pcapPath + "/bin/bammarkduplicates")
      .addArgument("O=" + this.dataDir + outputUnmappedFileName)
      .addArgument("M=" + this.dataDir + outputUnmappedFileName + ".metrics")
      .addArgument("tmpfile=" + this.dataDir + outputUnmappedFileName + ".biormdup").addArgument("markthreads=" + numOfThreads)
      .addArgument("rewritebam=1 rewritebamlevel=1 index=1 md5=1")
      .addArgument("I=unmappedReads1.bam I=unmappedReads2.bam I=unmappedReads3.bam");

    // now compute md5sum for the bai file
    mergeUnmappedJob.getCommand().addArgument(" && md5sum " + this.dataDir + outputUnmappedFileName + ".bai | awk '{printf $1}'" 
                                              + " > " + this.dataDir
                                              + outputUnmappedFileName + ".bai.md5");

    mergeUnmappedJob.addParent(unmappedReadsJob1);
    mergeUnmappedJob.addParent(unmappedReadsJob2);
    mergeUnmappedJob.addParent(unmappedReadsJob3);
    mergeUnmappedJob.setMaxMemory(unmappedReadsJobMemM);

    // CLEANUP LANE LEVEL BAM FILES
    if (cleanup) {
      for (int i = 0; i < numBamFiles; i++) {
        Job cleanup2 = this.getWorkflow().createBashJob("cleanup3_" + i);
        cleanup2.getCommand().addArgument("rm -f out_" + i + ".bam");
        cleanup2.addParent(job04);
        cleanup2.setMaxMemory(smallJobMemM);
        cleanup2.addParent(qcJobs.get(i));
      }
    }

    // PREPARE METADATA & UPLOAD
    String finalOutDir = this.dataDir;
    if (!useGtUpload) {
      finalOutDir = this.resultsDir;
    }
    Job job05 = this.getWorkflow().createBashJob("upload");
    // if we are using a GNOS repo, we can use the gt-download-upload-wrapper.
    if (useGNOS) {
      job05.getCommand().addArgument("perl -I" + this.getWorkflowBaseDir() + "/bin/gt-download-upload-wrapper-" 
                                     + gtDownloadWrapperVersion + "/lib " + this.getWorkflowBaseDir() 
                                     + "/scripts/gnos_upload_data.pl")
        .addArgument("--bam " + this.dataDir + outputFileName).addArgument("--key " + gnosKey)
        .addArgument("--outdir " + finalOutDir).addArgument("--metadata-urls " + gnosInputMetadataURLs)
        .addArgument("--upload-url " + gnosUploadFileURL).addArgument("--study-refname-override " + studyRefnameOverride)
        .addArgument("--bam-md5sum-file " + this.dataDir + outputFileName + ".md5");          
      if ("true".equals(skipUpload) || !useGtUpload) {
        job05.getCommand().addArgument("--force-copy");
        job05.getCommand().addArgument("--skip-upload");
      }
      if (!useGtValidation) {
        job05.getCommand().addArgument("--skip-validate");
      }
      job05.setMaxMemory(uploadScriptJobMem + "900");
    }
    else if (this.gnosUploadFileURL.startsWith("s3://")) // Using AWS S3
      {
        // TODO: Should we include settings for --acl (access control list) or --grants to allow uploaded files to be public?
        // TODO: also, what about --sse for sever-side encryption?
        job05.getCommand().addArgument("export AWS_CONFIG_FILE=/home/ubuntu/.gnos/config && aws s3 cp " 
                                       + this.dataDir + this.outputFileName + " " + this.gnosUploadFileURL 
                                       + this.outputFileName+ " --expected-size  $(stat --printf=\"%s\" " 
                                       + this.dataDir +this.outputFileName+")");
      }
        
    job05.addParent(job04);
    for (Job qcJob : qcJobs) {
      job05.addParent(qcJob);
    }
        
    Job job06 = this.getWorkflow().createBashJob("upload2");
        
    if (useGNOS)
      {
        job06.getCommand().addArgument("perl -I" + this.getWorkflowBaseDir() + "/bin/gt-download-upload-wrapper-" 
                                       + gtDownloadWrapperVersion + "/lib " + this.getWorkflowBaseDir() 
                                       + "/scripts/gnos_upload_data.pl --unmapped-reads-upload ")
          .addArgument("--bam " + this.dataDir + outputUnmappedFileName).addArgument("--key " + gnosKey)
          .addArgument("--outdir " + finalOutDir).addArgument("--metadata-urls " + gnosInputMetadataURLs)
          .addArgument("--upload-url " + gnosUploadFileURL).addArgument("--study-refname-override " + studyRefnameOverride)
          .addArgument("--bam-md5sum-file " + this.dataDir + outputUnmappedFileName + ".md5");
        if ("true".equals(skipUpload) || !useGtUpload) {
          job06.getCommand().addArgument("--force-copy");
          job06.getCommand().addArgument("--skip-upload");
        }
        if (!useGtValidation) {
          job06.getCommand().addArgument("--skip-validate");
        }
        job06.setMaxMemory(uploadScriptJobMem + "900");
      }
    else if(this.gnosUploadFileURL.startsWith("s3://")) // Using AWS S3
      {
        // TODO: Should we include settings for --acl (access control list) or --grants to allow uploaded files to be public?
        // TODO: also, what about --sse for sever-side encryption?
        job06.getCommand().addArgument("export AWS_CONFIG_FILE=/home/ubuntu/.gnos/config && aws s3 cp " 
                                       + this.dataDir + this.outputUnmappedFileName + " "+this.gnosUploadFileURL 
                                       + this.outputUnmappedFileName + " --expected-size  $(stat --printf=\"%s\" " 
                                       + this.dataDir +this.outputUnmappedFileName+")");
      }
    job06.addParent(mergeUnmappedJob);

    // CLEANUP FINAL BAM
    if (cleanup) {
      Job cleanup3 = this.getWorkflow().createBashJob("cleanup3");
      cleanup3.getCommand().addArgument("rm -f *.bam " + this.dataDir + outputFileName + " " 
                                        + this.dataDir + outputUnmappedFileName);
      cleanup3.addParent(job05);
      cleanup3.addParent(job06);
      for (Job qcJob : qcJobs) {
        cleanup3.addParent(qcJob);
      }
      cleanup3.setMaxMemory(smallJobMemM);
    }

  }

  public String parameters(final String setup) {

    String paramCommand = null;
    StringBuilder a = new StringBuilder();

    try {
      if (setup.equals("aln")) {

        if (!getProperty("numOfThreads").isEmpty()) {
          numOfThreads = Integer.parseInt(getProperty("numOfThreads"));
          a.append(" -t ");
          a.append(numOfThreads);
          a.append(" ");
        }

        if (!getProperty("bwa_aln_params").isEmpty()) {
          bwa_aln_params = getProperty("bwa_aln_params");
          a.append(" ");
          a.append(bwa_aln_params);
          a.append(" ");
        }
        paramCommand = a.toString();
        return paramCommand;
      }

      if (setup.equals("mem")) {

        if (!getProperty("numOfThreads").isEmpty()) {
          numOfThreads = Integer.parseInt(getProperty("numOfThreads"));
          a.append(" -t ");
          a.append(numOfThreads);
          a.append(" ");
        }

        if (!getProperty("bwa_mem_params").isEmpty()) {
          bwa_aln_params = getProperty("bwa_mem_params");
          a.append(" ");
          a.append(bwa_aln_params);
          a.append(" ");
        }
        paramCommand = a.toString();
        return paramCommand;
      }

      if (setup.equals("sampe")) {

        if (!getProperty("maxInsertSize").isEmpty()) {
          maxInsertSize = Integer.parseInt(getProperty("maxInsertSize"));
          a.append(" -a ");
          a.append(maxInsertSize);
          a.append(" ");
        }

        if (!getProperty("readGroup").isEmpty()) {
          a.append(" -r ");
          a.append(readGroup);
          a.append(" ");
        }

        if (!getProperty("bwa_sampe_params").isEmpty()) {
          bwa_sampe_params = getProperty("bwa_sampe_params");
          a.append(" ");
          a.append(bwa_sampe_params);
          a.append(" ");
        }
        paramCommand = a.toString();
        return paramCommand;
      }

    } catch (Exception e) {
      Logger.getLogger(WorkflowClient.class.getName()).log(Level.SEVERE, null, e);
      throw new RuntimeException("Param Parsing exception " + e.getMessage());
    }
    return paramCommand;
  }

  private Job addDownloadJobArgs(Job job, String file, String fileURL, int jobId, String wrapperType) {

    // a little unsafe
    String[] pathElements = file.split("/");
    String analysisId = pathElements[0];

    if ("file_based".equals(wrapperType)) {
      job.getCommand()
        .addArgument("set -e; set -o pipefail; date +%s > download_timing_" + jobId + ".txt;")
        .addArgument("perl -I " + this.getWorkflowBaseDir() + "/bin/gt-download-upload-wrapper-"+ gtDownloadWrapperVersion 
                     + "/lib " + this.getWorkflowBaseDir() + "/scripts/gnos_download_file.pl")
        .addArgument(" -k 60") 
        .addArgument(" --pem "+ gnosKey)
        .addArgument(" --url " + fileURL)
        .addArgument(" --file " + file )
        .addArgument(" --retries " + gtdownloadRetries  + " --sleep-min 1 --timeout-min 60;")
        .addArgument("date +%s >> download_timing_" + jobId + ".txt");
    } else {
      job.getCommand()
        .addArgument("set -e; set -o pipefail; date +%s > download_timing_" + jobId + ".txt;")
        .addArgument("perl " + this.getWorkflowBaseDir() + "/scripts/launch_and_monitor_cmd.pl")
        .addArgument(" --command 'gtdownload " + " --max-children " + gnosMaxChildren + " --rate-limit " + gnosRateLimit
                     + " --inactivity-timeout " + gnosTimeout + " -c " + gnosKey + " -v -d " + fileURL + "'")
        .addArgument("--retries " + gtdownloadRetries + " ;").addArgument("date +%s >> download_timing_" + jobId + ".txt");
    }

    return job;
  }

  private Job addBamStatsQcJobArgument(final int i, Job job) {

    job.getCommand()
      .addArgument("set -e; set -o pipefail; date +%s > qc_timing_" + i + ".txt;")
      .addArgument("perl -I " + this.getWorkflowBaseDir() + pcapPath + "/lib/perl5/")
      .addArgument("-I " + this.getWorkflowBaseDir() + pcapPath + "/lib/perl5/x86_64-linux-gnu-thread-multi/")
      .addArgument(this.getWorkflowBaseDir() + pcapPath + "/bin/bam_stats.pl")
      .addArgument("-i " + "out_" + i + ".bam")
      .addArgument("-o " + "out_" + i + ".bam.stats.txt")
      .addArgument("&& perl " + this.getWorkflowBaseDir() + "/scripts/verify_read_groups.pl --header-file bam_header." + i + ".txt"
                   + " --bas-file out_" + i + ".bam.stats.txt" + " --input-read-count-file input_bam_" + i + ".count.txt")
      .addArgument("&& date +%s >> qc_timing_" + i + ".txt");

    return job;
  }
}
