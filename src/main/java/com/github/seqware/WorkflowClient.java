package com.github.seqware;

/**
 * Mine
 */
import ca.on.oicr.pde.utilities.workflows.OicrWorkflow;
import java.util.ArrayList;
import java.util.Map;
import java.util.logging.Level;
import java.util.logging.Logger;
import net.sourceforge.seqware.pipeline.workflowV2.model.Job;
import net.sourceforge.seqware.pipeline.workflowV2.model.SqwFile;

public class WorkflowClient extends OicrWorkflow {

  // GENERAL
  // comma-seperated for multiple bam inputs
  String inputBamPaths = null;
  ArrayList<String> bamPaths = new ArrayList<String>();
  ArrayList<String> inputURLs = new ArrayList<String>();
  ArrayList<String> inputMetadataURLs = new ArrayList<String>();
  String bwaChoice = "aln"; //can be "aln" or "mem"
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
  // number of splits for bam files, default 1=no split
  int bamSplits = 1;
  String reference_path = null;
  String dataDir = "data/";
  String outputDir = "results";
  String outputPrefix = "./";
  String resultsDir = outputPrefix + outputDir;
  String outputFileName = "merged_output.bam";
  //BWA
  String bwaAlignMemG = "8";
  String bwaSampeMemG = "8";
  String bwaSampeSortSamMemG = "8";
  String additionalPicardParams;
  String picardSortMem = "6";
  String picardSortJobMem = "8";
  String uploadScriptJobMem = "2";
  int numOfThreads; //aln
  int maxInsertSize; //sampe
  String readGroup;//sampe
  String bwa_aln_params;
  String bwa_sampe_params;
  String skipUpload = null;
  String pcapPath = "/bin/PCAP-core-1.1.1";
  // GTDownload
  // each retry is 1 minute
  String gtdownloadRetries = "30";
  String gtdownloadMd5Time = "120";
  String gtdownloadMem = "8";
  String smallJobMemM = "4000";

