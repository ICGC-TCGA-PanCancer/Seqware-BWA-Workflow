package com.github.seqware;

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
    // used to download with gtdownload
    String gnosInputFileURL = null;
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
    String RGID;
    String RGLB;
    String RGPL;
    String RGPU;
    String RGSM;
    String additionalPicardParams;
    String picardReadGrpMem = "8";
    int readTrimming; //aln
    int numOfThreads; //aln 
    int pairingAccuracy; //aln
    int maxInsertSize; //sampe
    String readGroup;//sampe
    String bwa_aln_params;
    String bwa_sampe_params;
    
    @Override
    public Map<String, SqwFile> setupFiles() {

        /*
        This workflow isn't using file provisioning since 
        we're using GeneTorrent. So this method is just being
        used to setup various variables.
        */
        
        try {
            
            inputBamPaths = getProperty("input_bam_paths");
            for(String path : inputBamPaths.split(",")) {
                bamPaths.add(path);
            }
            gnosInputFileURL = getProperty("gnos_input_file_url");
            gnosUploadFileURL = getProperty("gnos_output_file_url");
            gnosKey = getProperty("gnos_key");
            reference_path = getProperty("input_reference");
            outputDir = this.getMetadata_output_dir();
            outputPrefix = this.getMetadata_output_file_prefix();
            RGID = getProperty("RGID");
            RGLB = getProperty("RGLB");
            RGPL = getProperty("RGPL");
            RGPU = getProperty("RGPU");
            RGSM = getProperty("RGSM");
            bwaAlignMemG = getProperty("bwaAlignMemG") == null ? "8" : getProperty("bwaAlignMemG");
            bwaSampeMemG = getProperty("bwaSampeMemG") == null ? "8" : getProperty("bwaSampeMemG");
            picardReadGrpMem = getProperty("picardReadGrpMem") == null ? "8" : getProperty("picardReadGrpMem");
            additionalPicardParams = getProperty("additionalPicardParams");


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
        
        ArrayList<Job> bamJobs = new ArrayList<Job>();
        
        // DOWNLOAD DATA
        // let's start by downloading the input BAMs
        Job gtDownloadJob = this.getWorkflow().createBashJob("gtdownload");
        gtDownloadJob.getCommand().addArgument("gtdownload")
                .addArgument("-c "+gnosKey)
                .addArgument("-v -d")
                .addArgument(gnosInputFileURL);
        
        // TODO for loop here
        int numBamFiles = bamPaths.size();
        for (int i=0; i<numBamFiles; i++) {
            
            String file = bamPaths.get(i);
        
            // BWA ALN STEPS
            //bwa aln   -t 8 -b1 ./reference/genome.fa.gz ./HG00096.chrom20.ILLUMINA.bwa.GBR.low_coverage.20120522.bam_000000.bam > aligned_1.sai 2> aligned_1.err
            //bwa aln   -t 8 -b2 ./reference/genome.fa.gz ./HG00096.chrom20.ILLUMINA.bwa.GBR.low_coverage.20120522.bam_000000.bam > aligned_2.sai 2> aligned_2.err
            Job job01 = this.getWorkflow().createBashJob("bwa_align1_"+i);
            job01.addParent(gtDownloadJob);
            job01.getCommand().addArgument(this.getWorkflowBaseDir() + "/bin/bwa-0.6.2/bwa aln ")
                    .addArgument(this.parameters("aln") == null ? " " : this.parameters("aln"))
                    .addArgument(reference_path+" -b1 ")
                    .addArgument(file)
                    .addArgument(" > aligned_"+i+"_1.sai");
            job01.setMaxMemory(bwaAlignMemG+"000");
   
            Job job02 = this.getWorkflow().createBashJob("bwa_align2_"+i);
            job02.addParent(gtDownloadJob);
            job02.getCommand().addArgument(this.getWorkflowBaseDir() + "/bin/bwa-0.6.2/bwa aln ")
                    .addArgument(this.parameters("aln") == null ? " " : this.parameters("aln"))
                    .addArgument(reference_path+" -b1 ")
                    .addArgument(file)
                    .addArgument(" > aligned_"+i+"_2.sai");
            job02.setMaxMemory(bwaAlignMemG+"000");
            
            // BWA SAMPE + CONVERT TO BAM
            //bwa sampe reference/genome.fa.gz aligned_1.sai aligned_2.sai HG00096.chrom20.ILLUMINA.bwa.GBR.low_coverage.20120522.bam_000000.bam HG00096.chrom20.ILLUMINA.bwa.GBR.low_coverage.20120522.bam_000000.bam > aligned.sam
            Job job03 = this.getWorkflow().createBashJob("bwa_sam_bam_"+i);
            job03.getCommand().addArgument(this.getWorkflowBaseDir() + "/bin/bwa-0.6.2/bwa sampe ")
            .addArgument(this.parameters("sampe").isEmpty() ? " " : this.parameters("sampe"))
            .addArgument(reference_path)
            .addArgument("aligned_"+i+"_1.sai")
            .addArgument("aligned_"+i+"_2.sai")
            .addArgument(file)
            .addArgument(file)
            .addArgument(" | java -Xmx"+bwaSampeMemG+"g -jar ")
            .addArgument(this.getWorkflowBaseDir() + "/bin/picard-tools-1.89/SortSam.jar")
            .addArgument("I=/dev/stdin TMP_DIR=./ VALIDATION_STRINGENCY=SILENT")
            .addArgument("SORT_ORDER=coordinate CREATE_INDEX=true")
            .addArgument("O=out_"+i+".bam");
            job03.addParent(job01);
            job03.addParent(job02);
            job03.setMaxMemory(bwaSampeMemG+"000");
            bamJobs.add(job03);        

        }
       
        // MERGE AND READGROUPS
        // add read groups and merge, will probably want to do this per bam above and just merge here with read groups to track... not sure if this will work properly
	Job job04 = this.getWorkflow().createBashJob("addReadGroups");
	job04.getCommand().addArgument("java -Xmx"+picardReadGrpMem+"g -jar "
                + this.getWorkflowBaseDir() + "/bin/picard-tools-1.89/AddOrReplaceReadGroups.jar "
                + " RGID=" + RGID
                + " RGLB=" + RGLB
                + " RGPL=" + RGPL
                + " RGPU=" + RGPU
                + " RGSM=" + RGSM
                + " " + (additionalPicardParams.isEmpty() ? "" : additionalPicardParams));
        for (int i=0; i<numBamFiles; i++) { job04.getCommand().addArgument(" I=out_"+i+".bam" ); }
        job04.getCommand().addArgument(" O=" + this.dataDir + outputFileName + " >> "+this.dataDir+outputFileName + ".out 2>> "+this.dataDir+outputFileName +".err");
	for (Job pJob : bamJobs) { 
            System.err.println("DEBUG: "+pJob);
            job04.addParent(pJob); 
        }
	job04.setMaxMemory(picardReadGrpMem+"000");
        
        // PREPARE METADATA & UPLOAD
        Job job05 = this.getWorkflow().createBashJob("upload");
        job05.getCommand().addArgument("perl " + this.getWorkflowBaseDir() + "/scripts/upload_data.pl")
                .addArgument("--bam "+this.dataDir + outputFileName)
                .addArgument("--key "+gnosKey)
                .addArgument("--url "+gnosUploadFileURL);
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
}
