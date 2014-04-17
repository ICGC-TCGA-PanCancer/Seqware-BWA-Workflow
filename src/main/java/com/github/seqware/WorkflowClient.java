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
  // number of splits for bam files, default 1=no split
  int bamSplits = 1;
  String reference_path = null;
  String outputPrefix = null;
  String outputDir = null;
  String dataDir = "data/";
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
      gnosUploadFileURL = getProperty("gnos_output_file_url");
      gnosKey = getProperty("gnos_key");
      reference_path = getProperty("input_reference");
      outputDir = this.getMetadata_output_dir();
      outputPrefix = this.getMetadata_output_file_prefix();
      bwaChoice = getProperty("bwa_choice") == null ? "aln" : getProperty("bwa_choice");
      bwaAlignMemG = getProperty("bwaAlignMemG") == null ? "8" : getProperty("bwaAlignMemG");
      bwaSampeMemG = getProperty("bwaSampeMemG") == null ? "8" : getProperty("bwaSampeMemG");
      bwaSampeSortSamMemG = getProperty("bwaSampeSortSamMemG") == null ? "4" : getProperty("bwaSampeSortSamMemG");
      picardSortMem = getProperty("picardSortMem") == null ? "6" : getProperty("picardSortMem");
      picardSortJobMem = getProperty("picardSortJobMem") == null ? "8" : getProperty("picardSortJobMem");
      uploadScriptJobMem = getProperty("uploadScriptJobMem") == null ? "2" : getProperty("uploadScriptJobMem");
      additionalPicardParams = getProperty("additionalPicardParams");
      skipUpload = getProperty("skip_upload") == null ? "true" : getProperty("skip_upload");

    } catch (Exception e) {
      Logger.getLogger(WorkflowClient.class.getName()).log(Level.SEVERE, null, e);
      System.exit(1);
    }

    return this.getFiles();
  }

  @Override
  public void setupDirectory() {
    // creates the final output 
    this.addDirectory(dataDir);
  }

  @Override
  public void buildWorkflow() {

    ArrayList<Job> downloadJobs = new ArrayList<Job>();
    ArrayList<Job> bamJobs = new ArrayList<Job>();

    // DOWNLOAD DATA
    // let's start by downloading the input BAMs
    int numInputURLs = this.inputURLs.size();
    for (int i = 0; i < numInputURLs; i++) {
      Job gtDownloadJob = this.getWorkflow().createBashJob("gtdownload");
      gtDownloadJob.getCommand().addArgument("gtdownload")
              .addArgument("-c " + gnosKey)
              .addArgument("-v -d")
              .addArgument(this.inputURLs.get(i));
      downloadJobs.add(gtDownloadJob);
    }

    // TODO for loop here
    int numBamFiles = bamPaths.size();
    for (int i = 0; i < numBamFiles; i++) {

      String file = bamPaths.get(i);

      // in the future this should use the read group if provided otherwise use read group from bam file
      Job headerJob = this.getWorkflow().createBashJob("headerJob" + i);
      headerJob.getCommand().addArgument("samtools view -H " + file + " | grep @RG | sed 's/\\t/\\\\t/g' > bam_header." + i + ".txt");
      for (Job gtDownloadJob : downloadJobs) {
        headerJob.addParent(gtDownloadJob);
      }

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
        job03.getCommand().addArgument(this.getWorkflowBaseDir() + "/bin/bwa-0.6.2/bwa sampe ")
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
        
        Job qcJob = this.getWorkflow().createBashJob("bam_stats_qc_" + i);
        qcJob = addBamStatsQcJobArgument(i, qcJob);
        qcJob.addParent(job03);

      } else if ("mem".equals(bwaChoice)) {

        // BWA MEM
        Job job01 = this.getWorkflow().createBashJob("bwa_mem_" + i);
        job01.addParent(headerJob);
        job01.getCommand().addArgument("LD_LIBRARY_PATH=" + this.getWorkflowBaseDir() + "/bin/PCAP-core_20140312/lib") 
                .addArgument(this.getWorkflowBaseDir() + "/bin/PCAP-core_20140312/bin/bamtofastq")
                .addArgument("exclude=QCFAIL,SECONDARY,SUPPLEMENTARY")
                .addArgument("T=out_" + i + ".t")
                .addArgument("S=out_" + i + ".s")
                .addArgument("O=out_" + i + ".o")
                .addArgument("O2=out_" + i + ".o2")
                .addArgument("collate=1")
                .addArgument("filename=" + file + " | LD_LIBRARY_PATH=" + this.getWorkflowBaseDir() + "/bin/PCAP-core_20140312/lib")
                .addArgument(this.getWorkflowBaseDir() + "/bin/PCAP-core_20140312/bin/bwa mem")
                // this pulls in threads and extra params
                .addArgument(this.parameters("mem") == null ? " " : this.parameters("mem"))
                .addArgument("-p -T 0")
                .addArgument("-R \"`cat bam_header." + i + ".txt`\"")
                .addArgument(reference_path)
                .addArgument("-")
                .addArgument("| LD_LIBRARY_PATH=" + this.getWorkflowBaseDir() + "/bin/PCAP-core_20140312/lib ")
                .addArgument(this.getWorkflowBaseDir() + "/bin/PCAP-core_20140312/bin/bamsort")
                .addArgument("inputformat=sam level=1 inputthreads=2 outputthreads=2")
                .addArgument("tmpfile=out_" + i + ".sorttmp")
                .addArgument("O=out_" + i + ".bam");
        job01.setMaxMemory(bwaAlignMemG + "900");
        /*if (!getProperty("numOfThreads").isEmpty()) {
          job01.setThreads(Integer.parseInt(getProperty("numOfThreads")));
        }*/
        bamJobs.add(job01);
        
        Job qcJob = this.getWorkflow().createBashJob("bam_stats_qc_" + i);
        qcJob = addBamStatsQcJobArgument(i, qcJob);
        qcJob.addParent(job01);

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
      job04.getCommand().addArgument("LD_LIBRARY_PATH=" + this.getWorkflowBaseDir() + "/bin/PCAP-core_20140312/lib") 
              .addArgument(this.getWorkflowBaseDir() + "/bin/PCAP-core_20140312/bin/bammarkduplicates")
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
      job04.setMaxMemory(picardSortJobMem + "900");
      
    }

    // PREPARE METADATA & UPLOAD
    Job job05 = this.getWorkflow().createBashJob("upload");
    job05.getCommand().addArgument("perl " + this.getWorkflowBaseDir() + "/scripts/gnos_upload_data.pl")
            .addArgument("--bam " + this.dataDir + outputFileName)
            .addArgument("--key " + gnosKey)
            .addArgument("--outdir " + this.dataDir)
            .addArgument("--metadata-urls " + gnosInputMetadataURLs)
            .addArgument("--upload-url " + gnosUploadFileURL)
            .addArgument("--bam-md5sum-file " + this.dataDir + outputFileName + ".md5");
    if ("true".equals(skipUpload)) {
      job05.getCommand().addArgument("--test");
    }
    job05.setMaxMemory(uploadScriptJobMem + "900");
    job05.addParent(job04);

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
    }
    return paramCommand;
  }
  
  private Job addBamStatsQcJobArgument (final int i, Job job) {
	  
	job.getCommand().addArgument(this.getWorkflowBaseDir() + "/bin/PCAP-core_0.3.0/bin/bam_stats.pl")
	                .addArgument("-i " + "out_" + i + "bam")
	                .addArgument("-o " + "out_" + i + "bam.stats.txt");
	  
	return job;  
  }
}