  @Override
  public Map<String, SqwFile> setupFiles() {

    /*
     This workflow isn't using file provisioning since
     we're using GeneTorrent. So this method is just being
     used to setup various variables.
     */
    try {

      inputBamPaths = getProperty("input_bam_paths");
      for (String path : inputBamPaths.split(",")) {
        bamPaths.add(path);
      }
      gnosInputFileURLs = getProperty("gnos_input_file_urls");
      for (String url : gnosInputFileURLs.split(",")) {
        inputURLs.add(url);
      }
      gnosInputMetadataURLs = getProperty("gnos_input_metadata_urls");
      for (String url : gnosInputMetadataURLs.split(",")) {
        inputMetadataURLs.add(url);
      }
      outputDir = this.getMetadata_output_dir();
      outputPrefix = this.getMetadata_output_file_prefix();
      resultsDir = outputPrefix + outputDir;
      gnosUploadFileURL = getProperty("gnos_output_file_url");
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
      gtdownloadMd5Time = getProperty("gtdownloadMd5time") == null ? "120" : getProperty("gtdownloadMd5time");
      gtdownloadMem = getProperty("gtdownloadMemG") == null ? "8" : getProperty("gtdownloadMemG");
      smallJobMemM = getProperty("smallJobMemM") == null ? "3000" : getProperty("smallJobMemM");
      if (getProperty("use_gtdownload") != null) { if("false".equals(getProperty("use_gtdownload"))) { useGtDownload = false; } }
      if (getProperty("use_gtupload") != null) { if("false".equals(getProperty("use_gtupload"))) { useGtUpload = false; } }
      if (getProperty("use_gtvalidation") != null) { if("false".equals(getProperty("use_gtvalidation"))) { useGtValidation = false; } }

    } catch (Exception e) {
      Logger.getLogger(WorkflowClient.class.getName()).log(Level.SEVERE, null, e);
      throw new RuntimeException("Problem parsing variable values: "+e.getMessage());
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
    ArrayList<Job> bamJobs = new ArrayList<Job>();
    ArrayList<Job> qcJobs = new ArrayList<Job>();

    // DOWNLOAD DATA
    // let's start by downloading the input BAMs
    int numInputURLs = this.inputURLs.size();
    for (int i = 0; i < numInputURLs; i++) {

      // the file downloaded will be in this path
      String file = bamPaths.get(i);
      // the URL to download this from
      String fileURL = inputURLs.get(i);

    /* Job job05 = this.getWorkflow().createBashJob("upload");
    job05.getCommand().addArgument(""
      + "synapse -u <uSERNAME > -p <PASSWORD> -parentId add " + fileURL + " > " + file +".synapse" ); */

      // the download job that either downloads or locates the file on the filesystem
      Job downloadJob = null;
      if (useGtDownload) {
        downloadJob = this.getWorkflow().createBashJob("gtdownload");
        addDownloadJobArgs(downloadJob, file, fileURL);
        downloadJob.setMaxMemory( gtdownloadMem + "000");
      }

      // in the future this should use the read group if provided otherwise use read group from bam file
      Job headerJob = this.getWorkflow().createBashJob("headerJob" + i);
      
      // Empty PI in @RG causes downstream analysis fail at BI, see https://jira.oicr.on.ca/browse/PANCANCER-32
      // The quick fix is to detect that and drop the empty PI in the header, one liner Perl is used (replacing previous sed)
      headerJob.getCommand().addArgument("set -e; set -o pipefail; " + this.getWorkflowBaseDir() + pcapPath +  "/bin/samtools view -H " + file 
    		  + " | perl -nae 'next unless /^\\@RG/; s/\\tPI:\\s*\\t/\\t/; s/\\tPI:\\s*\\z/\\n/; s/\\t/\\\\t/g; print' > bam_header." + i + ".txt");
      if (useGtDownload) { headerJob.addParent(downloadJob); }
      headerJob.setMaxMemory(smallJobMemM);

      // the QC job used by either path below
      Job qcJob = null;

      if ("aln".equals(bwaChoice)) {

        // BWA ALN STEPS
        //bwa aln   -t 8 -b1 ./reference/genome.fa.gz ./HG00096.chrom20.ILLUMINA.bwa.GBR.low_coverage.20120522.bam_000000.bam > aligned_1.sai 2> aligned_1.err
        //bwa aln   -t 8 -b2 ./reference/genome.fa.gz ./HG00096.chrom20.ILLUMINA.bwa.GBR.low_coverage.20120522.bam_000000.bam > aligned_2.sai 2> aligned_2.err
        Job job01 = this.getWorkflow().createBashJob("bwa_align1_" + i);
        job01.addParent(headerJob);
        job01.getCommand().addArgument(this.getWorkflowBaseDir() + "/bin/bwa-0.6.2/bwa aln ")
                .addArgument(this.parameters("aln") == null ? " " : this.parameters("aln"))
                .addArgument(reference_path + " -b1 ")
                .addArgument(file)
                .addArgument(" > aligned_" + i + "_1.sai");
        job01.setMaxMemory(bwaAlignMemG + "900");
        /*if (!getProperty("numOfThreads").isEmpty()) {
          job01.setThreads(Integer.parseInt(getProperty("numOfThreads")));
        }*/

        Job job02 = this.getWorkflow().createBashJob("bwa_align2_" + i);
        job02.addParent(headerJob);
        job02.getCommand().addArgument(this.getWorkflowBaseDir() + "/bin/bwa-0.6.2/bwa aln ")
                .addArgument(this.parameters("aln") == null ? " " : this.parameters("aln"))
                .addArgument(reference_path + " -b2 ")
                .addArgument(file)
                .addArgument(" > aligned_" + i + "_2.sai");
        job02.setMaxMemory(bwaAlignMemG + "900");
        /*if (!getProperty("numOfThreads").isEmpty()) {
          job02.setThreads(Integer.parseInt(getProperty("numOfThreads")));
        }*/

        // BWA SAMPE + CONVERT TO BAM
        //bwa sampe reference/genome.fa.gz aligned_1.sai aligned_2.sai HG00096.chrom20.ILLUMINA.bwa.GBR.low_coverage.20120522.bam_000000.bam HG00096.chrom20.ILLUMINA.bwa.GBR.low_coverage.20120522.bam_000000.bam > aligned.sam
        Job job03 = this.getWorkflow().createBashJob("bwa_sam_bam_" + i);
        job03.getCommand()
                .addArgument("set -e; set -o pipefail;")
                .addArgument(this.getWorkflowBaseDir() + "/bin/bwa-0.6.2/bwa sampe ")
                .addArgument("-r \"`cat bam_header." + i + ".txt`\"")
                .addArgument(this.parameters("sampe").isEmpty() ? " " : this.parameters("sampe"))
                .addArgument(reference_path)
                .addArgument("aligned_" + i + "_1.sai")
                .addArgument("aligned_" + i + "_2.sai")
                .addArgument(file)
                .addArgument(file)
                .addArgument(" | java -Xmx" + bwaSampeSortSamMemG + "g -jar ")
                .addArgument(this.getWorkflowBaseDir() + "/bin/picard-tools-1.89/SortSam.jar")
                .addArgument("I=/dev/stdin TMP_DIR=./ VALIDATION_STRINGENCY=SILENT")
                .addArgument("SORT_ORDER=coordinate CREATE_INDEX=true")
                .addArgument("O=out_" + i + ".bam");
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
        if (useGtDownload) {
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
                .addArgument("set -e; set -o pipefail;")
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
                .addArgument(" |perl -ne '$_ =~ s|@[01](/[12])$|\\1| if($. % 4 == 1); print $_;'")
                .addArgument(" | LD_LIBRARY_PATH=" + this.getWorkflowBaseDir() + pcapPath + "/lib")
                .addArgument(this.getWorkflowBaseDir() + pcapPath + "/bin/bwa mem")
                // this pulls in threads and extra params
                .addArgument(this.parameters("mem") == null ? " " : this.parameters("mem"))
                .addArgument("-p -T 0")
                .addArgument("-R \"`cat bam_header." + i + ".txt`\"")
                .addArgument(reference_path)
                .addArgument("-")
                .addArgument("| LD_LIBRARY_PATH=" + this.getWorkflowBaseDir() + pcapPath + "/lib ")
                .addArgument(this.getWorkflowBaseDir() + pcapPath + "/bin/bamsort")
                .addArgument("inputformat=sam level=1 inputthreads=2 outputthreads=2")
                .addArgument("calmdnm=1 calmdnmrecompindetonly=1 calmdnmreference=" + reference_path)
                .addArgument("tmpfile=out_" + i + ".sorttmp")
                .addArgument("O=out_" + i + ".bam");
        job01.setMaxMemory(bwaAlignMemG + "900");
        /*if (!getProperty("numOfThreads").isEmpty()) {
          job01.setThreads(Integer.parseInt(getProperty("numOfThreads")));
        }*/
        bamJobs.add(job01);

        // QC JOB
        qcJob = this.getWorkflow().createBashJob("bam_stats_qc_" + i);
        addBamStatsQcJobArgument(i, qcJob);
        qcJob.addParent(job01);
        qcJob.setMaxMemory(smallJobMemM);
        qcJobs.add(qcJob);

        // CLEANUP DOWNLOADED INPUT UNALIGNED BAM FILES
        if (useGtDownload) {
          Job cleanup1 = this.getWorkflow().createBashJob("cleanup2_" + i);
          cleanup1.getCommand().addArgument("rm -f " + file);
          cleanup1.setMaxMemory(smallJobMemM);
          cleanup1.addParent(job01);
        }

      } else {
        // not sure if there's a better way to do this
        throw new RuntimeException("Don't understand a bwa choice of " + bwaChoice + " needs to be aln or mem");
      }

    }

    // MERGE
    Job job04 = this.getWorkflow().createBashJob("mergeBAM");

    if ("aln".equals(bwaChoice)) {

      job04.getCommand().addArgument("java -Xmx" + picardSortMem + "g -jar "
              + this.getWorkflowBaseDir() + "/bin/picard-tools-1.89/MergeSamFiles.jar "
              + " " + (additionalPicardParams.isEmpty() ? "" : additionalPicardParams));
      for (int i = 0; i < numBamFiles; i++) {
        job04.getCommand().addArgument(" I=out_" + i + ".bam");
      }
      job04.getCommand().addArgument(" O=" + this.dataDir + outputFileName)
              .addArgument("SORT_ORDER=coordinate VALIDATION_STRINGENCY=SILENT CREATE_INDEX=true CREATE_MD5_FILE=true");
      //" >> "+this.dataDir+outputFileName + ".out 2>> "+this.dataDir+outputFileName +".err");
      for (Job pJob : bamJobs) {
        job04.addParent(pJob);
      }
      job04.setMaxMemory(picardSortJobMem + "900");

    } else if ("mem".equals(bwaChoice)) {

      int numThreads = 1;
      if (!getProperty("numOfThreads").isEmpty()) {
        numThreads = Integer.parseInt(getProperty("numOfThreads"));
      }
      job04.getCommand().addArgument("LD_LIBRARY_PATH=" + this.getWorkflowBaseDir() + pcapPath + "/lib")
              .addArgument(this.getWorkflowBaseDir() + pcapPath + "/bin/bammarkduplicates")
              .addArgument("O=" + this.dataDir + outputFileName)
              .addArgument("M=" + this.dataDir + outputFileName + ".metrics")
              .addArgument("tmpfile=" + this.dataDir + outputFileName + ".biormdup")
              .addArgument("markthreads=" + numThreads)
              .addArgument("rewritebam=1 rewritebamlevel=1 index=1 md5=1");
      for (int i = 0; i < numBamFiles; i++) {
        job04.getCommand().addArgument(" I=out_" + i + ".bam");
      }
      for (Job pJob : bamJobs) {
        job04.addParent(pJob);
      }
      /* if (!getProperty("numOfThreads").isEmpty()) {
        job04.setThreads(Integer.parseInt(getProperty("numOfThreads")));
      }*/

      // now compute md5sum for the bai file
      job04.getCommand().addArgument(" && md5sum " + this.dataDir + outputFileName + ".bai | awk '{printf $1}'"
          + " > " + this.dataDir + outputFileName + ".bai.md5");

      job04.setMaxMemory(picardSortJobMem + "900");

    }

    // CLEANUP LANE LEVEL BAM FILES
    for (int i = 0; i < numBamFiles; i++) {
      Job cleanup2 = this.getWorkflow().createBashJob("cleanup3_" + i);
      cleanup2.getCommand().addArgument("rm -f out_" + i + ".bam");
      cleanup2.addParent(job04);
      cleanup2.setMaxMemory(smallJobMemM);
      cleanup2.addParent(qcJobs.get(i));
    }

    // PREPARE METADATA & UPLOAD
    String finalOutDir = this.dataDir;
    if (!useGtUpload) { finalOutDir = this.resultsDir; }
    Job job05 = this.getWorkflow().createBashJob("upload");
    job05.getCommand().addArgument("perl " + this.getWorkflowBaseDir() + "/scripts/gnos_upload_data.pl")
            .addArgument("--bam " + this.dataDir + outputFileName)
            .addArgument("--key " + gnosKey)
            .addArgument("--outdir " + finalOutDir)
            .addArgument("--metadata-urls " + gnosInputMetadataURLs)
            .addArgument("--upload-url " + gnosUploadFileURL)
            .addArgument("--bam-md5sum-file " + this.dataDir + outputFileName + ".md5");
    if (!useGtUpload) {
      job05.getCommand().addArgument("--force-copy");
    }
    if ("true".equals(skipUpload) || !useGtUpload) {
      job05.getCommand().addArgument("--test");
    }
    if (!useGtValidation) {
      job05.getCommand().addArgument("--skip-validate");
    }
    job05.setMaxMemory(uploadScriptJobMem + "900");
    job05.addParent(job04);
    for (Job qcJob : qcJobs) {
      job05.addParent(qcJob);
    }

    /* Job job05 = this.getWorkflow().createBashJob("upload");
    job05.getCommand().addArgument(""
     for (int i = 0; i < numBamFiles; i++) {
        job04.getCommand().addArgument(" I=out_" + i + ".bam");
      }
     */

    // CLEANUP FINAL BAM
    Job cleanup3 = this.getWorkflow().createBashJob("cleanup4");
    cleanup3.getCommand().addArgument("rm -f " + this.dataDir + outputFileName);
    cleanup3.addParent(job05);
    cleanup3.setMaxMemory(smallJobMemM);
    for (Job qcJob : qcJobs) {
      cleanup3.addParent(qcJob);
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

  private Job addDownloadJobArgs (Job job, String file, String fileURL) {

    // a little unsafe
    String[] pathElements = file.split("/");
    String analysisId = pathElements[0];

    job.getCommand().addArgument("perl " + this.getWorkflowBaseDir() + "/scripts/launch_and_monitor_gnos.pl")
    .addArgument("--command 'gtdownload "
               + " --max-children " + gnosMaxChildren
               + " --rate-limit " + gnosRateLimit
               + " --inactivity-timeout " + gnosTimeout
               + " -c " + gnosKey
               + " -v -d "+fileURL+"'")
    .addArgument("--file-grep "+analysisId)
    .addArgument("--search-path .")
    .addArgument("--retries "+gtdownloadRetries)
    .addArgument("--md5-retries "+gtdownloadMd5Time);

    return(job);
  }

  private Job addBamStatsQcJobArgument (final int i, Job job) {

	job.getCommand().addArgument("perl -I " + this.getWorkflowBaseDir() + pcapPath + "/lib/perl5/")
                    .addArgument("-I " + this.getWorkflowBaseDir() + pcapPath + "/lib/perl5/x86_64-linux-gnu-thread-multi/")
                    .addArgument(this.getWorkflowBaseDir() + pcapPath + "/bin/bam_stats.pl")
                    .addArgument("-i " + "out_" + i + ".bam")
                    .addArgument("-o " + "out_" + i + ".bam.stats.txt")
                    .addArgument("&& perl " + this.getWorkflowBaseDir() + "/scripts/verify_read_groups.pl --header-file bam_header." + i + ".txt" 
                    + " --bas-file out_" + i + ".bam.stats.txt")
                    ;

	return job;
  }
}
