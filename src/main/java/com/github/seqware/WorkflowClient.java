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
    String gnosKey = null;
    // number of splits for bam files, default 1=no split
    int bamSplits = 1;
    String reference_path = null;
    String outputPrefix = null;
    String outputDir = null;
    String dataDir = "data";
    String outputFileName = null;
    //BWA
    String RGID;
    String RGLB;
    String RGPL;
    String RGPU;
    String RGSM;
    String additionalPicardParams;
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
            gnosKey = getProperty("gnos_key");
            reference_path = getProperty("input_reference");
            outputDir = this.getMetadata_output_dir();
            outputPrefix = this.getMetadata_output_file_prefix();
            RGID = getProperty("RGID");
            RGLB = getProperty("RGLB");
            RGPL = getProperty("RGPL");
            RGPU = getProperty("RGPU");
            RGSM = getProperty("RGSM");
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
        
            // EXAMPLE
            //bwa aln   -t 8 -b1 ./reference/genome.fa.gz ./HG00096.chrom20.ILLUMINA.bwa.GBR.low_coverage.20120522.bam_000000.bam > aligned_1.sai 2> aligned_1.err
            //bwa aln   -t 8 -b2 ./reference/genome.fa.gz ./HG00096.chrom20.ILLUMINA.bwa.GBR.low_coverage.20120522.bam_000000.bam > aligned_2.sai 2> aligned_2.err
            Job job01 = this.getWorkflow().createBashJob("bwa_align1_"+i);
            job01.addParent(gtDownloadJob);
            job01.getCommand().addArgument(this.getWorkflowBaseDir() + "/bin/bwa-0.6.2/bwa aln ")
                    .addArgument(this.parameters("aln") == null ? " " : this.parameters("aln"))
                    .addArgument(reference_path+" -b1 ")
                    .addArgument(file)
                    .addArgument(" > aligned_"+i+"_1.sai 2> aligned_"+i+"_1.err");
            job01.setMaxMemory("8000");
   
            Job job02 = this.getWorkflow().createBashJob("bwa_align2_"+i);
            job02.addParent(gtDownloadJob);
            job02.getCommand().addArgument(this.getWorkflowBaseDir() + "/bin/bwa-0.6.2/bwa aln ")
                    .addArgument(this.parameters("aln") == null ? " " : this.parameters("aln"))
                    .addArgument(reference_path+" -b1 ")
                    .addArgument(file)
                    .addArgument(" > aligned_"+i+"_2.sai 2> aligned_"+i+"_2.err");
            job02.setMaxMemory("8000");
            
            // EXAMPLE:
            //bwa sampe reference/genome.fa.gz aligned_1.sai aligned_2.sai HG00096.chrom20.ILLUMINA.bwa.GBR.low_coverage.20120522.bam_000000.bam HG00096.chrom20.ILLUMINA.bwa.GBR.low_coverage.20120522.bam_000000.bam > aligned.sam
            Job job03 = this.getWorkflow().createBashJob("bwa_sam_bam_"+i);
            job03.getCommand().addArgument(this.getWorkflowBaseDir() + "/bin/bwa-0.6.2/bwa sampe ")
            .addArgument(this.parameters("sampe").isEmpty() ? " " : this.parameters("sampe"))
            .addArgument(reference_path)
            .addArgument("aligned_"+i+"_1.sai")
            .addArgument("aligned_"+i+"_2.sai")
            .addArgument(file)
            .addArgument(file)
            .addArgument(" > out_"+i+".sam 2> sampe_error_"+i+".log");
            job03.addParent(job01);
            job03.addParent(job02);
            job03.setMaxMemory("8000");

        }
       
	/* Job job04 = this.getWorkflow().createBashJob("addReadGroups");
	job04.getCommand().addArgument("java -Xmx2g -jar "
                + this.getWorkflowBaseDir() + "/bin/picard-tools-1.89/AddOrReplaceReadGroups.jar "
                + " RGID=" + RGID
                + " RGLB=" + RGLB
                + " RGPL=" + RGPL
                + " RGPU=" + RGPU
                + " RGSM=" + RGSM
                + " " + (additionalPicardParams.isEmpty() ? "" : additionalPicardParams)
                + " I=" + this.dataDir + outputFileName + ".norg"
                + " O=" + this.dataDir + outputFileName + " >> "+this.dataDir+outputFileName + ".out 2>> "+this.dataDir+outputFileName +".err");
	job04.addParent(job03);
	job04.setQueue(queue);
	job04.setMaxMemory("8000");
	job04.addFile(file2); */
 
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
